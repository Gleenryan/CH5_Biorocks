from __future__ import annotations

import os
from pathlib import Path

SR = 16000
CLIP_S = 1.92

WINDOW_S = 1.92
HOP_S = 0.96
FADE_MS = 20
FADE_MS_MIN = 10
FADE_MS_MAX = 50

STAGE1_BASELINE_S = 30.0
STAGE1_FRAME_S = 0.01
STAGE1_HOP_S = 0.005
STAGE1_EXCESS_DB = 12.0
STAGE1_RISE_S = 0.050
STAGE1_FLATNESS_MIN = 0.25
STAGE1_REFRACTORY_S = 0.4

BLAST_CANDIDATE_S = 1.92
BLAST_WINDOW_S = BLAST_CANDIDATE_S

BI_FMIN = 2000.0
BI_FMAX = 8000.0
SPL_LOW = (20.0, 2000.0)
SPL_HIGH = (2000.0, 10000.0)

INDONESIA_DATASETS = {"indonesia_bombs"}
HYDROMOTH_RECORDERS = {"hydromoth"}
BLAST_SHARERS = {"b_williams_ucl"}

ENV_RAW = "REEFGUARD_RAW_DATA"


def data_root() -> Path:
    env = os.environ.get(ENV_RAW)
    if env:
        return Path(env).expanduser().resolve()
    here = Path(__file__).resolve()
    # Vendored under CH5_Biorocks/Python/ → prefer Desktop/CH5/raw-data.
    candidates = [
        here.parents[1],  # raw-data layout when package lives at data root
        Path.home() / "Desktop" / "CH5" / "raw-data",
    ]
    if len(here.parents) > 3:
        candidates.append(here.parents[3] / "CH5" / "raw-data")
    for candidate in candidates:
        if (candidate / "ReefSet_v1.0").is_dir() or (candidate / "ind_N1").is_dir():
            return candidate
    return Path.home() / "Desktop" / "CH5" / "raw-data"


def reefset_dir(root: Path | None = None) -> Path:
    return (root or data_root()) / "ReefSet_v1.0"


def annotations_path(root: Path | None = None) -> Path:
    return reefset_dir(root) / "reefset_annotations.json"


def reefset_wav_dir(root: Path | None = None) -> Path:
    return reefset_dir(root) / "full_dataset"


def ind_n1_dir(root: Path | None = None) -> Path:
    return (root or data_root()) / "ind_N1"


def blasts_203_dir(root: Path | None = None) -> Path:
    return (root or data_root()) / "blasts_203_confirmed"


def drive_blasts_dir(root: Path | None = None) -> Path:
    return (root or data_root()) / "drive_blasts_38"
