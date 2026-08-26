from __future__ import annotations

from pathlib import Path
from typing import List, Optional, Sequence

import joblib
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from reef_pipeline import EVENT_BOAT
from reef_pipeline.audio import load_audio
from reef_pipeline.catalog import Clip, load_annotations
from .stage2 import extract_features, jitter


def train_boat_model(
    out_path: Path,
    clips: Optional[Sequence[Clip]] = None,
    seed: int = 0,
    max_per_class: int = 800,
    augment: bool = True,
) -> Path:
    rng = np.random.default_rng(seed)
    clips = list(clips or load_annotations())
    pos = [c for c in clips if c.event_type == EVENT_BOAT]
    neg = [c for c in clips if c.event_type != EVENT_BOAT]
    rng.shuffle(pos)
    rng.shuffle(neg)
    pos = pos[:max_per_class]
    neg = neg[:max_per_class]
    xs: List[np.ndarray] = []
    ys: List[int] = []
    for label, group in ((1, pos), (0, neg)):
        for c in group:
            y, sr = load_audio(c.path)
            variants = [y]
            if augment:
                variants.append(jitter(y, rng))
            for v in variants:
                xs.append(extract_features(v, sr))
                ys.append(label)
    clf = Pipeline(
        [
            ("scale", StandardScaler()),
            ("lr", LogisticRegression(max_iter=400, class_weight="balanced")),
        ]
    )
    clf.fit(np.vstack(xs), np.asarray(ys))
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": clf, "kind": "boat_lr"}, out_path)
    return out_path


def smooth_binary(
    scores: Sequence[float],
    thresh: float = 0.5,
    enter: float = 0.6,
    leave: float = 0.4,
) -> List[int]:
    """Hysteresis so boat presence doesn't flap on borderline frames."""
    out: List[int] = []
    state = 0
    for s in scores:
        if state == 0 and s >= enter:
            state = 1
        elif state == 1 and s < leave:
            state = 0
        out.append(state)
    _ = thresh
    return out
