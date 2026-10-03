"""Collecting events that happen while a turn resolves."""

from __future__ import annotations

from anachronism.engine.state import Event


class EventLog:
    """Events for one turn, stamped with the turn number and year being played."""

    def __init__(self, turn: int, year: int) -> None:
        self.turn = turn
        self.year = year
        self.items: list[Event] = []

    def add(self, civ: str | None, kind: str, message: str, subject: str = "") -> None:
        """Record an event; ``subject`` names what it is about (an idea, a place)."""
        self.items.append(
            Event(
                turn=self.turn,
                year=self.year,
                civ=civ,
                kind=kind,
                message=message,
                subject=subject,
            )
        )


def list_names(names: list[str], limit: int = 3) -> str:
    """Join names as "A, B and C", or "A, B, C and 4 more" beyond ``limit``."""
    if len(names) > limit:
        return f"{', '.join(names[:limit])} and {len(names) - limit} more"
    if len(names) == 1:
        return names[0]
    return f"{', '.join(names[:-1])} and {names[-1]}"
