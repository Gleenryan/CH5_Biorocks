from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

from reef_pipeline import EVENT_BLAST, EVENT_BOAT

SNR_BUCKETS = [
    ("<0", None, 0.0),
    ("0-6", 0.0, 6.0),
    ("6-12", 6.0, 12.0),
    ("12-18", 12.0, 18.0),
    (">=18", 18.0, None),
]


def _load_jsonl(path: Path) -> List[dict]:
    rows = []
    for line in Path(path).read_text().splitlines():
        if line.strip():
            rows.append(json.loads(line))
    return rows


def _load_table(path: Path) -> List[dict]:
    path = Path(path)
    if path.suffix.lower() in {".jsonl", ".json"}:
        if path.suffix.lower() == ".json":
            obj = json.loads(path.read_text())
            return obj if isinstance(obj, list) else [obj]
        return _load_jsonl(path)
    import csv

    with open(path) as f:
        return list(csv.DictReader(f))


def _f1(tp: int, fp: int, fn: int) -> Dict[str, float]:
    prec = tp / (tp + fp) if (tp + fp) else 0.0
    rec = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = 2 * prec * rec / (prec + rec) if (prec + rec) else 0.0
    return {"precision": prec, "recall": rec, "f1": f1, "tp": tp, "fp": fp, "fn": fn}


def _overlap(a0: float, a1: float, b0: float, b1: float) -> bool:
    return a0 < b1 and b0 < a1


def _bucket(snr: float) -> str:
    for name, lo, hi in SNR_BUCKETS:
        if lo is None and snr < hi:
            return name
        if hi is None and snr >= lo:
            return name
        if lo is not None and hi is not None and lo <= snr < hi:
            return name
    return ">=18"


def match_detections(
    truth: Sequence[dict],
    dets: Sequence[dict],
    event_type: str,
    max_center_s: float = 0.75,
) -> Tuple[int, int, int, List[float]]:
    gt = [r for r in truth if r.get("type") == event_type]
    pr = [r for r in dets if r.get("type") == event_type]
    used = set()
    tp = 0
    latencies = []
    for g in gt:
        g0, g1 = float(g["t_start"]), float(g["t_end"])
        gc = 0.5 * (g0 + g1)
        best = None
        best_i = None
        for i, d in enumerate(pr):
            if i in used:
                continue
            d0, d1 = float(d["t_start"]), float(d["t_end"])
            dc = 0.5 * (d0 + d1)
            if _overlap(g0, g1, d0, d1) or abs(dc - gc) <= max_center_s:
                dist = abs(dc - gc)
                if best is None or dist < best:
                    best = dist
                    best_i = i
        if best_i is not None:
            used.add(best_i)
            tp += 1
            latencies.append(float(pr[best_i]["t_start"]) - g0)
    fp = len(pr) - tp
    fn = len(gt) - tp
    return tp, fp, fn, latencies


def evaluate(
    manifest_path: Path,
    detections_path: Path,
    distractor_types: Iterable[str] = (EVENT_BOAT, "mechanical", "ambient"),
) -> dict:
    truth = _load_table(manifest_path)
    dets = _load_table(detections_path)
    report: dict = {"by_type": {}, "blast_by_snr": {}, "latency_s": {}, "distractor_fp": {}}

    for et in (EVENT_BLAST, EVENT_BOAT):
        tp, fp, fn, lat = match_detections(truth, dets, et)
        stats = _f1(tp, fp, fn)
        stats["mean_latency_s"] = float(sum(lat) / len(lat)) if lat else None
        report["by_type"][et] = stats
        report["latency_s"][et] = lat

    # SNR buckets for blasts
    blast_gt = [r for r in truth if r.get("type") == EVENT_BLAST]
    by_snr = defaultdict(list)
    for g in blast_gt:
        by_snr[_bucket(float(g.get("snr_db", 0)))].append(g)
    for name, _, _ in SNR_BUCKETS:
        subset = by_snr.get(name, [])
        if not subset:
            continue
        tp, fp, fn, _ = match_detections(subset, dets, EVENT_BLAST)
        # fp is global-ish because dets aren't subset; recompute recall-only + matched
        report["blast_by_snr"][name] = {
            "n_injected": len(subset),
            "recall": tp / len(subset) if subset else 0.0,
            "tp": tp,
            "fn": fn,
        }

    # False blast detections overlapping distractor injections
    blast_dets = [d for d in dets if d.get("type") == EVENT_BLAST]
    distractors = [t for t in truth if t.get("type") in set(distractor_types)]
    fp_dist = 0
    for d in blast_dets:
        d0, d1 = float(d["t_start"]), float(d["t_end"])
        if any(_overlap(d0, d1, float(t["t_start"]), float(t["t_end"])) for t in distractors):
            fp_dist += 1
    n_dist = len(distractors)
    report["distractor_fp"] = {
        "blast_dets_on_distractors": fp_dist,
        "n_distractors": n_dist,
        "rate": fp_dist / n_dist if n_dist else 0.0,
    }
    return report


def _print_table(report: dict) -> None:
    print("type        precision  recall     f1     tp fp fn  latency_s")
    for et, s in report["by_type"].items():
        lat = s["mean_latency_s"]
        lat_s = f"{lat:.3f}" if lat is not None else "-"
        print(
            f"{et:10s}  {s['precision']:.3f}     {s['recall']:.3f}   {s['f1']:.3f}  "
            f"{int(s['tp']):3d} {int(s['fp']):2d} {int(s['fn']):2d}  {lat_s}"
        )
    print("\nblast recall by SNR")
    for name, s in report["blast_by_snr"].items():
        print(f"  {name:8s}  n={s['n_injected']:3d}  recall={s['recall']:.3f}")
    d = report["distractor_fp"]
    print(
        f"\ndistractor FP: {d['blast_dets_on_distractors']}/{d['n_distractors']} "
        f"(rate {d['rate']:.3f})"
    )


def validate_cli(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Score detections against a simulator manifest")
    p.add_argument("--manifest", required=True)
    p.add_argument("--detections", required=True)
    p.add_argument("--out-json")
    args = p.parse_args(argv)
    report = evaluate(Path(args.manifest), Path(args.detections))
    _print_table(report)
    if args.out_json:
        Path(args.out_json).write_text(json.dumps(report, indent=2, default=str))
        print(f"wrote {args.out_json}")
    return 0
