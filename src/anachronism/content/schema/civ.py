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
