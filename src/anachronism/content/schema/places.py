"""The places of Rome where the Republic is played (F2, D-304).

Which building serves which role in which year, and the numbers of the actions taken there
(contio, vow, games, site).

Read from ``republic_rules.city.places`` (``rome/republic_rules.yaml``). The engine
(``engine/city_acts.py``) and the view (``tools/places_view.py``) read these; nothing here is
hard-coded in code. Numbers are game balance unless a source is named.
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier
from anachronism.content.schema.tech import Category

Bp = Annotated[int, Field(ge=-10_000, le=10_000)]
Sources = Annotated[tuple[str, ...], Field(min_length=1)]


class YearSpan(Frozen):
    """Inclusive years (negative = BC); ``None`` is open-ended."""

    from_year: int | None = None
    to_year: int | None = None

    def holds(self, year: int) -> bool:
        """True when ``year`` falls in the span."""
        if self.from_year is not None and year < self.from_year:
            return False
        return self.to_year is None or year <= self.to_year


class PlaceOfYear(YearSpan):
    """A building that serves a role in some years, under the name it had then."""

    monument: Identifier
    name: str = Field(min_length=1)
    blurb: str = ""
    while_building: bool = False
    """It serves while still being built (the Curia Iulia, begun 44, dedicated 29)."""
    sources: Sources


class Assembly(Frozen):
    """One of the people's assemblies: which magistrates it elects, and where it meets."""

    id: Identifier
    name: str = Field(min_length=1)
    offices: tuple[Identifier, ...] = Field(min_length=1)
    places: tuple[PlaceOfYear, ...] = Field(min_length=1)
    sources: Sources


class TradePlace(PlaceOfYear):
    """Where craftsmen or shipwrights work: ideas of these categories are begun here."""

    role: Literal["workshop", "harbour"]
    categories: tuple[Category, ...] = Field(min_length=1)


class DomusOwner(YearSpan):
    """A house of the dataset owned by a gens in some years (the dataset's own houses)."""

    monument: Identifier
    gens: Identifier
    owner: str = Field(min_length=1)
    sources: Sources


class ContioRules(Frozen):
    """Addressing the people from the Rostra (``contio``)."""

    cost: Annotated[int, Field(ge=0)] = 150
    """Influence a contio costs."""
    shift_bp: Annotated[int, Field(ge=0, le=10_000)] = 1000
    """The favour a popular family moves on the issue, from a speaker of weight 10000."""
    others_share_bp: Annotated[int, Field(ge=0, le=10_000)] = 3000
    """The share of that shift the families that do not court the people feel."""
    popular_from_bp: Annotated[int, Field(ge=0, le=10_000)] = 5000
    """A family whose ``popular_lean_bp`` is at least this courts the people."""
    candidate_bp: Annotated[int, Field(ge=0)] = 500
    """Election weight a contio for a candidate adds, from a speaker of weight 10000."""
    speakers: dict[Identifier, Annotated[int, Field(ge=0, le=30_000)]] = Field(default_factory=dict)
    """Office -> the weight of a speech from a man holding it; only these may call a contio."""
    sources: Sources = ("game balance",)


class VowCause(Frozen):
    """Why a temple is vowed, and what the vow does at once."""

    id: Identifier
    name: str = Field(min_length=1)
    needs_war: bool = False
    legitimacy_bp: Bp = 0
    unrest_bp: Bp = 0
    sources: Sources


class VowRules(Frozen):
    """Vowing a temple (``vow``): a vow now, the temple dedicated some years later."""

    cost: Annotated[int, Field(ge=0)] = 200
    """Influence: the Senate must approve the vow and let the contract."""
    wealth_per_1000: Annotated[int, Field(ge=0)] = 40
    """Wealth per 1,000 people (as ``decrees.cost``) for the building."""
    build_years: Annotated[int, Field(ge=1)] = 5
    window_years: Annotated[int, Field(ge=1)] = 60
    """A temple history dedicated within this many years from now may be vowed."""
    offered: Annotated[int, Field(ge=1)] = 6
    """How many temples the view offers to vow."""
    vowers: tuple[Identifier, ...] = Field(min_length=1)
    """Offices whose holders may pronounce a vow for the state (magistrates with imperium)."""
    causes: tuple[VowCause, ...] = Field(min_length=1)
    sources: Sources


class GamesRules(Frozen):
    """Giving games (``games``): races in a circus (``ludi``) or a munus for a dead noble."""

    ludi_wealth_per_1000: Annotated[int, Field(ge=0)] = 40
    ludi_legitimacy_bp: Bp = 300
    ludi_unrest_bp: Bp = -500
    givers: tuple[Identifier, ...] = Field(min_length=1)
    """Offices whose holders give the regular games (the aediles)."""
    giver_dignitas_bp: Annotated[int, Field(ge=0)] = 300
    giver_glory: Annotated[int, Field(ge=0)] = 20
    circus: tuple[PlaceOfYear, ...] = Field(min_length=1)
    munus_wealth_per_1000: Annotated[int, Field(ge=0)] = 30
    munus_unrest_bp: Bp = -300
    munus_dignitas_bp: Annotated[int, Field(ge=0)] = 400
    munus_window_years: Annotated[int, Field(ge=0)] = 10
    """A man dead within this many years may be honoured with a munus."""
    munus_venues: tuple[PlaceOfYear, ...] = Field(min_length=1)
    arena_builds: Identifier = "amphitheatre"
    """An anachronism of this ``builds`` kind is also a venue for a munus."""
    per_venue_per_year: Annotated[int, Field(ge=1)] = 1
    sources: Sources


class Site(Frozen):
    """A place in the city where a great work of one ``builds`` kind may rise."""

    id: Identifier
    builds: Identifier
    name: str = Field(min_length=1)
    at: Identifier
    """The dataset monument whose ground the work takes (lat/lon from it)."""
    offset_m: tuple[int, int] = (0, 0)
    """Metres east and north of that monument's point."""
    bearing: int | None = None
    source: str = Field(min_length=1)


class SiteRules(Frozen):
    """Choosing where an anachronism rises (``site``)."""

    cost: Annotated[int, Field(ge=0)] = 50
    """Influence: the censors let the contract and the site."""
    sites: tuple[Site, ...] = ()
    sources: Sources = ("game balance",)


class PlacesRules(Frozen):
    """Which building serves which role in which year, and the actions taken there."""

    senate_houses: tuple[PlaceOfYear, ...] = ()
    rostra: tuple[PlaceOfYear, ...] = ()
    assemblies: tuple[Assembly, ...] = ()
    treasury: tuple[PlaceOfYear, ...] = ()
    vow_place: tuple[PlaceOfYear, ...] = ()
    levy: tuple[PlaceOfYear, ...] = ()
    gates: tuple[PlaceOfYear, ...] = ()
    trade: tuple[TradePlace, ...] = ()
    domus: tuple[DomusOwner, ...] = ()
    temple_types: tuple[str, ...] = ("temple",)
    """Dataset ``type`` values that are temples."""
    persuade_listed: Annotated[int, Field(ge=0)] = 3
    """How many families the Curia offers to persuade on each issue before the Senate."""
    back_listed: Annotated[int, Field(ge=0)] = 4
    """How many men per office the assemblies offer to back."""
    start_listed: Annotated[int, Field(ge=0)] = 6
    """How many ideas a workshop or harbour offers to begin."""
    contio: ContioRules = ContioRules()
    vow: VowRules | None = None
    games: GamesRules | None = None
    site: SiteRules = SiteRules()
    sources: tuple[str, ...] = ()
