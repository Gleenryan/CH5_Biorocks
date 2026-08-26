from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterator, List, Optional, Sequence, Union

import numpy as np
import pandas as pd

from reef_pipeline.audio import load_audio
from reef_pipeline.config import (
    BI_FMAX,
    BI_FMIN,
    HOP_S,
    SPL_HIGH,
    SPL_LOW,
    SR,
    WINDOW_S,
)
from reef_pipeline.features.indices import (
    aci,
    aei,
    aei_by_band,
    adi,
    bi,
    entropy_h,
    snap_rate,
    spl_band_db,
)

ACI_SIDECAR = {
    "aci": {
        "confidence": "low_confidence",
        "reason": (
            "ACI is unreliable on dense reef soundscapes: snapping shrimp "
            "saturate the index so values stop tracking biological complexity."
        ),
    }
}


def window_starts(n: int, sr: int, window_s: float, hop_s: float) -> np.ndarray:
    win = int(round(window_s * sr))
    hop = max(1, int(round(hop_s * sr)))
    if n < win:
        return np.array([0], dtype=int)
    return np.arange(0, n - win + 1, hop, dtype=int)


def compute_window_features(y: np.ndarray, sr: int, bi_fmin: float = BI_FMIN, bi_fmax: float = BI_FMAX) -> dict:
    ent = entropy_h(y, sr)
    bands = aei_by_band(y, sr)
    return {
        "spl_low_db": spl_band_db(y, sr, SPL_LOW[0], SPL_LOW[1]),
        "spl_high_db": spl_band_db(y, sr, SPL_HIGH[0], min(SPL_HIGH[1], sr / 2.0 - 1.0)),
        "snap_rate": snap_rate(y, sr),
        "aci": aci(y, sr),
        "aci_confidence": "low_confidence",
        "bi": bi(y, sr, fmin=bi_fmin, fmax=min(bi_fmax, sr / 2.0 - 1.0)),
        "adi": adi(y, sr),
        "aei": aei(y, sr),
        "aei_by_band": json.dumps(bands.tolist()),
        "entropy_h": ent["h"],
        "entropy_ht": ent["ht"],
        "entropy_hf": ent["hf"],
    }


def extract_windows(
    source: Union[str, Path, np.ndarray],
    sr: int = SR,
    window_s: float = WINDOW_S,
    hop_s: float = HOP_S,
    source_id: str = "",
    bi_fmin: float = BI_FMIN,
    bi_fmax: float = BI_FMAX,
    **kwargs,
) -> pd.DataFrame:
    window_s = kwargs.get("window_s", window_s)
    hop_s = kwargs.get("hop_s", hop_s)
    source_id = kwargs.get("source_id", source_id)
    if isinstance(source, (str, Path)):
        y, sr = load_audio(source, sr=sr)
        source_id = source_id or str(source)
    else:
        y = np.asarray(source, dtype=np.float32)
    win = int(round(window_s * sr))
    starts = window_starts(len(y), sr, window_s, hop_s)
    rows = []
    for i, s0 in enumerate(starts):
        sl = y[s0 : s0 + win]
        if len(sl) < win:
            sl = np.pad(sl, (0, win - len(sl)))
        feat = compute_window_features(sl, sr, bi_fmin=bi_fmin, bi_fmax=bi_fmax)
        feat["window_id"] = i
        feat["t_start"] = s0 / sr
        feat["t_end"] = (s0 + win) / sr
        feat["source"] = source_id
        rows.append(feat)
    return pd.DataFrame(rows)


def iter_file_features(
    files: Sequence[Path],
    sr: int = SR,
    window_s: float = WINDOW_S,
    hop_s: float = HOP_S,
    **kwargs,
) -> Iterator[pd.DataFrame]:
    for p in files:
        yield extract_windows(p, sr=sr, window_s=window_s, hop_s=hop_s, **kwargs)


def write_features(df: pd.DataFrame, out: Path, sidecar: Optional[Path] = None) -> None:
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.suffix.lower() in {".parquet", ".pq"}:
        df.to_parquet(out, index=False)
    else:
        df.to_csv(out, index=False)
    side = sidecar or out.with_name(out.stem + "_meta.json")
    side.write_text(json.dumps(ACI_SIDECAR, indent=2))


def extract_windows_cli(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Extract ecoacoustic indices on a sliding window")
    p.add_argument("--input", required=True, help="WAV file or directory")
    p.add_argument("--out", required=True, help="CSV or parquet path")
    p.add_argument("--window-s", type=float, default=WINDOW_S)
    p.add_argument("--hop-s", type=float, default=HOP_S)
    p.add_argument("--sr", type=int, default=SR)
    p.add_argument("--bi-fmin", type=float, default=BI_FMIN)
    p.add_argument("--bi-fmax", type=float, default=BI_FMAX)
    args = p.parse_args(argv)
    inp = Path(args.input)
    files = list_wavs(inp) if inp.is_dir() else [inp]
    frames = [
        extract_windows(
            f,
            sr=args.sr,
            window_s=args.window_s,
            hop_s=args.hop_s,
            bi_fmin=args.bi_fmin,
            bi_fmax=args.bi_fmax,
        )
        for f in files
    ]
    df = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()
    write_features(df, Path(args.out))
    print(f"wrote {len(df)} windows -> {args.out}")
    return 0

