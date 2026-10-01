"""Game state: everything that changes during a game, plus the fixed world it is played in.

``GameState`` is fully serialisable (see ``engine/save.py``). Content models inside it are
frozen and shared between copies; everything else is copied when the engine advances.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from anachronism.content.schema import (
    Access,
    Disposition,
    EffectType,
    Era,
    Faith,
    Frozen,
    General,
    Happening,
    MapResource,
    ProvinceGeography,
    RelationStatus,
    Rules,
    Script,
    SeaZone,
    SocialGroup,
    Stage,
    Successor,
    TechNode,
    Terrain,
    Unit,
)
from anachronism.engine.actions import LoggedAction, Priority
from anachronism.engine.rng import RngState

SAVE_SCHEMA_VERSION = 1


class Mutable(BaseModel):
    """Base for state that changes during play. Unknown fields are errors."""

    model_config = ConfigDict(extra="forbid")


class Framing(StrEnum):
    """How the people explain their rulers' uncanny progress (DESIGN §7)."""

    NONE = "none"
    INSPIRED = "inspired"
    WITCHCRAFT = "witchcraft"
    FRAUD = "fraud"


class World(Frozen):
    """Everything fixed for the whole game, copied from content when it starts."""

    scenario_id: str
    scenario_name: str
    content_digest: str
    years_per_turn: int
    rules: Rules
    difficulty: str = "normal"
    """The difficulty level whose overrides are already in ``rules``."""
    eras: tuple[Era, ...]
    effect_caps: dict[EffectType, dict[str, int]]
    terrain: dict[str, Terrain]
    resources: dict[str, MapResource]
    geography: dict[str, ProvinceGeography]
    """Provinces in play; neighbours outside the scenario are removed."""
    seas: dict[str, SeaZone] = Field(default_factory=dict)
    """Sea zones touching provinces in play."""
    map: str | None = None
    """Real-Earth map region, or ``None`` for a generated map."""
    cost_scale: int = 1
    """Multiplier on every project cost (see ``Scenario.cost_scale``)."""
    happenings: dict[str, Happening] = Field(default_factory=dict)
    units: dict[str, Unit] = Field(default_factory=dict)
    """The kinds of soldier that exist (raising them needs their advancements)."""
    """Chance events that can strike (plague, flood, bumper harvests...)."""
    scripts: dict[str, tuple[Script, ...]] = Field(default_factory=dict)
    successors: dict[str, tuple[Successor, ...]] = Field(default_factory=dict)
    faiths: dict[str, Faith] = Field(default_factory=dict)
    """Each civilisation's historical successors, in order."""
    """Each civilisation's intentions (brief §7.1), from the scenario."""


class ProvinceState(Mutable):
    """A province's changing situation."""

    owner: str | None
    population: int
    resources: dict[str, Access]
    """Current access to each map resource (discoveries change it)."""


class Stockpiles(Mutable):
    """Stored resources."""

    food: int
    materials: int
    wealth: int
    knowledge: int


class Stats(Mutable):
    """Civilisation-wide stats in basis points of 0-100."""

    literacy_bp: int
    unrest_bp: int
    legitimacy_bp: int
    suspicion_bp: int
    strain_bp: int = 0


class TechState(Mutable):
    """How far a civilisation has taken one advancement."""

    stage: Stage
    spread_bp: int = 0
    """How widely an adopted advancement is used, 0-100%."""
    goal: bool = False
    """Marked because an idea the civilisation wanted needs it."""


class Project(Mutable):
    """An experimentation project turning a concept into an adopted advancement."""

    node_id: str
    started_turn: int
    priority: Priority = Priority.NORMAL
    progress_bp: int = 0
    paused: bool = False
    stalled_turns: int = 0
    last_funding_bp: int = 0


class Snapshot(Mutable):
    """A civilisation's key numbers at the end of a turn, for trends and charts."""

    turn: int
    year: int
    population: int
    food: int
    materials: int
    wealth: int
    knowledge: int
    workforce: int
    free_labour: int
    literacy_bp: int
    unrest_bp: int
    legitimacy_bp: int
    suspicion_bp: int
    strain_bp: int


class Awareness(StrEnum):
    """How far a rival has noticed the player's meddling (brief §7.2)."""

    ON_SCRIPT = "on_script"
    """Untouched: plays out its own history."""
    AWARE = "aware"
    """Has heard something; still follows its plans, but reacts (copies, grows wary)."""
    FREE_AGENT = "free_agent"
    """Knocked off its script: acts on its ruler's temperament and its situation."""


class Heard(Mutable):
    """News a civilisation has received about another's advancement (brief §7.3)."""

    about: str
    node_id: str
    turn: int
    garbled: bool
    """Garbled news ("strange fire weapons") makes a rival wary but gives nothing to copy."""


class NewsInTransit(Mutable):
    """News on its way along trade routes, envoys, refugees and soldiers."""

    to_civ: str
    about: str
    node_id: str
    arrives_turn: int
    garbled: bool


class Relation(Mutable):
    """How two civilisations stand, with the memory of what passed between them (§7.5)."""

    status: RelationStatus
    since_turn: int = 0
    grievance: dict[str, int] = Field(default_factory=dict)
    """Each side's grudge against the other, in basis points."""
    weariness: dict[str, int] = Field(default_factory=dict)
    """During a war: how tired of it each side is."""
    losses: dict[str, int] = Field(default_factory=dict)
    """During a war: provinces each side has lost."""


class Outcome(Mutable):
    """How the game ended for the player (DESIGN §11)."""

    result: str
    """``victory`` or ``defeat``."""
    path: str
    """``military``, ``economic``, ``cultural`` or ``collapse``."""
    tier: str
    """``regional`` for now; hemispheric and world need several regions (Phase 8)."""
    turn: int
    year: int


class Army(Mutable):
    """A force in the field (D-099): where it stands, who is in it, and its orders."""

    id: str
    owner: str
    name: str
    province: str
    troops: dict[str, int]
    """Unit id -> men."""
    morale_bp: int = 8000
    general: str = ""
    """Who commands it (empty: no named general)."""
    skill: int = 1
    """The general's skill, 1-5."""
    trait: str = ""
    """The general's gift (see ``content.schema.General``), if any."""
    target: str | None = None
    """The province it is marching to, if any."""
    stance: Literal["defend", "hold"] = "defend"
    """Without a march order: ``defend`` meets invaders of its own land, ``hold`` stays put."""
    came_from: str = ""
    """Where it marched from last (a beaten army falls back that way)."""
    siege_bp: int = 0
    """Progress of its siege of the province it stands in (10_000 = a normal province)."""
    raised_turn: int = 0
    contract: int = 0
    """Turns a mercenary company still serves (0: the state's own men)."""

    @property
    def men(self) -> int:
        """Everyone in the army."""
        return sum(self.troops.values())


class CivState(Mutable):
    """A civilisation in play."""

    id: str
    name: str
    adjective: str
    lineage: str
    colour: str
    capital: str
    starting_provinces: int
    influence: dict[SocialGroup, int]
    stockpiles: Stockpiles
    stats: Stats
    framing: Framing = Framing.NONE
    tech: dict[str, TechState] = Field(default_factory=dict)
    projects: dict[str, Project] = Field(default_factory=dict)
    """Active projects, keyed by the advancement they work on."""
    unlocked: list[str] = Field(default_factory=list)
    """Buildings and units unlocked by advancements (used from later phases)."""
    history: list[Snapshot] = Field(default_factory=list)
    collapsed: bool = False
    disposition: Disposition = Disposition.CAUTIOUS
    awareness: Awareness = Awareness.ON_SCRIPT
    ruler: str = ""
    """Who rules now (empty: unnamed)."""
    faith: str = ""
    """The court's religion or school of belief (a faith id, or empty)."""
    martial_bp: int = 10_000  # share of the people under arms, against the usual (steppe: more)
    revolts: int = 0  # provinces lost to revolt: half the starting ones is collapse
    envoy_turn: int = -1  # the turn the last embassy left: one a turn
    mercenaries: int = 0
    """Turns of hired soldiers left."""
    explained_turn: int = -99
    """The turn the court last explained its new arts (see ``Explain``)."""
    sealed: int = 0
    """Turns the borders stay sealed (no trade; news of the court's arts travels slowly)."""
    generals: list[General] = Field(default_factory=list)
    """Commanders not yet leading an army (best first)."""
    armies_raised: int = 0
    """How many armies the state has raised (numbers new ones)."""
    ruler_age: int = 40
    rulers: int = 1
    """How many rulers the state has had in this game (1 = the one it started with)."""
    heard: list[Heard] = Field(default_factory=list)


class Event(Mutable):
    """Something that happened, shown in reports and chronicles."""

    turn: int
    year: int
    civ: str | None
    kind: str
    message: str
    subject: str = ""
    """What it is about, by name (an idea, a province or a resource); used by dialogue."""


class GameState(Mutable):
    """A complete game at one moment: saving this is saving the game."""

    schema_version: int = SAVE_SCHEMA_VERSION
    engine_version: str
    seed: int
    rng: RngState
    turn: int = 0
    """Number of turns completed."""
    year: int
    player_civ: str
    world: World
    tech_nodes: dict[str, TechNode]
    provinces: dict[str, ProvinceState]
    civs: dict[str, CivState]
    action_log: list[LoggedAction] = Field(default_factory=list)
    events: list[Event] = Field(default_factory=list)
    armies: dict[str, Army] = Field(default_factory=dict)
    """Every army in the field, keyed by id."""
    relations: dict[str, Relation] = Field(default_factory=dict)
    """Keyed ``"a|b"`` with the ids sorted; only pairs that can reach each other."""
    news: list[NewsInTransit] = Field(default_factory=list)
    scripts_fired: dict[str, int] = Field(default_factory=dict)
    """Script id -> turn it fired."""
    scripts_lapsed: dict[str, int] = Field(default_factory=dict)
    """Script id -> turn it lapsed (its moment passed or what it needed failed)."""
    outcome: Outcome | None = None
    victory_start: dict[str, int] = Field(default_factory=dict)
    """The player's share on each victory path at the start: victory means gaining ground."""

    def owned_provinces(self, civ_id: str) -> list[str]:
        """Ids of the provinces a civilisation owns, sorted."""
        return sorted(pid for pid, p in self.provinces.items() if p.owner == civ_id)

    def population(self, civ_id: str) -> int:
        """Total population of a civilisation."""
        return sum(p.population for p in self.provinces.values() if p.owner == civ_id)
