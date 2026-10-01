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
    rules = state.world.rules.society
    civ.ruler_age += state.world.years_per_turn
    if not rng.chance(death_chance_bp(state, civ)):
        return
    old = civ.ruler or f"the ruler of {civ.name}"
    old_desc = f"{civ.ruler} of {civ.name}" if civ.ruler else old
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
        civ.ruler_age = 20 + rng.below(21)
    civ.rulers += 1
    new = civ.ruler or "a new ruler"
    shaky = civ.stats.legitimacy_bp < rules.succession_crisis_below_bp
    civ.stats.legitimacy_bp = clamp(civ.stats.legitimacy_bp - rules.succession_legitimacy_bp, 0, BP)
    events.add(
        civ.id,
        "ruler_died",
        f"{_cap(old_desc)} has died. {_cap(new)} takes the throne.",
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
