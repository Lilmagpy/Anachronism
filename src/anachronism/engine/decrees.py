"""Royal decrees that spend the treasury: festivals, mercenaries and explanations.

Wealth builds up in a peaceful state; these give it uses with a price that grows with the
state's size, so a festival in a great empire costs more than in a small kingdom.
"""

from __future__ import annotations

from anachronism.engine.actions import Decree, Explain, HireMercenaries, HoldFestival
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.state import Framing, GameState


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
    if isinstance(action, Explain):
        return _explain(state, action)
    raise AssertionError(f"unhandled decree {action!r}")


def explain_costs(state: GameState, civ_id: str) -> tuple[int, int]:
    """Wealth for a divine proclamation and knowledge for crediting foreign sages."""
    rules = state.world.rules.suspicion
    return (
        cost(state, civ_id, rules.explain_wealth_per_1000),
        cost(state, civ_id, rules.sages_knowledge_per_1000),
    )


def explain_ready_in(state: GameState, civ_id: str) -> int:
    """Turns until the court may explain itself again (0: now)."""
    since = state.turn - state.civs[civ_id].explained_turn
    return max(0, state.world.rules.suspicion.explain_cooldown_turns - since)


def _explain(state: GameState, action: Explain) -> tuple[bool, str]:
    civ = state.civs[action.civ]
    rules = state.world.rules.suspicion
    stats = civ.stats
    if stats.suspicion_bp <= 0:
        return False, "nobody is asking where the court's arts come from"
    wait = explain_ready_in(state, civ.id)
    if wait:
        return False, f"the people heard the court's last story too recently ({wait} turn(s))"
    wealth, knowledge = explain_costs(state, civ.id)
    if action.story == "divine":
        if civ.stockpiles.wealth < wealth:
            return False, f"the temples want {wealth} wealth for the rites"
        civ.stockpiles.wealth -= wealth
        stats.suspicion_bp = max(0, stats.suspicion_bp - rules.explain_suspicion_bp)
        civ.explained_turn = state.turn
        believed = stats.legitimacy_bp >= rules.explain_belief_legitimacy_bp
        if believed and civ.framing in (Framing.WITCHCRAFT, Framing.FRAUD):
            civ.framing = Framing.INSPIRED
            return (
                True,
                f"Priests proclaim {civ.name}'s new arts a gift of the gods - "
                "and the people believe it.",
            )
        if believed:
            return (
                True,
                f"Priests proclaim {civ.name}'s new arts a gift of the gods. The talk quietens.",
            )
        return (
            True,
            "Priests proclaim the new arts divine. Some believe; the doubters only whisper lower.",
        )
    if civ.stockpiles.knowledge < knowledge:
        return False, f"crediting foreign sages takes {knowledge} knowledge"
    civ.stockpiles.knowledge -= knowledge
    stats.suspicion_bp = max(0, stats.suspicion_bp - rules.sages_suspicion_bp)
    civ.explained_turn = state.turn
    for news in state.news:  # the story travels: rivals learn of these arts at once
        if news.about == civ.id:
            news.arrives_turn = min(news.arrives_turn, state.turn + 1)
    return (
        True,
        f"Scholars of {civ.name} credit wise men from distant lands. Strangers' arts, not sorcery.",
    )
