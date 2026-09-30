"""Civilisations (polities) and their lasting identity."""

from __future__ import annotations

from anachronism.content.schema.base import Frozen, HexColour, Identifier


class CivDefinition(Frozen):
    """A polity's identity. Its situation at a given moment lives in scenarios."""

    id: Identifier
    name: str
    adjective: str
    lineage: Identifier
    """Cultural line the player's guiding hand follows across dynasties (D-011)."""
    colour: HexColour
    description: str = ""
    emblem: str = ""
    """One or two characters on the civilisation's badge (e.g. 秦); the adjective's first
    letter when empty. Characters outside Latin must be in the client's emblem font
    (scripts/build_emblem_font.py)."""
    portrait: str = ""
    """Placeholder portrait style drawn by the client (e.g. ``court``, ``steppe``,
    ``southern``, ``hills``); real portraits replace these later (D-060)."""
