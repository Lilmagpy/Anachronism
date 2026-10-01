"""Kinds of soldier an army is made of (the war of armies and battles, D-099).

Each unit type says what it needs (advancements known, resources on the map), what 1,000
men of it cost to raise and keep, how well they attack and defend, what they are good
against, and where they fight well or badly. Content, not code: a war elephant or a
musketeer is a YAML entry.
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier, NonNegative

UnitKind = Literal["infantry", "spear", "missile", "mounted", "elephant", "siege"]
"""What a unit is, for match-ups: spears stop horse, horse rides down archers..."""

Stat = Annotated[int, Field(ge=0, le=40)]
Swing = Annotated[int, Field(ge=-8000, le=8000)]
"""A modifier of up to 80% either way, in basis points."""


class Unit(Frozen):
    """One kind of soldier."""

    id: Identifier
    name: Annotated[str, Field(min_length=1, max_length=40)]
    kind: UnitKind
    attack: Stat
    """Fighting power when attacking, per 1,000 men."""
    defence: Stat
    """Fighting power when defending, per 1,000 men."""
    siege: Stat = 0
    """How much 1,000 of them speed a siege (rams, towers, guns)."""
    mobility: Annotated[int, Field(ge=1, le=4)] = 2
    """Provinces an army of only these can march in one turn."""
    needs_techs: tuple[Identifier, ...] = ()
    """Advancements the state must use (adopted) to raise them."""
    needs_resources: tuple[Identifier, ...] = ()
    """Resources the state must hold on its land (horses for cavalry)."""
    food: NonNegative = 0
    """Cost to raise 1,000 men (food, materials, wealth, in store units)."""
    materials: NonNegative = 0
    wealth: NonNegative = 0
    upkeep_food: NonNegative = 0
    """Cost per turn to keep 1,000 men in the field."""
    upkeep_wealth: NonNegative = 0
    bonus_vs: dict[UnitKind, Swing] = Field(default_factory=dict)
    """Extra power against enemies of these kinds (in proportion to how many there are)."""
    terrain: dict[Identifier, Swing] = Field(default_factory=dict)
    """Extra (or less) power when fighting on these terrains."""
    note: str = ""
    """A line of history shown in the game."""
