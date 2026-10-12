"""Kinds of warship (D-107).

A fleet is a number of ships of one kind. Each kind needs its advancements, costs materials
and wealth per ship to build and wealth per ship each turn to keep, fights with its
``attack``, and carries ``men`` soldiers across the sea. Content, not code.
"""

from __future__ import annotations

from typing import Annotated

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier, NonNegative


class Ship(Frozen):
    """One kind of warship."""

    id: Identifier
    name: Annotated[str, Field(min_length=1, max_length=40)]
    attack: Annotated[int, Field(ge=1, le=60)]
    """Fighting power per ship."""
    needs_techs: tuple[Identifier, ...] = ()
    materials: NonNegative = 0
    """Cost to build one ship."""
    wealth: NonNegative = 0
    upkeep_wealth: NonNegative = 0
    """Cost per ship per turn (in tenths of a unit: 10 = one wealth)."""
    note: str = ""
