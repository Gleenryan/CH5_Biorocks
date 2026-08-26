from __future__ import annotations

from typing import List

import numpy as np

from reef_pipeline.audio import frame_views
from reef_pipeline.config import (
    STAGE1_BASELINE_S,
    STAGE1_EXCESS_DB,
    STAGE1_FLATNESS_MIN,
    STAGE1_FRAME_S,
    STAGE1_HOP_S,
    STAGE1_REFRACTORY_S,
    STAGE1_RISE_S,
)
from reef_pipeline.features.indices import spectral_flatness


def _frame_rms(y: np.ndarray, sr: int, frame_s: float, hop_s: float) -> np.ndarray:
    frame = max(8, int(round(frame_s * sr)))
    hop = max(1, int(round(hop_s * sr)))
    frames = frame_views(y, frame, hop)
    return np.sqrt(np.mean(frames.astype(np.float64) ** 2, axis=1) + 1e-20)


def _rise_time_s(env: np.ndarray, sr: int, peak_idx: int) -> float:
    peak = float(env[peak_idx])
    if peak <= 0:
        return 1e9
    thresh = 0.1 * peak
    i = peak_idx
    while i > 0 and env[i] > thresh:
        i -= 1
    return (peak_idx - i) / sr


def stage1_candidates(
    y: np.ndarray,
    sr: int,
    excess_db: float = STAGE1_EXCESS_DB,
    baseline_s: float = STAGE1_BASELINE_S,
    rise_s: float = STAGE1_RISE_S,
    flatness_min: float = STAGE1_FLATNESS_MIN,
    frame_s: float = STAGE1_FRAME_S,
    hop_s: float = STAGE1_HOP_S,
    refractory_s: float = STAGE1_REFRACTORY_S,
    **kwargs,
) -> List[dict]:
    excess_db = kwargs.get("excess_db", excess_db)
    baseline_s = kwargs.get("baseline_s", baseline_s)
    y = np.asarray(y, dtype=np.float32)
    hop = max(1, int(round(hop_s * sr)))
    energy = _frame_rms(y, sr, frame_s, hop_s)
    if energy.size == 0:
        return []
    energy_db = 20.0 * np.log10(energy + 1e-20)
    n_base = max(3, int(round(baseline_s / hop_s)))
    baseline = np.empty_like(energy_db)
    for i in range(len(energy_db)):
        lo = max(0, i - n_base)
        hi = max(lo + 1, i)
        baseline[i] = np.median(energy_db[lo:hi])
    excess = energy_db - baseline
    peaks: List[dict] = []
    last_t = -1e9
    for i, ex in enumerate(excess):
        t = i * hop_s
        if ex < excess_db or (t - last_t) < refractory_s:
            continue
        peak_sample = min(len(y) - 1, i * hop + hop // 2)
        w0 = max(0, peak_sample - int(0.1 * sr))
        w1 = min(len(y), peak_sample + int(0.1 * sr))
        snippet = y[w0:w1]
        if snippet.size < 16:
            continue
        env = np.abs(snippet.astype(np.float64))
        local_peak = int(np.argmax(env))
        rise = _rise_time_s(env, sr, local_peak)
        if rise > rise_s:
            continue
        flat = spectral_flatness(snippet, sr)
        if flat < flatness_min:
            continue
        t_peak = w0 / sr + local_peak / sr
        peaks.append(
            {
                "t_peak": t_peak,
                "t_start": max(0.0, t_peak - 0.05),
                "t_end": t_peak + 0.15,
                "excess_db": float(ex),
                "rise_s": float(rise),
                "flatness": float(flat),
            }
        )
        last_t = t
    return peaks
