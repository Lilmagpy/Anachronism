"""Envoys from rival courts and the player's answers (D-105)."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.content.schema import Disposition, RelationStatus
from anachronism.engine.actions import AnswerEnvoy, DeclareWar
from anachronism.engine.events import EventLog
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.offers import _candidates, envoys
from anachronism.engine.rivals import relation, status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState, Offer


@pytest.fixture
def qin(content: Content) -> GameState:
    state = new_game(content, "warring_states", seed=1, player_civ="qin")
    state.turn = 5  # past the opening grace
    return state


def test_a_beaten_weary_enemy_sues_for_peace(qin: GameState) -> None:
    state, _ = apply_action(qin, DeclareWar(civ="qin", target="wei"))
    rel = relation(state, "qin", "wei")
    assert rel is not None
    rel.losses["wei"] = 2
    rel.weariness["wei"] = 9000
    assert any(o.kind == "peace" and o.from_civ == "wei" for o in _candidates(state))
    state.offer = Offer(kind="peace", from_civ="wei")
    state, logged = apply_action(state, AnswerEnvoy(civ="qin", accept=True))
    assert logged.ok
    assert status(state, "qin", "wei") is not RelationStatus.WAR


def test_defying_an_ultimatum_means_war(qin: GameState) -> None:
    qin.offer = Offer(kind="ultimatum", from_civ="wei")
    state, logged = apply_action(qin, AnswerEnvoy(civ="qin", accept=False))
    assert logged.ok
    assert status(state, "qin", "wei") is RelationStatus.WAR


def test_paying_tribute_keeps_the_peace_at_a_price(qin: GameState) -> None:
    qin.offer = Offer(kind="ultimatum", from_civ="wei")
    wealth = qin.civs["qin"].stockpiles.wealth
    state, logged = apply_action(qin, AnswerEnvoy(civ="qin", accept=True))
    assert logged.ok
    assert state.civs["qin"].stockpiles.wealth < wealth
    assert status(state, "qin", "wei") is RelationStatus.TRIBUTARY


def test_unanswered_envoys_are_refused(qin: GameState) -> None:
    qin.offer = Offer(kind="trade", from_civ="wei")
    state, events = end_turn(qin)
    assert any(e.kind == "envoy_declined" for e in events)
    assert status(state, "qin", "wei") is not RelationStatus.TRADING


def test_a_merchant_court_proposes_trade(qin: GameState) -> None:
    qin.civs["wei"].disposition = Disposition.MERCANTILE
    rel = relation(qin, "qin", "wei")
    assert rel is not None
    rel.status = RelationStatus.NEUTRAL
    rel.grievance = {}
    override = qin.world.rules.rivals.model_copy(update={"envoy_offer_bp": 10_000})
    qin.world = qin.world.model_copy(
        update={"rules": qin.world.rules.model_copy(update={"rivals": override})}
    )
    envoys(qin, GameRng(qin.rng), EventLog(qin.turn, qin.year))
    assert qin.offer is not None
    state, logged = apply_action(qin, AnswerEnvoy(civ="qin", accept=True))
    if qin.offer.kind == "trade" and qin.offer.from_civ == "wei":
        assert status(state, "qin", "wei") is RelationStatus.TRADING
    assert logged.ok
