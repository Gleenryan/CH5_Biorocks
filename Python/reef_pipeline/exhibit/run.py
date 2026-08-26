"""Exhibition CLI: beach / sea scene with hydrophones + blast, streaming into Coralyst."""

from __future__ import annotations

import argparse
import signal
import threading
import time
import traceback
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

from reef_pipeline.config import SR
from reef_pipeline.exhibit.panels import HydroPanelState, blast_windows_from_events
from reef_pipeline.stream.fleet_audio import build_fleet_jobs
from reef_pipeline.stream.hydrophone_sim import _prepare
from reef_pipeline.stream.protocol import DEFAULT_HOST, DEFAULT_PORT, stream_to_app

# Coastal exhibition palette
SKY_TOP = "#7ec8e3"
SKY_BOT = "#c8e7f5"
SAND = "#e8d5a3"
SAND_DARK = "#cbb67a"
SEA_SHALLOW = "#3db8c9"
SEA_DEEP = "#0b4f6c"
SEA_MID = "#1a7a8c"
FOAM = "#eaf6fb"
CORAL = "#e07a5f"
ACCENT = "#f4a261"
INK = "#1d3557"
MUTED = "#457b9d"
ALERT = "#e63946"
BUOY = "#f1faee"
CABLE = "#264653"


def exhibit_cli(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Exhibition scene — beach & sea with hydrophones; streams into Coralyst"
    )
    parser.add_argument("--n-blasts", type=int, default=1, choices=[1, 2])
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--max-seconds", type=float, default=45.0)
    parser.add_argument("--loop", action="store_true")
    parser.add_argument("--no-app", action="store_true")
    parser.add_argument("--fullscreen", action="store_true")
    args = parser.parse_args(argv)

    seed = int(args.seed if args.seed is not None else (time.time() % 10_000))
    jobs = build_fleet_jobs(seed=seed, n_blasts=args.n_blasts)
    prepared: List[Dict[str, Any]] = []
    panels: List[HydroPanelState] = []

    for job in jobs:
        trimmed = _trim_job(job, args.max_seconds)
        audio, hello, hydro_id = _prepare(trimmed)
        events = hello.get("events") or []
        panel = HydroPanelState(
            name=str(hello.get("hydrophoneName") or trimmed["hydrophone_name"]),
            site_name=str(hello.get("siteName") or trimmed["site_name"]),
            contains_blast=bool(hello.get("containsBlastAudio")),
            latitude=float(trimmed.get("latitude") or hello.get("latitude") or 0.0),
            longitude=float(trimmed.get("longitude") or hello.get("longitude") or 0.0),
            blast_windows=blast_windows_from_events(events),
            status="connecting" if not args.no_app else "local",
        )
        panels.append(panel)
        prepared.append(
            {
                "audio": audio,
                "hello": hello,
                "panel": panel,
                "name": panel.name,
            }
        )

    stop = threading.Event()
    errors: List[str] = []

    def _request_stop(*_args) -> None:
        stop.set()
        try:
            import matplotlib.pyplot as plt

            plt.close("all")
        except Exception:  # noqa: BLE001
            pass

    signal.signal(signal.SIGTERM, _request_stop)
    signal.signal(signal.SIGINT, _request_stop)

    def _stream_one(item: Dict[str, Any]) -> None:
        panel: HydroPanelState = item["panel"]

        def on_frame(_i: int, samples: np.ndarray, t: float) -> None:
            panel.push(samples, t)

        try:
            if args.no_app:
                _local_play(item["audio"], on_frame, stop.is_set, loop=args.loop)
            else:
                panel.status = "connecting"
                stream_to_app(
                    item["audio"],
                    item["hello"],
                    host=args.host,
                    port=args.port,
                    realtime=True,
                    loop=args.loop,
                    on_frame=on_frame,
                    should_stop=stop.is_set,
                )
            panel.status = "done"
            panel.connected = False
        except Exception as exc:  # noqa: BLE001
            panel.status = "error"
            errors.append(f"{panel.name}: {exc}")
            print(f"[exhibit] stream error: {panel.name}: {exc}", flush=True)

    threads = [
        threading.Thread(target=_stream_one, args=(item,), daemon=True, name=f"hydro-{item['name']}")
        for item in prepared
    ]
    for thread in threads:
        thread.start()

    try:
        _run_scene(
            panels,
            seed=seed,
            host=args.host,
            port=args.port,
            to_app=not args.no_app,
            fullscreen=args.fullscreen,
            stop=stop,
            errors=errors,
        )
    finally:
        stop.set()
        for thread in threads:
            thread.join(timeout=1.5)
    return 0


def _trim_job(job: Dict[str, Any], max_seconds: float) -> Dict[str, Any]:
    if max_seconds is None or max_seconds <= 0:
        return job
    out = dict(job)
    audio = np.asarray(job["audio"], dtype=np.float64)
    n = min(len(audio), int(max_seconds * SR))
    out["audio"] = audio[:n]
    from reef_pipeline.stream.scenarios import GroundTruthEvent

    rebuilt: List[Any] = []
    for event in job.get("events") or []:
        wire = event.as_wire() if hasattr(event, "as_wire") else dict(event)
        onset = float(wire.get("tOnsetSeconds") or 0.0)
        if onset >= max_seconds:
            continue
        offset = min(float(wire.get("tOffsetSeconds") or onset), max_seconds)
        rebuilt.append(
            GroundTruthEvent(
                id=str(wire.get("id") or "event"),
                t_onset_seconds=onset,
                t_offset_seconds=offset,
                label=str(wire.get("label") or "field"),
                expected_alert=bool(wire.get("expectedAlert")),
                source_clip_id=str(wire.get("sourceClipId") or ""),
                notes=str(wire.get("notes") or ""),
            )
        )
    out["events"] = rebuilt
    return out


def _local_play(audio: np.ndarray, on_frame, should_stop, loop: bool) -> None:
    from reef_pipeline.stream.protocol import FRAME_SAMPLES, float_frames

    frame_dur = FRAME_SAMPLES / SR
    while True:
        t0 = time.perf_counter()
        for i, samples in enumerate(float_frames(audio)):
            if should_stop():
                return
            on_frame(i, samples, (i + 1) * frame_dur)
            target = (i + 1) * frame_dur
            sleep = target - (time.perf_counter() - t0)
            if sleep > 0:
                time.sleep(sleep)
        if not loop:
            return


def _lonlat_to_xy(
    lon: float,
    lat: float,
    lons: np.ndarray,
    lats: np.ndarray,
) -> Tuple[float, float]:
    """Map geo coords into scene space: x in [0.12, 0.88], y in sea band [0.18, 0.62]."""
    lon_min, lon_max = float(lons.min()), float(lons.max())
    lat_min, lat_max = float(lats.min()), float(lats.max())
    lon_pad = max((lon_max - lon_min) * 0.35, 0.002)
    lat_pad = max((lat_max - lat_min) * 0.35, 0.002)
    nx = (lon - (lon_min - lon_pad)) / ((lon_max + lon_pad) - (lon_min - lon_pad))
    ny = (lat - (lat_min - lat_pad)) / ((lat_max + lat_pad) - (lat_min - lat_pad))
    x = 0.12 + 0.76 * float(np.clip(nx, 0, 1))
    # Higher latitude → farther from beach (beach is at top of sea in our scene).
    y = 0.58 - 0.36 * float(np.clip(ny, 0, 1))
    return x, y


def _run_scene(
    panels: List[HydroPanelState],
    *,
    seed: int,
    host: str,
    port: int,
    to_app: bool,
    fullscreen: bool,
    stop: threading.Event,
    errors: List[str],
) -> None:
    try:
        import matplotlib

        for backend in ("MacOSX", "TkAgg"):
            try:
                matplotlib.use(backend, force=True)
                break
            except Exception:  # noqa: BLE001
                continue
        import matplotlib.pyplot as plt
        from matplotlib.animation import FuncAnimation
        from matplotlib.patches import Circle, Ellipse, FancyBboxPatch, Polygon, Rectangle, Wedge
        from matplotlib.collections import LineCollection
    except ImportError as exc:
        raise SystemExit(
            "matplotlib is required for exhibition mode. Run: .venv/bin/pip install matplotlib"
        ) from exc

    print(f"[exhibit] beach scene backend={matplotlib.get_backend()}", flush=True)

    fig, ax = plt.subplots(figsize=(14, 9), facecolor=SKY_TOP)
    try:
        fig.canvas.manager.set_window_title("Coralyst · Exhibition Scene")
    except Exception:  # noqa: BLE001
        pass
    if fullscreen:
        try:
            fig.canvas.manager.full_screen_toggle()
        except Exception:  # noqa: BLE001
            pass

    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.set_aspect("equal")
    ax.axis("off")
    fig.subplots_adjust(left=0, right=1, top=1, bottom=0)

    # --- Static scenery ---
    # Sky
    ax.add_patch(Rectangle((0, 0.72), 1, 0.28, facecolor=SKY_TOP, edgecolor="none", zorder=0))
    ax.imshow(
        np.linspace(0, 1, 64).reshape(-1, 1),
        extent=(0, 1, 0.72, 1.0),
        aspect="auto",
        cmap=plt.cm.colors.LinearSegmentedColormap.from_list("sky", [SKY_BOT, SKY_TOP]),
        origin="lower",
        zorder=0,
        interpolation="bilinear",
    )
    # Sun
    ax.add_patch(Circle((0.88, 0.90), 0.045, facecolor="#ffe08a", edgecolor="#ffd166", lw=2, zorder=1))

    # Beach (top of waterline)
    beach = Polygon(
        [[0, 0.62], [1, 0.62], [1, 0.78], [0.0, 0.74]],
        closed=True,
        facecolor=SAND,
        edgecolor="none",
        zorder=2,
    )
    ax.add_patch(beach)
    ax.add_patch(
        Polygon(
            [[0, 0.62], [1, 0.62], [1, 0.66], [0, 0.65]],
            closed=True,
            facecolor=SAND_DARK,
            edgecolor="none",
            zorder=3,
            alpha=0.55,
        )
    )
    # Palm-ish umbrellas / beach markers
    for ux, color in ((0.18, "#e76f51"), (0.42, "#2a9d8f"), (0.65, "#e9c46a")):
        ax.plot([ux, ux], [0.70, 0.78], color="#6d4c41", lw=3, zorder=4, solid_capstyle="round")
        ax.add_patch(Wedge((ux, 0.78), 0.055, 200, 340, facecolor=color, edgecolor="none", zorder=4))

    # Deep sea body
    ax.add_patch(Rectangle((0, 0), 1, 0.62, facecolor=SEA_DEEP, edgecolor="none", zorder=1))
    # Shallow gradient near shore
    ax.imshow(
        np.linspace(0, 1, 80).reshape(-1, 1),
        extent=(0, 1, 0.45, 0.62),
        aspect="auto",
        cmap=plt.cm.colors.LinearSegmentedColormap.from_list("sea", [SEA_MID, SEA_SHALLOW]),
        origin="lower",
        zorder=1,
        interpolation="bilinear",
        alpha=0.95,
    )

    # Coral / rock silhouettes on seabed
    for cx, cy, s, c in (
        (0.22, 0.10, 0.05, CORAL),
        (0.55, 0.08, 0.07, "#d4a373"),
        (0.78, 0.12, 0.045, CORAL),
        (0.35, 0.06, 0.04, "#adb5bd"),
    ):
        ax.add_patch(Ellipse((cx, cy), s * 2.2, s, facecolor=c, edgecolor="none", alpha=0.85, zorder=2))

    # Soft foam line
    foam_x = np.linspace(0, 1, 80)
    (foam_line,) = ax.plot(
        foam_x,
        0.62 + 0.008 * np.sin(foam_x * 18),
        color=FOAM,
        lw=4,
        alpha=0.85,
        zorder=5,
    )

    # Title
    ax.text(
        0.03,
        0.96,
        "CORALYST",
        fontsize=28,
        fontweight="bold",
        color=INK,
        va="top",
        zorder=20,
    )
    ax.text(
        0.03,
        0.915,
        "Indonesia N1  ·  four hydrophones listening under the waves",
        fontsize=12,
        color=MUTED,
        va="top",
        zorder=20,
    )
    status_text = ax.text(
        0.97,
        0.96,
        "",
        fontsize=11,
        color=INK,
        ha="right",
        va="top",
        family="monospace",
        zorder=20,
    )
    event_text = ax.text(
        0.5,
        0.03,
        "",
        fontsize=14,
        fontweight="bold",
        color=ALERT,
        ha="center",
        va="bottom",
        zorder=20,
    )

    # Hydrophone positions from lat/lon
    lons = np.array([p.longitude for p in panels], dtype=float)
    lats = np.array([p.latitude for p in panels], dtype=float)
    hydro_artists = []
    for panel in panels:
        x, y = _lonlat_to_xy(panel.longitude, panel.latitude, lons, lats)
        # cable to seabed
        cable = ax.plot([x, x], [y - 0.02, 0.05], color=CABLE, lw=1.5, alpha=0.55, zorder=6)[0]
        # buoy body
        buoy = Circle((x, y), 0.022, facecolor=BUOY, edgecolor=INK, lw=1.8, zorder=8)
        ax.add_patch(buoy)
        # hydrophone tip under buoy
        tip = Circle((x, y - 0.035), 0.012, facecolor=ACCENT, edgecolor=INK, lw=1.2, zorder=8)
        ax.add_patch(tip)
        pulse = Circle((x, y), 0.022, facecolor="none", edgecolor=ACCENT, lw=2, alpha=0.0, zorder=9)
        ax.add_patch(pulse)
        label = ax.text(
            x,
            y + 0.045,
            panel.name.replace("Hydrophone ", "H"),
            ha="center",
            va="bottom",
            fontsize=11,
            fontweight="bold",
            color=INK,
            zorder=10,
            bbox=dict(boxstyle="round,pad=0.2", facecolor=FOAM, edgecolor="none", alpha=0.9),
        )
        hydro_artists.append(
            {
                "panel": panel,
                "x": x,
                "y": y,
                "buoy": buoy,
                "tip": tip,
                "pulse": pulse,
                "cable": cable,
                "label": label,
            }
        )

    blast_panel = next((p for p in panels if p.contains_blast), panels[0])
    blast_xy = next((h for h in hydro_artists if h["panel"] is blast_panel), hydro_artists[0])
    bx, by = blast_xy["x"], blast_xy["y"]

    # Bomb / charge that travels then detonates near the blast hydro
    bomb = ax.plot([0.05], [0.55], marker="o", markersize=14, color=ALERT, markeredgecolor=INK, markeredgewidth=1.5, zorder=12)[0]
    bomb_fin = ax.plot([], [], color=INK, lw=2, zorder=11)[0]
    rings = [
        Circle((bx, by), 0.01, facecolor="none", edgecolor=ALERT, lw=2.5, alpha=0.0, zorder=11)
        for _ in range(3)
    ]
    for ring in rings:
        ax.add_patch(ring)
    flash = Circle((bx, by), 0.04, facecolor="#ffb703", edgecolor="none", alpha=0.0, zorder=10)
    ax.add_patch(flash)

    # Boat silhouette that carries / drops the charge
    boat_body = Polygon(
        [[0, 0], [0.07, 0], [0.08, 0.018], [-0.01, 0.018]],
        closed=True,
        facecolor="#6c757d",
        edgecolor=INK,
        lw=1.2,
        zorder=12,
    )
    ax.add_patch(boat_body)
    boat_cabin = FancyBboxPatch(
        (0, 0),
        0.028,
        0.016,
        boxstyle="round,pad=0.002",
        facecolor="#ced4da",
        edgecolor=INK,
        lw=1,
        zorder=13,
    )
    ax.add_patch(boat_cabin)

    def _place_boat(x: float, y: float) -> None:
        boat_body.set_xy(
            [
                [x - 0.01, y - 0.01],
                [x + 0.07, y - 0.01],
                [x + 0.08, y + 0.012],
                [x - 0.015, y + 0.012],
            ]
        )
        boat_cabin.set_x(x + 0.018)
        boat_cabin.set_y(y + 0.01)

    _place_boat(0.05, 0.55)

    # Animated wave lines
    wave_lines = []
    for wy in (0.25, 0.35, 0.48):
        (wl,) = ax.plot([], [], color=FOAM, lw=1.2, alpha=0.35, zorder=3)
        wave_lines.append((wl, wy))

    def _scene_time() -> float:
        # Prefer blast hydro clock so bomb syncs with audio mix.
        t, _, _, _ = blast_panel.snapshot()
        if t > 0:
            return t
        times = [p.snapshot()[0] for p in panels]
        return max(times) if times else 0.0

    def _update(_frame: int):
        try:
            now = time.time()
            t = _scene_time()
            live_n = sum(1 for p in panels if p.connected)
            link = f"→ app {host}:{port}" if to_app else "visual only"
            status_text.set_text(f"{live_n}/4 live   t={t:4.1f}s   {link}")

            # Gentle foam / waves
            foam_line.set_ydata(0.62 + 0.01 * np.sin(foam_x * 18 + now * 1.6))
            for wl, base_y in wave_lines:
                xs = np.linspace(0, 1, 60)
                wl.set_data(xs, base_y + 0.006 * np.sin(xs * 22 + now * 2.0 + base_y * 10))

            # Hydrophone listening pulse from RMS
            for item in hydro_artists:
                panel: HydroPanelState = item["panel"]
                _t, connected, _status, rms = panel.snapshot()
                listen = 0.015 + min(0.05, rms * 0.35)
                item["pulse"].set_radius(0.022 + listen)
                item["pulse"].set_alpha(0.15 + min(0.55, rms * 4.0) if connected else 0.0)
                if panel.contains_blast and panel.near_blast(t):
                    item["buoy"].set_facecolor("#ffccd5")
                    item["tip"].set_facecolor(ALERT)
                else:
                    item["buoy"].set_facecolor(BUOY)
                    item["tip"].set_facecolor(ACCENT if connected else "#adb5bd")

            # Boat + bomb choreography relative to first blast onset
            onset = blast_panel.blast_windows[0][0] if blast_panel.blast_windows else 12.0
            approach_start = max(0.0, onset - 8.0)
            drop_t = onset - 1.2

            if t < approach_start:
                boat_x = 0.04
                boat_y = 0.56
                bomb.set_data([boat_x + 0.03], [boat_y - 0.02])
                bomb.set_alpha(0.0)
                _place_boat(boat_x, boat_y)
                event_text.set_text("Listening to the reef…")
                event_text.set_color(MUTED)
                for ring in rings:
                    ring.set_alpha(0.0)
                flash.set_alpha(0.0)
            elif t < drop_t:
                # Cruise toward the blast hydro
                u = (t - approach_start) / max(drop_t - approach_start, 0.1)
                boat_x = 0.04 + (bx - 0.08 - 0.04) * u
                boat_y = 0.56 + (by + 0.08 - 0.56) * u
                _place_boat(boat_x, boat_y)
                bomb.set_data([boat_x + 0.03], [boat_y - 0.025])
                bomb.set_alpha(1.0)
                event_text.set_text("Vessel approaching hydrophone array…")
                event_text.set_color(INK)
                for ring in rings:
                    ring.set_alpha(0.0)
                flash.set_alpha(0.0)
            elif t < onset:
                # Charge sinking toward hydro
                u = (t - drop_t) / max(onset - drop_t, 0.1)
                _place_boat(bx - 0.08, by + 0.08)
                bomb_x = bx - 0.04 * (1 - u)
                bomb_y = (by + 0.06) * (1 - u) + by * u
                bomb.set_data([bomb_x], [bomb_y])
                bomb.set_alpha(1.0)
                event_text.set_text("Charge in the water…")
                event_text.set_color(ALERT)
                for ring in rings:
                    ring.set_alpha(0.0)
                flash.set_alpha(0.0)
            else:
                # Detonation + expanding rings (synced to blast audio window)
                _place_boat(bx - 0.08, by + 0.08)
                bomb.set_alpha(0.0)
                prog = blast_panel.blast_progress(t)
                if prog is None:
                    prog = min(1.0, (t - onset) / 1.5)
                flash.set_center((bx, by))
                flash.set_radius(0.03 + 0.05 * min(prog, 1.0))
                flash.set_alpha(max(0.0, 0.55 * (1.0 - prog)))
                for i, ring in enumerate(rings):
                    phase = (prog * 1.4 + i * 0.22) % 1.2
                    ring.set_center((bx, by))
                    ring.set_radius(0.03 + phase * 0.22)
                    ring.set_alpha(max(0.0, 0.7 * (1.0 - phase / 1.2)))
                if blast_panel.near_blast(t):
                    event_text.set_text(f"BLAST near {blast_panel.name} — Coralyst is detecting…")
                    event_text.set_color(ALERT)
                else:
                    event_text.set_text("Shockwave fading · check Coralyst for the alert")
                    event_text.set_color(MUTED)

            if errors:
                event_text.set_text(errors[-1][:100])
                event_text.set_color(ALERT)
        except Exception:  # noqa: BLE001
            traceback.print_exc()
        return []

    fig._coralyst_anim = FuncAnimation(  # type: ignore[attr-defined]
        fig, _update, interval=50, cache_frame_data=False
    )

    def _on_close(_event) -> None:
        stop.set()

    fig.canvas.mpl_connect("close_event", _on_close)
    fig.canvas.draw_idle()
    print("[exhibit] beach scene open — close window to stop", flush=True)
    plt.show(block=True)
    stop.set()


def main(argv: Optional[List[str]] = None) -> int:
    return exhibit_cli(argv)


if __name__ == "__main__":
    raise SystemExit(main())
