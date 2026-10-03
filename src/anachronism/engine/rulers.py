"""Rulers grow old and die; successions change a state's temperament (brief §7.6).

Each turn every ruler ages. The chance of dying rises with age. The next ruler is the
scenario's next historical successor if one is listed, otherwise an unnamed heir. A death
costs legitimacy; if the court was already shaky, the succession brings a crisis.
"""

from __future__ import annotations

from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.rng import GameRng
from anachronism.engine.state import CivState, GameState
from anachronism.engine.timeflow import per_turn


def death_chance_bp(state: GameState, civ: CivState) -> int:
    """Chance this turn that the ruler dies."""
    per_decade = (
        max(0, civ.ruler_age - 30) * state.world.rules.society.death_chance_per_year_of_age_bp
    )
    return clamp(per_turn(state, per_decade), 0, 9000)


def age_and_succeed(state: GameState, civ: CivState, rng: GameRng, events: EventLog) -> None:
    """Age the ruler by a turn; perhaps they die and are succeeded."""
    civ.ruler_age += state.world.years_per_turn
    until, dies = history_of_reign(state, civ)
    if spared(state, civ):
        return  # history has not reached the end of this reign
    if until is not None and dies:
        succeed(state, civ, events, heir_age=30)  # the chronicle keeps to history (D-132)
        return
    if not rng.chance(death_chance_bp(state, civ)):
        return
    named_heir = civ.rulers - 1 < len(state.world.successors.get(civ.id, ()))
    succeed(state, civ, events, heir_age=30 if named_heir else 20 + rng.below(21))


def history_of_reign(state: GameState, civ: CivState) -> tuple[int | None, bool]:
    """When the player's ruler's reign really ended, in a chronicle (D-132).

    The flag is True for a natural death the chronicle keeps to, False for an end that a
    chapter tells (the ruler is only spared until then).
    """
    if not state.chronicle_mode or civ.id != state.player_civ:
        return None, False
    if civ.rulers == 1:
        died = state.world.reign_died.get(civ.id)
        return (died, True) if died is not None else (state.world.reign_until.get(civ.id), False)
    line = state.world.successors.get(civ.id, ())
    index = civ.rulers - 2
    if index >= len(line):
        return None, False
    heir = line[index]
    return (heir.died, True) if heir.died is not None else (heir.until, False)


def spared(state: GameState, civ: CivState) -> bool:
    """True if the chronicle keeps the player's ruler from old age (D-130).

    That lasts until the year their reign really ended: how it ends is history's to tell.
    """
    until, _ = history_of_reign(state, civ)
    # a turn covers its year and the ones after it, up to the next turn's
    return until is not None and state.year + state.world.years_per_turn <= until


def succeed(
    state: GameState, civ: CivState, events: EventLog, heir_age: int = 30, how: str = "has died"
) -> None:
    """The ruler's reign ends (``how`` says how); the next in line takes the throne."""
    rules = state.world.rules.society
    old = civ.ruler or f"the ruler of {civ.name}"
    old_desc = old  # a named ruler needs no state name ("Genghis Khan has died")
    line = state.world.successors.get(civ.id, ())
    index = civ.rulers - 1
    if index < len(line):
        heir = line[index]
        civ.ruler = heir.name
        civ.ruler_age = heir.age
        if heir.disposition is not None:
            civ.disposition = heir.disposition
    else:
        civ.ruler = ""
        civ.ruler_age = heir_age
    civ.rulers += 1
    new = civ.ruler or "a new ruler"
    shaky = civ.stats.legitimacy_bp < rules.succession_crisis_below_bp
    civ.stats.legitimacy_bp = clamp(civ.stats.legitimacy_bp - rules.succession_legitimacy_bp, 0, BP)
    events.add(
        civ.id,
        "ruler_died",
        f"{_cap(old_desc)} {how}. {_cap(new)} takes the throne.",
        old,
    )
    if shaky:
        civ.stats.unrest_bp = clamp(civ.stats.unrest_bp + rules.succession_crisis_unrest_bp, 0, BP)
        events.add(
            civ.id,
            "succession_crisis",
            f"Rival claimants fight over the throne of {civ.name}.",
            civ.name,
        )


def _cap(text: str) -> str:
    return text[:1].upper() + text[1:]
