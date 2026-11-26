"""Heraldic symbols for civilisations (G1): the client draws one on badges, banners and maps."""

from __future__ import annotations

from anachronism.content.schema.base import Frozen, Identifier


class Symbol(Frozen):
    """One symbol a civilisation may bear."""

    id: Identifier
    name: str
    source: str = ""
    """Where the art comes from (an icon in the game-icons.net collection)."""
