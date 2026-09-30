"""Scenarios: a named historical moment and everyone's situation in it."""

from __future__ import annotations

from typing import Annotated

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier, NonNegative, Positive, Rate
from anachronism.content.schema.rivals import Disposition, Script, StartingRelation
from anachronism.content.schema.tech import SocialGroup, Stage


class StartingStockpiles(Frozen):
    """Stored resources at the start."""

    food: NonNegative
    materials: NonNegative
    wealth: NonNegative
    knowledge: NonNegative


class StartingStats(Frozen):
    """Civilisation-wide stats at the start, in basis points of 0-100."""

    literacy_bp: Rate
    unrest_bp: Rate
    legitimacy_bp: Rate
    suspicion_bp: Rate = 0


class Successor(Frozen):
    """Who comes next on the throne, if history is followed (brief §7.6)."""

    name: Annotated[str, Field(min_length=1, max_length=60)]
    age: Annotated[int, Field(ge=1, le=90)] = 25
    """Age on taking the throne."""
    disposition: Disposition | None = None
    """Their temperament; empty keeps the state's."""


class ScenarioCiv(Frozen):
    """One civilisation's situation at the scenario's start."""

    capital: Identifier
    provinces: dict[Identifier, Positive]
    """Owned provinces and their starting populations."""
    stockpiles: StartingStockpiles
    stats: StartingStats
    influence: dict[SocialGroup, Rate]
    """How much weight each social group carries (0-100%)."""
    techs: dict[Identifier, Stage] = Field(default_factory=dict)
    """Advancements already known at the start (the era baseline)."""
    leader: str = ""
    """Who rules at the start, e.g. ``Duke Xiao``; empty when the sources are unclear."""
    pitch: str = ""
    """One or two sentences for the civilisation picker: why play this state now."""
    leader_age: Annotated[int, Field(ge=1, le=90)] = 40
    """The ruler's age at the start."""
    successors: tuple[Successor, ...] = ()
    """Who follows, in order, when rulers die (after that, unnamed heirs)."""
    disposition: Disposition = Disposition.CAUTIOUS
    """The ruler's temperament, which steers the civilisation once it leaves its script."""
    scripts: tuple[Script, ...] = ()
    """What this civilisation means to do, if conditions allow (brief §7.1)."""


class Scenario(Frozen):
    """A playable starting moment."""

    id: Identifier
    name: str
    description: str = ""
    start_year: int
    years_per_turn: Annotated[int, Field(ge=1, le=50)]
    player_civ: Identifier
    civs: dict[Identifier, ScenarioCiv]
    unowned: dict[Identifier, NonNegative] = Field(default_factory=dict)
    """Provinces nobody controls, with their populations."""
    map: Identifier | None = None
    """Real-Earth map region the client draws (e.g. ``east_asia``); ``None`` means a map
    generated from province positions. On a real map every province needs a ``latlon``."""
    relations: tuple[StartingRelation, ...] = ()
    """Alliances, wars and grudges at the start; other reachable pairs begin neutral."""
    cost_scale: Annotated[int, Field(ge=1, le=1000)] = 1
    """Multiplies every project cost. Scenarios with real historical populations (millions,
    not tens of thousands) raise it so inventions cost the same share of a state's effort."""
