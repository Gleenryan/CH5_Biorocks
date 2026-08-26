"""Build Indonesia N1 fleet audio from real dataset files.

Genuine rules (no UI hardcoding):
- Exactly one hydrophone receives blast audio mixed into a field recording.
- The other hydrophones receive only normal long ind_N1 field WAVs (no blast clips).
- Which hydro gets the blast is chosen from the seed (not fixed in the UI).
- Alerts in the app come only from live Core ML on the streamed PCM.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

from reef_pipeline.audio import list_wavs, load_audio
from reef_pipeline.catalog import unique_blast_paths
from reef_pipeline.config import SR, data_root, ind_n1_dir
from reef_pipeline.simulator.run import mix_clip
from reef_pipeline.stream.scenarios import GroundTruthEvent, hydrophone_uuid

# Positions only — no blast role baked into a specific name for the UI.
FLEET_SPECS: List[Dict[str, Any]] = [
    {
        "site_name": "Indonesia N1",
        "hydrophone_name": "Hydrophone 1",
        "latitude": -8.1287,
        "longitude": 114.6608,
    },
    {
        "site_name": "Indonesia N1",
        "hydrophone_name": "Hydrophone 2",
        "latitude": -8.1264,
        "longitude": 114.6636,
    },
    {
        "site_name": "Indonesia N1",
        "hydrophone_name": "Hydrophone 3",
        "latitude": -8.1312,
        "longitude": 114.6582,
    },
    {
        "site_name": "Indonesia N1",
        "hydrophone_name": "Hydrophone 4",
        "latitude": -8.1271,
        "longitude": 114.6574,
    },
]


def build_fleet_jobs(
    seed: int = 7,
    n_blasts: int = 1,
    root: Optional[Path] = None,
    synthetic: bool = False,
    duration_seconds: float = 45.0,
) -> List[Dict[str, Any]]:
    """Return stream jobs: one blast hydro + the rest pure field."""
    n_blasts = int(max(1, min(2, n_blasts)))
    root = root or data_root()
    if synthetic or not _has_field_wavs(root):
        print(
            "[fleet] using synthetic hydrophone audio "
            "(mount REEFGUARD_RAW_DATA with ind_N1 WAVs for real recordings)",
            flush=True,
        )
        return _synthetic_fleet_jobs(seed=seed, n_blasts=n_blasts, duration_seconds=duration_seconds)

    rng = np.random.default_rng(seed)

    field_files = _pick_long_field_wavs(len(FLEET_SPECS), seed=seed, root=root)
    blast_clips = _pick_blast_clips(n_blasts, seed=seed + 99, root=root)

    # Exactly one hydrophone carries blast audio this run.
    blast_index = int(rng.integers(0, len(FLEET_SPECS)))

    jobs: List[Dict[str, Any]] = []
    for i, spec in enumerate(FLEET_SPECS):
        job = dict(spec)
        job["hydrophone_id"] = hydrophone_uuid(spec["hydrophone_name"])
        job["seed"] = int(seed + i * 17)
        wav = field_files[i]

        if i == blast_index:
            audio, events, sources = _mix_blasts_into_field(
                wav, blast_clips, seed=int(job["seed"]), n_blasts=n_blasts
            )
            job.update(
                {
                    "scenario": "field_with_blast",
                    # Filename only — do not put "BLAST" into the UI label.
                    "scenario_name": wav.name,
                    "audio": audio,
                    "events": events,
                    "audio_files": sources,
                    "contains_blast_audio": True,
                }
            )
        else:
            audio, _ = load_audio(wav, sr=SR)
            audio = _normalize_field(audio.astype(np.float64))
            dur = len(audio) / SR
            job.update(
                {
                    "scenario": "field_recording",
                    "scenario_name": wav.name,
                    "audio": audio,
                    "events": [
                        GroundTruthEvent(
                            id=f"field-{spec['hydrophone_name']}",
                            t_onset_seconds=0.0,
                            t_offset_seconds=dur,
                            label="field",
                            expected_alert=False,
                            source_clip_id=str(wav),
                            notes="Field recording only; no blast clip mixed in.",
                        )
                    ],
                    "audio_files": [str(wav)],
                    "contains_blast_audio": False,
                }
            )
        jobs.append(job)

    blast_jobs = [j for j in jobs if j.get("contains_blast_audio")]
    if len(blast_jobs) != 1:
        raise RuntimeError(f"expected exactly 1 blast hydro, got {len(blast_jobs)}")
    return jobs


def _has_field_wavs(root: Path) -> bool:
    folder = ind_n1_dir(root)
    try:
        return folder.is_dir() and bool(list_wavs(folder))
    except OSError:
        return False


def _add_impulse(audio: np.ndarray, onset: float, gain: float = 0.4) -> np.ndarray:
    out = np.asarray(audio, dtype=np.float64).copy()
    start = int(onset * SR)
    t = np.arange(int(0.08 * SR)) / SR
    impulse = gain * np.exp(-t * 60.0) * np.sin(2 * np.pi * 180 * t)
    end = min(len(out), start + len(impulse))
    if start >= 0 and end > start:
        out[start:end] += impulse[: end - start]
    peak = float(np.max(np.abs(out))) if len(out) else 0.0
    if peak > 0.95:
        out *= 0.95 / peak
    return out


def _synthetic_fleet_jobs(
    seed: int,
    n_blasts: int,
    duration_seconds: float,
) -> List[Dict[str, Any]]:
    """Four hydros that anyone can stream without the raw-data archive."""
    from reef_pipeline.stream.scenarios import _synthetic_ambient

    rng = np.random.default_rng(seed)
    blast_index = int(rng.integers(0, len(FLEET_SPECS)))
    duration = float(max(12.0, duration_seconds))
    jobs: List[Dict[str, Any]] = []
    for i, spec in enumerate(FLEET_SPECS):
        job = dict(spec)
        job["hydrophone_id"] = hydrophone_uuid(spec["hydrophone_name"])
        job["seed"] = int(seed + i * 17)
        audio = _synthetic_ambient(duration, seed=int(job["seed"]))
        if i == blast_index:
            onset = float(rng.uniform(8.0, min(18.0, duration - 4.0)))
            onsets = [onset]
            if n_blasts > 1:
                onsets.append(min(duration - 3.0, onset + 10.0))
            events: List[GroundTruthEvent] = []
            for blast_i, t0 in enumerate(onsets):
                audio = _add_impulse(audio, t0)
                events.append(
                    GroundTruthEvent(
                        id=f"gt-blast-{blast_i + 1}",
                        t_onset_seconds=t0,
                        t_offset_seconds=t0 + 0.15,
                        label="blast",
                        expected_alert=True,
                        source_clip_id="synthetic:impulse",
                        notes="Synthetic Docker/demo blast",
                    )
                )
            job.update(
                {
                    "audio": audio,
                    "events": events,
                    "scenario": "synthetic_fleet_blast",
                    "scenario_name": "Synthetic blast hydro",
                    "audio_files": ["synthetic:impulse"],
                    "contains_blast_audio": True,
                }
            )
        else:
            job.update(
                {
                    "audio": audio,
                    "events": [],
                    "scenario": "synthetic_fleet_field",
                    "scenario_name": "Synthetic field hydro",
                    "audio_files": ["synthetic:ambient"],
                    "contains_blast_audio": False,
                }
            )
        jobs.append(job)
    return jobs


def _pick_long_field_wavs(n: int, seed: int, root: Path) -> List[Path]:
    folder = ind_n1_dir(root)
    files = list_wavs(folder)
    if not files:
        raise FileNotFoundError(
            f"No field WAVs in {folder}. Set REEFGUARD_RAW_DATA to the raw-data folder."
        )
    ranked = sorted(files, key=lambda p: (-p.stat().st_size, p.name))
    rng = np.random.default_rng(seed)
    pool = ranked[: max(n * 8, n)]
    idx = rng.choice(len(pool), size=min(n, len(pool)), replace=False)
    chosen = [pool[int(i)] for i in idx]
    while len(chosen) < n:
        chosen.append(pool[len(chosen) % len(pool)])
    return chosen


def _pick_blast_clips(n: int, seed: int, root: Path) -> List[Path]:
    paths = [p for p in unique_blast_paths(root) if p.exists()]
    if not paths:
        from reef_pipeline.config import blasts_203_dir

        paths = list_wavs(blasts_203_dir(root))
    if not paths:
        raise FileNotFoundError("No blast clips found under REEFGUARD_RAW_DATA")
    rng = np.random.default_rng(seed)
    idx = rng.choice(len(paths), size=min(n, len(paths)), replace=False)
    return [paths[int(i)] for i in idx]


def _mix_blasts_into_field(
    background: Path,
    blast_clips: List[Path],
    seed: int,
    n_blasts: int,
    snr_db: float = 12.0,
) -> Tuple[np.ndarray, List[GroundTruthEvent], List[str]]:
    audio, _ = load_audio(background, sr=SR)
    audio = audio.astype(np.float64)
    duration = len(audio) / SR
    rng = np.random.default_rng(seed)
    events: List[GroundTruthEvent] = []
    sources = [str(background)]

    usable_start = min(10.0, max(6.0, duration * 0.15))
    usable_end = max(usable_start + 4.0, min(duration - 3.0, 35.0))
    onsets: List[float] = []
    for i in range(n_blasts):
        if i == 0:
            t = float(rng.uniform(usable_start, min(usable_start + 8.0, usable_end)))
        else:
            t = onsets[-1] + float(rng.uniform(8.0, 12.0))
            if t > usable_end - 2.0:
                t = usable_end - 2.0
        onsets.append(t)

    for i, (onset, clip_path) in enumerate(zip(onsets, blast_clips)):
        blast, _ = load_audio(clip_path, sr=SR)
        start = int(onset * SR)
        audio = mix_clip(audio, blast, start, snr_db, SR).astype(np.float64)
        dur = len(blast) / SR
        events.append(
            GroundTruthEvent(
                id=f"gt-blast-{i+1}",
                t_onset_seconds=onset,
                t_offset_seconds=onset + dur,
                label="blast",
                expected_alert=True,
                source_clip_id=str(clip_path),
                notes=f"Mixed into {background.name} @ {snr_db:.0f} dB SNR",
            )
        )
        sources.append(str(clip_path))

    peak = float(np.max(np.abs(audio))) if len(audio) else 0.0
    if peak > 1e-9:
        audio = audio * (0.45 / peak)
    return audio, events, sources


def _normalize_field(audio: np.ndarray, peak_target: float = 0.35) -> np.ndarray:
    audio = np.asarray(audio, dtype=np.float64)
    peak = float(np.max(np.abs(audio))) if len(audio) else 0.0
    if peak > 1e-9:
        audio = audio * (peak_target / peak)
    return audio
