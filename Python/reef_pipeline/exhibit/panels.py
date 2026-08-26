"""Shared live state for exhibition scene (synced to streamed audio time)."""

from __future__ import annotations

from dataclasses import dataclass, field
from threading import Lock
from typing import List, Optional, Sequence, Tuple

import numpy as np

from reef_pipeline.stream.protocol import SAMPLE_RATE

WINDOW_SECONDS = 2.0


@dataclass
class HydroPanelState:
    name: str
    site_name: str
    contains_blast: bool
    latitude: float
    longitude: float
    blast_windows: List[Tuple[float, float]] = field(default_factory=list)
    connected: bool = False
    t_seconds: float = 0.0
    status: str = "waiting"
    _lock: Lock = field(default_factory=Lock, repr=False)
    _capacity: int = field(default=int(WINDOW_SECONDS * SAMPLE_RATE), repr=False)
    _buf: np.ndarray = field(default_factory=lambda: np.zeros(0, dtype=np.float32), repr=False)

    def __post_init__(self) -> None:
        self._buf = np.zeros(self._capacity, dtype=np.float32)
        self._fill = 0

    def push(self, samples: np.ndarray, t_seconds: float) -> None:
        samples = np.asarray(samples, dtype=np.float32).reshape(-1)
        with self._lock:
            n = samples.size
            if n >= self._capacity:
                self._buf[:] = samples[-self._capacity :]
                self._fill = self._capacity
            elif self._fill + n <= self._capacity:
                self._buf[self._fill : self._fill + n] = samples
                self._fill += n
            else:
                keep = self._capacity - n
                self._buf[:keep] = self._buf[self._fill - keep : self._fill]
                self._buf[keep:] = samples
                self._fill = self._capacity
            self.t_seconds = float(t_seconds)
            self.connected = True
            self.status = "live"

    def snapshot(self) -> Tuple[float, bool, str, float]:
        """Return (t_seconds, connected, status, rms)."""
        with self._lock:
            audio = self._buf[: self._fill]
            rms = float(np.sqrt(np.mean(np.square(audio)))) if audio.size else 0.0
            return self.t_seconds, self.connected, self.status, rms

    def near_blast(self, t: float, pad: float = 0.4) -> bool:
        for onset, offset in self.blast_windows:
            if (onset - pad) <= t <= (offset + pad):
                return True
        return False

    def blast_progress(self, t: float) -> Optional[float]:
        """0..1 during an active blast window, else None."""
        for onset, offset in self.blast_windows:
            if onset <= t <= offset + 0.8:
                span = max(offset - onset, 0.3)
                return float(np.clip((t - onset) / span, 0.0, 1.0))
        return None


def blast_windows_from_events(events: Sequence[dict]) -> List[Tuple[float, float]]:
    windows: List[Tuple[float, float]] = []
    for event in events:
        label = str(event.get("label") or "")
        expected = bool(event.get("expectedAlert"))
        if label == "blast" or expected:
            onset = float(event.get("tOnsetSeconds") or 0.0)
            offset = float(event.get("tOffsetSeconds") or (onset + 1.0))
            windows.append((onset, offset))
    return windows
