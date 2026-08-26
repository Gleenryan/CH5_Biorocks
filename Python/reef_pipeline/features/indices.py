from __future__ import annotations

from typing import Dict, Optional, Tuple

import numpy as np
from scipy.signal import butter, hilbert, sosfiltfilt

try:
    import librosa
except ImportError:  # pragma: no cover
    librosa = None


def _power_spectrum(y: np.ndarray, sr: int, n_fft: int = 2048) -> Tuple[np.ndarray, np.ndarray]:
    y = np.asarray(y, dtype=np.float32)
    if librosa is not None:
        try:
            S = np.abs(librosa.stft(y, n_fft=n_fft, hop_length=n_fft // 4)) ** 2
            freqs = librosa.fft_frequencies(sr=sr, n_fft=n_fft)
            mag = S.mean(axis=1)
            return freqs, mag
        except Exception:
            pass
    n = min(n_fft, len(y))
    spec = np.fft.rfft(y[:n] * np.hanning(n), n=n_fft)
    mag = (np.abs(spec) ** 2).astype(np.float64)
    freqs = np.fft.rfftfreq(n_fft, 1.0 / sr)
    return freqs, mag


def _band_mask(freqs: np.ndarray, fmin: float, fmax: float) -> np.ndarray:
    nyq = freqs[-1] if len(freqs) else 0.0
    hi = min(fmax, nyq - 1e-6) if nyq else fmax
    return (freqs >= fmin) & (freqs < hi)


def _butter_band(y: np.ndarray, sr: int, fmin: float, fmax: float, order: int = 4) -> np.ndarray:
    nyq = 0.5 * sr
    lo = max(fmin / nyq, 1e-6)
    hi = min(fmax / nyq, 0.999)
    if hi <= lo:
        return np.asarray(y, dtype=np.float64)
    sos = butter(order, [lo, hi], btype="bandpass", output="sos")
    return sosfiltfilt(sos, np.asarray(y, dtype=np.float64))


def spl_band_db(y: np.ndarray, sr: int, fmin: float, fmax: float) -> float:
    """Uncalibrated band RMS in dBFS (20*log10). Not hydrophone-calibrated SPL."""
    band = _butter_band(y, sr, fmin, fmax)
    rms = float(np.sqrt(np.mean(band * band) + 1e-20))
    return 20.0 * np.log10(rms + 1e-20)


def snap_rate(y: np.ndarray, sr: int, percentile: float = 99.9, min_sep_s: float = 0.001) -> float:
    """Peaks/sec on the Hilbert envelope above the given percentile."""
    y = np.asarray(y, dtype=np.float64)
    if y.size < 8:
        return 0.0
    env = np.abs(hilbert(y))
    thr = np.percentile(env, percentile)
    min_sep = max(1, int(min_sep_s * sr))
    above = env > thr
    peaks = 0
    last = -min_sep
    i = 1
    n = len(env) - 1
    while i < n:
        if above[i] and env[i] >= env[i - 1] and env[i] >= env[i + 1] and (i - last) >= min_sep:
            peaks += 1
            last = i
            i += min_sep
        else:
            i += 1
    return peaks / (len(y) / sr)


def aci(y: np.ndarray, sr: int, n_fft: int = 512, hop: Optional[int] = None) -> float:
    """Acoustic Complexity Index (Pieretti). Unreliable on snapping-shrimp reefs."""
    hop = hop or n_fft // 4
    y = np.asarray(y, dtype=np.float32)
    S = None
    if librosa is not None:
        try:
            S = np.abs(librosa.stft(y, n_fft=n_fft, hop_length=hop))
        except Exception:
            S = None
    if S is None:
        from reef_pipeline.audio import frame_views

        frames = frame_views(y, n_fft, hop)
        win = np.hanning(n_fft).astype(np.float32)
        spec = np.fft.rfft(frames * win, axis=1)
        S = np.abs(spec).T
    if S.shape[1] < 2:
        return 0.0
    diff = np.abs(np.diff(S, axis=1))
    denom = S[:, :-1].sum(axis=1) + 1e-12
    return float(np.sum(diff.sum(axis=1) / denom))


def bi(y: np.ndarray, sr: int, fmin: float = 2000.0, fmax: float = 8000.0, n_fft: int = 2048) -> float:
    """Bioacoustic Index: sum of dB above the band floor, default 2–8 kHz."""
    freqs, mag = _power_spectrum(y, sr, n_fft=n_fft)
    mask = _band_mask(freqs, fmin, min(fmax, sr / 2.0 - 1.0))
    if not np.any(mask):
        return 0.0
    db = 10.0 * np.log10(mag[mask] + 1e-20)
    return float(np.sum(db - db.min()))


def band_proportions(
    y: np.ndarray,
    sr: int,
    bin_hz: float = 1000.0,
    fmin: float = 0.0,
    fmax: Optional[float] = None,
    n_fft: int = 2048,
    occupancy_db: float = -50.0,
) -> np.ndarray:
    """Occupied-bin proportions per `bin_hz` band (ADI/AEI input)."""
    fmax = fmax if fmax is not None else sr / 2.0
    freqs, mag = _power_spectrum(y, sr, n_fft=n_fft)
    db = 10.0 * np.log10(mag + 1e-20)
    edges = np.arange(fmin, fmax, bin_hz)
    if len(edges) < 2:
        edges = np.array([fmin, fmax])
    props = []
    for a, b in zip(edges, np.clip(edges + bin_hz, None, fmax)):
        mask = (freqs >= a) & (freqs < b)
        if not np.any(mask):
            props.append(0.0)
            continue
        occ = np.mean(db[mask] > occupancy_db)
        props.append(float(occ))
    p = np.asarray(props, dtype=np.float64)
    s = p.sum()
    if s <= 0:
        return p
    return p / s


def shannon_entropy(p: np.ndarray) -> float:
    p = np.asarray(p, dtype=np.float64)
    p = p[p > 0]
    if p.size == 0:
        return 0.0
    p = p / p.sum()
    h = -np.sum(p * np.log(p))
    return float(h / np.log(len(p))) if len(p) > 1 else 0.0


def adi(y: np.ndarray, sr: int, bin_hz: float = 1000.0, **kwargs) -> float:
    """Acoustic Diversity Index: Shannon entropy of per-band occupancy."""
    return shannon_entropy(band_proportions(y, sr, bin_hz=bin_hz, **kwargs))


def gini(x: np.ndarray) -> float:
    x = np.sort(np.asarray(x, dtype=np.float64).ravel())
    x = np.clip(x, 0, None)
    if x.size == 0 or x.sum() == 0:
        return 0.0
    n = x.size
    idx = np.arange(1, n + 1, dtype=np.float64)
    return float((2.0 * np.sum(idx * x) / (n * np.sum(x))) - (n + 1) / n)


def aei(y: np.ndarray, sr: int, bin_hz: float = 1000.0, **kwargs) -> float:
    """Acoustic Evenness Index: Gini of per-band occupancy proportions."""
    return gini(band_proportions(y, sr, bin_hz=bin_hz, **kwargs))


def aei_by_band(y: np.ndarray, sr: int, bin_hz: float = 1000.0, n_fft: int = 2048, **kwargs) -> np.ndarray:
    """Per-1 kHz-band Gini across FFT bins (frequency-resolved evenness)."""
    fmax = kwargs.pop("fmax", sr / 2.0)
    fmin = kwargs.pop("fmin", 0.0)
    freqs, mag = _power_spectrum(y, sr, n_fft=n_fft)
    edges = np.arange(fmin, fmax, bin_hz)
    out = []
    for a, b in zip(edges, np.clip(edges + bin_hz, None, fmax)):
        mask = (freqs >= a) & (freqs < b)
        out.append(gini(mag[mask]) if np.any(mask) else 0.0)
    return np.asarray(out, dtype=np.float64)


def entropy_h(y: np.ndarray, sr: int, n_fft: int = 1024, hop: Optional[int] = None) -> Dict[str, float]:
    """Ht × Hf (Sueur), each Shannon entropy normalized to 0–1."""
    hop = hop or n_fft // 4
    y = np.asarray(y, dtype=np.float64)
    env = np.abs(hilbert(y))
    ht = shannon_entropy(env)
    spec = None
    if librosa is not None:
        try:
            S = np.abs(librosa.stft(np.asarray(y, dtype=np.float32), n_fft=n_fft, hop_length=hop)) ** 2
            spec = S.mean(axis=1)
        except Exception:
            spec = None
    if spec is None:
        freqs, spec = _power_spectrum(y.astype(np.float32), sr, n_fft=n_fft)
        _ = freqs
    hf = shannon_entropy(spec)
    return {"ht": ht, "hf": hf, "h": ht * hf}


def spectral_flatness(y: np.ndarray, sr: int, n_fft: int = 1024) -> float:
    freqs, mag = _power_spectrum(y, sr, n_fft=n_fft)
    _ = freqs
    mag = np.maximum(mag, 1e-20)
    geo = np.exp(np.mean(np.log(mag)))
    arith = np.mean(mag)
    return float(geo / (arith + 1e-20))

