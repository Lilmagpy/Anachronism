"""Simple automated players, used to run rival civilisations and to test balance (D-023).

Bots only choose actions; they never touch the state directly and use no randomness, so a
game played by bots replays exactly from its action log.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from typing import Protocol

from anachronism.content.schema import Category, RelationStatus
from anachronism.engine.actions import (
    Action,
    Build,
    DeclareWar,
    Explain,
    HoldFestival,
    MakePeace,
    MarchArmy,
    RaiseArmy,
    StartProject,
)
from anachronism.engine.armies import under_arms
from anachronism.engine.buildings import best_choice
from anachronism.engine.decrees import cost, explain_costs, explain_ready_in
from anachronism.engine.economy import project_costs
from anachronism.engine.fixed import apply_bp
from anachronism.engine.game import apply_action, end_turn
from anachronism.engine.reports import capacity
from anachronism.engine.rivals import at_war, frontier, relation, strength
from anachronism.engine.state import Event, GameState
from anachronism.engine.tech import feasibility
from anachronism.engine.war import defence_bp


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
    conquer: bool = False
    """Go to war against clearly weaker neighbours and campaign to take their land."""
    rank: dict[Category, int] = field(init=False)

    def __post_init__(self) -> None:
        self.rank = {category: index for index, category in enumerate(self.preferred)}

    def decide(self, state: GameState, civ_id: str) -> list[Action]:
        """Raise troops in wartime; start the best affordable idea if there is room."""
        civ = state.civs[civ_id]
        levy = call_up(state, civ_id) if civ_id == state.player_civ else []
        levy += self._build(state, civ_id) + self._steady(state, civ_id)
        if self.conquer:
            levy += self._campaign(state, civ_id)
        # a realm in turmoil consolidates before it reaches for anything new
        if len(civ.projects) >= self.max_projects or civ.stats.unrest_bp >= self.calm_first_bp:
            return levy
        return levy + self._idea(state, civ_id)

    def _campaign(self, state: GameState, civ_id: str) -> list[Action]:
        """A conqueror's war: march on a much weaker neighbour's weakest border province.

        After a few years of war it sues for peace on the land its armies hold.
        """
        civ = state.civs[civ_id]
        enemies = at_war(state, civ_id)
        if not enemies:
            if civ.stats.unrest_bp >= 3000 or state.turn < 2:
                return []
            mine = strength(state, civ_id)
            options = sorted(
                (strength(state, other), other)
                for pair, rel in sorted(state.relations.items())
                if civ_id in pair.split("|")
                and rel.status not in (RelationStatus.ALLIED, RelationStatus.TRIBUTARY)
                for other in pair.split("|")
                if other != civ_id and frontier(state, civ_id, other)
            )
            for theirs, other in options:
                if mine * 10 >= theirs * 14:
                    return [DeclareWar(civ=civ_id, target=other)]
            return []
        enemy = enemies[0]
        targets = frontier(state, civ_id, enemy)
        orders: list[Action] = []
        if targets:
            goal = min(targets, key=lambda p: (defence_bp(state, enemy, p), p))
            for army in sorted(state.armies.values(), key=lambda a: a.id):
                if army.owner == civ_id and army.target is None and army.province != goal:
                    orders.append(MarchArmy(civ=civ_id, army=army.id, target=goal))
        rel = relation(state, civ_id, enemy)
        besieging = any(
            a.owner == civ_id and a.siege_bp > 0 and state.provinces[a.province].owner == enemy
            for a in state.armies.values()
        )
        # sue for peace once nothing is left under siege and the war has dragged on
        if rel is not None and state.turn - rel.since_turn >= 8 and not besieging:
            orders.append(MakePeace(civ=civ_id, target=enemy, terms="cede"))
        return orders

    def _steady(self, state: GameState, civ_id: str) -> list[Action]:
        """Quiet suspicion with a divine proclamation; win back a doubting people with feasts."""
        civ = state.civs[civ_id]
        rules = state.world.rules.rivals
        wealth = civ.stockpiles.wealth
        if (
            civ.stats.suspicion_bp >= 4000
            and not explain_ready_in(state, civ_id)
            and wealth >= explain_costs(state, civ_id)[0] * 2
        ):
            return [Explain(civ=civ_id, story="divine")]
        doubted = civ.stats.legitimacy_bp < 2000 or civ.stats.unrest_bp >= 3000
        if doubted and wealth >= cost(state, civ_id, rules.festival_wealth_per_1000) * 2:
            return [HoldFestival(civ=civ_id)]
        return []

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
        conquer=True,
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
