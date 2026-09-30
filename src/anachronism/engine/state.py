"""Game state: everything that changes during a game, plus the fixed world it is played in.

``GameState`` is fully serialisable (see ``engine/save.py``). Content models inside it are
frozen and shared between copies; everything else is copied when the engine advances.
"""

from __future__ import annotations

from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field

from anachronism.content.schema import (
    Access,
    EffectType,
    Era,
    Frozen,
    MapResource,
    ProvinceGeography,
    Rules,
    SocialGroup,
    Stage,
    TechNode,
    Terrain,
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
    eras: tuple[Era, ...]
    effect_caps: dict[EffectType, dict[str, int]]
    terrain: dict[str, Terrain]
    resources: dict[str, MapResource]
    geography: dict[str, ProvinceGeography]
    """Provinces in play; neighbours outside the scenario are removed."""


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


class Event(Mutable):
    """Something that happened, shown in reports and chronicles."""

    turn: int
    year: int
    civ: str | None
    kind: str
    message: str


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

    def owned_provinces(self, civ_id: str) -> list[str]:
        """Ids of the provinces a civilisation owns, sorted."""
        return sorted(pid for pid, p in self.provinces.items() if p.owner == civ_id)

    def population(self, civ_id: str) -> int:
        """Total population of a civilisation."""
        return sum(p.population for p in self.provinces.values() if p.owner == civ_id)
