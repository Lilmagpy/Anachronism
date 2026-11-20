"""Rome's world as it changes (R3, F1): treaties, levies, colonies, provinces and governors.

Models only; the rules live in ``engine/allies.py``, ``engine/colonies.py`` and
``engine/provinces_rome.py``. Integers throughout (D-035). The state hangs off
``RepublicState.italy``, so it exists only in Republic games and is saved with them.
"""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from anachronism.content.schema.italy import AllyStatus, ColonyKind


class _Mutable(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Treaty(_Mutable):
    """One ally's bond with Rome in this game."""

    civ: str
    name: str
    status: AllyStatus = AllyStatus.ALLY
    loyalty_bp: int = 7000
    levy_bp: int = 800
    """Share of its people the treaty obliges it to send."""
    booty_share: bool = True
    land_share: bool = False
    since: int
    """The year the present status began."""
    revolted: bool = False
    """It has broken with Rome (at war with it); the treaty is kept as a memory."""
    serving: int = 0
    """Its men now serving in Rome's armies."""
    citizens: int = 0
    """Its adult men counted in Rome's census (citizenship without the vote)."""
    italian: bool = True
    """Its home is in Italy (the Social War is an Italian matter)."""


class Colony(_Mutable):
    """A colony standing in a province."""

    id: str
    name: str
    province: str
    kind: ColonyKind
    year: int
    settlers: int
    """Colonists (men) now in it."""
    garrison: int
    loyalty_bp: int
    historical: bool
    """Founded by history (a foundation of ``colonies.yaml``), not by the Senate's vote."""
    refusals: int = 0
    """Times it refused its levy."""


class Provincia(_Mutable):
    """An overseas region governed by a Roman magistrate."""

    id: str
    name: str
    since: int
    governor: str = ""
    """Person id of the governor (empty: none this year)."""
    governor_name: str = ""
    office: str = ""
    """``praetor``, ``propraetor`` (prorogued) ..."""
    governor_since: int = 0
    loyalty_bp: int = 5000
    tribute: int = 0
    """What it paid Rome last year."""
    extorted: int = 0
    """What the present governor has taken for himself."""
    extorted_total: int = 0
    revolts: int = 0
    prosecutions: int = 0


class Prosecution(_Mutable):
    """A governor tried for extortion (the lex Calpurnia, 149 BC)."""

    year: int
    provincia: str
    governor: str
    name: str
    amount: int
    convicted: bool


class ItalyState(_Mutable):
    """Rome's allies, colonies and provinces in one game."""

    treaties: dict[str, Treaty] = Field(default_factory=dict)
    """Civ id -> its treaty."""
    levies: dict[str, dict[str, int]] = Field(default_factory=dict)
    """Army id -> ally civ -> its men serving in that army."""
    colonies: dict[str, Colony] = Field(default_factory=dict)
    """Colony id -> the colony (historical foundations keep their content id)."""
    lapsed: dict[str, int] = Field(default_factory=dict)
    """Foundation id -> the year it could not be founded (history had turned there)."""
    provinciae: dict[str, Provincia] = Field(default_factory=dict)
    prosecutions: list[Prosecution] = Field(default_factory=list)
    citizens_added: int = 0
    """Adult men added to the citizen body by grants, all told."""
    social_war_year: int | None = None
    """The year the Italian allies rose, if they did."""
    citizenship_year: int | None = None
    """The year citizenship was given to the Italian allies as a whole."""
