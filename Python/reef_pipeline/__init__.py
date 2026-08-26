"""Coral reef hydrophone pipeline."""

from __future__ import annotations

__version__ = "0.1.0"

DOMAIN_INDONESIA_HYDROMOTH = "indonesia_hydromoth"
DOMAIN_GENERAL = "general"
VALID_DOMAIN_SCOPES = (DOMAIN_INDONESIA_HYDROMOTH, DOMAIN_GENERAL)

BLAST_LABEL = "anthrop_bomb"
BOAT_LABEL = "anthrop_boat_engine"
MECHANICAL_LABEL = "anthrop_mechanical"
AMBIENT_LABEL = "ambient"

EVENT_BLAST = "blast"
EVENT_BOAT = "boat"
EVENT_MECHANICAL = "mechanical"
EVENT_AMBIENT = "ambient"
EVENT_BIOPHONY = "biophony"
