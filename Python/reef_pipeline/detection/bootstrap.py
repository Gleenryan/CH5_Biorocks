from __future__ import annotations

import csv
import json
import shutil
from pathlib import Path
from typing import Optional

from reef_pipeline.audio import list_wavs, load_audio, pad_or_crop, write_audio
from reef_pipeline.config import BLAST_WINDOW_S, SR, ind_n1_dir
from .stage1 import stage1_candidates
from .stage2 import load_model, score_window


def bootstrap_ind_n1(
    out_dir: Path,
    model_path: Optional[Path] = None,
    audio_dir: Optional[Path] = None,
    max_files: Optional[int] = None,
    min_score: float = 0.3,
    sr: int = SR,
) -> Path:
    audio_dir = Path(audio_dir) if audio_dir else ind_n1_dir()
    out_dir = Path(out_dir)
    wav_dir = out_dir / "candidates"
    wav_dir.mkdir(parents=True, exist_ok=True)
    model = load_model(model_path) if model_path else None
    files = list_wavs(audio_dir)
    if max_files:
        files = files[:max_files]
    rows = []
    cid = 0
    win = int(BLAST_WINDOW_S * sr)
    for fp in files:
        y, _ = load_audio(fp, sr=sr)
        for cand in stage1_candidates(y, sr):
            peak = int(cand["t_peak"] * sr)
            sl = pad_or_crop(y[max(0, peak - win // 2) : peak + win // 2], win)
            score = score_window(model, sl, sr) if model is not None else float("nan")
            if model is not None and score < min_score:
                continue
            cid += 1
            snippet = wav_dir / f"cand_{cid:05d}.wav"
            write_audio(snippet, sl, sr)
            rows.append(
                {
                    "candidate_id": f"cand_{cid:05d}",
                    "source_file": str(fp),
                    "t_peak": cand["t_peak"],
                    "excess_db": cand["excess_db"],
                    "rise_s": cand["rise_s"],
                    "flatness": cand["flatness"],
                    "stage2_score": score,
                    "snippet": str(snippet),
                    "review_label": "",
                }
            )
    csv_path = out_dir / "candidates.csv"
    if rows:
        with open(csv_path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
    else:
        csv_path.write_text("candidate_id,review_label\n")
    (out_dir / "bootstrap_meta.json").write_text(
        json.dumps({"n_files": len(files), "n_candidates": len(rows)}, indent=2)
    )
    return csv_path


def fold_review(review_csv: Path, confirmed_dir: Path) -> int:
    confirmed_dir = Path(confirmed_dir)
    confirmed_dir.mkdir(parents=True, exist_ok=True)
    n = 0
    with open(review_csv) as f:
        for row in csv.DictReader(f):
            lab = (row.get("review_label") or "").strip().lower()
            if lab not in {"blast", "positive", "1", "true", "yes"}:
                continue
            src = Path(row["snippet"])
            if not src.exists():
                continue
            shutil.copy2(src, confirmed_dir / src.name)
            n += 1
    (confirmed_dir / "fold_log.json").write_text(json.dumps({"n_new_positives": n}, indent=2))
    return n
