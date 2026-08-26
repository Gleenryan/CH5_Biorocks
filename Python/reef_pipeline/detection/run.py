from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import List, Optional, Sequence

import numpy as np

from reef_pipeline import EVENT_BLAST, EVENT_BOAT
from reef_pipeline.audio import load_audio, pad_or_crop, write_audio
from reef_pipeline.catalog import domain_scope_for
from reef_pipeline.config import BLAST_WINDOW_S, HOP_S, SR, WINDOW_S
from .events import Event
from .boat import smooth_binary
from .stage1 import stage1_candidates
from .stage2 import load_model, score_window


def detect_file(
    audio_path: Path,
    blast_model_path: Optional[Path] = None,
    boat_model_path: Optional[Path] = None,
    site_id: str = "",
    recorder_id: str = "",
    dataset: str = "",
    domain_scope: Optional[str] = None,
    blast_thresh: float = 0.5,
    boat_thresh: float = 0.5,
    snippet_dir: Optional[Path] = None,
    sr: int = SR,
) -> List[Event]:
    y, sr = load_audio(audio_path, sr=sr)
    scope = domain_scope or domain_scope_for(dataset=dataset, recorder=recorder_id, site_id=site_id)
    events: List[Event] = []
    blast_model = load_model(blast_model_path) if blast_model_path else None
    boat_model = load_model(boat_model_path) if boat_model_path else None
    win = int(BLAST_WINDOW_S * sr)

    for i, cand in enumerate(stage1_candidates(y, sr)):
        peak = int(cand["t_peak"] * sr)
        sl = pad_or_crop(y[max(0, peak - win // 2) : peak + win // 2], win)
        if blast_model is not None:
            conf = score_window(blast_model, sl, sr)
            if conf < blast_thresh:
                continue
        else:
            excess = float(cand.get("excess_db", 0.0))
            conf = float(1.0 / (1.0 + np.exp(-(excess - 12.0) / 3.0)))
        snippet = ""
        if snippet_dir:
            snippet_dir_p = Path(snippet_dir)
            snippet_dir_p.mkdir(parents=True, exist_ok=True)
            snippet_p = snippet_dir_p / f"{Path(audio_path).stem}_blast_{i}.wav"
            write_audio(snippet_p, sl, sr)
            snippet = str(snippet_p)
        events.append(
            Event(
                event_id=f"{Path(audio_path).stem}_blast_{i}",
                type=EVENT_BLAST,
                t_start=float(cand["t_start"]),
                t_end=float(cand["t_end"]),
                confidence=conf,
                site_id=site_id,
                recorder_id=recorder_id,
                source_file=str(audio_path),
                audio_snippet_path=snippet,
                domain_scope=scope,
            )
        )

    if boat_model is not None:
        hop = int(HOP_S * sr)
        w = int(WINDOW_S * sr)
        scores = []
        starts = []
        if len(y) < w:
            y = pad_or_crop(y, w)
        for s0 in range(0, max(1, len(y) - w + 1), hop):
            sl = y[s0 : s0 + w]
            scores.append(score_window(boat_model, sl, sr))
            starts.append(s0 / sr)
        flags = smooth_binary(
            scores,
            thresh=boat_thresh,
            enter=max(boat_thresh, 0.55),
            leave=min(boat_thresh, 0.4),
        )
        in_run = False
        run_i = 0
        n_boat = 0
        for i, flag in enumerate(flags):
            if flag and not in_run:
                in_run = True
                run_i = i
            if in_run and (not flag or i == len(flags) - 1):
                j = i
                t0 = starts[run_i]
                t1 = starts[min(j, len(starts) - 1)] + WINDOW_S
                conf = float(np.max(scores[run_i : j + 1]))
                n_boat += 1
                events.append(
                    Event(
                        event_id=f"{Path(audio_path).stem}_boat_{n_boat}",
                        type=EVENT_BOAT,
                        t_start=t0,
                        t_end=t1,
                        confidence=conf,
                        site_id=site_id,
                        recorder_id=recorder_id,
                        source_file=str(audio_path),
                    )
                )
                in_run = False
    return events


def write_events(events: Sequence[Event], path: Path) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = [e.to_dict() for e in events]
    if path.suffix.lower() == ".jsonl":
        with open(path, "w") as f:
            for r in rows:
                f.write(json.dumps(r) + "\n")
        return
    if not rows:
        path.write_text("")
        return
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
