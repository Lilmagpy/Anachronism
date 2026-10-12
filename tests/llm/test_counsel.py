"""Aware rival courts decide with the model (brief §7.2): bounded, guarded and recorded."""

from __future__ import annotations

from pathlib import Path

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import RelationStatus
from anachronism.engine.actions import DeclareWar, SendEnvoy
from anachronism.engine.game import new_game
from anachronism.engine.rivals import relation
from anachronism.engine.state import Awareness, GameState
from anachronism.llm.config import LlmConfig
from anachronism.llm.counsel import available_moves, to_action, who_counsels
from anachronism.llm.fake import FakeProvider
from anachronism.llm.pipeline import IdeaPipeline
from anachronism.llm.provider import ProviderError
from anachronism.tools.server import Session

ONLINE = LlmConfig(api_key="test", model="fake-model")


@pytest.fixture(scope="module")
def content() -> Content:
    return load_content()


@pytest.fixture
def game(content: Content) -> GameState:
    state = new_game(content, "warring_states", seed=4, player_civ="qin")
    state.civs["wei"].awareness = Awareness.AWARE
    state.civs["wei"].stockpiles.wealth = 100_000
    return state


def test_only_aware_courts_counsel_the_deepest_grudge_first(game: GameState) -> None:
    assert who_counsels(game) == "wei"
    game.civs["han"].awareness = Awareness.FREE_AGENT
    rel = relation(game, "han", "qin")
    assert rel is not None
    rel.grievance["han"] = 5000
    assert who_counsels(game) == "han"
    for civ in game.civs.values():
        civ.awareness = Awareness.ON_SCRIPT
    assert who_counsels(game) is None


def test_the_guard_refuses_hopeless_wars(game: GameState) -> None:
    assert "war" in available_moves(game, "wei")
    assert isinstance(to_action(game, "wei", "war"), DeclareWar)
    assert isinstance(to_action(game, "wei", "envoy"), SendEnvoy)
    assert to_action(game, "wei", "wait") is None
    for province in game.provinces.values():  # make Wei a speck
        if province.owner == "wei":
            province.population = 1000
    assert "war" not in available_moves(game, "wei")
    assert to_action(game, "wei", "war") is None


def test_counsel_returns_a_guarded_move_and_a_line(game: GameState) -> None:
    fake = FakeProvider({"move": "envoy", "line": "Let us talk, Qin.", "reason": "curious"})
    action, line = IdeaPipeline(ONLINE, fake, use_files=False).counsel(game, "wei")
    assert isinstance(action, SendEnvoy)
    assert line == "Let us talk, Qin."
    assert "available moves" in fake.calls[0][1]
    for reply in (ProviderError("down"), {"move": "conquer the world", "line": "x"}):
        pipeline = IdeaPipeline(ONLINE, FakeProvider(reply), use_files=False)
        assert pipeline.counsel(game, "wei") == (None, "")
    assert IdeaPipeline(LlmConfig(offline=True), use_files=False).counsel(game, "wei") == (None, "")


def test_a_court_that_marches_is_recorded_and_speaks(tmp_path: Path, game: GameState) -> None:
    fake = FakeProvider({"move": "war", "line": "Your sorcery ends here."})
    session = Session(load_content(), tmp_path, IdeaPipeline(ONLINE, fake, use_files=False))
    session.new_game({"scenario": "warring_states", "civ": "qin", "seed": 4})
    session.state = game
    view = session.end_turn({})
    assert view["voices"][0]["text"] == "Your sorcery ends here."
    assert view["voices"][0]["civ"] == "wei"
    rel = relation(session.game(), "wei", "qin")
    assert rel is not None
    assert rel.status is RelationStatus.WAR
    assert any(isinstance(entry.action, DeclareWar) for entry in session.game().action_log)
