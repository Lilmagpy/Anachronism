"""How the Roman Republic governs itself: magistracies, families, people and the Fasti (R2).

Years are astronomical integers as everywhere else (509 BC is ``-509``). Every entry carries
``sources`` (ancient authors first); disputed or legendary facts say so in ``notes``.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Annotated

from pydantic import Field, model_validator

from anachronism.content.schema.base import Confidence, Frozen, Identifier, Rate
from anachronism.content.schema.monuments import CityRules

Sources = Annotated[tuple[str, ...], Field(min_length=1)]
"""Where a fact comes from, e.g. ``("Livy 2.1", "Fasti Capitolini")``."""


class Order(StrEnum):
    """The two orders of the early Republic."""

    PATRICIAN = "patrician"
    PLEBEIAN = "plebeian"


class Issue(StrEnum):
    """What the Senate votes on; each family has a stance on each."""

    WAR = "war"
    PEACE = "peace"
    LAND = "land"
    COLONY = "colony"
    BUILDING = "building"
    IDEA = "idea"
    DEBT = "debt"
    CITIZENSHIP = "citizenship"


class MagistracyEra(Frozen):
    """How an office works in a span of years."""

    from_year: int
    to_year: int | None = None
    """Last year it applies (inclusive); ``None``: to the end of the game."""
    seats: Annotated[int, Field(ge=1, le=60)] = 2
    every: Annotated[int, Field(ge=1, le=20)] = 1
    """Chosen every this many years, counted from ``from_year`` (censors: 5)."""
    patricians_only: bool = False
    plebeians_only: bool = False
    plebeian_min: Annotated[int, Field(ge=0)] = 0
    """Seats that must go to plebeians."""
    plebeian_max: Annotated[int, Field(ge=0)] | None = None
    """Seats plebeians may hold (``None``: no limit)."""
    replaced_by: Identifier | None = None
    """In some years this college gives way to another (consular tribunes for consuls)."""
    replaced_bp: Rate = 0
    """Chance in a year that it does."""
    term_months: Annotated[int, Field(ge=1, le=60)] = 12
    min_age: int | None = None
    """Least age to stand (the Lex Villia annalis, 180 BC); ``None``: only adulthood."""
    interval_years: int = 0
    """Years that must pass since the candidate last held any office."""
    reelect_gap_years: int = 0
    """Years before the same office may be held again."""
    prior_office: Identifier | None = None
    """An office a candidate must have held (the cursus honorum)."""
    appointed: bool = False
    """Named by a magistrate, not elected (the dictator)."""
    companion: Identifier | None = None
    """An office filled with the holder (the dictator's magister equitum)."""
    sources: tuple[str, ...] = ()

    @model_validator(mode="after")
    def _consistent(self) -> MagistracyEra:
        if self.to_year is not None and self.to_year < self.from_year:
            raise ValueError("to_year is before from_year")
        if self.patricians_only and self.plebeians_only:
            raise ValueError("an office cannot be for both patricians only and plebeians only")
        if self.replaced_bp and not self.replaced_by:
            raise ValueError("replaced_bp needs replaced_by")
        return self

    def covers(self, year: int) -> bool:
        """True if this era applies in ``year``."""
        return year >= self.from_year and (self.to_year is None or year <= self.to_year)

    def held_in(self, year: int) -> bool:
        """True if the office is filled in ``year`` (it may be chosen only every few years)."""
        return self.covers(year) and (year - self.from_year) % self.every == 0


class Magistracy(Frozen):
    """An office of the Republic and how it changed over the centuries."""

    id: Identifier
    name: str
    rank: int
    """Place on the ladder: quaestor 1 ... consul 5; offices outside it use 0 or 9."""
    cursus: bool = True
    """Part of the cursus honorum (tribunes and dictators are not)."""
    census: bool = False
    """Its holders take the census (the censors)."""
    eras: tuple[MagistracyEra, ...] = Field(min_length=1)
    glory: Annotated[int, Field(ge=0)] = 100
    """Standing (basis points of glory) the office brings its holder."""
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW

    def era_at(self, year: int) -> MagistracyEra | None:
        """The era of this office that covers ``year``, if it exists then."""
        for era in self.eras:
            if era.covers(year):
                return era
        return None


class Standing(Frozen):
    """A family's weight at a moment; the engine seeds from the latest at or before the start."""

    from_year: int
    dignitas_bp: Annotated[int, Field(ge=0)] = 1000
    auctoritas_bp: Annotated[int, Field(ge=0)] = 1000
    wealth: Annotated[int, Field(ge=0)] = 100
    """Talents, roughly; only the proportions matter."""
    clients: Annotated[int, Field(ge=0)] = 100


class Gens(Frozen):
    """A Roman family (gens)."""

    id: Identifier
    name: str
    """Plural, as in the Fasti: ``Cornelii``."""
    nomen: str
    """Singular, as in a name: ``Cornelius``."""
    order: Order
    praenomina: tuple[str, ...] = ()
    """First names the family used (for children the game generates)."""
    cognomina: tuple[str, ...] = ()
    """Family branches, for generated persons."""
    standing: tuple[Standing, ...] = Field(min_length=1)
    stances: dict[Issue, Annotated[int, Field(ge=-10_000, le=10_000)]] = Field(default_factory=dict)
    """Disposition on each issue, -10000 (against) to 10000 (for)."""
    popular_lean_bp: Rate = 5000
    """0: conservative (optimate); 10000: populist (popularis), for the late Republic."""
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW

    def standing_at(self, year: int) -> Standing:
        """The latest standing at or before ``year`` (the first one if none is earlier)."""
        ordered = sorted(self.standing, key=lambda item: item.from_year)
        best = ordered[0]
        for item in ordered:
            if item.from_year <= year:
                best = item
        return best


class OfficeHeld(Frozen):
    """One office a person held."""

    office: Identifier
    year: int
    note: str = ""


class HistoricalPerson(Frozen):
    """A real person, seeded into the game."""

    id: Identifier
    name: str
    """Full name as written in the Fasti: ``Lucius Junius Brutus``."""
    gens: Identifier
    order: Order | None = None
    """Only if it differs from the family's."""
    born: int | None = None
    died: int | None = None
    father: Identifier | None = None
    offices: tuple[OfficeHeld, ...] = ()
    traits: tuple[Identifier, ...] = ()
    popular: bool | None = None
    """Populares or optimates in the late Republic; ``None``: the family's lean."""
    legendary: bool = False
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW

    @model_validator(mode="after")
    def _datable(self) -> HistoricalPerson:
        if self.born is None and self.died is None and not self.offices:
            raise ValueError("a person needs a birth, a death or an office to be dated by")
        return self

    def birth_year(self, age_at_first_office: int) -> int:
        """When he was born: known, or estimated from his first office or his death."""
        if self.born is not None:
            return self.born
        if self.offices:
            return min(held.year for held in self.offices) - age_at_first_office
        assert self.died is not None
        return self.died - 50


class Holder(Frozen):
    """Someone who held a seat in a year of the Fasti."""

    person: Identifier | None = None
    """A ``HistoricalPerson`` id, or ``None`` with ``name`` and ``gens`` for a man not modelled."""
    name: str = ""
    gens: Identifier | None = None
    plebeian: bool | None = None
    suffect: bool = False
    note: str = ""

    @model_validator(mode="after")
    def _identified(self) -> Holder:
        if self.person is None and not (self.name and self.gens):
            raise ValueError("a holder needs a person id, or a name and a gens")
        return self


class College(Frozen):
    """The holders of one office in one year."""

    office: Identifier
    holders: tuple[Holder, ...] = Field(min_length=1)


class FastiYear(Frozen):
    """One year of the Fasti: who held which office."""

    id: Identifier
    year: int
    colleges: tuple[College, ...] = Field(min_length=1)
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW


class Faction(Frozen):
    """A bloc in the Senate during a span of years."""

    id: Identifier
    name: str
    from_year: int
    to_year: int | None = None
    order: Order | None = None
    """Members are the families of this order."""
    populist: bool | None = None
    """Members are the families leaning this way (``True`` populares, ``False`` optimates)."""
    # neither set: every family belongs (the nobility of the middle Republic)

    def covers(self, year: int) -> bool:
        """True if the faction exists in ``year``."""
        return year >= self.from_year and (self.to_year is None or year <= self.to_year)


class SenateLaw(Frozen):
    """A law the player can put to the Senate (``law:<id>``); passing it sets a flag.

    The flag is ``RepublicState.laws[id]`` (the year it passed): content and scripts read it.
    """

    id: Identifier
    name: str
    issue: Issue
    """Which question of the Senate it is: the families' stances on it decide the vote."""
    from_year: int
    """First year the law can be proposed."""
    to_year: int | None = None
    sources: Sources
    confidence: Confidence = Confidence.LOW
    notes: str = ""

    def open_in(self, year: int) -> bool:
        """True if the law can be put to the Senate in ``year``."""
        return year >= self.from_year and (self.to_year is None or year <= self.to_year)


class SenateCosts(Frozen):
    """What each kind of proposal costs in influence, whatever the vote's outcome."""

    war_with: Annotated[int, Field(ge=0)] = 200
    peace_with: Annotated[int, Field(ge=0)] = 150
    law: Annotated[int, Field(ge=0)] = 300
    fund: Annotated[int, Field(ge=0)] = 200
    colony: Annotated[int, Field(ge=0)] = 250


class SenateRules(Frozen):
    """What the player can put to the Senate (R2 follow-up, D-286) and what a vote costs."""

    costs: SenateCosts = SenateCosts()
    fail_influence_loss: Annotated[int, Field(ge=0)] = 50
    """Influence lost besides the cost when the Senate says no (never below zero)."""
    fail_legitimacy_bp: Rate = 200
    """Legitimacy the court loses when the Senate refuses the player."""
    opposed_favour_shift: Annotated[int, Field(ge=0, le=10_000)] = 1000
    """How far the families that voted no turn against the player on that issue."""
    forced_favour_shift: Annotated[int, Field(ge=0, le=10_000)] = 1500
    """The same, when a tribune forces the matter over the Senate's refusal."""
    veto_office: Identifier = "tribune_plebs"
    veto_from_year: int = -494
    """The tribune's veto (auxilium): Livy 2.33.1-3; it can block a vote from this year."""
    force_from_year: int = -287
    """From here plebiscites bind everyone, so a tribune can also carry a refused matter."""
    veto_scale_bp: Rate = 5000
    """Chance of an interposition, per point of popular lean between the two sides of the vote."""
    veto_max_bp: Rate = 2500
    """Never more than this chance: the interposition is a small risk, not a rule."""
    laws: tuple[SenateLaw, ...] = ()
    sources: tuple[str, ...] = ()


class RepublicRules(Frozen):
    """Tunable numbers of the Republic (one optional file per pack); every field has a default."""

    default_praenomina: tuple[str, ...] = ()
    """First names for generated persons of a family that lists none."""
    adult_age: int = 17
    age_at_first_listed_office: int = 40
    """Assumed when a person's birth is unknown: their age at their first recorded office."""
    pre_villia_min_age: int = 30
    births_per_gens_per_year_bp: Rate = 3000
    death_bp_by_age: tuple[tuple[int, int], ...] = (
        (0, 300),
        (17, 120),
        (40, 200),
        (55, 450),
        (65, 1000),
        (75, 2500),
        (85, 6000),
    )
    """(from age, yearly chance of death in bp); the latest row at or below the age applies."""
    election_noise: Annotated[int, Field(ge=0)] = 1000
    """Floor added to every candidate's weight, so an outsider can still win."""
    glory_weight_bp: Rate = 3000
    wealth_weight_bp: Rate = 1500
    faction_weight_bp: Rate = 2500
    backing_bp: Annotated[int, Field(ge=0)] = 6000
    """Weight the player's backing adds to a candidate."""
    dignitas_decay_bp: Rate = 200
    """Share of a family's dignitas above its baseline that fades each year."""
    dictator_emergency_bp: Rate = 4000
    """Emergency level at which the Senate begins to think of a dictator."""
    influence_income: Annotated[int, Field(ge=0)] = 100
    persuade_cost: Annotated[int, Field(ge=1)] = 150
    persuade_shift: Annotated[int, Field(ge=0, le=10_000)] = 2500
    back_cost: Annotated[int, Field(ge=1)] = 250
    census_citizen_share_bp: Rate = 1800
    """Adult male citizens as a share of the people, for the census."""
    spawn_new_men: bool = True
    """When too few men are eligible, new men (novi homines) stand."""
    factions: tuple[Faction, ...] = ()
    senate: SenateRules = SenateRules()
    """What the player may put to the Senate, and the tribune's veto."""
    city: CityRules = CityRules()
    """The city of Rome's calendar of games and where the Senate sits (U7)."""
    sources: tuple[str, ...] = ()
