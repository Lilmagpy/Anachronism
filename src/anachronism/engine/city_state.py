"""The city of Rome's changing state (U7): what stands, what was built early, the turn's events.

Models only; the rules live in ``engine/city.py``. Integers and ids throughout (D-035). The 3D
client reads this through ``tools/view.py`` (key ``city``); nothing here is for display.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

MonumentState = Literal["planned", "building", "standing", "burnt", "ruined"]
EventKind = Literal["games", "senate", "sacrifice", "triumph", "fire", "flood"]


class _Mutable(BaseModel):
    model_config = ConfigDict(extra="forbid")


class MonumentStatus(_Mutable):
    """Where one monument is in its life this year."""

    state: MonumentState = "planned"
    years_left: int = 0
    """Years until the work is finished: while ``building``, or while a ``burnt`` or ``ruined``
    monument is being rebuilt; 0 when no work is going on (or the end is not recorded)."""
    since: int = 0
    """The year it entered this state."""


class Anachronism(_Mutable):
    """A great work the player's ideas raised in the city before its time."""

    id: str
    tech: str
    name: str
    builds: str
    """The kind of structure, e.g. ``aqueduct``, ``dome``."""
    year: int
    """The year the idea was adopted."""
    ahead: int
    """Years before its place in history (0 or less: not early)."""


@dataclass(frozen=True)
class CityEvent:
    """Something happening in the city that the 3D client plays out. Ids and ints only.

    ``games``: ``ref`` the festival id (or ``munus``), ``monument`` the venue, ``person`` the
    dead man honoured by a ``munus``, ``value`` the month. ``senate``: ``ref`` the issue,
    ``monument`` the house, ``value``/``other`` yes and no in basis points. ``sacrifice``:
    ``ref`` is ``vow`` or ``dedication`` at ``monument``. ``triumph``: ``person`` the
    triumphator, ``ref`` the place or ``capital``, ``value`` the spoils (wealth).
    ``fire``/``flood``: the ``monument`` struck.
    """

    kind: EventKind
    year: int
    turn: int
    ref: str = ""
    monument: str = ""
    person: str = ""
    value: int = 0
    other: int = 0


class CityState(_Mutable):
    """Rome the city, in one game (Republic scenarios only)."""

    year: int = 0
    """The last year the city was brought up to."""
    standing: dict[str, MonumentStatus] = Field(default_factory=dict)
    """Monument id -> status, for every monument in the dataset."""
    changed: list[str] = Field(default_factory=list)
    """Monuments whose ``state`` changed in the latest step (sorted)."""
    anachronisms: list[Anachronism] = Field(default_factory=list)
    events: list[CityEvent] = Field(default_factory=list)
    """This turn's events, in order; older turns' are dropped at the next turn."""
    funerals: list[str] = Field(default_factory=list)
    """People already honoured with funeral games (sorted)."""
