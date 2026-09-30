"""Time: eras, and scaling per-decade rules to the scenario's turn length."""

from __future__ import annotations

from anachronism.content.schema import Era
from anachronism.engine.fixed import BP, div_round
from anachronism.engine.state import GameState


def era_at(eras: tuple[Era, ...], year: int) -> Era:
    """Return the era a year belongs to."""
    for era in eras:
        if era.ends is None or year < era.ends:
            return era
    raise ValueError("eras must end with an open-ended era")


def current_era(state: GameState) -> Era:
    """The era of the current game year."""
    return era_at(state.world.eras, state.year)


def per_turn(state: GameState, per_decade: int) -> int:
    """Scale an amount defined per ``reference_years`` to one turn of this scenario."""
    return div_round(per_decade * state.world.years_per_turn, state.world.rules.reference_years)


def rate_per_turn(state: GameState, rate_bp: int) -> int:
    """Scale a per-decade rate to one turn, never above 100%."""
    return min(BP, per_turn(state, rate_bp))


def turns_for(state: GameState, decades: int) -> int:
    """Turns needed for something that takes ``decades`` reference periods (at least one)."""
    reference = state.world.rules.reference_years
    return max(1, -(-decades * reference // state.world.years_per_turn))
