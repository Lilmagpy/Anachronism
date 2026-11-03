"""Strain, unrest, legitimacy, riots, revolts and collapse (DESIGN §5.3).

Overextension is not a special rule: shortfalls and diverted labour raise strain, strain feeds
unrest, unrest cuts the workforce (see ``economy.labour``), which deepens the shortfall.
"""

from __future__ import annotations

from anachronism.content.schema import EffectType
from anachronism.engine.buildings import weighted
from anachronism.engine.economy import EconomyOutcome
from anachronism.engine.effects import Effects
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.rng import GameRng
from anachronism.engine.state import CivState, GameState
from anachronism.engine.tech import resistance_bp
from anachronism.engine.timeflow import per_turn, rate_per_turn


def strain_target_bp(state: GameState, outcome: EconomyOutcome) -> int:
    """The strain level current conditions push towards."""
    rules = state.world.rules.society
    target = apply_bp(outcome.shortfall_bp, rules.strain_from_shortfall_bp)
    target += apply_bp(outcome.diversion_bp, rules.strain_from_diversion_bp)
    target += apply_bp(outcome.wealth_shortfall_bp, rules.strain_from_shortfall_bp)
    return min(BP, target)


def update_society(
    state: GameState,
    civ: CivState,
    outcome: EconomyOutcome,
    effects: Effects,
    rng: GameRng,
    events: EventLog,
) -> None:
    """Update strain, unrest and legitimacy; roll for riots and revolts."""
    rules = state.world.rules.society
    stats = civ.stats

    gap = strain_target_bp(state, outcome) - stats.strain_bp
    stats.strain_bp = clamp(
        stats.strain_bp + apply_bp(gap, rate_per_turn(state, rules.strain_response_bp)), 0, BP
    )

    opposition = sum(
        resistance_bp(state, civ, state.tech_nodes[p.node_id])
        for p in civ.projects.values()
        if not p.paused
    )
    pressure = apply_bp(stats.strain_bp, rules.unrest_from_strain_bp) + opposition
    pressure += effects[EffectType.UNREST]
    growth = per_turn(state, pressure) + apply_bp(outcome.famine_bp, rules.unrest_from_famine_bp)
    recovery = apply_bp(stats.unrest_bp, rate_per_turn(state, rules.unrest_recovery_bp))
    recovery += per_turn(state, apply_bp(rules.unrest_recovery_legitimacy_bp, stats.legitimacy_bp))
    recovery += per_turn(state, weighted(state, civ.id, "calm_bp"))  # temples, courts (D-111)
    stats.unrest_bp = clamp(stats.unrest_bp + growth - recovery, 0, BP)

    drift = apply_bp(
        rules.legitimacy_baseline_bp - stats.legitimacy_bp,
        rate_per_turn(state, rules.legitimacy_drift_bp),
    )
    change = drift + per_turn(state, effects[EffectType.LEGITIMACY])
    change -= apply_bp(outcome.famine_bp, rules.famine_legitimacy_bp)
    stats.legitimacy_bp = clamp(stats.legitimacy_bp + change, 0, BP)

    if stats.unrest_bp > rules.riot_threshold_bp:
        excess = stats.unrest_bp - rules.riot_threshold_bp
        if rng.chance(rate_per_turn(state, apply_bp(excess, rules.riot_chance_per_excess_bp))):
            _riot(state, civ, events)
    if stats.unrest_bp > rules.revolt_threshold_bp:
        excess = stats.unrest_bp - rules.revolt_threshold_bp
        if rng.chance(rate_per_turn(state, apply_bp(excess, rules.revolt_chance_per_excess_bp))):
            _revolt(state, civ, rng, events)
    _check_collapse(state, civ, events)


def _riot(state: GameState, civ: CivState, events: EventLog) -> None:
    rules = state.world.rules.society
    stock = civ.stockpiles
    stock.materials -= apply_bp(stock.materials, rules.riot_loss_bp)
    stock.wealth -= apply_bp(stock.wealth, rules.riot_loss_bp)
    civ.stats.legitimacy_bp = clamp(civ.stats.legitimacy_bp - rules.riot_legitimacy_bp, 0, BP)
    events.add(civ.id, "riot", f"Riots in {civ.name}: storehouses are looted.")


def _revolt(state: GameState, civ: CivState, rng: GameRng, events: EventLog) -> None:
    rules = state.world.rules.society
    candidates = [pid for pid in state.owned_provinces(civ.id) if pid != civ.capital]
    if not candidates:
        return
    province_id = rng.pick(candidates)
    state.provinces[province_id].owner = None
    civ.revolts += 1
    stats = civ.stats
    stats.unrest_bp = clamp(stats.unrest_bp - rules.revolt_unrest_release_bp, 0, BP)
    stats.legitimacy_bp = clamp(stats.legitimacy_bp - rules.revolt_legitimacy_bp, 0, BP)
    place = state.world.geography[province_id].name
    events.add(civ.id, "revolt", f"{place} rises in revolt and breaks away from {civ.name}.", place)


def _check_collapse(state: GameState, civ: CivState, events: EventLog) -> None:
    if civ.collapsed or civ.starting_provinces == 0:
        return
    # collapse is breaking apart from within: provinces lost in war do not count
    if civ.revolts * BP >= civ.starting_provinces * state.world.rules.society.collapse_share_bp:
        civ.collapsed = True
        events.add(
            civ.id,
            "collapse",
            f"The {civ.adjective} state has collapsed, its provinces in open revolt.",
        )
