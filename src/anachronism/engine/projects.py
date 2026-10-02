"""Experimentation projects: progress, luck, stalling and completion."""

from __future__ import annotations

from anachronism.engine.actions import Priority
from anachronism.engine.events import EventLog, list_names
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.rng import GameRng
from anachronism.engine.state import CivState, GameState
from anachronism.engine.tech import adopt
from anachronism.engine.timeflow import rate_per_turn, turns_for


def project_turns(state: GameState, node_id: str) -> int:
    """Turns a fully funded project on this advancement takes."""
    node = state.tech_nodes[node_id]
    return turns_for(state, state.world.rules.projects.duration_decades[node.complexity - 1])


def setback_chance_bp(state: GameState, civ: CivState, node_id: str) -> int:
    """Chance of a setback per turn: a base, plus more for each literacy point missing."""
    rules = state.world.rules.projects
    shortfall = max(0, state.tech_nodes[node_id].requires.literacy_bp - civ.stats.literacy_bp)
    return min(BP, rules.setback_chance_bp + shortfall * rules.setback_per_literacy_point_bp // 100)


def advance_projects(
    state: GameState,
    civ: CivState,
    funding: dict[str, int],
    rng: GameRng,
    events: EventLog,
) -> None:
    """Move every project forward by its funding, roll for luck, and adopt finished ones.

    Every unpaused project draws exactly two random numbers per turn (setback, then
    breakthrough), so the sequence does not depend on how the rolls come out.
    """
    rules = state.world.rules.projects
    decay = rate_per_turn(state, rules.decay_bp)
    newly_stalled: list[str] = []
    for node_id in sorted(civ.projects):
        project = civ.projects[node_id]
        name = state.tech_nodes[node_id].name
        if project.paused:
            project.progress_bp -= apply_bp(project.progress_bp, decay)
            project.last_funding_bp = 0
            continue
        share = funding.get(node_id, 0)
        project.last_funding_bp = share
        gain = apply_bp(-(-BP // project_turns(state, node_id)), share)
        setback = rng.chance(setback_chance_bp(state, civ, node_id))
        breakthrough = rng.chance(rules.breakthrough_chance_bp)
        if share > 0 and setback:
            gain = -rules.setback_loss_bp
            events.add(civ.id, "setback", f"Experiments with {name} in {civ.name} go badly.", name)
        elif share > 0 and breakthrough:
            gain += rules.breakthrough_gain_bp
            events.add(civ.id, "breakthrough", f"A breakthrough with {name} in {civ.name}!", name)
        # steady (low-priority) work that keeps moving never decays, however slowly it goes
        steady = project.priority is Priority.LOW and share > 0
        starved = share < rules.stall_funding_bp and not steady
        project.stalled_turns = project.stalled_turns + 1 if starved else 0
        if project.stalled_turns >= rules.stall_turns:
            gain -= apply_bp(project.progress_bp, decay)
            if project.stalled_turns == rules.stall_turns:
                newly_stalled.append(name)
        project.progress_bp = clamp(project.progress_bp + gain, 0, BP)
        if project.progress_bp >= BP:
            del civ.projects[node_id]
            adopt(state, civ, node_id, events)
    if newly_stalled:
        events.add(
            civ.id,
            "stalled",
            f"Work in {civ.name} has stalled on {list_names(newly_stalled)}; progress is decaying.",
            list_names(newly_stalled),
        )
