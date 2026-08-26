from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Optional

from reef_pipeline import (
    DOMAIN_GENERAL,
    DOMAIN_INDONESIA_HYDROMOTH,
    EVENT_BLAST,
    VALID_DOMAIN_SCOPES,
)


class DomainScopeError(ValueError):
    pass


@dataclass
class Event:
    event_id: str
    type: str
    t_start: float
    t_end: float
    confidence: float
    site_id: str
    recorder_id: str
    source_file: str
    audio_snippet_path: str = ""
    domain_scope: Optional[str] = None

    def __post_init__(self) -> None:
        if self.type == EVENT_BLAST and self.domain_scope not in VALID_DOMAIN_SCOPES:
            raise DomainScopeError(
                "blast events require domain_scope "
                f"{DOMAIN_INDONESIA_HYDROMOTH!r} or {DOMAIN_GENERAL!r}; "
                "never emit a bare blast confidence"
            )

    def to_dict(self) -> dict:
        d = asdict(self)
        if self.type != EVENT_BLAST:
            d.pop("domain_scope", None)
        return d
