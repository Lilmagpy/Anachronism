"""Resolving a turn: the fixed pipeline of ARCHITECTURE §4."""

from __future__ import annotations

from anachronism.content.schema import EffectType
from anachronism.engine.armies import command, march, upkeep
from anachronism.engine.buildings import advance_works, rival_builders, weighted
from anachronism.engine.campaign import advance, almanac
from anachronism.engine.conquest import sieges
from anachronism.engine.culture import spread_faiths, trade
from anachronism.engine.dilemmas import ask
from anachronism.engine.dynasty import renew
from anachronism.engine.economy import run_economy
from anachronism.engine.effects import Effects, civ_effects
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.happenings import strike
from anachronism.engine.intelligence import gather, rival_spies
from anachronism.engine.navies import admiralty, blockades, fleet_upkeep, sail
from anachronism.engine.occupation import occupation
from anachronism.engine.offers import envoys
from anachronism.engine.population import grow_population
from anachronism.engine.projects import advance_projects
from anachronism.engine.reports import snapshot
from anachronism.engine.rivals import rivals_turn
from anachronism.engine.rng import GameRng
from anachronism.engine.rulers import age_and_succeed
from anachronism.engine.society import update_society
from anachronism.engine.state import Event, GameState, Stats
from anachronism.engine.suspicion import update_suspicion
from anachronism.engine.tech import spread_step
from anachronism.engine.timeflow import per_turn, rate_per_turn
from anachronism.engine.victory import check_outcome
from anachronism.engine.war import wear_wars


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
        _update_literacy(new, civ.stats, effects, weighted(new, civ_id, "literacy_bp"))
        strike(new, civ, effects, rng, events)
        age_and_succeed(new, civ, rng, events)
        effects_by_civ[civ_id] = effects
    # rivals: news, awareness, scripts, free agents; then the wars (brief §7)
    strengths = rivals_turn(new, effects_by_civ, list(events.items), rng, events)
    # builders: sites move on, and rival courts with full stores raise new buildings (D-111)
    advance_works(new, events)
    rival_builders(new, events)
    # the campaigns: orders, marches and battles, sieges, supply; then the toll of war
    command(new, strengths)
    admiralty(new)
    sail(new, rng, events)
    blockades(new, events)
    march(new, rng, events)
    sieges(new, events, rng)
    upkeep(new, events)
    fleet_upkeep(new)
    occupation(new, rng, events)
    renew(new, events)  # collapsed states pass to new dynasties (D-113)
    wear_wars(new, events)
    for civ_id in sorted(new.civs):
        new.civs[civ_id].mercenaries = max(0, new.civs[civ_id].mercenaries - 1)
        new.civs[civ_id].sealed = max(0, new.civs[civ_id].sealed - 1)
    ask(new, rng, events)
    envoys(new, rng, events)
    gather(new, rng, events)  # what the player's envoys, merchants and spies report (D-115)
    rival_spies(new, rng, events)  # courts try to steal the player's ideas from the future (D-125)
    trade(new)
    spread_faiths(new, effects_by_civ, rng, events)
    grow_population(new, effects_by_civ, starving)
    new.turn += 1
    new.year += new.world.years_per_turn
    # chronicle mode (D-120): the world's news, then the next chapter of history
    almanac(new, new.year - new.world.years_per_turn, events)
    advance(new, events)
    for civ_id in sorted(new.civs):
        new.civs[civ_id].history.append(snapshot(new, civ_id))
    check_outcome(new, events)
    new.events.extend(events.items)
    return new, events.items


def _update_literacy(state: GameState, stats: Stats, effects: Effects, schools: int = 0) -> None:
    """Teaching adds literacy; attrition removes a share, so effects set a sustainable level.

    ``schools`` is what the realm's school buildings add each decade (D-111).
    """
    gain = per_turn(state, effects[EffectType.LITERACY_GROWTH] + schools)
    attrition_bp = rate_per_turn(state, state.world.rules.society.literacy_attrition_bp)
    loss = apply_bp(stats.literacy_bp, attrition_bp)
    stats.literacy_bp = clamp(stats.literacy_bp + gain - loss, 0, BP)
