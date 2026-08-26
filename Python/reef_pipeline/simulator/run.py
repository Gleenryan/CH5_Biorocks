from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Iterator, List, Optional, Sequence, Tuple

import numpy as np

from reef_pipeline.audio import apply_fade, crossfade_concat, list_wavs, load_audio, rms, write_audio
from reef_pipeline.catalog import Clip, load_annotations, unique_blast_paths
from reef_pipeline.config import (
    CLIP_S,
    FADE_MS,
    FADE_MS_MAX,
    FADE_MS_MIN,
    SR,
    data_root,
    ind_n1_dir,
    reefset_wav_dir,
)
from reef_pipeline import EVENT_AMBIENT, EVENT_BLAST, EVENT_BOAT, EVENT_MECHANICAL


@dataclass
class InjectedEvent:
    event_id: str
    type: str
    t_start: float
    t_end: float
    snr_db: float
    source_clip: str
    source_dataset: str
    source_recorder: str

    def to_dict(self) -> dict:
        return asdict(self)


def fade_seconds(fade_ms: float) -> float:
    ms = min(max(fade_ms, FADE_MS_MIN), FADE_MS_MAX)
    return ms / 1000.0


def mix_clip(
    background: np.ndarray,
    clip: np.ndarray,
    start: int,
    snr_db: float,
    sr: int,
    fade_ms: float = FADE_MS,
    fade_in: bool = True,
    fade_out: bool = True,
) -> np.ndarray:
    """Add `clip` onto `background` at `start`, scaled to snr_db vs local RMS."""
    out = np.array(background, dtype=np.float32, copy=True)
    n = len(clip)
    if start < 0 or start >= len(out):
        return out
    end = min(len(out), start + n)
    n_use = end - start
    local = out[start:end]
    bg_rms = rms(local)
    cl = clip[:n_use]
    cl_rms = rms(cl)
    if cl_rms <= 0:
        return out
    gain = (bg_rms * (10.0 ** (snr_db / 20.0))) / cl_rms
    mixed = apply_fade(
        cl * np.float32(gain),
        sr,
        fade_seconds(fade_ms),
        fade_in=fade_in,
        fade_out=fade_out,
    )
    out[start:end] = np.clip(local + mixed[:n_use], -1.0, 1.0)
    return out


def _wavs(folder: Path) -> List[Path]:
    return list_wavs(folder)


class BackgroundReader:
    def __init__(self, files: Sequence[Path], sr: int, fade_ms: float):
        if not files:
            raise ValueError("no background files")
        self.files = list(files)
        self.sr = sr
        self.fade_n = int(round(fade_seconds(fade_ms) * sr))
        self._i = 0
        self._buf = np.zeros(0, dtype=np.float32)

    def _pull_file(self) -> None:
        y, _ = load_audio(self.files[self._i % len(self.files)], sr=self.sr)
        self._i += 1
        if len(self._buf) == 0:
            self._buf = y
        else:
            self._buf = crossfade_concat(self._buf, y, self.fade_n)

    def read(self, n: int) -> np.ndarray:
        while len(self._buf) < n:
            self._pull_file()
        out = self._buf[:n]
        self._buf = self._buf[n:]
        return out


def background_stream(
    files: Sequence[Path],
    sr: int = SR,
    fade_ms: float = FADE_MS,
    chunk_s: float = 1.0,
) -> Iterator[Tuple[float, np.ndarray]]:
    reader = BackgroundReader(files, sr, fade_ms)
    hop = int(chunk_s * sr)
    t = 0.0
    while True:
        chunk = reader.read(hop)
        yield t, chunk
        t += hop / sr


def _pick_clips(root: Path, rng: np.random.Generator) -> Dict[str, List[Clip]]:
    ann = load_annotations(root)
    by: Dict[str, List[Clip]] = {EVENT_BLAST: [], EVENT_BOAT: [], EVENT_MECHANICAL: [], EVENT_AMBIENT: []}
    for c in ann:
        if c.event_type in by and c.path.exists():
            by[c.event_type].append(c)
    extra = unique_blast_paths(root)
    if extra and not by[EVENT_BLAST]:
        for p in extra:
            by[EVENT_BLAST].append(
                Clip(
                    clip_id=p.stem,
                    path=p,
                    label="anthrop_bomb",
                    data_sharer="",
                    dataset="external_blast",
                    recorder="",
                    source="external",
                )
            )
    return by


def _schedule(
    duration_s: float,
    rates: Dict[str, float],
    rng: np.random.Generator,
) -> List[Tuple[str, float]]:
    """Poisson-like placements: rates are events per minute."""
    placed: List[Tuple[str, float]] = []
    min_gap = CLIP_S + 0.3
    for etype, rate in rates.items():
        if rate <= 0:
            continue
        n = int(np.round(rate * (duration_s / 60.0)))
        n = max(n, 0)
        for _ in range(n):
            t = float(rng.uniform(1.0, max(1.1, duration_s - CLIP_S - 1.0)))
            placed.append((etype, t))
    placed.sort(key=lambda x: x[1])
    kept: List[Tuple[str, float]] = []
    last_end = -1e9
    for etype, t in placed:
        if t < last_end + 0.05:
            continue
        kept.append((etype, t))
        last_end = t + min_gap
    return kept


def simulate(
    background_dir: Path,
    out_wav: Path,
    out_manifest: Path,
    duration_s: float = 120.0,
    sr: int = SR,
    fade_ms: float = FADE_MS,
    snr_db: Tuple[float, float] = (0.0, 12.0),
    events_per_minute: Optional[Dict[str, float]] = None,
    seed: int = 0,
    root: Optional[Path] = None,
    clip_pools: Optional[Dict[str, List[Clip]]] = None,
    **kwargs,
) -> List[InjectedEvent]:
    """Write a mixed WAV + JSONL ground-truth manifest."""
    duration_s = kwargs.get("duration_s", duration_s)
    events_per_minute = kwargs.get("events_per_minute", events_per_minute)
    clip_pools = kwargs.get("clip_pools", clip_pools)
    root = root or data_root()
    rates = events_per_minute or {
        EVENT_BLAST: 2.0,
        EVENT_BOAT: 2.0,
        EVENT_MECHANICAL: 1.0,
        EVENT_AMBIENT: 1.0,
    }
    rng = np.random.default_rng(seed)
    bg_files = _wavs(Path(background_dir))
    if not bg_files:
        raise FileNotFoundError(f"no wavs in {background_dir}")
    reader = BackgroundReader(bg_files, sr, fade_ms)
    n = int(round(duration_s * sr))
    background = reader.read(n)
    pools = clip_pools or _pick_clips(root, rng)
    schedule = _schedule(duration_s, rates, rng)
    events: List[InjectedEvent] = []
    mixed = background
    for i, (etype, t) in enumerate(schedule):
        pool = pools.get(etype) or []
        if not pool:
            continue
        clip_meta = pool[int(rng.integers(0, len(pool)))]
        y, _ = load_audio(clip_meta.path, sr=sr)
        snr = float(rng.uniform(snr_db[0], snr_db[1]))
        start = int(t * sr)
        mixed = mix_clip(mixed, y, start, snr, sr, fade_ms=fade_ms)
        dur = len(y) / sr
        events.append(
            InjectedEvent(
                event_id=f"inj_{i:04d}_{etype}",
                type=etype,
                t_start=t,
                t_end=t + dur,
                snr_db=snr,
                source_clip=str(clip_meta.path),
                source_dataset=clip_meta.dataset,
                source_recorder=clip_meta.recorder,
            )
        )
    write_audio(out_wav, mixed, sr)
    out_manifest = Path(out_manifest)
    out_manifest.parent.mkdir(parents=True, exist_ok=True)
    with open(out_manifest, "w") as f:
        for e in events:
            f.write(json.dumps(e.to_dict()) + "\n")
    return events


def simulate_stream(
    background_dir: Path,
    duration_s: float,
    chunk_s: float = 1.0,
    sr: int = SR,
    fade_ms: float = FADE_MS,
    snr_db: Tuple[float, float] = (0.0, 12.0),
    events_per_minute: Optional[Dict[str, float]] = None,
    seed: int = 0,
    root: Optional[Path] = None,
    clip_pools: Optional[Dict[str, List[Clip]]] = None,
) -> Iterator[Tuple[float, np.ndarray, List[InjectedEvent]]]:
    """Yield (t_start, chunk, events overlapping this chunk)."""
    root = root or data_root()
    rng = np.random.default_rng(seed)
    rates = events_per_minute or {EVENT_BLAST: 2.0, EVENT_BOAT: 1.0}
    bg_files = _wavs(Path(background_dir))
    reader = BackgroundReader(bg_files, sr, fade_ms)
    pools = clip_pools or _pick_clips(root, rng)
    schedule = _schedule(duration_s, rates, rng)
    prepared: List[Tuple[InjectedEvent, np.ndarray]] = []
    for i, (etype, t) in enumerate(schedule):
        pool = pools.get(etype) or []
        if not pool:
            continue
        clip_meta = pool[int(rng.integers(0, len(pool)))]
        y, _ = load_audio(clip_meta.path, sr=sr)
        snr = float(rng.uniform(snr_db[0], snr_db[1]))
        ev = InjectedEvent(
            event_id=f"inj_{i:04d}_{etype}",
            type=etype,
            t_start=t,
            t_end=t + len(y) / sr,
            snr_db=snr,
            source_clip=str(clip_meta.path),
            source_dataset=clip_meta.dataset,
            source_recorder=clip_meta.recorder,
        )
        prepared.append((ev, y))
    hop = int(chunk_s * sr)
    t = 0.0
    n_total = int(round(duration_s * sr))
    n_done = 0
    # Keep leftover mixed audio from previous overlap
    while n_done < n_total:
        take = min(hop, n_total - n_done)
        chunk = reader.read(take)
        t0 = t
        t1 = t + take / sr
        overlapping = []
        for ev, y in prepared:
            if ev.t_end <= t0 or ev.t_start >= t1:
                continue
            overlapping.append(ev)
            local_start = int(round((ev.t_start - t0) * sr))
            if local_start >= 0:
                fits = local_start + len(y) <= len(chunk)
                chunk = mix_clip(
                    chunk, y, local_start, ev.snr_db, sr, fade_ms=fade_ms,
                    fade_in=True, fade_out=fits,
                )
            else:
                skip = -local_start
                if skip < len(y):
                    rem = y[skip:]
                    fits = len(rem) <= len(chunk)
                    chunk = mix_clip(
                        chunk, rem, 0, ev.snr_db, sr, fade_ms=fade_ms,
                        fade_in=False, fade_out=fits,
                    )
        yield t0, chunk, overlapping
        t = t1
        n_done += take


def simulate_cli(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Build a synthetic hydrophone stream")
    p.add_argument("--background", default=None, help="Directory of background WAVs (default ind_N1)")
    p.add_argument("--out-wav", required=True)
    p.add_argument("--out-manifest", required=True)
    p.add_argument("--duration-s", type=float, default=120.0)
    p.add_argument("--snr-min", type=float, default=0.0)
    p.add_argument("--snr-max", type=float, default=12.0)
    p.add_argument("--fade-ms", type=float, default=FADE_MS)
    p.add_argument("--seed", type=int, default=0)
    p.add_argument("--blast-per-min", type=float, default=2.0)
    p.add_argument("--boat-per-min", type=float, default=2.0)
    p.add_argument("--mechanical-per-min", type=float, default=1.0)
    p.add_argument("--ambient-per-min", type=float, default=1.0)
    p.add_argument("--root", default=None)
    args = p.parse_args(argv)
    root = Path(args.root) if args.root else data_root()
    bg = Path(args.background) if args.background else ind_n1_dir(root)
    simulate(
        background_dir=bg,
        out_wav=Path(args.out_wav),
        out_manifest=Path(args.out_manifest),
        duration_s=args.duration_s,
        fade_ms=args.fade_ms,
        snr_db=(args.snr_min, args.snr_max),
        events_per_minute={
            EVENT_BLAST: args.blast_per_min,
            EVENT_BOAT: args.boat_per_min,
            EVENT_MECHANICAL: args.mechanical_per_min,
            EVENT_AMBIENT: args.ambient_per_min,
        },
        seed=args.seed,
        root=root,
    )
    print(f"wrote {args.out_wav} and {args.out_manifest}")
    return 0
