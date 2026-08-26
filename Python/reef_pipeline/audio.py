from __future__ import annotations

from pathlib import Path
from typing import Tuple, Union

import numpy as np
from numpy.lib.stride_tricks import as_strided
from scipy.signal import resample_poly

try:
    import soundfile as sf
except ImportError:  # pragma: no cover
    sf = None

from reef_pipeline.config import SR

PathLike = Union[str, Path]


def load_audio(path: PathLike, sr: int = SR) -> Tuple[np.ndarray, int]:
    path = Path(path)
    if sf is not None:
        y, file_sr = sf.read(str(path), always_2d=False)
    else:
        from scipy.io import wavfile

        file_sr, y = wavfile.read(str(path))
        if np.issubdtype(y.dtype, np.integer):
            y = y.astype(np.float32) / np.iinfo(y.dtype).max
    y = np.asarray(y, dtype=np.float32)
    if y.ndim > 1:
        y = y.mean(axis=1).astype(np.float32)
    if file_sr != sr:
        y = resample_audio(y, file_sr, sr)
        file_sr = sr
    return y, int(file_sr)


def write_audio(path: PathLike, y: np.ndarray, sr: int = SR) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    y = np.asarray(y, dtype=np.float32)
    y = np.clip(y, -1.0, 1.0)
    if sf is not None:
        sf.write(str(path), y, sr, subtype="PCM_16")
    else:
        from scipy.io import wavfile

        wavfile.write(str(path), sr, (y * 32767.0).astype(np.int16))


def resample_audio(y: np.ndarray, orig_sr: int, target_sr: int) -> np.ndarray:
    if orig_sr == target_sr:
        return np.asarray(y, dtype=np.float32)
    g = np.gcd(orig_sr, target_sr)
    up = target_sr // g
    down = orig_sr // g
    out = resample_poly(y, up, down)
    return np.asarray(out, dtype=np.float32)


def rms(y: np.ndarray) -> float:
    y = np.asarray(y, dtype=np.float64)
    if y.size == 0:
        return 0.0
    return float(np.sqrt(np.mean(y * y) + 1e-20))


def db(x: float, floor: float = 1e-20) -> float:
    return float(20.0 * np.log10(max(x, floor)))


def apply_fade(
    y: np.ndarray,
    sr: int,
    fade_s: float,
    fade_in: bool = True,
    fade_out: bool = True,
) -> np.ndarray:
    """Linear fade in/out. fade_s is clamped to 10–50 ms by callers."""
    y = np.array(y, dtype=np.float32, copy=True)
    n = int(round(fade_s * sr))
    n = min(n, max(1, len(y) // 4))
    if n <= 1 or len(y) == 0:
        return y
    ramp = np.linspace(0.0, 1.0, n, dtype=np.float32)
    if fade_in:
        y[:n] *= ramp
    if fade_out:
        y[-n:] *= ramp[::-1]
    return y


def crossfade_concat(a: np.ndarray, b: np.ndarray, n: int) -> np.ndarray:
    if n <= 0 or len(a) == 0:
        return np.concatenate([a, b]) if len(a) or len(b) else np.zeros(0, dtype=np.float32)
    n = min(n, len(a), len(b))
    if n <= 0:
        return np.concatenate([a, b])
    w = np.linspace(0.0, 1.0, n, dtype=np.float32)
    mixed = a[-n:] * (1.0 - w) + b[:n] * w
    return np.concatenate([a[:-n], mixed, b[n:]])


def frame_views(y: np.ndarray, frame_len: int, hop: int) -> np.ndarray:
    y = np.ascontiguousarray(y, dtype=np.float32)
    if len(y) < frame_len:
        y = np.pad(y, (0, frame_len - len(y)))
    n_frames = 1 + (len(y) - frame_len) // hop
    shape = (n_frames, frame_len)
    strides = (y.strides[0] * hop, y.strides[0])
    return as_strided(y, shape=shape, strides=strides)


def pad_or_crop(y: np.ndarray, n: int) -> np.ndarray:
    y = np.asarray(y, dtype=np.float32)
    if len(y) == n:
        return y
    if len(y) > n:
        extra = len(y) - n
        start = extra // 2
        return y[start : start + n]
    return np.pad(y, (0, n - len(y)))


def list_wavs(folder: Path) -> list:
    """WAV paths in `folder`, case-insensitive (.wav / .WAV)."""
    folder = Path(folder)
    if not folder.exists():
        return []
    return sorted(
        p
        for p in folder.iterdir()
        if p.is_file() and p.suffix.lower() == ".wav" and not p.name.startswith(".")
    )


# Names used by detection / listen
frame_signal = frame_views
pad_or_trim = pad_or_crop
write_wav = write_audio

