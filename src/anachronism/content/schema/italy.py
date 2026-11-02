"""Rome's way of expanding (R3, F1): allies and their treaties, colonies, provinces.

Four content kinds, all in the ``rome`` pack:

- ``treaties``: each Italian people allied to Rome (D-287: the *socii* are civs allied to Rome)
  has a treaty with a levy obligation, a place on the ladder of rights and the steps history
  gave it (Caere 353, the Campanians 338, the Hernici 306, the Lex Iulia 90).
- ``colonies``: the historical foundations (Livy's notices, Velleius 1.14-15), each with its
  year, its kind (Latin or citizen) and the map province it lies in.
- ``provinciae``: the overseas regions that became a *provincia* with a governor, from 227 BC.
- ``italy_rules``: every tunable number of these systems (game balance, with the sources the
  defaults are drawn from), one optional file.

Years are astronomical integers (``-264`` is 264 BC). Every entry carries ``sources``.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Annotated

from pydantic import Field, model_validator

from anachronism.content.schema.base import Confidence, Frozen, Identifier, Rate

Sources = Annotated[tuple[str, ...], Field(min_length=1)]


class AllyStatus(StrEnum):
    """The ladder of rights a people climbs: each step changes levies, loyalty and the census."""

    ALLY = "ally"
    """An Italian ally bound by treaty (*socius*): its own laws, its own levy for Rome."""
    LATIN = "latin"
    """The Latin right (*ius Latii*): trade and marriage with Romans, a heavier levy."""
    SINE_SUFFRAGIO = "sine_suffragio"
    """Citizenship without the vote: its men are counted in the census (Caere 353, Livy 7.20
    and Gellius 16.13; the Campanians, Fundi and Formiae 338, Livy 8.14.10)."""
    CITIZEN = "citizen"
    """Full citizenship: the people and its land become Roman (the Lex Iulia of 90)."""

    @property
    def rank(self) -> int:
        """Place on the ladder, 0 (ally) to 3 (citizen)."""
        return _RANK[self]


_RANK = {
    AllyStatus.ALLY: 0,
    AllyStatus.LATIN: 1,
    AllyStatus.SINE_SUFFRAGIO: 2,
    AllyStatus.CITIZEN: 3,
}


class ColonyKind(StrEnum):
    """Latin colonies were new states with the Latin right; citizen colonies stayed Roman."""

    LATIN = "latin"
    CITIZEN = "citizen"


class StatusStep(Frozen):
    """A step up the ladder that history gave a people in a year (applied in a chronicle)."""

    year: int
    status: AllyStatus
    note: str = ""
    sources: Sources


class AllyTreaty(Frozen):
    """One people's treaty with Rome.

    ``levy_bp`` is the share of the people's population the treaty obliges them to furnish
    when Rome calls (the *formula togatorum*): Polybius 2.24 lists each people's men able to
    bear arms in 225 BC apart from the Romans', and the engine takes the allies as a whole to
    match the citizen levy (``ItalyRules.allied_ratio_bp``), each people's share pro rata.
    """

    id: Identifier
    civ: Identifier
    """The ally's civ id in the scenarios (``e2_samnites``...)."""
    name: str
    status: AllyStatus = AllyStatus.ALLY
    levy_bp: Rate = 800
    """Share of its people the treaty obliges it to send (basis points)."""
    loyalty_bp: Rate = 7000
    booty_share: bool = True
    """It shares in the booty of Rome's wars (so victories raise its loyalty)."""
    land_share: bool = False
    """It shares in the land Rome takes (colonies in its country do not offend it)."""
    steps: tuple[StatusStep, ...] = ()
    """What history gave it, by year; applied in order when the year comes."""
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW

    @model_validator(mode="after")
    def _ordered(self) -> AllyTreaty:
        years = [step.year for step in self.steps]
        if years != sorted(years):
            raise ValueError("steps must be in year order")
        return self


class ColonyFoundation(Frozen):
    """A colony history founded, in its year, on the map province that holds the site."""

    id: Identifier
    name: str
    province: Identifier
    kind: ColonyKind
    year: int
    settlers: Annotated[int, Field(ge=1)] | None = None
    """Colonists the source names (men, or families: ``notes`` says which); the rules'
    default when unknown."""
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW


class ProvinciaDefinition(Frozen):
    """An overseas region that Rome governed as a *provincia* once it held it (from 227 BC)."""

    id: Identifier
    name: str
    provinces: Annotated[tuple[Identifier, ...], Field(min_length=1)]
    """The map provinces it is made of."""
    from_year: int = -227
    """No earlier than this: the engine makes it a provincia when Rome holds the land, the age
    of provinces has come (227) and this year is reached."""
    historical_year: int | None = None
    """The year history gave it its governor, for the view."""
    office: Identifier = "praetor"
    """The magistracy its governor is drawn from."""
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW

    @model_validator(mode="after")
    def _distinct(self) -> ProvinciaDefinition:
        if len(set(self.provinces)) != len(self.provinces):
            raise ValueError("provinces contains duplicates")
        return self


class ItalyRules(Frozen):
    """Tunable numbers of the alliance, colony and province systems; every field has a default."""

    # --- the allies' levies
    allied_ratio_bp: Annotated[int, Field(ge=0, le=30_000)] = 12_000
    """Allied men in a Roman army for every ten thousand citizen soldiers: each consular army
    had 20,800 Roman foot beside 30,000 allied foot (Polybius 2.24.3-4), about half the force
    and more; Velleius 2.15.2 has the allies furnish twice the Romans' numbers."""
    levy_loyalty_floor_bp: Rate = 3000
    """Below this loyalty an ally sends no men (the twelve colonies of 209: Livy 27.9.7)."""
    # --- loyalty
    baseline_loyalty_bp: Rate = 6000
    loyalty_drift_bp: Rate = 300
    """Share of the gap to the baseline closed each year."""
    victory_bp: Annotated[int, Field(ge=0)] = 300
    """Per Roman victory in the year, for every ally; doubled for an ally with a booty share."""
    defeat_bp: Annotated[int, Field(ge=0)] = 600
    """Per Roman defeat (the allies defected after Cannae: Polybius 3.118.5)."""
    refused_citizenship_bp: Annotated[int, Field(ge=0)] = 150
    """Per year the citizenship law could be passed and has not been (from 125: Appian
    BC 1.34)."""
    confiscation_bp: Annotated[int, Field(ge=0)] = 400
    """Per year, for ``confiscation_years`` after an agrarian law: the Gracchan commission's
    claims on the allies' land (Appian BC 1.18-21)."""
    confiscation_years: Annotated[int, Field(ge=0)] = 10
    colony_in_ally_land_bp: Annotated[int, Field(ge=0)] = 800
    """When a colony is planted in an ally's country without a land share (Fregellae and the
    Samnites' complaint: Livy 8.23.6, unverified)."""
    grant_bp: Annotated[int, Field(ge=0)] = 2000
    """A step up the ladder."""
    # --- the Social War
    social_war_year: int = -91
    """The allies rise if their loyalty is low and citizenship has not been granted (Appian
    BC 1.38-39; Velleius 2.15.1)."""
    social_war_until: int = -85
    """After this the moment has passed (the revolt may still come from a single ally's
    grievance through the ordinary rules)."""
    social_war_loyalty_bp: Rate = 4000
    """Allies below this rise as a bloc in the Social War."""
    lex_iulia_year: int = -90
    """Citizenship for the loyal allies, the year after the rising (Appian BC 1.49; Velleius
    2.16.4): default history, unless the law is already passed or the war never came."""
    plautia_papiria_year: int = -89
    """Citizenship for those who laid down their arms (Velleius 2.16.4, 2.17.1; Cicero, Pro
    Archia 7, unverified)."""
    lay_down_arms_bp: Rate = 5000
    """Yearly chance a risen ally lays down its arms for the citizenship once it is offered
    (the conquered admitted singly: Velleius 2.17.1)."""
    # --- colonies
    latin_settlers: Annotated[int, Field(ge=1)] = 2500
    """Default men for a Latin colony (Cales: Livy 8.16.14; Luceria: Livy 9.26.5)."""
    citizen_settlers: Annotated[int, Field(ge=1)] = 300
    """Default men for a citizen colony (Puteoli, Volturnum, Liternum: Livy 34.45.1)."""
    settler_families_bp: Annotated[int, Field(ge=10_000)] = 35_000
    """People moved per colonist named (a man with his household)."""
    latin_until_year: int = -180
    """Last year the Senate's own colonies are Latin (Luca, 180: Velleius 1.15.2); after it
    they are citizen colonies."""
    colony_loyalty_bp: Rate = 8000
    colony_garrison_bp: Rate = 4000
    """Share of the settlers who stand as the colony's garrison."""
    colony_growth_bp: Rate = 50
    """Yearly growth of the settlers."""
    colony_refusal_bp: Rate = 4000
    """Below this loyalty a colony refuses its levy (Livy 27.9.7)."""
    # --- provinces
    provinces_from_year: int = -227
    """Two praetors added for Sicily and Sardinia (Livy, Periochae 20.7; Pomponius, Digest
    1.2.2.32): the age of provinces."""
    tribute_per_1000: Annotated[int, Field(ge=0)] = 2
    """Wealth a province pays Rome per year for each thousand people (Sicily's tithe: Cicero,
    Verrines 2.3.12-15, unverified)."""
    tribute_loyalty_bp: Annotated[int, Field(ge=0)] = 50
    """Yearly loyalty cost of being taxed."""
    province_baseline_loyalty_bp: Rate = 5000
    province_drift_bp: Rate = 300
    extortion_chance_bp: Rate = 1500
    """Yearly chance a governor enriches himself from his province."""
    extortion_share_bp: Rate = 5000
    """Share of the tribute he takes."""
    extortion_loyalty_bp: Annotated[int, Field(ge=0)] = 800
    wealth_per_talent: Annotated[int, Field(ge=1)] = 500
    """Wealth units in one talent of a family's ``wealth``."""
    lex_calpurnia_year: int = -149
    """The first standing court for extortion, L. Piso's law under Censorinus and Manilius
    (Cicero, Brutus 106)."""
    prosecution_chance_bp: Rate = 4000
    """Chance an extorting governor is prosecuted when he lays down his province."""
    conviction_bp: Rate = 5000
    prosecution_glory: Annotated[int, Field(ge=0)] = 300
    """Glory a convicted governor loses."""
    revolt_loyalty_bp: Rate = 2000
    revolt_chance_bp: Rate = 800
    """Yearly chance a province below the revolt loyalty throws off Rome's rule."""
    triumph_hunger_bp: Rate = 1500
    """Yearly chance a governor provokes a neighbour of his province for the sake of a
    triumph (the grievance is the hook for the rivals)."""
    triumph_hunger_grievance_bp: Rate = 1000
    sources: tuple[str, ...] = ()
