"""Buildings raised in a province (D-111): markets, granaries, temples, workshops, mines...

Each needs its advancements (all adopted), may need the province to lie on the coast or a
river or to hold a map resource, costs materials and wealth to build (times the scenario's
``cost_scale``), takes ``decades`` to finish, and costs wealth each decade to keep. Once
standing it makes its province produce more of something, grow faster, hold more people,
or calms the realm. ``look`` tells the client what to draw in the city. Content, not code.
"""

from __future__ import annotations

from typing import Annotated

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier, NonNegative

Bonus = Annotated[int, Field(ge=0, le=10_000)]
"""A per-province bonus in basis points (2_000 = +20%)."""


class Building(Frozen):
    """One kind of building."""

    id: Identifier
    name: Annotated[str, Field(min_length=1, max_length=40)]
    note: str = ""
    needs_techs: tuple[Identifier, ...] = ()
    """Advancements that must all be in use."""
    replaces: Identifier | None = None
    """An older building this one improves on: it needs it, and takes its place."""
    coastal: bool = False
    river: bool = False
    needs_resource: tuple[Identifier, ...] = ()
    """The province must have access to at least one of these map resources."""
    materials: NonNegative = 0
    wealth: NonNegative = 0
    decades: Annotated[int, Field(ge=1, le=5)] = 1
    """How long it takes to build."""
    upkeep: NonNegative = 0
    """Wealth per decade to keep it (times ``cost_scale``)."""
    food_bp: Bonus = 0
    materials_bp: Bonus = 0
    wealth_bp: Bonus = 0
    knowledge_bp: Bonus = 0
    growth_bp: Bonus = 0
    """Faster population growth in the province."""
    capacity_bp: Bonus = 0
    """More people the province can hold."""
    calm_bp: Bonus = 0
    """Unrest eased each decade, weighted by the province's share of the realm's people."""
    literacy_bp: Bonus = 0
    """Literacy gained each decade, weighted the same way."""
    veterans_bp: Bonus = 0
    """Training for soldiers raised in the province (their starting experience)."""
    look: Identifier = "hall"
    """What the client draws in the city (e.g. market, temple, mill)."""
