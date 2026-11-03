"""The city of Rome (U7): monuments, the timeline of their fortunes, and the city's calendar.

``Monument`` mirrors ``data/rome/city/monuments.yaml`` (see that folder's README). The dataset is
shared with the 3D client, which adds fields of its own, so unknown fields are *kept*, not
rejected. ``CityTimeline`` entries say, as data, when a monument was begun, finished, burnt or
pulled down, so the engine never has to read the dataset's free text. ``CityRules`` holds the
games calendar and the other numbers the city's yearly step needs.
"""

from __future__ import annotations

from typing import Any, Literal

from pydantic import ConfigDict, Field

from anachronism.content.schema.base import Frozen, Identifier


class _Open(Frozen):
    """Dataset models tolerate fields the engine does not know (the client adds its own)."""

    model_config = ConfigDict(extra="allow", frozen=True)


class MonumentBuilt(_Open):
    """When and by whom a monument was built."""

    year: int | None = None
    """Negative = BC; ``None`` if unknown (then it stands from the start, or `not_before`)."""
    not_before: int | None = None
    """A floor from the sources when the year is unknown ("after 27 BC"): stands from here."""
    certainty: str = ""
    by: str = ""


class MonumentEvent(_Open):
    """A dated note: a rebuild, a fire, an end."""

    year: int | None = None  # None: known only by a reign, not a year
    what: str = ""


class Monument(_Open):
    """One structure of the city of Rome."""

    id: Identifier
    latin: str = ""
    english: str = ""
    type: str = ""
    regio: int = 0
    lat: float = 0.0
    lon: float = 0.0
    precision: str = ""
    location: str = ""
    built: MonumentBuilt | None = None
    events: tuple[MonumentEvent, ...] = ()
    ended: MonumentEvent | None = None
    form: str = ""
    materials: tuple[str, ...] = ()
    route: tuple[tuple[float, float], ...] = ()
    sources: tuple[str, ...] = ()
    pleiades: Any = None
    notes: str = ""

    @property
    def built_year(self) -> int | None:
        """The year it was finished or dedicated, if known."""
        return self.built.year if self.built is not None else None


TimelineKind = Literal["vowed", "begun", "completed", "fire", "demolished", "flood"]


class CityTimeline(Frozen):
    """One turning point in a monument's life, as data (the dataset's text is not parsed).

    ``vowed`` is only a vow (a sacrifice, no change of status); ``begun`` starts building (or
    rebuilding after a fire); ``completed`` is a dedication or rebuilding finished (it replaces
    the dataset's ``built.year`` as the finishing year unless it follows a fire or demolition);
    ``fire`` burns it; ``demolished`` ruins it; ``flood`` only floods it (no status change).
    """

    id: Identifier
    monument: Identifier
    year: int
    kind: TimelineKind
    source: str = Field(min_length=1)


class Ludus(Frozen):
    """A festival of games that comes round every year."""

    id: Identifier
    name: str = Field(min_length=1)
    kind: Literal["circus", "scaenic"]
    """``circus``: chariot races in a circus; ``scaenic``: plays on a temporary stage."""
    month: int = Field(ge=1, le=12)
    from_year: int
    venue: Identifier
    """A monument id."""
    sources: tuple[str, ...] = Field(min_length=1)


class CityRules(Frozen):
    """Numbers and calendar for the city's yearly step."""

    ludi: tuple[Ludus, ...] = ()
    munus_from_year: int = -264
    """The first gladiator games at a funeral (Livy Per. 16)."""
    munus_venue: Identifier | None = None
    munus_min_rank: int = Field(default=5, ge=0)
    """A notable who held an office of at least this rank is given funeral games when he dies."""
    senate_houses: tuple[Identifier, ...] = ()
    """Monument ids in order of preference: where the Senate meets is the first that stands."""
