"""Rome's world (R3, F1): the one yearly entry for allies, colonies and provinces.

``republic.run_year`` calls :func:`run_year` after the year's magistrates are seated, and
``start_republic`` calls :func:`start` once. The three systems run in a fixed order: the
allies (treaties, loyalty, levies, the Social War), then the colonies (foundations), then the
provinces (governors, tribute, extortion, prosecutions, revolts). Everything is deterministic:
sorted ids, integers, and the game's ``GameRng`` for the few draws.
"""

from __future__ import annotations

from anachronism.engine import allies, colonies, provinces_rome
from anachronism.engine.events import EventLog
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState


def start(state: GameState) -> None:
    """Seed the treaties, standing colonies and provinces at the scenario's start."""
    if state.republic is None:
        return
    allies.start(state)
    colonies.start(state)
    provinces_rome.start(state)


def run_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """One year of Rome's world."""
    if state.republic is None:
        return
    allies.run_year(state, rng, events, year)
    colonies.run_year(state, rng, events, year)
    provinces_rome.run_year(state, rng, events, year)


def extra_citizens(state: GameState) -> int:
    """Adult men the census counts beyond Rome's own population (allies with citizenship)."""
    return allies.extra_citizens(state)
