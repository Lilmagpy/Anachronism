"""Rulers age, die and are succeeded by history's heirs, then by unnamed ones."""

from __future__ import annotations

from anachronism.content.loader import Content
from anachronism.engine.events import EventLog
from anachronism.engine.game import new_game
from anachronism.engine.rng import GameRng
from anachronism.engine.rulers import age_and_succeed, death_chance_bp
from tests.engine.conftest import override_rules


def test_rulers_start_from_the_scenario(content: Content) -> None:
    state = new_game(content, "warring_states", seed=1)
    assert state.civs["qin"].ruler == "Duke Xiao"
    assert state.civs["qin"].ruler_age == 31
    assert state.world.successors["qin"][0].name == "King Huiwen"


def test_older_rulers_are_likelier_to_die(content: Content) -> None:
    state = new_game(content, "warring_states", seed=1)
    qin = state.civs["qin"]
    young = death_chance_bp(state, qin)
    qin.ruler_age = 70
    assert death_chance_bp(state, qin) > young


def test_succession_follows_history_then_heirs(content: Content) -> None:
    state = new_game(content, "warring_states", seed=1)
    override_rules(state, society={"death_chance_per_year_of_age_bp": 10_000})
    qin = state.civs["qin"]
    qin.stats.legitimacy_bp = 3000
    events = EventLog(0, state.year)
    rng = GameRng(state.rng)
    names = []
    for _ in range(5):
        qin.ruler_age = 80
        age_and_succeed(state, qin, rng, events)
        names.append(qin.ruler)
    assert names[:3] == ["King Huiwen", "King Wu", "King Zhaoxiang"]
    assert names[3] == ""
    assert qin.rulers >= 5  # the chance is capped at 90%, so one may survive
    kinds = [e.kind for e in events.items]
    assert "ruler_died" in kinds
    assert "succession_crisis" in kinds
