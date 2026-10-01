"""Royal decrees that spend the treasury: festivals and mercenaries.

Wealth builds up in a peaceful state; these give it uses with a price that grows with the
state's size, so a festival in a great empire costs more than in a small kingdom.
"""

from __future__ import annotations

from anachronism.engine.actions import Decree, HireMercenaries, HoldFestival
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.state import GameState


def cost(state: GameState, civ_id: str, per_1000: int) -> int:
    """Wealth a decree costs: ``per_1000`` hundredths of a unit per 1,000 people."""
    return max(1, state.population(civ_id) // 1000 * per_1000 // 100)


def apply_decree(state: GameState, action: Decree) -> tuple[bool, str]:
    """Carry out a decree if the treasury allows."""
    civ = state.civs[action.civ]
    rules = state.world.rules.rivals
    if isinstance(action, HoldFestival):
        price = cost(state, civ.id, rules.festival_wealth_per_1000)
        if civ.stockpiles.wealth < price:
            return False, f"a festival needs {price} wealth"
        civ.stockpiles.wealth -= price
        civ.stats.legitimacy_bp = clamp(
            civ.stats.legitimacy_bp + rules.festival_legitimacy_bp, 0, BP
        )
        civ.stats.unrest_bp = clamp(civ.stats.unrest_bp - rules.festival_unrest_bp, 0, BP)
        return True, f"Feasts and games across {civ.name}: the people cheer the throne."
    if isinstance(action, HireMercenaries):
        price = cost(state, civ.id, rules.mercenary_wealth_per_1000)
        if civ.stockpiles.wealth < price:
            return False, f"mercenaries want {price} wealth"
        if civ.mercenaries > 0:
            return False, "the mercenaries you hired are still serving"
        civ.stockpiles.wealth -= price
        civ.mercenaries = rules.mercenary_turns
        return True, f"Hired swords join {civ.name}'s army for {rules.mercenary_turns} turns."
    raise AssertionError(f"unhandled decree {action!r}")
