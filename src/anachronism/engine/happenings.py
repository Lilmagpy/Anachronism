"""Chance events striking a state: plague, flood, drought, a bumper harvest (DESIGN §12).

At most one happening per state per turn. Each is rolled on the game's RNG with its chance
scaled to the turn's length; it strikes a province that fits it (terrain, river, coast),
more often a populous one. Harm is softened by the matching effect (health against plague,
storage against flood and drought).
"""

from __future__ import annotations

from anachronism.content.schema import Happening
from anachronism.engine.effects import Effects
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.rng import GameRng
from anachronism.engine.state import CivState, GameState
from anachronism.engine.tech import is_adopted
from anachronism.engine.timeflow import per_turn


def _places(state: GameState, civ: CivState, happening: Happening) -> list[str]:
    places = []
    for pid in state.owned_provinces(civ.id):
        geography = state.world.geography[pid]
        if happening.terrain and geography.terrain not in happening.terrain:
            continue
        if happening.river and not geography.river:
            continue
        if happening.coastal and not geography.coastal:
            continue
        places.append(pid)
    return places


def _soften(amount: int, happening: Happening, effects: Effects) -> int:
    """Harm (negative amounts) is reduced by the softening effect's percentage."""
    if amount >= 0 or happening.softened_by is None:
        return amount
    relief = clamp(effects[happening.softened_by], 0, 8000)
    return apply_bp(amount, BP - relief)


def strike(
    state: GameState, civ: CivState, effects: Effects, rng: GameRng, events: EventLog
) -> None:
    """Perhaps let one happening strike ``civ`` this turn."""
    frequency = state.world.rules.society.happening_frequency_bp
    if frequency == 0:
        return
    for happening_id in sorted(state.world.happenings):
        happening = state.world.happenings[happening_id]
        if any(not is_adopted(civ, t) for t in happening.needs_adopted):
            continue
        chance = per_turn(state, apply_bp(happening.chance_bp, frequency))
        if not rng.chance(chance):
            continue
        places = _places(state, civ, happening)
        if not places:
            continue
        where = places[rng.weighted_index([max(1, state.provinces[p].population) for p in places])]
        _apply(state, civ, happening, where, effects, events)
        return


def _apply(
    state: GameState,
    civ: CivState,
    happening: Happening,
    where: str,
    effects: Effects,
    events: EventLog,
) -> None:
    province = state.provinces[where]
    province.population = max(
        0,
        province.population
        + apply_bp(province.population, _soften(happening.population_bp, happening, effects)),
    )
    stores = civ.stockpiles
    stores.food = max(
        0, stores.food + apply_bp(stores.food, _soften(happening.food_bp, happening, effects))
    )
    stores.materials = max(
        0,
        stores.materials
        + apply_bp(stores.materials, _soften(happening.materials_bp, happening, effects)),
    )
    stores.wealth = max(
        0, stores.wealth + apply_bp(stores.wealth, _soften(happening.wealth_bp, happening, effects))
    )
    stores.knowledge = max(
        0,
        stores.knowledge
        + apply_bp(stores.knowledge, _soften(happening.knowledge_bp, happening, effects)),
    )
    stats = civ.stats
    stats.unrest_bp = clamp(stats.unrest_bp + happening.unrest_bp, 0, BP)
    stats.legitimacy_bp = clamp(stats.legitimacy_bp + happening.legitimacy_bp, 0, BP)
    stats.suspicion_bp = clamp(stats.suspicion_bp + happening.suspicion_bp, 0, BP)
    for group, change in sorted(happening.influence.items()):
        civ.influence[group] = clamp(civ.influence.get(group, 0) + change, 0, BP)
    name = state.world.geography[where].name
    events.add(
        civ.id,
        happening.kind,
        happening.message.format(civ=civ.name, province=name),
        happening.name,
    )
