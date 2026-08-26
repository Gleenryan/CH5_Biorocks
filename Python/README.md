# Coralyst hydrophone Python pipeline

This is the `reef_pipeline` package used by the Coralyst macOS app Simulator.

## Setup

```bash
cd Python
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Set data root (ReefSet / ind_N1 / blasts):

```bash
export REEFGUARD_RAW_DATA="/Users/bhanageviraj/Desktop/CH5/raw-data"
```

## Stream into the running app (DEBUG)

With Coralyst running and the hydrophone port listening on 17455:

```bash
# Four hydrophones on Indonesia N1, each with separate audio
.venv/bin/python -m reef_pipeline stream --fleet --realtime

# Exhibition visualizer (beach scene) + stream into the app
.venv/bin/python -m reef_pipeline exhibit --loop --fullscreen

# One hydro only
.venv/bin/python -m reef_pipeline stream --scenario blast_in_ambient --realtime \
  --site-name "Indonesia N1" --hydrophone-name "Hydrophone 1"

# Stream a real ind_N1 file into Hydrophone 1
.venv/bin/python -m reef_pipeline stream --wav "$REEFGUARD_RAW_DATA/ind_N1/ind_N1_20220906_105800.WAV" \
  --realtime --site-name "Indonesia N1" --hydrophone-name "Hydrophone 1"
```

The Simulator screen in Coralyst can also launch these commands with one click.
Use **Exhibition** for a side-by-side demo: Python shows a beach/sea scene with
hydrophones and a blast event; Coralyst shows detections and alerts.

Offline CLI (no app): `simulate`, `features`, `detect`, `train-blast`, `validate`, `listen`.

### Exhibition layout

1. Run Coralyst (DEBUG) and open **Tools → Simulator**.
2. Choose **Exhibition visualizer** → **Start exhibition**.
3. Place the Python spectrogram window beside Coralyst Alerts / Live results.
4. When Core ML promotes a blast, it appears in the app while the visualizer flashes the impulse window.
