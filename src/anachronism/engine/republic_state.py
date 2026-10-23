"""The Republic's changing state (R2): people, families, this year's magistrates, the record.

Models only; the rules live in ``engine/republic.py``. Integers throughout (D-035).
"""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from anachronism.content.schema import Order


class _Mutable(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Held(_Mutable):
    """An office a person held."""

    office: str
    year: int
    suffect: bool = False


class Person(_Mutable):
    """A man of the Republic who can stand for office."""

    id: str
    name: str
    gens: str
    order: Order
    born: int
    died: int | None = None
    alive: bool = True
    historical: bool = False
    """From the content (a real person), or made up by the game."""
    content_id: str = ""
    traits: list[str] = Field(default_factory=list)
    popular: bool | None = None
    glory: int = 0
    offices: list[Held] = Field(default_factory=list)
    future: list[Held] = Field(default_factory=list)
    """Offices history says he will hold (used only when following the Fasti)."""
    protected_until: int | None = None
    """In a chronicle, no natural death before this year (his last recorded office)."""
    history_died: int | None = None
    """The year he really died, when known (a chronicle keeps to it)."""


class Family(_Mutable):
    """A gens in the Senate."""

    id: str
    dignitas_bp: int
    auctoritas_bp: int
    wealth: int
    clients: int
    base_dignitas_bp: int
    favour: dict[str, int] = Field(default_factory=dict)
    """Issue -> how far the player has won this family over (-10000..10000)."""


class Magistrate(_Mutable):
    """Someone holding office in a year."""

    office: str
    person: str
    name: str
    year: int
    ends_year: int
    term_months: int
    suffect: bool = False
    appointed: bool = False
    by_fasti: bool = False
    """Taken from the Fasti (history), not elected."""
    master: str = ""
    """For a master of the horse: the dictator he serves."""


class CensusRecord(_Mutable):
    """A count of the citizens."""

    year: int
    citizens: int


class Backing(_Mutable):
    """The player has thrown his weight behind a man for an office in a year."""

    person: str
    office: str
    year: int


class RepublicState(_Mutable):
    """How Rome governs itself, in one game."""

    magistrates: list[Magistrate] = Field(default_factory=list)
    """Everyone in office now: this year's college, plus any who carry over."""
    record: list[Magistrate] = Field(default_factory=list)
    """The game's own Fasti: the senior offices of past years."""
    people: dict[str, Person] = Field(default_factory=dict)
    families: dict[str, Family] = Field(default_factory=dict)
    census: list[CensusRecord] = Field(default_factory=list)
    influence: int = 0
    """The player's standing with the Senate, spent on persuading and backing."""
    backing: list[Backing] = Field(default_factory=list)
    emergency_bp: int = 0
    extra_emergency_bp: int = 0
    """Added by events (a defeat, a threat) and fading each year."""
    diverged: bool = False
    """History has been turned from the Fasti."""
    next_person: int = 1
