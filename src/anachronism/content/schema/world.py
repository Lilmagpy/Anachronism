"""The physical world: eras, terrain, map resources and province geography."""

from __future__ import annotations

from enum import StrEnum
from typing import Annotated

from pydantic import Field, model_validator

from anachronism.content.schema.base import Frozen, Identifier, NonNegative, Positive


class Era(Frozen):
    """A span of history. Effect caps are set per era."""

    id: Identifier
    name: str
    ends: int | None
    """First year that is no longer in this era; ``None`` for the last era."""


class Terrain(Frozen):
    """A terrain type and what 1,000 people living on it produce per decade."""

    id: Identifier
    name: str
    food_bp: NonNegative
    """Food per 1,000 people per decade (10_000 = 1 unit)."""
    materials_bp: NonNegative
    capacity: Positive
    """Default number of people a province of this terrain can support."""


class MapResource(Frozen):
    """A resource that can exist on the map: iron, timber, horses..."""

    id: Identifier
    name: str


class Access(StrEnum):
    """How usable a map resource is in a province."""

    ACCESSIBLE = "accessible"
    LIMITED = "limited"
    UNEXPLORED = "unexplored"

    @property
    def usable(self) -> bool:
        """True if the resource can meet material requirements."""
        return self is not Access.UNEXPLORED


class ProvinceGeography(Frozen):
    """The fixed geography of a province. Ownership and population live in scenarios."""

    id: Identifier
    name: str
    terrain: Identifier
    river: bool = False
    coastal: bool = False
    capacity: Annotated[int, Field(ge=1)] | None = None
    """Overrides the terrain's default capacity when set."""
    resources: dict[Identifier, Access] = Field(default_factory=dict)
    neighbours: tuple[Identifier, ...] = ()

    @model_validator(mode="after")
    def _check_neighbours(self) -> ProvinceGeography:
        if self.id in self.neighbours:
            raise ValueError("a province cannot neighbour itself")
        if len(set(self.neighbours)) != len(self.neighbours):
            raise ValueError("neighbours contains duplicates")
        return self
