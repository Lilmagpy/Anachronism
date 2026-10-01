"""The story so far: chapters of the game, told plainly or by the model."""

from __future__ import annotations

from pathlib import Path

from anachronism.content.loader import load_content
from anachronism.engine.bots import make_bot, play_turn
from anachronism.engine.game import new_game
from anachronism.engine.state import GameState
from anachronism.llm.config import LlmConfig
from anachronism.llm.fake import FakeProvider
from anachronism.llm.pipeline import IdeaPipeline
from anachronism.tools.chronicle import CHAPTER_TURNS, chapters
from anachronism.tools.server import Session


def played(turns: int) -> GameState:
    state = new_game(load_content(), "alexander", seed=2)
    bots = {civ: make_bot("growth") for civ in state.civs}
    for _ in range(turns):
        state, _ = play_turn(state, bots)
    return state


def test_chapters_cover_the_game_in_order() -> None:
    state = played(CHAPTER_TURNS * 2 + 2)
    told = chapters(state)
    assert [c.finished for c in told] == [True, True, False]
    assert told[0].start_year == -336
    assert told[0].end_year == told[1].start_year
    assert told[-1].end_year == state.year
    assert all(c.text for c in told)
    assert "Macedon" in told[0].facts["realm"]
    assert "million" in told[0].facts["people"]


def test_a_new_game_has_no_chapters() -> None:
    assert chapters(new_game(load_content(), "alexander", seed=2)) == []


def test_finished_chapters_are_told_by_the_model_and_cached(tmp_path: Path) -> None:
    fake = FakeProvider({"line": "In those years Macedon grew wise and quarrelsome."})
    online = IdeaPipeline(LlmConfig(api_key="k", model="m"), fake, use_files=False)
    session = Session(load_content(), tmp_path, online)
    session.new_game({"scenario": "alexander", "seed": 2})
    session.state = played(CHAPTER_TURNS + 1)
    reply = session.chronicle({})
    told = reply["chapters"]
    assert [c["source"] for c in told] == ["content", "model"]  # newest first
    assert told[1]["text"].startswith("In those years")
    assert session.chronicle({})["chapters"][1]["source"] == "cache"
    assert len(fake.calls) == 1
