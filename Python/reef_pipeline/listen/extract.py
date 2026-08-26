from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List, Optional, Union

from reef_pipeline.audio import load_audio, write_audio
from reef_pipeline.config import SR


def extract_snippet(
    source_file: Union[str, Path],
    t_start: float,
    t_end: float,
    pad_s: float = 0.5,
    sr: int = SR,
    out_path: Optional[Path] = None,
    **kwargs,
):
    pad_s = kwargs.get("pad_s", pad_s)
    out_path = kwargs.get("out_path", out_path)
    y, sr = load_audio(source_file, sr=sr)
    a = max(0, int((t_start - pad_s) * sr))
    b = min(len(y), int((t_end + pad_s) * sr))
    snippet = y[a:b]
    if out_path is not None:
        write_audio(out_path, snippet, sr)
    return snippet, sr


def extract_by_event(
    event_id: str,
    events_path: Path,
    pad_s: float = 0.5,
    out_path: Optional[Path] = None,
    sr: int = SR,
):
    events_path = Path(events_path)
    rec = None
    if events_path.suffix.lower() == ".jsonl":
        for line in events_path.read_text().splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            if str(row.get("event_id") or row.get("event_id")) == event_id:
                rec = row
                break
    else:
        import csv

        with open(events_path) as f:
            for row in csv.DictReader(f):
                if str(row.get("event_id") or row.get("event_id")) == event_id:
                    rec = row
                    break
    if rec is None:
        raise KeyError(f"event {event_id} not found in {events_path}")
    src = rec.get("source_file") or rec.get("audio_snippet_path")
    return extract_snippet(
        src,
        float(rec["t_start"]),
        float(rec["t_end"]),
        pad_s=pad_s,
        sr=sr,
        out_path=out_path,
    )


def listen_cli(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Extract a WAV snippet for human review")
    p.add_argument("--event-id")
    p.add_argument("--events")
    p.add_argument("--source-file")
    p.add_argument("--t-start", type=float)
    p.add_argument("--t-end", type=float)
    p.add_argument("--pad-s", type=float, default=0.5)
    p.add_argument("--out", required=True)
    args = p.parse_args(argv)
    if args.event_id:
        if not args.events:
            p.error("--events is required with --event-id")
        extract_by_event(args.event_id, Path(args.events), pad_s=args.pad_s, out_path=Path(args.out))
    else:
        if args.source_file is None or args.t_start is None or args.t_end is None:
            p.error("need --source-file --t-start --t-end, or --event-id --events")
        extract_snippet(
            args.source_file,
            args.t_start,
            args.t_end,
            pad_s=args.pad_s,
            out_path=Path(args.out),
        )
    print(f"wrote {args.out}")
    return 0
