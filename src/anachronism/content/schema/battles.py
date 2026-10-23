"""Historical battles (R4): orders of battle for later replays and scenario scripting.

Reference data, not rules: each entry records who fought, with how many of which kind of
soldier, where, under whom, and how it ended, with the ancient passages it rests on. The
numbers are the ancient authors' own and often disagree; ``disputed`` says how.
"""

from __future__ import annotations

from typing import Literal

from pydantic import Field, model_validator

from anachronism.content.schema.base import Frozen, Identifier


class BattleSide(Frozen):
    """One army of a battle."""

    name: str = Field(min_length=1, max_length=80)
    civ: str = ""
    """Who they were, in words (``rome``, ``carthage``, ``cisalpine gauls``)."""
    commanders: tuple[str, ...] = Field(min_length=1)
    troops: dict[Identifier, int] = Field(default_factory=dict)
    """Men by unit id (see units.yaml), as the sources give them, rounded; may be partial."""
    total_men: int = Field(default=0, ge=0)
    """The source's total for the side (0 if no source gives one)."""
    formation: Identifier | None = None
    tactic: Identifier | None = None
    deployment: str = ""
    """How the line stood, left to right, as the source describes it."""
    losses: str = ""


class Battle(Frozen):
    """One historical battle."""

    id: Identifier
    name: str = Field(min_length=1, max_length=60)
    year: int
    """Negative = BC."""
    place: str = Field(min_length=1)
    terrain: Identifier
    """A terrain id of the core pack."""
    war: str = ""
    side_a: BattleSide
    """The Roman (or Roman-led) army."""
    side_b: BattleSide
    winner: Literal["a", "b", "drawn"]
    outcome: str = Field(min_length=1)
    notes: str = ""
    disputed: str = ""
    """What the sources disagree on (numbers, site, the course of the fight)."""
    sources: tuple[str, ...] = Field(min_length=1)

    @model_validator(mode="after")
    def _check_sides(self) -> Battle:
        for side in (self.side_a, self.side_b):
            if any(n <= 0 for n in side.troops.values()):
                raise ValueError(f"{side.name}: troop numbers must be positive")
        return self
