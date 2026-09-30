"""Resolving a turn: the fixed pipeline of ARCHITECTURE §4 (the Phase 1 subset)."""

from __future__ import annotations

from anachronism.content.schema import EffectType
from anachronism.engine.economy import run_economy
from anachronism.engine.effects import Effects, civ_effects
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.population import grow_population
from anachronism.engine.projects import advance_projects
from anachronism.engine.reports import snapshot
from anachronism.engine.rng import GameRng
from anachronism.engine.society import update_society
from anachronism.engine.state import Event, GameState
from anachronism.engine.suspicion import update_suspicion
from anachronism.engine.tech import spread_step
from anachronism.engine.timeflow import per_turn


def end_turn(state: GameState) -> tuple[GameState, list[Event]]:
    """Resolve one turn and return the new state plus what happened. ``state`` is unchanged.

    Civilisations are processed in id order and all randomness comes from the state's RNG,
    so the same state always produces the same next state.
    """
    new = state.model_copy(deep=True)
    rng = GameRng(new.rng)
    events = EventLog(turn=state.turn + 1, year=state.year)
    effects_by_civ: dict[str, Effects] = {}
    starving: set[str] = set()
    for civ_id in sorted(new.civs):
        civ = new.civs[civ_id]
        if not new.owned_provinces(civ_id):
            continue
        effects = civ_effects(new, civ_id)
        outcome = run_economy(new, civ_id, effects)
        if outcome.deaths:
            starving.add(civ_id)
            events.add(civ_id, "famine", f"Famine in {civ.name}: {outcome.deaths:,} people die.")
        advance_projects(new, civ, outcome.allocation.funding, rng, events)
        effects = civ_effects(new, civ_id)
        update_society(new, civ, outcome, effects, rng, events)
        spread_step(new, civ, effects, events)
        update_suspicion(new, civ, rng, events)
        literacy_gain = per_turn(new, effects[EffectType.LITERACY_GROWTH])
        civ.stats.literacy_bp = clamp(civ.stats.literacy_bp + literacy_gain, 0, BP)
        effects_by_civ[civ_id] = effects
    grow_population(new, effects_by_civ, starving)
    new.turn += 1
    new.year += new.world.years_per_turn
    for civ_id in sorted(new.civs):
        new.civs[civ_id].history.append(snapshot(new, civ_id))
    new.events.extend(events.items)
    return new, events.items
