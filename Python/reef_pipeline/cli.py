from __future__ import annotations

import argparse
from pathlib import Path

from reef_pipeline.catalog import domain_scope_for, unique_blast_paths
from reef_pipeline.config import data_root
from reef_pipeline.detection.bootstrap import bootstrap_ind_n1, fold_review
from reef_pipeline.detection.boat import train_boat_model
from reef_pipeline.detection.run import detect_file, write_events
from reef_pipeline.detection.stage2 import train_blast_model
from reef_pipeline.features.extract import extract_windows_cli
from reef_pipeline.listen.extract import listen_cli
from reef_pipeline.simulator.run import simulate_cli
from reef_pipeline.exhibit.run import exhibit_cli
from reef_pipeline.stream.hydrophone_sim import stream_cli
from reef_pipeline.validation.metrics import validate_cli


def _cmd_dedupe(args: argparse.Namespace) -> int:
    root = Path(args.root) if args.root else data_root()
    paths = unique_blast_paths(root)
    print(f"{len(paths)} unique blast files after MD5 de-dupe")
    for p in paths:
        print(p)
    return 0


def _cmd_train_blast(args: argparse.Namespace) -> int:
    train_blast_model(Path(args.out), seed=args.seed, augment=not args.no_augment)
    print(f"wrote {args.out}")
    return 0


def _cmd_train_boat(args: argparse.Namespace) -> int:
    train_boat_model(Path(args.out), seed=args.seed, augment=not args.no_augment)
    print(f"wrote {args.out}")
    return 0


def _cmd_detect(args: argparse.Namespace) -> int:
    scope = args.domain_scope or domain_scope_for(
        dataset=args.dataset, recorder=args.recorder, site_id=args.site
    )
    events = detect_file(
        Path(args.input),
        blast_model_path=Path(args.blast_model) if args.blast_model else None,
        boat_model_path=Path(args.boat_model) if args.boat_model else None,
        site_id=args.site or "",
        recorder_id=args.recorder or "",
        dataset=args.dataset or "",
        domain_scope=scope,
        snippet_dir=Path(args.snippet_dir) if args.snippet_dir else None,
    )
    write_events(events, Path(args.out))
    print(f"wrote {len(events)} events -> {args.out}")
    return 0


def _cmd_bootstrap(args: argparse.Namespace) -> int:
    path = bootstrap_ind_n1(
        Path(args.out_dir),
        model_path=Path(args.blast_model) if args.blast_model else None,
        audio_dir=Path(args.audio_dir) if args.audio_dir else None,
        max_files=args.max_files,
    )
    print(f"wrote {path}")
    return 0


def _cmd_fold(args: argparse.Namespace) -> int:
    n = fold_review(Path(args.review_csv), Path(args.confirmed_dir))
    print(f"folded {n} new positives")
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="reef-pipeline")
    sub = p.add_subparsers(dest="cmd", required=True)

    # add_help=False so `reef-pipeline simulate --help` reaches simulate_cli.
    sub.add_parser("simulate", add_help=False)
    sub.add_parser("features", add_help=False)
    sub.add_parser("listen", add_help=False)
    sub.add_parser("validate", add_help=False)
    sub.add_parser("stream", add_help=False)
    sub.add_parser("exhibit", add_help=False)

    s = sub.add_parser("dedupe-blasts")
    s.add_argument("--root")
    s.set_defaults(run=_cmd_dedupe)

    s = sub.add_parser("train-blast")
    s.add_argument("--out", required=True)
    s.add_argument("--seed", type=int, default=0)
    s.add_argument("--no-augment", action="store_true")
    s.set_defaults(run=_cmd_train_blast)

    s = sub.add_parser("train-boat")
    s.add_argument("--out", required=True)
    s.add_argument("--seed", type=int, default=0)
    s.add_argument("--no-augment", action="store_true")
    s.set_defaults(run=_cmd_train_boat)

    s = sub.add_parser("detect")
    s.add_argument("--input", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--blast-model")
    s.add_argument("--boat-model")
    s.add_argument("--site", default="")
    s.add_argument("--recorder", default="")
    s.add_argument("--dataset", default="")
    s.add_argument("--domain-scope")
    s.add_argument("--snippet-dir")
    s.set_defaults(run=_cmd_detect)

    s = sub.add_parser("bootstrap")
    s.add_argument("--out-dir", required=True)
    s.add_argument("--blast-model")
    s.add_argument("--audio-dir")
    s.add_argument("--max-files", type=int)
    s.set_defaults(run=_cmd_bootstrap)

    s = sub.add_parser("fold-review")
    s.add_argument("--review-csv", required=True)
    s.add_argument("--confirmed-dir", required=True)
    s.set_defaults(run=_cmd_fold)

    args, rest = p.parse_known_args(argv)
    delegated = {
        "simulate": simulate_cli,
        "features": extract_windows_cli,
        "listen": listen_cli,
        "validate": validate_cli,
        "stream": stream_cli,
        "exhibit": exhibit_cli,
    }
    if args.cmd in delegated:
        return delegated[args.cmd](rest)
    return args.run(args)


if __name__ == "__main__":
    raise SystemExit(main())
