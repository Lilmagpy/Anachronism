"""Combining the effects of a civilisation's adopted advancements (DESIGN §9).

Each effect is capped for the current era (D-038), scaled by how widely the advancement has
spread, and stacked with diminishing returns: the strongest effect of a type counts fully,
the next ``stacking_decay_bp`` as much, and so on.
"""

from __future__ import annotations

from collections import defaultdict

from anachronism.content.schema import EffectType
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.state import GameState
from anachronism.engine.timeflow import current_era

Effects = defaultdict[EffectType, int]
"""Combined effect per type in basis points; missing types count as 0."""


def civ_effects(state: GameState, civ_id: str) -> Effects:
    """Return the combined numeric effects of everything a civilisation has adopted."""
    civ = state.civs[civ_id]
    era = current_era(state).id
    caps = state.world.effect_caps
    values: dict[EffectType, list[int]] = defaultdict(list)
    for node_id, tech in sorted(civ.tech.items()):
        if not tech.stage.is_adopted:
            continue
        for effect in state.tech_nodes[node_id].effects:
            if effect.type.is_unlock or effect.type is EffectType.SUSPICION:
                continue
            cap = caps[effect.type][era]
            capped = clamp(effect.bp, -cap, cap)
            values[effect.type].append(apply_bp(capped, tech.spread_bp))
    combined: Effects = defaultdict(int)
    decay = state.world.rules.stacking_decay_bp
    for effect_type, amounts in values.items():
        weight = BP
        total = 0
        for amount in sorted(amounts, key=lambda value: (-abs(value), value)):
            total += apply_bp(amount, weight)
            weight = apply_bp(weight, decay)
        combined[effect_type] = total
    return combined
