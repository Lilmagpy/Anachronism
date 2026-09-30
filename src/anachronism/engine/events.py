"""Collecting events that happen while a turn resolves."""

from __future__ import annotations

from anachronism.engine.state import Event


class EventLog:
    """Events for one turn, stamped with the turn number and year being played."""

    def __init__(self, turn: int, year: int) -> None:
        self.turn = turn
        self.year = year
        self.items: list[Event] = []

    def add(self, civ: str | None, kind: str, message: str) -> None:
        """Record an event."""
        self.items.append(
            Event(turn=self.turn, year=self.year, civ=civ, kind=kind, message=message)
        )
