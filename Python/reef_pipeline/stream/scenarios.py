"""Simulator scenarios that stream into Coralyst (matches SimulatorCatalog.fleet)."""

from __future__ import annotations

import tempfile
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

import numpy as np

from reef_pipeline import EVENT_AMBIENT, EVENT_BLAST, EVENT_BOAT, EVENT_MECHANICAL
from reef_pipeline.audio import load_audio, list_wavs
from reef_pipeline.config import SR, data_root, ind_n1_dir, reefset_dir
from reef_pipeline.simulator.run import simulate


@dataclass
class GroundTruthEvent:
    id: str
    t_onset_seconds: float
    t_offset_seconds: float
    label: str
    expected_alert: bool
    source_clip_id: str
    notes: str = ""

    def as_wire(self) -> dict:
        return {
            "id": self.id,
            "tOnsetSeconds": self.t_onset_seconds,
            "tOffsetSeconds": self.t_offset_seconds,
            "label": self.label,
            "expectedAlert": self.expected_alert,
            "sourceClipId": self.source_clip_id,
            "notes": self.notes,
        }


@dataclass
class Scenario:
    id: str
    name: str
    duration_seconds: float
    construction: str
    description: str
    events: List[GroundTruthEvent] = field(default_factory=list)
    builder: Optional[Callable[[int], Tuple[np.ndarray, List[GroundTruthEvent]]]] = None

    def mix(self, seed: int = 7) -> Tuple[np.ndarray, List[GroundTruthEvent]]:
        assert self.builder is not None
        audio, events = self.builder(seed)
        if events:
            self.events = events
        return audio, self.events

    def hello_payload(
        self,
        hydrophone_id: str,
        hydrophone_name: str,
        site_name: str,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        events: Optional[List[GroundTruthEvent]] = None,
    ) -> dict:
        evs = events if events is not None else self.events
        payload = {
            "type": "hello",
            "protocol": "reefguard-hydro-v1",
            "hydrophoneId": hydrophone_id,
            "hydrophoneName": hydrophone_name,
            "siteName": site_name,
            "sampleRate": SR,
            "channels": 1,
            "scenarioId": self.id,
            "scenarioName": self.name,
            "source": "reef_pipeline",
            "construction": self.construction,
            "durationSeconds": self.duration_seconds,
            "events": [e.as_wire() for e in evs],
            "domainScope": "indonesia_hydromoth",
        }
        if latitude is not None:
            payload["latitude"] = latitude
        if longitude is not None:
            payload["longitude"] = longitude
        return payload


def _has_real_data() -> bool:
    root = data_root()
    return ind_n1_dir(root).is_dir() and bool(list_wavs(ind_n1_dir(root))) and reefset_dir(root).is_dir()


def _synthetic_ambient(duration: float, seed: int, snap_rate: float = 80.0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = int(round(duration * SR))
    y = rng.normal(0, 0.008, size=n).astype(np.float64)
    n_snaps = max(1, int(duration * snap_rate / 60.0))
    for t in rng.uniform(0, duration, size=n_snaps):
        i = int(t * SR)
        if 0 <= i < n - 8:
            y[i : i + 8] += rng.normal(0, 0.15, size=8)
    peak = np.max(np.abs(y))
    if peak > 0.95:
        y *= 0.95 / peak
    return y


def _synthetic_impulse(duration: float, onset: float, seed: int, gain: float = 0.4) -> np.ndarray:
    y = _synthetic_ambient(duration, seed, snap_rate=40.0)
    i = int(onset * SR)
    t = np.arange(int(0.08 * SR)) / SR
    impulse = gain * np.exp(-t * 60.0) * np.sin(2 * np.pi * 180 * t)
    end = min(len(y), i + len(impulse))
    y[i:end] += impulse[: end - i]
    peak = np.max(np.abs(y))
    if peak > 0.95:
        y *= 0.95 / peak
    return y


def _synthetic_boat(duration: float, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    y = _synthetic_ambient(duration, seed, snap_rate=30.0)
    n = len(y)
    t = np.arange(n) / SR
    rumble = 0.12 * np.sin(2 * np.pi * 45 * t) + 0.06 * np.sin(2 * np.pi * 90 * t)
    rumble *= np.linspace(0.2, 1.0, n)
    rumble += rng.normal(0, 0.01, size=n)
    y += rumble
    peak = np.max(np.abs(y))
    if peak > 0.95:
        y *= 0.95 / peak
    return y


def _simulate_rates(
    duration: float,
    seed: int,
    rates: Dict[str, float],
) -> Tuple[np.ndarray, List[GroundTruthEvent]]:
    if not _has_real_data():
        # Lightweight fallback when ReefSet / ind_N1 are not mounted.
        if rates.get(EVENT_BLAST, 0) > 0:
            onset = max(4.0, duration * 0.35)
            audio = _synthetic_impulse(duration, onset, seed)
            return audio, [
                GroundTruthEvent(
                    id="gt-blast-1",
                    t_onset_seconds=onset,
                    t_offset_seconds=onset + 0.15,
                    label="blast",
                    expected_alert=True,
                    source_clip_id="synthetic:impulse",
                    notes="Synthetic fallback (no REEFGUARD_RAW_DATA).",
                )
            ]
        if rates.get(EVENT_BOAT, 0) > 0:
            audio = _synthetic_boat(duration, seed)
            return audio, [
                GroundTruthEvent(
                    id="gt-boat",
                    t_onset_seconds=0.0,
                    t_offset_seconds=duration,
                    label="boat_engine",
                    expected_alert=False,
                    source_clip_id="synthetic:boat",
                )
            ]
        audio = _synthetic_ambient(duration, seed)
        return audio, [
            GroundTruthEvent(
                id="gt-ambient",
                t_onset_seconds=0.0,
                t_offset_seconds=duration,
                label="shrimp",
                expected_alert=False,
                source_clip_id="synthetic:ambient",
            )
        ]

    root = data_root()
    with tempfile.TemporaryDirectory(prefix="reef_stream_") as tmp:
        out_wav = Path(tmp) / "mix.wav"
        out_man = Path(tmp) / "manifest.jsonl"
        injected = simulate(
            background_dir=ind_n1_dir(root),
            out_wav=out_wav,
            out_manifest=out_man,
            duration_s=duration,
            snr_db=(6.0, 12.0),
            events_per_minute=rates,
            seed=seed,
            root=root,
        )
        audio, _ = load_audio(out_wav, sr=SR)
    events = [
        GroundTruthEvent(
            id=e.event_id,
            t_onset_seconds=e.t_start,
            t_offset_seconds=e.t_end,
            label=e.type,
            expected_alert=(e.type == EVENT_BLAST),
            source_clip_id=e.source_clip,
            notes=f"snr={e.snr_db:.1f}dB domain=indonesia_hydromoth",
        )
        for e in injected
    ]
    return audio.astype(np.float64), events


SCENARIOS: Dict[str, Scenario] = {}


def _register(s: Scenario) -> Scenario:
    SCENARIOS[s.id] = s
    return s


_register(
    Scenario(
        id="blast_in_ambient",
        name="Blast in reef ambient",
        duration_seconds=30.0,
        construction="reef_pipeline_simulate",
        description="Real ind_N1 background + exactly one ReefSet blast inject.",
        builder=lambda seed: _simulate_rates(
            30.0,
            seed,
            {
                EVENT_BLAST: 2.0,  # ~1 in 30s
                EVENT_BOAT: 0.0,
                EVENT_MECHANICAL: 0.0,
                EVENT_AMBIENT: 1.0,
            },
        ),
    )
)

_register(
    Scenario(
        id="ambient",
        name="Reef ambient (no blast)",
        duration_seconds=30.0,
        construction="reef_pipeline_simulate",
        description="Ambient / biophony only. Expect zero blast alerts.",
        builder=lambda seed: _simulate_rates(
            30.0,
            seed,
            {
                EVENT_BLAST: 0.0,
                EVENT_BOAT: 0.0,
                EVENT_MECHANICAL: 0.0,
                EVENT_AMBIENT: 4.0,
            },
        ),
    )
)

_register(
    Scenario(
        id="boat_pass",
        name="Boat pass, no blast",
        duration_seconds=30.0,
        construction="reef_pipeline_simulate",
        description="Boat energy over reef ambient. Expect no blast promote.",
        builder=lambda seed: _simulate_rates(
            30.0,
            seed,
            {
                EVENT_BLAST: 0.0,
                EVENT_BOAT: 4.0,
                EVENT_MECHANICAL: 0.0,
                EVENT_AMBIENT: 1.0,
            },
        ),
    )
)


def get_scenario(scenario_id: str) -> Scenario:
    if scenario_id not in SCENARIOS:
        known = ", ".join(sorted(SCENARIOS))
        raise SystemExit(f"unknown scenario {scenario_id!r}. Choose one of: {known}")
    return SCENARIOS[scenario_id]


# Keep legacy scenario builders for single-stream CLI; fleet uses fleet_audio.py.
SIMULATOR_FLEET = [
    {
        "site_name": "Indonesia N1",
        "hydrophone_name": "Hydrophone 1",
        "scenario": "blast_in_ambient",
        "latitude": -8.1287,
        "longitude": 114.6608,
        "seed": 7,
    },
]


def hydrophone_uuid(name: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, name))
