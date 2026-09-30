"""Population growth toward each province's capacity."""

from __future__ import annotations

from anachronism.content.schema import EffectType
from anachronism.engine.effects import Effects
from anachronism.engine.fixed import BP, apply_bp, div_round, with_bonus
from anachronism.engine.state import GameState
from anachronism.engine.timeflow import rate_per_turn


def province_capacity(state: GameState, province_id: str, effects: Effects | None) -> int:
    """People the province can support, including its owner's population_cap effects."""
    geography = state.world.geography[province_id]
    base = geography.capacity or state.world.terrain[geography.terrain].capacity
    if effects is None:
        return base
    return with_bonus(base, effects[EffectType.POPULATION_CAP])


def grow_population(
    state: GameState, effects_by_civ: dict[str, Effects], starving: set[str]
) -> None:
    """Logistic growth toward capacity; overcrowded provinces shrink; famine stops growth."""
    rules = state.world.rules.population
    for province_id in sorted(state.provinces):
        province = state.provinces[province_id]
        people = province.population
        if people == 0 or (province.owner is not None and province.owner in starving):
            continue
        effects = effects_by_civ.get(province.owner) if province.owner else None
        capacity = province_capacity(state, province_id, effects)
        if people < capacity:
            rate = rate_per_turn(state, rules.growth_bp)
            if effects is not None:
                rate = with_bonus(rate, effects[EffectType.HEALTH])
            province.population += div_round(people * rate * (capacity - people), capacity * BP)
        elif people > capacity:
            loss = apply_bp(people - capacity, rate_per_turn(state, rules.overcrowding_loss_bp))
            province.population -= loss
