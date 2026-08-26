"""Pretend to be Coralyst hydrophones and stream reef_pipeline audio into the app."""

from __future__ import annotations

import argparse
import json
import signal
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np

from reef_pipeline.audio import load_audio
from reef_pipeline.config import SR, data_root
from reef_pipeline.stream.fleet_audio import build_fleet_jobs
from reef_pipeline.stream.protocol import DEFAULT_HOST, DEFAULT_PORT, stream_to_app
from reef_pipeline.stream.scenarios import (
    SCENARIOS,
    GroundTruthEvent,
    get_scenario,
    hydrophone_uuid,
)


def stream_cli(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Stream reef_pipeline audio into Coralyst as fake hydrophones"
    )
    parser.add_argument("--scenario", default=None, choices=sorted(SCENARIOS))
    parser.add_argument(
        "--fleet",
        action="store_true",
        help="Stream Indonesia N1 fleet (1 blast hydro + 3 field hydros)",
    )
    parser.add_argument(
        "--n-blasts",
        type=int,
        default=1,
        choices=[1, 2],
        help="Blasts injected on the blast hydrophone only (fleet mode)",
    )
    parser.add_argument(
        "--synthetic",
        action="store_true",
        help="Use generated reef/blast audio instead of REEFGUARD_RAW_DATA WAVs",
    )
    parser.add_argument("--wav", type=Path, help="Stream a single WAV file")
    parser.add_argument("--site-name", default="Indonesia N1")
    parser.add_argument("--hydrophone-name", default="Hydrophone 1")
    parser.add_argument("--hydrophone-id", default=None)
    parser.add_argument("--recorder", default="hydromoth")
    parser.add_argument("--latitude", type=float, default=-8.1287)
    parser.add_argument("--longitude", type=float, default=114.6608)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--realtime", action="store_true")
    parser.add_argument("--fast", action="store_true")
    parser.add_argument("--loop", action="store_true")
    parser.add_argument("--expect-blast", action="store_true")
    args = parser.parse_args(argv)

    realtime = args.realtime or not args.fast
    jobs = _jobs_from_args(args)
    print(f"Streaming {len(jobs)} hydrophone(s) to {args.host}:{args.port}", flush=True)
    stop = threading.Event()

    def _request_stop(*_args) -> None:
        stop.set()

    signal.signal(signal.SIGTERM, _request_stop)
    signal.signal(signal.SIGINT, _request_stop)

    try:
        if len(jobs) == 1:
            print(_stream_job(jobs[0], args.host, args.port, realtime, args.loop, stop))
            return 0
        with ThreadPoolExecutor(max_workers=len(jobs)) as pool:
            futures = [
                pool.submit(_stream_job, job, args.host, args.port, realtime, args.loop, stop)
                for job in jobs
            ]
            for future in as_completed(futures):
                print(future.result())
        return 0
    except KeyboardInterrupt:
        stop.set()
        print("stopped")
        return 130


def _jobs_from_args(args: argparse.Namespace) -> List[Dict[str, Any]]:
    if args.wav is not None:
        path = args.wav.expanduser().resolve()
        if not path.is_file():
            raise SystemExit(f"WAV not found: {path}")
        return [
            {
                "site_name": args.site_name,
                "hydrophone_name": args.hydrophone_name,
                "scenario": "wav_file",
                "latitude": args.latitude,
                "longitude": args.longitude,
                "seed": args.seed,
                "hydrophone_id": args.hydrophone_id,
                "wav": path,
                "expect_blast": args.expect_blast,
            }
        ]
    if args.fleet:
        return build_fleet_jobs(
            seed=args.seed,
            n_blasts=args.n_blasts,
            synthetic=args.synthetic,
        )
    return [
        {
            "site_name": args.site_name,
            "hydrophone_name": args.hydrophone_name,
            "scenario": args.scenario or "blast_in_ambient",
            "latitude": args.latitude,
            "longitude": args.longitude,
            "seed": args.seed,
            "hydrophone_id": args.hydrophone_id,
        }
    ]


def _stream_job(
    job: Dict[str, Any],
    host: str,
    port: int,
    realtime: bool,
    loop: bool,
    stop: Optional[threading.Event] = None,
) -> str:
    audio, hello, hydro_id = _prepare(job)
    try:
        result = stream_to_app(
            audio,
            hello,
            host=host,
            port=port,
            realtime=realtime,
            loop=loop,
            should_stop=(stop.is_set if stop is not None else None),
        )
    except OSError as exc:
        raise SystemExit(
            f"Could not connect to Coralyst at {host}:{port} ({exc}). "
            "Start the app first so the hydrophone ingress is listening."
        ) from exc
    return json.dumps(
        {
            "siteName": job["site_name"],
            "hydrophoneName": job["hydrophone_name"],
            "hydrophoneId": hydro_id,
            "scenarioId": hello.get("scenarioId"),
            "scenarioName": hello.get("scenarioName"),
            "domainScope": hello.get("domainScope"),
            "durationSeconds": hello.get("durationSeconds"),
            "nEvents": len(hello.get("events") or []),
            "containsBlastAudio": hello.get("containsBlastAudio"),
            "audioFiles": [Path(p).name for p in (hello.get("audioFiles") or [])],
            "dataRoot": str(data_root()),
            "streamed": result,
        }
    )


def _prepare(job: Dict[str, Any]):
    hydro_id = job.get("hydrophone_id") or hydrophone_uuid(job["hydrophone_name"])

    # Pre-built fleet audio (real field + optional single blast).
    if job.get("audio") is not None:
        audio = np.asarray(job["audio"], dtype=np.float64)
        events: List[GroundTruthEvent] = list(job.get("events") or [])
        duration = len(audio) / SR
        hello = {
            "type": "hello",
            "protocol": "reefguard-hydro-v1",
            "hydrophoneId": hydro_id,
            "hydrophoneName": job["hydrophone_name"],
            "siteName": job["site_name"],
            "sampleRate": SR,
            "channels": 1,
            "scenarioId": job.get("scenario") or "fleet",
            "scenarioName": job.get("scenario_name") or job.get("scenario") or "fleet",
            "source": "reef_pipeline",
            "construction": "dataset_field" if not job.get("expect_blast") else "field_plus_blast",
            "durationSeconds": duration,
            "latitude": job.get("latitude"),
            "longitude": job.get("longitude"),
            "events": [e.as_wire() if hasattr(e, "as_wire") else e for e in events],
            "domainScope": "indonesia_hydromoth",
                    "audioFiles": job.get("audio_files") or [],
                    "containsBlastAudio": bool(job.get("contains_blast_audio")),
                }
        return audio, hello, hydro_id

    wav = job.get("wav")
    if wav is not None:
        audio, sr = load_audio(Path(wav), sr=SR)
        assert sr == SR
        duration = len(audio) / SR
        events_wire = []
        if job.get("expect_blast"):
            events_wire = [
                {
                    "id": "gt-wav-blast",
                    "tOnsetSeconds": 0.5,
                    "tOffsetSeconds": min(2.0, duration),
                    "label": "blast",
                    "expectedAlert": True,
                    "sourceClipId": str(wav),
                    "notes": "User WAV marked expect-blast",
                }
            ]
        hello = {
            "type": "hello",
            "protocol": "reefguard-hydro-v1",
            "hydrophoneId": hydro_id,
            "hydrophoneName": job["hydrophone_name"],
            "siteName": job["site_name"],
            "sampleRate": SR,
            "channels": 1,
            "scenarioId": "wav_file",
            "scenarioName": Path(wav).name,
            "source": "reef_pipeline",
            "construction": "wav_file",
            "durationSeconds": duration,
            "latitude": job.get("latitude"),
            "longitude": job.get("longitude"),
            "events": events_wire,
            "domainScope": "indonesia_hydromoth",
            "audioFiles": [str(wav)],
        }
        return audio.astype(float), hello, hydro_id

    scenario = get_scenario(job["scenario"])
    audio, events = scenario.mix(seed=int(job["seed"]))
    hello = scenario.hello_payload(
        hydro_id,
        job["hydrophone_name"],
        job["site_name"],
        latitude=job.get("latitude"),
        longitude=job.get("longitude"),
        events=events,
    )
    return audio, hello, hydro_id


def main(argv: Optional[List[str]] = None) -> int:
    return stream_cli(argv)


if __name__ == "__main__":
    raise SystemExit(main())
