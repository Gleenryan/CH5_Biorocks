from reef_pipeline.cli import main as _cli_main

if __name__ == "__main__":
    import sys

    # `python -m reef_pipeline.detection --input ...` shares the top-level CLI.
    sys.argv = [sys.argv[0], "detect", *sys.argv[1:]]
    raise SystemExit(_cli_main())
