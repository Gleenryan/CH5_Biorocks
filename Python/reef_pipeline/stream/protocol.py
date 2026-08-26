"""TCP hydrophone protocol: JSON hello, then framed int16 PCM (reefguard-hydro-v1)."""

from __future__ import annotations

import json
import socket
import struct
import time
from typing import Callable, Iterable, Optional

import numpy as np

PROTOCOL_NAME = "reefguard-hydro-v1"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 17455
FRAME_SAMPLES = 1_600  # 100 ms @ 16 kHz
SAMPLE_RATE = 16_000

# Optional per-frame hook: (frame_index, float32 samples, t_seconds) -> None
FrameCallback = Callable[[int, np.ndarray, float], None]


def pcm16_frames(audio: np.ndarray, frame_samples: int = FRAME_SAMPLES) -> Iterable[bytes]:
    clipped = np.clip(audio.astype(np.float64), -1.0, 1.0)
    pcm = (clipped * 32767.0).astype("<i2")
    n = len(pcm)
    i = 0
    while i < n:
        chunk = pcm[i : i + frame_samples]
        i += frame_samples
        yield struct.pack("<I", len(chunk)) + chunk.tobytes()


def float_frames(audio: np.ndarray, frame_samples: int = FRAME_SAMPLES) -> Iterable[np.ndarray]:
    audio = np.asarray(audio, dtype=np.float32).reshape(-1)
    n = len(audio)
    i = 0
    while i < n:
        chunk = audio[i : i + frame_samples]
        i += frame_samples
        yield chunk


def stream_to_app(
    audio: np.ndarray,
    hello: dict,
    host: str = DEFAULT_HOST,
    port: int = DEFAULT_PORT,
    realtime: bool = True,
    timeout: float = 3.0,
    loop: bool = False,
    on_frame: Optional[FrameCallback] = None,
    should_stop: Optional[Callable[[], bool]] = None,
) -> dict:
    hello = dict(hello)
    hello["protocol"] = PROTOCOL_NAME
    hello["frameSamples"] = FRAME_SAMPLES
    if loop:
        hello["loop"] = True
    payload = (json.dumps(hello) + "\n").encode("utf-8")
    sock = socket.create_connection((host, port), timeout=timeout)
    sock.settimeout(timeout)
    try:
        sock.sendall(payload)
        line = _recv_line(sock)
        ack = json.loads(line.decode("utf-8"))
        if not ack.get("ok"):
            raise RuntimeError(f"app rejected hydrophone: {ack}")
        sock.settimeout(None)
        frame_dur = FRAME_SAMPLES / SAMPLE_RATE
        sent = 0
        cycles = 0
        while True:
            if should_stop is not None and should_stop():
                break
            t0 = time.perf_counter()
            for i, (frame_bytes, samples) in enumerate(
                zip(pcm16_frames(audio), float_frames(audio))
            ):
                if should_stop is not None and should_stop():
                    break
                sock.sendall(frame_bytes)
                sent += 1
                if on_frame is not None:
                    on_frame(i, samples, (i + 1) * frame_dur)
                if realtime:
                    target = (i + 1) * frame_dur
                    sleep = target - (time.perf_counter() - t0)
                    if sleep > 0:
                        time.sleep(sleep)
            cycles += 1
            if not loop or (should_stop is not None and should_stop()):
                break
        return {"ack": ack, "frames": sent, "cycles": cycles}
    finally:
        sock.close()


def _recv_line(sock: socket.socket, limit: int = 65536) -> bytes:
    buf = bytearray()
    while b"\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise ConnectionError("app closed during handshake")
        buf.extend(chunk)
        if len(buf) > limit:
            raise ValueError("handshake too large")
    line, _rest = buf.split(b"\n", 1)
    return line
