"""The changing state of Roman society (R4, F1): priests, portents, land, grain, coin, legions.

Models only; the rules live in ``engine/religion.py``, ``engine/roman_economy.py`` and
``engine/legions.py``, run from ``engine/rome_society.py``. Integers throughout (D-035);
every list is kept in a fixed order so saves are byte-identical.
"""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class _Mutable(BaseModel):
    model_config = ConfigDict(extra="forbid")


# ---------------------------------------------------------------- religion


class Priest(_Mutable):
    """A seat in a college and who fills it."""

    priesthood: str
    person: str = ""
    """A ``RepublicState.people`` id; empty for a Vestal (a daughter, not one of the men)."""
    name: str
    gens: str = ""
    since: int
    """The year the seat was taken."""


class Auspice(_Mutable):
    """The signs taken before a battle of the player's army."""

    turn: int
    year: int
    army: str
    commander: str
    province: str
    favourable: bool
    morale_bp: int
    """What the signs did to the men's morale (bp, signed)."""
    chance_bp: int
    """The odds the signs would be favourable."""


class ProdigyRecord(_Mutable):
    """A portent reported in a year and what was done about it."""

    turn: int
    year: int
    prodigy: str
    dated: bool
    """From the list's dated entries (else drawn as a recurring kind)."""
    expiated: bool
    cost: int


class ReligionState(_Mutable):
    """Rome's relations with its gods, in one game."""

    priests: list[Priest] = Field(default_factory=list)
    pontifex_maximus: str = ""
    """The chief pontiff (a person id)."""
    auspices: list[Auspice] = Field(default_factory=list)
    """The latest signs taken, oldest first."""
    prodigies: list[ProdigyRecord] = Field(default_factory=list)
    unexpiated: int = 0
    """Prodigies the Senate has not yet been able to expiate."""
    cults: dict[str, int] = Field(default_factory=dict)
    """Cult id -> the year it came to Rome (or was put down)."""
    consultations: list[int] = Field(default_factory=list)
    """Years the Sibylline Books were opened, oldest first."""
    books_lost: bool = False
    """The Books burned with the Capitol and have not been replaced."""


# ---------------------------------------------------------------- land, slaves, debt


class LandState(_Mutable):
    """Who holds the land, who works it, and what the people owe."""

    ager_publicus: int = 0
    """Public land in thousands of iugera."""
    latifundia: int = 0
    """The part of it the rich have taken into their estates."""
    assidui_bp: int = 7000
    """Share of adult male citizens who meet the property threshold for the legions."""
    slaves: int = 0
    revolts: list[int] = Field(default_factory=list)
    """Years the slaves rose."""
    reform_applied: int | None = None
    """The year of the last land law applied (``republic.laws`` carries the Senate's year)."""
    debt_bp: int = 0
    """How deep the small farmers are in debt, 0..10_000."""
    relief_applied: int | None = None
    secessions: list[int] = Field(default_factory=list)
    """Years the plebs seceded."""


# ---------------------------------------------------------------- grain


class GrainState(_Mutable):
    """Rome's food this year."""

    city_people: int = 0
    """The city's estimated people (the demand)."""
    supply_bp: int = 10_000
    """How much of the city's need was covered (bp; below 10_000 is a shortage)."""
    shortfall_bp: int = 0
    shortages: int = 0
    """Years of shortage so far."""
    dole_since: int | None = None
    dole_cost: int = 0
    """What the dole cost this year."""
    held: list[str] = Field(default_factory=list)
    """Grain supplies (ids) whose provinces the state holds this year."""


# ---------------------------------------------------------------- coin and tribute


class CoinState(_Mutable):
    """Rome's money."""

    reforms: list[str] = Field(default_factory=list)
    """Coin reforms in force (ids, in order)."""
    trade_bonus_bp: int = 0
    tribute: int = 0
    """Tribute received this year."""
    trade_bonus: int = 0
    """Extra trade income this year from the coinage."""


# ---------------------------------------------------------------- the legions


class LegionState(_Mutable):
    """Which army Rome fields, whom it can levy, and whom the soldiers follow."""

    era: str = ""
    """The army era in force (an ``ArmyEra`` id)."""
    era_since: int = 0
    threshold_asses: int = 0
    """The property qualification this year."""
    assidui: int = 0
    """Men of the classes who can be levied (the pool)."""
    proletarii: bool = False
    """The capite censi serve: no threshold."""
    levied: int = 0
    """Men levied from the pool and still under arms."""
    loyalty: dict[str, int] = Field(default_factory=dict)
    """General's name -> his men's loyalty to him rather than the state (bp)."""


class RomeSocietyState(_Mutable):
    """Roman society in one game (Republic scenarios only)."""

    year: int = 0
    """The last year the society was brought up to."""
    religion: ReligionState = Field(default_factory=ReligionState)
    land: LandState = Field(default_factory=LandState)
    grain: GrainState = Field(default_factory=GrainState)
    coin: CoinState = Field(default_factory=CoinState)
    legions: LegionState = Field(default_factory=LegionState)
