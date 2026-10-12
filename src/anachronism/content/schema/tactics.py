"""Battle plans (D-108): how an army means to fight, and which plans beat which.

Each army goes into battle with a plan - its general's natural choice for its soldiers and
the ground, or one its ruler ordered. A plan that beats the enemy's gives its side the edge.
Content, not code: a new plan is a YAML entry.
"""

from __future__ import annotations

from typing import Literal

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier, Rate
from anachronism.content.schema.scenario import GeneralTrait


class Tactic(Frozen):
    """One battle plan."""

    id: Identifier
    name: str = Field(min_length=1, max_length=40)
    """A noun phrase: "Feigned retreat"."""
    note: str = Field(min_length=1, max_length=400)
    """What the plan is, what it beats and what beats it, for the player."""
    needs_units: tuple[Identifier, ...] = ()
    """Soldiers it needs (any of these kinds of unit) ..."""
    needs_share_bp: Rate = 0
    """... making up at least this share of the side's men."""
    needs_terrain: tuple[Identifier, ...] = ()
    """Ground it can only be fought on (empty: any)."""
    when: Literal["any", "attacking", "defending"] = "any"
    """Only for the side that attacks (or defends) the province."""
    power_bp: int = Field(default=0, ge=-5000, le=5000)
    """Extra fighting power for its side."""
    terrain_bp: dict[Identifier, int] = Field(default_factory=dict)
    """Extra (or less) power on particular ground."""
    beats: tuple[Identifier, ...] = ()
    """Plans this one beats: its side has the edge against them."""
    trait: GeneralTrait | None = None
    """A general with this gift doubles the plan's edge."""
    losses_bp: int = Field(default=0, ge=-8000, le=10_000)
    """More (or fewer) dead on both sides."""
    rout_bp: int = Field(default=0, ge=0, le=5000)
    """If it wins, the beaten side loses as if the defeat were this much worse."""
    skirmish_bp: int = Field(default=0, ge=-5000, le=10_000)
    """More (or less) harm done by the army's missile troops in the opening skirmish (D-267)."""
