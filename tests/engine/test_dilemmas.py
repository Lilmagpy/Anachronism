"""Dilemmas put to the ruler (D-104)."""

from __future__ import annotations

from anachronism.content.loader import Content
from anachronism.content.schema import Stage
from anachronism.engine.actions import ChooseDilemma
from anachronism.engine.dilemmas import ask, fits
from anachronism.engine.events import EventLog
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState


def only(state: GameState, dilemma_id: str, chance: int = 10_000) -> None:
    dilemma = state.world.dilemmas[dilemma_id].model_copy(update={"chance_bp": chance})
    state.world = state.world.model_copy(update={"dilemmas": {dilemma_id: dilemma}})


def test_historical_dilemmas_need_their_moment(content: Content) -> None:
    state = new_game(content, "alexander", seed=1)
    knot = state.world.dilemmas["gordian_knot"]
    assert not fits(state, knot)  # 336 BC: too early
    state.year = -334
    assert fits(state, knot)
    qin = new_game(content, "warring_states", seed=1, player_civ="qin")
    assert "gordian_knot" not in {d for d in qin.world.dilemmas if fits(qin, qin.world.dilemmas[d])}


def test_answering_applies_the_choice(content: Content) -> None:
    state = new_game(content, "warring_states", seed=1, player_civ="qin")
    only(state, "shang_yang")
    ask(state, GameRng(state.rng), EventLog(state.turn, state.year))
    assert state.dilemma == "shang_yang"
    nobles = state.civs["qin"].influence
    before = dict(nobles)
    state, logged = apply_action(state, ChooseDilemma(civ="qin", dilemma="shang_yang", choice=0))
    assert logged.ok
    assert "machine for farming and war" in logged.message
    assert state.dilemma is None
    assert state.civs["qin"].influence != before
    assert state.civs["qin"].tech["written_law"].stage is not None
    _, logged = apply_action(state, ChooseDilemma(civ="qin", dilemma="shang_yang", choice=0))
    assert not logged.ok  # answered already


def test_unanswered_the_court_decides_and_once_is_once(content: Content) -> None:
    state = new_game(content, "warring_states", seed=1, player_civ="qin")
    only(state, "comet")
    ask(state, GameRng(state.rng), EventLog(state.turn, state.year))
    assert state.dilemma == "comet"
    state, events = end_turn(state)
    assert any(e.kind == "dilemma_settled" for e in events)
    assert state.dilemma is None  # a "once" dilemma does not return
    assert state.dilemmas_seen == ["comet"]


def test_an_idea_is_planted(content: Content) -> None:
    state = new_game(content, "sengoku", seed=1)
    only(state, "tanegashima")
    ask(state, GameRng(state.rng), EventLog(state.turn, state.year))
    me = state.player_civ
    state.civs[me].stockpiles.wealth = 10_000
    had = state.civs[me].tech.get("musket")
    state, logged = apply_action(state, ChooseDilemma(civ=me, dilemma="tanegashima", choice=0))
    assert logged.ok
    if had is None:
        assert state.civs[me].tech["musket"].stage is Stage.CONCEPT
