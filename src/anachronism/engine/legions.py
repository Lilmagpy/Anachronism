"""The army's three systems and the census-class levy (R4, F1). Filled in by the third delivery."""

from __future__ import annotations

from anachronism.engine.events import EventLog
from anachronism.engine.state import Army, GameState


def start(state: GameState, events: EventLog) -> None:
    """Set the army era and the levy pool at the scenario's start."""


def run_year(state: GameState, events: EventLog, year: int) -> None:
    """The legions' year."""


def levy(
    state: GameState, civ_id: str, province_id: str, men: int, troops: dict[str, int], style: str
) -> tuple[int, dict[str, int]]:
    """Rome's levy by census class and era; other states' levies pass through unchanged."""
    return men, troops


def after_battle(
    state: GameState, winners: list[Army], losers: list[Army], events: EventLog
) -> None:
    """A battle's effect on the soldiers' loyalty to their general."""
