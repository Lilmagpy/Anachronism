"""Chronicle mode: playing along history in chapters (D-120)."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.content.schema import RelationStatus, Stage
from anachronism.engine.actions import ChooseChapter
from anachronism.engine.campaign import PASSED_OVER, historical_index
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.rivals import status
from anachronism.engine.save import dumps, loads
from anachronism.engine.state import GameState, TechState
from anachronism.tools.story import chronicle_block


@pytest.fixture
def chronicle(content: Content) -> GameState:
    return new_game(content, "punic_wars", seed=1, player_civ="rome", chronicle=True)


def test_free_play_has_no_chapters(content: Content) -> None:
    state = new_game(content, "punic_wars", seed=1, player_civ="rome")
    assert not state.world.chapters
    assert state.chapter is None
    assert state.world.years_per_turn == 10


def test_the_chronicle_opens_with_its_first_chapter_and_short_turns(
    chronicle: GameState,
) -> None:
    assert chronicle.world.years_per_turn == 2
    assert chronicle.chapter == "rome_messana"
    assert any(e.kind == "almanac" for e in chronicle.events)


def test_a_choice_acts_in_the_world_and_is_compared_with_history(
    chronicle: GameState,
) -> None:
    chapter = chronicle.world.chapters["rome_messana"]
    index = historical_index(chapter)
    state, logged = apply_action(
        chronicle, ChooseChapter(civ="rome", chapter="rome_messana", choice=index)
    )
    assert logged.ok, logged.message
    assert status(state, "rome", "carthage") is RelationStatus.WAR
    assert state.provinces["messana"].owner == "rome"
    assert state.chapter is None
    assert state.chapter_result is not None
    assert state.chapter_result.historical
    assert "real Rome held 8" in state.chapter_result.benchmark


def test_an_unanswered_chapter_goes_as_history_went(chronicle: GameState) -> None:
    state, events = end_turn(chronicle)
    assert state.chapters_done["rome_messana"] == historical_index(
        chronicle.world.chapters["rome_messana"]
    )
    assert any(e.kind == "chapter_settled" for e in events)


def test_a_chapter_whose_world_is_gone_is_passed_over(chronicle: GameState) -> None:
    # refuse Messana: there is no war, so Hiero never changes sides
    refuse = ChooseChapter(civ="rome", chapter="rome_messana", choice=1)
    state, _ = apply_action(chronicle, refuse)
    for _ in range(4):
        if state.chapter is not None:
            chapter = state.world.chapters[state.chapter]
            state, _ = apply_action(
                state,
                ChooseChapter(civ="rome", chapter=chapter.id, choice=historical_index(chapter)),
            )
        state, _ = end_turn(state)
    assert state.chapters_done.get("rome_hiero") == PASSED_OVER


def test_ideas_ahead_of_their_time_open_choices_history_never_had(
    chronicle: GameState,
) -> None:
    fleet = chronicle.world.chapters["rome_fleet"]
    locked = next(i for i, c in enumerate(fleet.choices) if c.needs_adopted)
    chronicle.chapter = "rome_fleet"
    _, logged = apply_action(
        chronicle, ChooseChapter(civ="rome", chapter="rome_fleet", choice=locked)
    )
    assert not logged.ok
    for tech in fleet.choices[locked].needs_adopted:
        chronicle.civs["rome"].tech[tech] = TechState(stage=Stage.ADOPTED)
    block = chronicle_block_for(chronicle)
    assert block["chapter"]["choices"][locked]["locked"] == ""
    _, logged = apply_action(
        chronicle, ChooseChapter(civ="rome", chapter="rome_fleet", choice=locked)
    )
    assert logged.ok


def chronicle_block_for(state: GameState) -> dict:  # type: ignore[type-arg]
    from anachronism.content.loader import load_content

    block = chronicle_block(load_content(), state)
    assert block is not None
    return block


def test_chronicle_games_save_and_replay(chronicle: GameState) -> None:
    state, _ = end_turn(chronicle)
    assert dumps(loads(dumps(state))) == dumps(state)
