"""Read-only summaries of a civilisation for players, bots and history."""

from __future__ import annotations

from dataclasses import dataclass

from anachronism.engine.economy import Costs, active_projects, labour, project_costs
from anachronism.engine.effects import civ_effects
from anachronism.engine.state import GameState, Snapshot


@dataclass(frozen=True)
class Capacity:
    """What a civilisation can still take on (the "free capacity" of the brief, §5.1)."""

    workforce: int
    surplus: int
    committed: Costs
    """Per-turn inputs requested by active projects."""
    food: int
    materials: int
    wealth: int
    knowledge: int

    @property
    def free_labour(self) -> int:
        """Surplus labour left after commitments; negative means production is being cut."""
        return self.surplus - self.committed.labour


def capacity(state: GameState, civ_id: str) -> Capacity:
    """Summarise workforce, commitments and stockpiles for one civilisation."""
    civ = state.civs[civ_id]
    work = labour(state, civ_id, civ_effects(state, civ_id))
    committed = sum(
        (project_costs(state, p.node_id) for p in active_projects(state, civ_id)), Costs()
    )
    stock = civ.stockpiles
    return Capacity(
        workforce=work.workforce,
        surplus=work.surplus,
        committed=committed,
        food=stock.food,
        materials=stock.materials,
        wealth=stock.wealth,
        knowledge=stock.knowledge,
    )


def snapshot(state: GameState, civ_id: str) -> Snapshot:
    """Record a civilisation's key numbers now, for trends and history."""
    civ = state.civs[civ_id]
    summary = capacity(state, civ_id)
    stats = civ.stats
    return Snapshot(
        turn=state.turn,
        year=state.year,
        population=state.population(civ_id),
        food=summary.food,
        materials=summary.materials,
        wealth=summary.wealth,
        knowledge=summary.knowledge,
        workforce=summary.workforce,
        free_labour=summary.free_labour,
        literacy_bp=stats.literacy_bp,
        unrest_bp=stats.unrest_bp,
        legitimacy_bp=stats.legitimacy_bp,
        suspicion_bp=stats.suspicion_bp,
        strain_bp=stats.strain_bp,
    )
