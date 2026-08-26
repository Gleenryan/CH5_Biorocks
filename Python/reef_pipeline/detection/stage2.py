from __future__ import annotations

import json
from pathlib import Path
from typing import List, Optional, Sequence, Tuple

import joblib
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from reef_pipeline.audio import load_audio, pad_or_crop
from reef_pipeline.catalog import Clip, blast_training_clips, negative_training_clips
from reef_pipeline.config import BLAST_WINDOW_S, SR
from reef_pipeline.features.indices import spectral_flatness

try:
    import librosa
except ImportError:  # pragma: no cover
    librosa = None


def _mel_vector(y: np.ndarray, sr: int, n_mels: int = 32, n_fft: int = 512) -> np.ndarray:
    y = pad_or_crop(np.asarray(y, dtype=np.float32), int(BLAST_WINDOW_S * sr))
    log_s = None
    if librosa is not None:
        try:
            S = librosa.feature.melspectrogram(
                y=y, sr=sr, n_mels=n_mels, n_fft=n_fft, hop_length=n_fft // 4
            )
            log_s = librosa.power_to_db(S, ref=np.max)
        except Exception:
            log_s = None
    if log_s is None:
        spec = np.abs(np.fft.rfft(y * np.hanning(len(y)))) ** 2
        log_s = 10.0 * np.log10(spec + 1e-20)
        idx = np.linspace(0, len(log_s) - 1, n_mels).astype(int)
        log_s = log_s[idx][:, None]
    vec = np.concatenate(
        [log_s.mean(axis=1), log_s.std(axis=1), log_s.max(axis=1), np.array([spectral_flatness(y, sr)])]
    )
    return np.nan_to_num(vec, nan=0.0, posinf=0.0, neginf=0.0)


def extract_features(y: np.ndarray, sr: int) -> np.ndarray:
    return _mel_vector(y, sr)


def pitch_shift(y: np.ndarray, rng: np.random.Generator, sr: int = SR) -> np.ndarray:
    """Resample by a few semitones, then pad/crop back to the original length."""
    from scipy.signal import resample

    n_st = float(rng.choice([-2, -1, 1, 2]))
    rate = 2.0 ** (n_st / 12.0)
    n_out = max(8, int(round(len(y) / rate)))
    shifted = resample(np.asarray(y, dtype=np.float64), n_out).astype(np.float32)
    return pad_or_crop(shifted, len(y))


def jitter(y: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    n = int(rng.integers(0, max(1, int(0.05 * len(y)))))
    if n:
        y = np.roll(y, int(rng.integers(-n, n + 1)))
    return y * np.float32(rng.uniform(0.7, 1.3))


def mix_noise(y: np.ndarray, noise: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    if len(noise) < len(y):
        reps = int(np.ceil(len(y) / max(1, len(noise))))
        noise = np.tile(noise, reps)
    start = int(rng.integers(0, max(1, len(noise) - len(y))))
    n = noise[start : start + len(y)]
    snr = float(rng.uniform(-3.0, 12.0))
    y_rms = float(np.sqrt(np.mean(y**2) + 1e-20))
    n_rms = float(np.sqrt(np.mean(n**2) + 1e-20))
    gain = y_rms / ((10 ** (snr / 20.0)) * n_rms + 1e-12)
    return np.clip(y + n * gain, -1.0, 1.0).astype(np.float32)


def _xy(
    positives: Sequence[Clip],
    negatives: Sequence[Clip],
    rng: np.random.Generator,
    noise_clips: Sequence[Clip],
    augment: bool,
    sr: int = SR,
) -> Tuple[np.ndarray, np.ndarray]:
    xs: List[np.ndarray] = []
    ys: List[int] = []

    def add(clip: Clip, label: int) -> None:
        y, _ = load_audio(clip.path, sr=sr)
        variants = [y]
        if augment:
            variants.append(jitter(y, rng))
            variants.append(pitch_shift(y, rng, sr))
            if noise_clips:
                nclip = noise_clips[int(rng.integers(0, len(noise_clips)))]
                ny, _ = load_audio(nclip.path, sr=sr)
                variants.append(mix_noise(y, ny, rng))
        for v in variants:
            xs.append(extract_features(v, sr))
            ys.append(label)

    for c in positives:
        add(c, 1)
    for c in negatives:
        add(c, 0)
    return np.vstack(xs), np.asarray(ys)


def train_blast_model(
    out_path: Path,
    positives: Optional[Sequence[Clip]] = None,
    negatives: Optional[Sequence[Clip]] = None,
    noise_clips: Optional[Sequence[Clip]] = None,
    seed: int = 0,
    augment: bool = True,
    max_neg: int = 800,
) -> Path:
    rng = np.random.default_rng(seed)
    positives = list(positives or blast_training_clips())
    negs = list(negatives or negative_training_clips(max_biophony=max_neg))
    if len(negs) > max_neg:
        idx = rng.choice(len(negs), size=max_neg, replace=False)
        negs = [negs[i] for i in idx]
    noise = list(noise_clips or [c for c in negs if c.dataset != "indonesia_bombs"][:200])
    X, y = _xy(positives, negs, rng, noise, augment=augment)
    clf = Pipeline(
        [
            ("scale", StandardScaler()),
            ("lr", LogisticRegression(max_iter=400, class_weight="balanced")),
        ]
    )
    clf.fit(X, y)
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": clf, "kind": "blast_lr", "window_s": BLAST_WINDOW_S}, out_path)
    out_path.with_suffix(".json").write_text(
        json.dumps({"n_pos": int(y.sum()), "n_neg": int((1 - y).sum())}, indent=2)
    )
    return out_path


def load_model(path: Path):
    obj = joblib.load(path)
    if isinstance(obj, dict) and "model" in obj:
        return obj["model"]
    return obj


def score_window(model, y: np.ndarray, sr: int) -> float:
    x = extract_features(y, sr).reshape(1, -1)
    if hasattr(model, "predict_proba"):
        return float(model.predict_proba(x)[0, 1])
    return float(model.decision_function(x)[0])
