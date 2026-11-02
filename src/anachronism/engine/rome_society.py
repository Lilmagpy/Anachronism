"""Roman society's yearly step (R4, F1): religion, land and grain, coin, the legions.

One entry point for the Republic to call each year after the city has been brought up to
date (``republic.run_year``), and one at the start (``start_republic``). It does nothing in a
game that is not a Republic scenario or whose packs carry no society content.

Order within a year: the colleges and prodigies (religion), then land, slaves, grain, coin and
debt (roman_economy), then the army's era and the levy pool (legions). Conquests, sacks and
disasters are read from the turn's events in the turn's last year, as the city does for its
triumphs.
"""

from __future__ import annotations

from anachronism.engine import legions, religion, roman_economy
from anachronism.engine.events import EventLog
from anachronism.engine.rng import GameRng
from anachronism.engine.rome_society_state import RomeSocietyState
from anachronism.engine.state import GameState


def active(state: GameState) -> bool:
    """True when the society runs in this game."""
    return (
        state.republic is not None
        and state.rome_society is not None
        and state.world.rome_society.present
    )


def start(state: GameState, rng: GameRng, events: EventLog) -> None:
    """Create the society's state at the scenario's start (Republic scenarios with content)."""
    if state.republic is None or not state.world.rome_society.present:
        return
    state.rome_society = RomeSocietyState(year=state.year)
    religion.start(state, rng, events)
    roman_economy.start(state)
    legions.start(state, events)


def run_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """Bring the society to ``year``. Years already passed are ignored."""
    if not active(state):
        return
    society = state.rome_society
    assert society is not None
    if year <= society.year:
        return
    religion.run_year(state, rng, events, year)
    roman_economy.run_year(state, rng, events, year)
    legions.run_year(state, events, year)
    society.year = year
