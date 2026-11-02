"""Religion, land, grain, coin and the legion's eras (R4, F1): the content of Roman society.

Eight kinds, each its own file in the rome pack: ``priesthoods``, ``prodigies`` and ``cults``
are lists; ``rites``, ``land``, ``grain``, ``coinage`` and ``recruitment`` are single rule
objects with a default for every number, so a pack without them still loads. Every historical
entry carries ``sources``; numbers that are game balance say so in the YAML. The engine reads
them through ``World.rome_society`` (a :class:`RomeSociety` bundle built from the registry).
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Annotated, Literal, Protocol

from pydantic import Field

from anachronism.content.schema.base import Confidence, Frozen, Identifier, NonNegative, Rate
from anachronism.content.schema.republic import Sources

# ---------------------------------------------------------------- religion


class PriesthoodEra(Frozen):
    """How many seats a college had from a year, and who could fill them."""

    from_year: int
    seats: Annotated[int, Field(ge=1, le=60)]
    patricians_only: bool = False
    plebeian_min: Annotated[int, Field(ge=0)] = 0
    """Seats that must go to plebeians (the Lex Ogulnia's added places)."""
    sources: tuple[str, ...] = ()


class Priesthood(Frozen):
    """A college of priests, held for life by the Republic's men (or its daughters)."""

    id: Identifier
    name: str
    eras: tuple[PriesthoodEra, ...] = Field(min_length=1)
    for_life: bool = True
    women: bool = False
    """The Vestals: a daughter of a gens, not one of the Republic's men."""
    term_years: int | None = None
    """Years of service when not for life (the Vestals' thirty)."""
    augural: bool = False
    """Its members take the auspices (the augurs shape the odds before a battle)."""
    sibylline: bool = False
    """Its members keep and consult the Sibylline Books."""
    chief: bool = False
    """The college has a chief (the pontifex maximus)."""
    blocks_command: bool = False
    """Its holder may not look on an army under arms (the flamen Dialis)."""
    glory: Annotated[int, Field(ge=0)] = 100
    """Standing (glory) the priesthood brings its holder."""
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW

    def era_at(self, year: int) -> PriesthoodEra | None:
        """The latest era beginning at or before ``year``, if the college exists then."""
        best: PriesthoodEra | None = None
        for era in sorted(self.eras, key=lambda e: e.from_year):
            if era.from_year <= year:
                best = era
        return best


class Prodigy(Frozen):
    """A portent reported to the Senate and the expiation it ordered.

    A dated prodigy fires in its year; an undated one (``year`` ``None``) is a recurring kind
    the engine may draw in a year the list does not cover.
    """

    id: Identifier
    year: int | None = None
    place: str = ""
    sign: str = Field(min_length=1)
    expiation: str = Field(min_length=1)
    cost: NonNegative = 0
    """Wealth the expiation costs (0: the rules' default). Game balance."""
    monument: Identifier | None = None
    """Where the sacrifice is played in the city (``None``: the rules' default temple)."""
    sibylline: bool = False
    """The decemviri consulted the Books over it."""
    cult: Identifier | None = None
    """A cult this prodigy brought to Rome (introduced when the prodigy fires)."""
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW


CultKind = Literal["introduced", "suppressed"]
CultTrigger = Literal["sibylline", "vow", "senate"]


class Cult(Frozen):
    """A new god received at Rome (or a rite put down), and the temple it got."""

    id: Identifier
    name: str
    year: int
    """When history brought it (or put it down)."""
    kind: CultKind = "introduced"
    trigger: CultTrigger = "senate"
    """``sibylline``: the Books ordered it (a consultation within ``window_years`` before its
    year brings it early); ``vow``: a general's vow; ``senate``: a decree."""
    window_years: NonNegative = 0
    monument: Identifier | None = None
    """The temple in the city dataset (its own dates decide when it stands)."""
    unrest_bp: int = 0
    """Change to unrest when it comes (negative calms). Game balance."""
    legitimacy_bp: int = 0
    notes: str = ""
    sources: Sources
    confidence: Confidence = Confidence.LOW


class AuspiceRules(Frozen):
    """The odds of favourable auspices before a battle and what they do to morale."""

    base_bp: Rate = 6500
    pious_bp: int = 1500
    """Added for a commander with the pious trait."""
    impious_bp: int = -2500
    """Added for a commander with the impious trait (Flaminius, Pulcher)."""
    augur_bp: int = 500
    """Added when the commander is himself an augur."""
    college_bp: int = 1000
    """Added in proportion to the augurs' seats that are filled."""
    favourable_morale_bp: int = 400
    unfavourable_morale_bp: int = -700
    pious_trait: Identifier = "pious"
    impious_trait: Identifier = "impious"
    sources: tuple[str, ...] = ()


class ProdigyRules(Frozen):
    """How prodigies are drawn, paid for, and what neglect costs."""

    yearly_chance_bp: Rate = 3000
    """Chance of an undated prodigy in a year the list does not date."""
    default_cost: NonNegative = 15
    default_monument: Identifier | None = None
    unexpiated_unrest_bp: NonNegative = 250
    """Unrest a year for each prodigy the treasury could not expiate."""
    expiation_unrest_relief_bp: NonNegative = 100
    kept: Annotated[int, Field(ge=1)] = 30
    """Prodigy records kept in the state for the view."""
    sources: tuple[str, ...] = ()


class SibyllineRules(Frozen):
    """When the decemviri open the Books and what the consultation does."""

    consult_on: tuple[str, ...] = ("famine", "disaster", "battle_lost")
    """Event kinds (for the player's civ) that send the Senate to the Books; a ``battle_lost``
    counts only when decisive."""
    cost: NonNegative = 40
    unrest_relief_bp: NonNegative = 600
    legitimacy_bp: NonNegative = 200
    lost_from_year: int | None = None
    """The Books burned with the Capitol (83 BC) and could not be opened..."""
    restored_year: int | None = None
    """...until a new collection was gathered (76 BC)."""
    monument: Identifier | None = None
    """Where the lectisternium is played in the city."""
    sources: tuple[str, ...] = ()


class Rites(Frozen):
    """Religion's tunable numbers (one optional file)."""

    auspices: AuspiceRules = AuspiceRules()
    prodigies: ProdigyRules = ProdigyRules()
    sibylline: SibyllineRules = SibyllineRules()
    kept_auspices: Annotated[int, Field(ge=1)] = 20
    sources: tuple[str, ...] = ()


# ---------------------------------------------------------------- land, slaves, debt


class LandReform(Frozen):
    """An agrarian law of history: when it came and what it did to the land."""

    id: Identifier
    name: str
    year: int
    limit_iugera: NonNegative = 500
    law: Identifier = "land_reform"
    """The Senate law (``republic_rules.senate.laws``) whose passing applies it."""
    latifundia_cut_bp: Rate = 3000
    """Share of the great estates' land given back to small farmers."""
    assidui_gain_bp: Rate = 1500
    """Share of the citizens restored to the classes that can be levied."""
    sources: Sources
    notes: str = ""
    confidence: Confidence = Confidence.LOW


class SlaveRevolt(Frozen):
    """A slave war of history."""

    id: Identifier
    name: str
    year: int
    province: Identifier | None = None
    """Where it rose (ravaged if the player holds it)."""
    sources: Sources
    notes: str = ""
    confidence: Confidence = Confidence.LOW


class SlaveRules(Frozen):
    """How slaves come, what they work, and when they rise."""

    per_1000_conquered: NonNegative = 25
    """Slaves per 1,000 people of a province taken (Livy's captive counts)."""
    sacked_enslaved_bp: Rate = 10_000
    """Share of a sacked city's lost people carried off as slaves."""
    estate_wealth_per_1000: NonNegative = 2
    """Wealth a year the estates' slaves earn, per 1,000 slaves."""
    revolt_threshold_bp: Rate = 1500
    """Slaves as a share of the free people above which a revolt can start."""
    revolt_chance_bp: Rate = 400
    """Yearly chance above the threshold (dated revolts fire on their year regardless)."""
    revolt_unrest_bp: NonNegative = 1200
    revolt_wealth_loss_bp: Rate = 1000
    revolt_slaves_lost_bp: Rate = 2500
    revolts: tuple[SlaveRevolt, ...] = ()
    sources: tuple[str, ...] = ()


class Secession(Frozen):
    """A secession of the plebs in history."""

    id: Identifier
    name: str
    year: int
    sources: Sources
    notes: str = ""
    confidence: Confidence = Confidence.LOW


class DebtRules(Frozen):
    """How debt grows and what happens when it is ignored."""

    war_bp_per_year: NonNegative = 300
    famine_bp: NonNegative = 600
    shortage_bp: NonNegative = 300
    """Added in a year the grain supply fell short."""
    peace_relief_bp: Rate = 500
    """Share of the debt paid off in a year of peace."""
    law: Identifier = "debt_relief"
    relief_cut_bp: Rate = 6000
    """Share of the debt the law wipes out."""
    unrest_per_debt_bp: Rate = 800
    """Unrest a year at full debt (scaled by the debt level)."""
    secession_threshold_bp: Rate = 6000
    secession_chance_bp: Rate = 1500
    secession_unrest_bp: NonNegative = 1500
    secession_legitimacy_bp: NonNegative = 800
    secession_relief_bp: Rate = 5000
    """The debt eased by the settlement that ends a secession."""
    secessions: tuple[Secession, ...] = ()
    sources: tuple[str, ...] = ()


class Land(Frozen):
    """Ager publicus, latifundia, slaves and debt (one optional file)."""

    start_ager_per_1000: NonNegative = 60
    """Public land (iugera, in thousands) per 1,000 people the state holds at the start."""
    start_latifundia_bp: Rate = 2500
    """Share of it already in the great estates at the start."""
    ager_per_1000_conquered: NonNegative = 120
    """Public land added per 1,000 people of a province taken."""
    occupation_bp: Rate = 400
    """Share of the unoccupied public land the rich take into their estates each year."""
    assidui_start_bp: Rate = 7000
    """Share of adult male citizens who meet the property threshold at the start."""
    assidui_floor_bp: Rate = 2500
    assidui_decline_bp: Rate = 120
    """Yearly fall of the assidui share at full latifundia (scaled by the estates' share)."""
    reforms: tuple[LandReform, ...] = ()
    slaves: SlaveRules = SlaveRules()
    debt: DebtRules = DebtRules()
    sources: tuple[str, ...] = ()


# ---------------------------------------------------------------- grain


class GrainSupply(Frozen):
    """A region that fed Rome once the Republic held it."""

    id: Identifier
    name: str
    provinces: tuple[Identifier, ...] = Field(min_length=1)
    share_bp: Rate
    """How much of the city's need it covers when every listed province is held."""
    from_year: int | None = None
    """The first year the supply counts (``None``: whenever held)."""
    sources: Sources
    notes: str = ""
    confidence: Confidence = Confidence.LOW


class CityPopulation(Frozen):
    """An estimate of the city's people in a year (the demand for grain)."""

    year: int
    people: NonNegative
    sources: Sources


class DoleRules(Frozen):
    """The grain dole: what the law costs and what it steadies."""

    law: Identifier = "grain_dole"
    cost_per_1000: NonNegative = 1
    """Wealth a year per 1,000 people of the city while the law stands."""
    unrest_relief_bp: NonNegative = 300
    shortage_relief_bp: Rate = 5000
    """Share of a shortage's unrest the dole absorbs."""
    free_from_year: int | None = None
    """From here the grain is free (Clodius), and the cost rises by ``free_cost_bp``."""
    free_cost_bp: Rate = 10_000
    sources: tuple[str, ...] = ()


class Grain(Frozen):
    """Rome's food (one optional file)."""

    home_share_bp: Rate = 6000
    """What Latium and Italy supply of the city's need without any province."""
    home_fade_per_100k_bp: NonNegative = 400
    """The home share falls by this for every 100,000 people the city grows past its first
    estimate: the city outgrows its fields."""
    supplies: tuple[GrainSupply, ...] = ()
    city: tuple[CityPopulation, ...] = ()
    shortage_unrest_bp: NonNegative = 1500
    """Unrest at a total shortfall (scaled by the shortfall)."""
    surplus_calm_bp: NonNegative = 100
    dole: DoleRules = DoleRules()
    sources: tuple[str, ...] = ()


# ---------------------------------------------------------------- coinage and tribute


class CoinReform(Frozen):
    """A change in Rome's money."""

    id: Identifier
    name: str
    year: int
    trade_bonus_bp: NonNegative = 0
    """Added to the trade income (bp) once in force."""
    sources: Sources
    notes: str = ""
    confidence: Confidence = Confidence.LOW


class TributeRules(Frozen):
    """What conquered provinces pay."""

    per_1000: NonNegative = 3
    """Wealth a year per 1,000 people of a province whose people are not Rome's own."""
    exempt: tuple[Identifier, ...] = ()
    """Provinces that pay no tribute (allies who send men instead)."""
    sources: tuple[str, ...] = ()


class Coinage(Frozen):
    """Coinage and tribute (one optional file)."""

    reforms: tuple[CoinReform, ...] = ()
    tribute: TributeRules = TributeRules()
    sources: tuple[str, ...] = ()


# ---------------------------------------------------------------- recruitment


class ArmyEra(Frozen):
    """One of the army's systems: the phalanx, the manipular legion, the cohort legion."""

    id: Identifier
    name: str
    tech: Identifier
    """The advancement that marks it (adopting it early switches the era early)."""
    from_year: int
    """When history switched (the era comes then even if the idea was not pursued)."""
    composition: dict[Identifier, Annotated[int, Field(ge=0)]] = Field(default_factory=dict)
    """Unit id -> weight in a levy (only units the state can raise are used)."""
    allies: dict[Identifier, Annotated[int, Field(ge=0)]] = Field(default_factory=dict)
    """Units and weights added when the Italian alliance is in force."""
    allies_tech: Identifier = "italian_alliance"
    proletarii: bool = False
    """The era levies the capite censi: no property threshold."""
    sources: Sources
    notes: str = ""
    confidence: Confidence = Confidence.LOW


class Threshold(Frozen):
    """The property qualification for the legions in a span of years."""

    from_year: int
    asses: NonNegative
    qualify_bp: Rate
    """Share of adult male citizens above it with the land as it stood at the start."""
    sources: Sources
    notes: str = ""


class LoyaltyRules(Frozen):
    """How a soldier's loyalty shifts from the state to his general."""

    from_era: Identifier = "cohort"
    per_victory_bp: NonNegative = 600
    per_year_bp: NonNegative = 150
    proletarii_bp: NonNegative = 1000
    """Added once to a general's men when they are capite censi."""
    land_law_bp: NonNegative = 800
    """Added while a land law stands (land for veterans is the general's gift)."""
    fade_bp: Rate = 1000
    """Share of loyalty lost each year an army has no named general."""
    march_threshold_bp: Rate = 7000
    """Loyalty at which an army would follow its general against the city."""
    sources: tuple[str, ...] = ()


class Recruitment(Frozen):
    """The army's eras and the census-class levy (one optional file)."""

    eras: tuple[ArmyEra, ...] = ()
    thresholds: tuple[Threshold, ...] = ()
    service_years: Annotated[int, Field(ge=1)] = 16
    max_age: Annotated[int, Field(ge=17)] = 46
    levy_share_bp: Rate = 2500
    """Share of the assidui that may be under arms at once."""
    citizen_share_bp: Rate = 1800
    """Adult male citizens as a share of the people (as the census counts them)."""
    loyalty: LoyaltyRules = LoyaltyRules()
    sources: tuple[str, ...] = ()


# ---------------------------------------------------------------- the bundle


class RomeSociety(Frozen):
    """Everything the society modules read, copied into ``World`` for Republic scenarios."""

    priesthoods: dict[str, Priesthood] = Field(default_factory=dict)
    prodigies: dict[str, Prodigy] = Field(default_factory=dict)
    cults: dict[str, Cult] = Field(default_factory=dict)
    rites: Rites = Rites()
    land: Land = Land()
    grain: Grain = Grain()
    coinage: Coinage = Coinage()
    recruitment: Recruitment = Recruitment()

    @property
    def present(self) -> bool:
        """True when a pack gave the society any content at all."""
        return bool(self.priesthoods or self.prodigies or self.cults or self.recruitment.eras)


class _Registry(Protocol):
    """What the checks need of the content registry (kept here to avoid an import cycle)."""

    @property
    def priesthoods(self) -> Mapping[str, Priesthood]: ...
    @property
    def prodigies(self) -> Mapping[str, Prodigy]: ...
    @property
    def cults(self) -> Mapping[str, Cult]: ...
    @property
    def rites(self) -> Rites | None: ...
    @property
    def land(self) -> Land | None: ...
    @property
    def grain(self) -> Grain | None: ...
    @property
    def coinage(self) -> Coinage | None: ...
    @property
    def recruitment(self) -> Recruitment | None: ...
    def is_unknown(self, kind: str, item_id: str | None) -> bool: ...
    def origin(self, kind: str, item_id: str) -> str: ...


def bundle(registry: _Registry) -> RomeSociety:
    """Gather the society's kinds from a loaded registry (defaults where a kind is absent)."""
    return RomeSociety(
        priesthoods=dict(sorted(registry.priesthoods.items())),
        prodigies=dict(sorted(registry.prodigies.items())),
        cults=dict(sorted(registry.cults.items())),
        rites=registry.rites or Rites(),
        land=registry.land or Land(),
        grain=registry.grain or Grain(),
        coinage=registry.coinage or Coinage(),
        recruitment=registry.recruitment or Recruitment(),
    )


def issues(registry: _Registry) -> list[tuple[str, str, str]]:
    """Broken references across the society's kinds: (file, label, message) triples.

    Monuments named by prodigies, cults and rites must exist; provinces named by the grain
    supplies and tribute exemptions must exist; units and techs named by the army's eras must
    exist; the laws named by the land and grain rules are checked by the caller against the
    Republic's laws if it has them.
    """
    found: list[tuple[str, str, str]] = []

    def monument(where: str, label: str, mid: str | None) -> None:
        if mid is not None and registry.is_unknown("monuments", mid):
            found.append((where, label, f"unknown monument {mid!r}"))

    for prodigy in registry.prodigies.values():
        where = registry.origin("prodigies", prodigy.id)
        monument(where, f"prodigies ({prodigy.id})", prodigy.monument)
        if prodigy.cult is not None and registry.is_unknown("cults", prodigy.cult):
            found.append((where, f"prodigies ({prodigy.id})", f"unknown cult {prodigy.cult!r}"))
    for cult in registry.cults.values():
        monument(registry.origin("cults", cult.id), f"cults ({cult.id})", cult.monument)
    rites = registry.rites
    if rites is not None:
        where = registry.origin("rites", "rites")
        monument(where, "rites.prodigies.default_monument", rites.prodigies.default_monument)
        monument(where, "rites.sibylline.monument", rites.sibylline.monument)
    grain = registry.grain
    if grain is not None:
        where = registry.origin("grain", "grain")
        for supply in grain.supplies:
            for pid in supply.provinces:
                if registry.is_unknown("provinces", pid):
                    found.append(
                        (where, f"grain.supplies ({supply.id})", f"unknown province {pid!r}")
                    )
    coinage = registry.coinage
    if coinage is not None:
        where = registry.origin("coinage", "coinage")
        for pid in coinage.tribute.exempt:
            if registry.is_unknown("provinces", pid):
                found.append((where, "coinage.tribute.exempt", f"unknown province {pid!r}"))
    land = registry.land
    if land is not None:
        where = registry.origin("land", "land")
        for revolt in land.slaves.revolts:
            if revolt.province is not None and registry.is_unknown("provinces", revolt.province):
                found.append(
                    (
                        where,
                        f"land.slaves.revolts ({revolt.id})",
                        f"unknown province {revolt.province!r}",
                    )
                )
    recruitment = registry.recruitment
    if recruitment is not None:
        where = registry.origin("recruitment", "recruitment")
        for era in recruitment.eras:
            label = f"recruitment.eras ({era.id})"
            for tech in (era.tech, era.allies_tech):
                if registry.is_unknown("techs", tech):
                    found.append((where, label, f"unknown tech {tech!r}"))
            for unit in (*era.composition, *era.allies):
                if registry.is_unknown("units", unit):
                    found.append((where, label, f"unknown unit {unit!r}"))
        if recruitment.eras and recruitment.loyalty.from_era not in {
            e.id for e in recruitment.eras
        }:
            found.append((where, "recruitment.loyalty.from_era", "names no era"))
    return found
