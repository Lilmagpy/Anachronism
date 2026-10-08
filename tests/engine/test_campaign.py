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
    shown = next(c for c in block["chapter"]["choices"] if c["index"] == locked)
    assert shown["locked"] == ""
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


@pytest.fixture
def qin(content: Content) -> GameState:
    return new_game(content, "warring_states", seed=1, player_civ="qin", chronicle=True)


def test_reforms_last_and_conquered_land_comes_with_a_garrison(qin: GameState) -> None:
    from anachronism.engine.occupation import garrisoned

    assert qin.chapter == "qin_xianyang"
    before = qin.civs["qin"].martial_bp
    state, _ = apply_action(qin, ChooseChapter(civ="qin", chapter="qin_xianyang", choice=0))
    assert state.civs["qin"].martial_bp > before
    # jump to Sima Cuo's march on Shu: Ba falls whole, Chengdu is taken and held
    state.chapter = "qin_shu_or_han"
    state, _ = apply_action(state, ChooseChapter(civ="qin", chapter="qin_shu_or_han", choice=0))
    assert state.civs["ba"].collapsed
    for pid in ("ba_jiangzhou", "shu_chengdu"):
        assert state.provinces[pid].owner == "qin"
        assert garrisoned(state, pid)
    # a garrison keeps apart from a host passing through
    state, _ = end_turn(state)
    assert garrisoned(state, "shu_chengdu")


def test_a_conquest_waits_until_the_state_is_strong_enough(qin: GameState) -> None:
    from anachronism.engine.campaign import fits

    han_falls = qin.world.chapters["qin_han_falls"]
    assert not fits(qin, han_falls)  # Qin is nowhere near half as strong again as Han
    qin.civs["han"].stockpiles.food = 0
    for pid in qin.owned_provinces("han"):
        qin.provinces[pid].population = 1_000
    assert fits(qin, han_falls)


@pytest.fixture
def oda(content: Content) -> GameState:
    return new_game(content, "sengoku", seed=1, player_civ="oda", chronicle=True)


def test_nobunaga_is_spared_old_age_until_honnoji(oda: GameState, content: Content) -> None:
    """The chronicle, not the dice, ends Nobunaga's reign (D-130)."""
    from anachronism.engine.rulers import spared

    assert oda.world.years_per_turn == 1
    assert oda.chapter == "oda_okehazama"
    civ = oda.civs["oda"]
    civ.ruler_age = 80  # old enough to die any year
    assert spared(oda, civ)
    oda.year = 1583
    assert not spared(oda, civ)
    free = new_game(content, "sengoku", seed=1, player_civ="oda")
    assert not spared(free, free.civs["oda"])  # in free play the dice decide


def test_a_chapter_can_end_the_reign(oda: GameState) -> None:
    """At Honno-ji the historical choice kills Nobunaga and loses Kyoto."""
    oda.provinces["j_kyoto"].owner = "oda"
    oda.chapter = "oda_honnoji"
    state, _ = apply_action(oda, ChooseChapter(civ="oda", chapter="oda_honnoji", choice=0))
    civ = state.civs["oda"]
    assert civ.ruler == "Oda Nobutada"
    assert civ.rulers == 2
    assert state.provinces["j_kyoto"].owner is None
    assert state.chapter_result is not None


def test_the_court_can_move_and_a_tributary_can_break_away(content: Content) -> None:
    """Jangsu moves to Pyongyang (427); Silla slips out of Goguryeo's orbit (433)."""
    state = new_game(content, "three_kingdoms", seed=1, player_civ="goguryeo", chronicle=True)
    assert status(state, "goguryeo", "silla") is RelationStatus.TRIBUTARY
    state.chapter = "gog_pyongyang"
    state, _ = apply_action(state, ChooseChapter(civ="goguryeo", chapter="gog_pyongyang", choice=0))
    assert state.civs["goguryeo"].capital == "k4_pyongyang"
    state.chapter = "gog_naje"
    state, _ = apply_action(state, ChooseChapter(civ="goguryeo", chapter="gog_naje", choice=0))
    assert status(state, "goguryeo", "silla") is RelationStatus.HOSTILE


def test_heirs_are_spared_until_their_reigns_really_ended(content: Content) -> None:
    """Jangsu died in 491; in the chronicle old age does not take him first."""
    from anachronism.engine.events import EventLog
    from anachronism.engine.rulers import spared, succeed

    state = new_game(content, "three_kingdoms", seed=1, player_civ="goguryeo", chronicle=True)
    civ = state.civs["goguryeo"]
    succeed(state, civ, EventLog(state.turn, state.year), how="dies")
    assert civ.ruler == "King Jangsu"
    state.year = 480
    assert spared(state, civ)
    state.year = 491
    assert not spared(state, civ)


def test_a_reign_can_end_as_history_says_not_only_by_death(content: Content) -> None:
    """Isaac Komnenos abdicated in 1059; the chronicle says so, and the court gives no eulogy."""
    from anachronism.engine.events import EventLog
    from anachronism.engine.rng import GameRng
    from anachronism.engine.rulers import age_and_succeed

    state = new_game(content, "year_1000", seed=1, player_civ="byzantium", chronicle=True)
    civ = state.civs["byzantium"]
    civ.rulers = 9  # Isaac I Komnenos, eighth in the line after Basil
    civ.ruler = "Isaac I Komnenos"
    state.year = 1060
    events = EventLog(state.turn, state.year)
    age_and_succeed(state, civ, GameRng(state.rng), events)
    assert civ.ruler == "Constantine X Doukas"
    assert [e.kind for e in events.items] == ["ruler_fell"]
    assert "abdicates" in events.items[0].message


def test_every_chronicle_starts_and_its_chapters_are_in_its_age(content: Content) -> None:
    """Each state with a chronicle can start one; its chapters fall within its moment."""
    chronicles = sorted({(c.scenario, c.civ) for c in content.chapters.values()})
    assert len(chronicles) >= 20
    for scenario_id, civ in chronicles:
        state = new_game(content, scenario_id, seed=1, player_civ=civ, chronicle=True)
        start = content.scenarios[scenario_id].start_year
        years = [c.year for c in state.world.chapters.values()]
        assert years, (scenario_id, civ)
        assert start <= min(years), (scenario_id, civ)
        assert max(years) <= start + 170, (scenario_id, civ)
        for chapter in state.world.chapters.values():
            for choice in chapter.choices:
                for node in choice.needs_adopted:
                    assert node in state.tech_nodes, (chapter.id, node)


def test_a_coup_does_not_happen_once_history_has_turned(content: Content) -> None:
    """If the player's last answer turned from history, a scheduled murder or deposition
    does not follow; natural deaths still keep their dates (D-153)."""
    from anachronism.engine.events import EventLog
    from anachronism.engine.rng import GameRng
    from anachronism.engine.rulers import age_and_succeed
    from anachronism.engine.state import ChapterResult

    state = new_game(content, "year_1000", seed=1, player_civ="byzantium", chronicle=True)
    civ = state.civs["byzantium"]
    civ.rulers, civ.ruler, civ.ruler_age = 9, "Isaac I Komnenos", 30
    state.year = 1060
    state.chapter_result = ChapterResult(
        chapter="byz_schism", choice=1, outcome="", history="", historical=False, benchmark=""
    )
    age_and_succeed(state, civ, GameRng(state.rng), EventLog(state.turn, state.year))
    assert civ.ruler == "Isaac I Komnenos"
