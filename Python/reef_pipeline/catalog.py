from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Optional, Sequence

from reef_pipeline import (
    AMBIENT_LABEL,
    BLAST_LABEL,
    BOAT_LABEL,
    DOMAIN_GENERAL,
    DOMAIN_INDONESIA_HYDROMOTH,
    EVENT_AMBIENT,
    EVENT_BIOPHONY,
    EVENT_BLAST,
    EVENT_BOAT,
    EVENT_MECHANICAL,
    MECHANICAL_LABEL,
)
from reef_pipeline.config import (
    BLAST_SHARERS,
    HYDROMOTH_RECORDERS,
    INDONESIA_DATASETS,
    annotations_path,
    blasts_203_dir,
    data_root,
    drive_blasts_dir,
    reefset_wav_dir,
)


@dataclass
class Clip:
    clip_id: str
    path: Path
    label: str
    data_sharer: str
    dataset: str
    recorder: str
    source: str = "reefset"

    @property
    def event_type(self) -> str:
        return label_to_event_type(self.label)

    @property
    def domain_scope(self) -> str:
        return domain_scope_for(self.dataset, self.recorder, self.data_sharer)


def label_to_event_type(label: str) -> str:
    if label == BLAST_LABEL:
        return EVENT_BLAST
    if label == BOAT_LABEL:
        return EVENT_BOAT
    if label == MECHANICAL_LABEL:
        return EVENT_MECHANICAL
    if label == AMBIENT_LABEL:
        return EVENT_AMBIENT
    return EVENT_BIOPHONY


def domain_scope_for(
    dataset: Optional[str] = None,
    recorder: Optional[str] = None,
    data_sharer: Optional[str] = None,
    site_id: Optional[str] = None,
    **kwargs,
) -> str:
    """Blast training support is Indonesia Hydromoth only."""
    data_sharer = kwargs.get("data_sharer", data_sharer)
    site_id = kwargs.get("site_id", site_id)
    ds = (dataset or "").strip().lower()
    rec = (recorder or "").strip().lower()
    sharer = (data_sharer or "").strip().lower()
    site = (site_id or "").strip().lower()
    indonesia = (
        ds in INDONESIA_DATASETS
        or "indonesia" in ds
        or site in {"indonesia_bombs", "indonesia", "ind_n1"}
        or site.startswith("ind_n")
        or "indonesia" in site
    )
    hydromoth = rec in HYDROMOTH_RECORDERS or (indonesia and rec in {"", "unknown"})
    known_sharer = sharer in BLAST_SHARERS or sharer == ""
    if indonesia and hydromoth and known_sharer:
        return DOMAIN_INDONESIA_HYDROMOTH
    return DOMAIN_GENERAL


def load_annotations(root: Optional[Path] = None) -> List[Clip]:
    root = root or data_root()
    path = annotations_path(root)
    wav_dir = reefset_wav_dir(root)
    with open(path) as f:
        rows = json.load(f)
    clips = []
    for row in rows:
        clips.append(
            Clip(
                clip_id=str(row["id"]),
                path=wav_dir / row["file_name"],
                label=row["label"],
                data_sharer=row.get("data_sharer", ""),
                dataset=row.get("dataset", ""),
                recorder=row.get("recorder", ""),
                source="reefset",
            )
        )
    return clips


def clips_of_type(clips: Sequence[Clip], event_type: str) -> List[Clip]:
    return [c for c in clips if c.event_type == event_type]


def md5_file(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def iter_wavs(folder: Path) -> Iterator[Path]:
    if not folder.exists():
        return
        yield  # pragma: no cover
    for p in sorted(folder.iterdir()):
        if p.suffix.lower() == ".wav" and not p.name.startswith("."):
            yield p


def unique_blast_paths(root: Optional[Path] = None) -> List[Path]:
    root = root or data_root()
    seen: Dict[str, Path] = {}
    for folder in (blasts_203_dir(root), drive_blasts_dir(root)):
        for p in iter_wavs(folder):
            digest = md5_file(p)
            if digest not in seen:
                seen[digest] = p
    return list(seen.values())


def blast_training_clips(root: Optional[Path] = None) -> List[Clip]:
    clips = [c for c in load_annotations(root) if c.label == BLAST_LABEL]
    seen = {md5_file(c.path) for c in clips if c.path.exists()}
    for extra in extra_blast_holdout(root):
        digest = md5_file(extra.path)
        if digest not in seen:
            clips.append(extra)
            seen.add(digest)
    return clips


def extra_blast_holdout(root: Optional[Path] = None) -> List[Clip]:
    root = root or data_root()
    confirmed = {md5_file(p) for p in iter_wavs(blasts_203_dir(root))}
    out = []
    for i, p in enumerate(iter_wavs(drive_blasts_dir(root))):
        if md5_file(p) in confirmed:
            continue
        out.append(
            Clip(
                clip_id=f"drive_blast_{i}",
                path=p,
                label=BLAST_LABEL,
                data_sharer="unknown",
                dataset="drive_semporna",
                recorder="unknown",
                source="drive_blasts_38",
            )
        )
    return out


def negative_training_clips(
    root: Optional[Path] = None,
    types: Iterable[str] = (EVENT_BOAT, EVENT_MECHANICAL, EVENT_AMBIENT, EVENT_BIOPHONY),
    max_biophony: int = 2000,
) -> List[Clip]:
    out: List[Clip] = []
    bio_n = 0
    for c in load_annotations(root):
        et = c.event_type
        if et not in types or et == EVENT_BLAST:
            continue
        if et == EVENT_BIOPHONY:
            if bio_n >= max_biophony:
                continue
            bio_n += 1
        out.append(c)
    return out
