"""Simple automated players, used to run rival civilisations and to test balance (D-023).

Bots only choose actions; they never touch the state directly and use no randomness, so a
game played by bots replays exactly from its action log.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from typing import Protocol

from anachronism.content.schema import Category
from anachronism.engine.actions import Action, Build, RaiseArmy, StartProject
from anachronism.engine.armies import under_arms
from anachronism.engine.buildings import best_choice
from anachronism.engine.economy import project_costs
from anachronism.engine.fixed import apply_bp
from anachronism.engine.game import apply_action, end_turn
from anachronism.engine.reports import capacity
from anachronism.engine.rivals import at_war
from anachronism.engine.state import Event, GameState
from anachronism.engine.tech import feasibility


class Bot(Protocol):
    """Anything that can choose a civilisation's actions for a turn."""

    name: str

    def decide(self, state: GameState, civ_id: str) -> list[Action]:
        """Return the actions to take this turn."""
        ...


def candidate_ideas(state: GameState, civ_id: str) -> list[str]:
    """Ideas the civilisation could start right now, in id order."""
    civ = state.civs[civ_id]
    return [
        node_id
        for node_id in sorted(state.tech_nodes)
        if node_id not in civ.projects
        and not (node_id in civ.tech and civ.tech[node_id].stage.is_adopted)
        and not feasibility(state, civ_id, node_id).blocked
    ]


@dataclass
class IdleBot:
    """Never starts anything: the baseline."""

    name: str = "idle"

    def decide(self, state: GameState, civ_id: str) -> list[Action]:
        """Do nothing."""
        return []


@dataclass
class GreedyBot:
    """Starts every feasible idea at once: the overextension test case."""

    name: str = "greedy"

    def decide(self, state: GameState, civ_id: str) -> list[Action]:
        """Start everything possible."""
        return [StartProject(civ=civ_id, node_id=n) for n in candidate_ideas(state, civ_id)]


@dataclass
class PlannerBot:
    """Starts preferred ideas one at a time, only when there is spare capacity."""

    name: str
    preferred: Sequence[Category]
    max_projects: int = 2
    knowledge_turns: int = 3
    """Keep enough knowledge to fund a new project for this many turns."""
    calm_first_bp: int = 5_000
    """Start nothing new while unrest is this high."""
    rank: dict[Category, int] = field(init=False)

    def __post_init__(self) -> None:
        self.rank = {category: index for index, category in enumerate(self.preferred)}

    def decide(self, state: GameState, civ_id: str) -> list[Action]:
        """Raise troops in wartime; start the best affordable idea if there is room."""
        civ = state.civs[civ_id]
        levy = call_up(state, civ_id) if civ_id == state.player_civ else []
        levy += self._build(state, civ_id)
        # a realm in turmoil consolidates before it reaches for anything new
        if len(civ.projects) >= self.max_projects or civ.stats.unrest_bp >= self.calm_first_bp:
            return levy
        return levy + self._idea(state, civ_id)

    def _build(self, state: GameState, civ_id: str) -> list[Action]:
        """Raise the most worthwhile building the stores can comfortably pay for (D-111)."""
        choice = best_choice(state, civ_id, state.world.rules.buildings.rival_reserve)
        if choice is None:
            return []
        return [Build(civ=civ_id, province=choice[0], building=choice[1])]

    def _idea(self, state: GameState, civ_id: str) -> list[Action]:
        room = capacity(state, civ_id)
        spare_knowledge = room.knowledge - room.committed.knowledge * self.knowledge_turns

        def order(node_id: str) -> tuple[int, int, int, str]:
            node = state.tech_nodes[node_id]
            early = max(0, node.year - state.year)
            return (self.rank.get(node.category, len(self.rank)), node.complexity, early, node_id)

        for node_id in sorted(candidate_ideas(state, civ_id), key=order):
            cost = project_costs(state, node_id)
            if (
                cost.labour <= room.free_labour
                and cost.knowledge * self.knowledge_turns <= spare_knowledge
            ):
                return [StartProject(civ=civ_id, node_id=node_id)]
        return []


def call_up(state: GameState, civ_id: str) -> list[Action]:
    """A sensible ruler at war raises a levy at the capital until the army is large enough.

    (Rival courts do this in ``armies.command``; this is for bots playing the player.)
    """
    if not at_war(state, civ_id):
        return []
    civ = state.civs[civ_id]
    rules = state.world.rules.armies
    want = apply_bp(apply_bp(state.population(civ_id), rules.war_army_bp), civ.martial_bp)
    if under_arms(state, civ_id) >= want or civ.capital not in state.provinces:
        return []
    return [RaiseArmy(civ=civ_id, province=civ.capital, size="medium")]


def growth_bot() -> PlannerBot:
    """Compounding growth: food, health, knowledge and trade first."""
    return PlannerBot(
        name="growth",
        preferred=(
            Category.AGRICULTURE,
            Category.HEALTH,
            Category.KNOWLEDGE,
            Category.TRADE,
            Category.GOVERNANCE,
            Category.CRAFT,
            Category.CONSTRUCTION,
        ),
    )


def military_bot() -> PlannerBot:
    """Quick military strength: weapons and metal first."""
    return PlannerBot(
        name="military",
        preferred=(Category.MILITARY, Category.METALLURGY, Category.CONSTRUCTION, Category.CRAFT),
    )


BOTS: dict[str, Callable[[], Bot]] = {
    "idle": IdleBot,
    "greedy": GreedyBot,
    "growth": growth_bot,
    "military": military_bot,
}
"""Bot factories by name."""


def make_bot(name: str) -> Bot:
    """Create a bot by name (idle, greedy, growth, military)."""
    try:
        return BOTS[name]()
    except KeyError:
        raise ValueError(f"unknown bot {name!r}; choose from {', '.join(BOTS)}") from None


def play_turn(state: GameState, bots: Mapping[str, Bot]) -> tuple[GameState, list[Event]]:
    """Let each bot act for its civilisation (in id order), then resolve the turn."""
    for civ_id in sorted(bots):
        if civ_id not in state.civs or not state.owned_provinces(civ_id):
            continue
        for action in bots[civ_id].decide(state, civ_id):
            state, _ = apply_action(state, action)
    return end_turn(state)
