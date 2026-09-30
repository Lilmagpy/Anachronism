"""Tests for actions, turn resolution, determinism and replay."""

from __future__ import annotations

from anachronism.content.loader import Content
from anachronism.content.schema import Stage
from anachronism.engine.actions import (
    Action,
    CancelProject,
    PauseProject,
    Priority,
    ProposeIdea,
    ResumeProject,
    SetPriority,
    StartProject,
)
from anachronism.engine.game import apply_action, end_turn, new_game, replay
from anachronism.engine.save import dumps, loads
from anachronism.engine.state import GameState


def play(state: GameState, turns: int) -> GameState:
    """Play turns with a scripted set of actions, so the test covers actions too."""
    script: dict[int, list[Action]] = {
        0: [
            StartProject(civ="veyra", node_id="alphabet"),
            ProposeIdea(civ="veyra", node_id="iron_plough"),
        ],
        1: [StartProject(civ="kessrin", node_id="iron_working", priority=Priority.HIGH)],
        2: [
            StartProject(civ="veyra", node_id="ore_prospecting"),
            PauseProject(civ="kessrin", node_id="iron_working"),
        ],
        4: [
            ResumeProject(civ="kessrin", node_id="iron_working"),
            StartProject(civ="ushkai", node_id="stirrup"),
        ],
    }
    for _ in range(turns):
        for action in script.get(state.turn, []):
            state, _ = apply_action(state, action)
        state, _ = end_turn(state)
    return state


def test_starting_a_feasible_project(game: GameState) -> None:
    state, logged = apply_action(game, StartProject(civ="veyra", node_id="alphabet"))
    assert logged.ok
    assert state.civs["veyra"].tech["alphabet"].stage is Stage.EXPERIMENTING
    assert "alphabet" in state.civs["veyra"].projects
    assert state.action_log == [logged]
    assert "alphabet" not in game.civs["veyra"].projects  # the input state is untouched


def test_rejected_action_explains_why_and_only_logs(game: GameState) -> None:
    state, logged = apply_action(game, StartProject(civ="veyra", node_id="iron_working"))
    assert not logged.ok
    assert "Iron ore" in logged.message
    assert state.civs == game.civs
    assert state.action_log == [logged]


def test_rejections_for_known_duplicate_and_unknown(game: GameState) -> None:
    _, adopted = apply_action(game, StartProject(civ="veyra", node_id="writing"))
    assert not adopted.ok
    state, _ = apply_action(game, StartProject(civ="veyra", node_id="alphabet"))
    _, twice = apply_action(state, StartProject(civ="veyra", node_id="alphabet"))
    assert not twice.ok
    _, no_civ = apply_action(game, ProposeIdea(civ="atlantis", node_id="alphabet"))
    _, no_idea = apply_action(game, ProposeIdea(civ="veyra", node_id="teleportation"))
    assert not no_civ.ok
    assert not no_idea.ok


def test_proposing_reports_blockers_and_reveals_goals(game: GameState) -> None:
    state, logged = apply_action(game, ProposeIdea(civ="veyra", node_id="iron_plough"))
    assert logged.ok
    assert "Iron working" in logged.message
    assert "Iron ore" in logged.message
    assert state.civs["veyra"].tech["iron_working"].goal


def test_pause_resume_priority_and_cancel(game: GameState) -> None:
    state, _ = apply_action(game, StartProject(civ="veyra", node_id="alphabet"))
    state, paused = apply_action(state, PauseProject(civ="veyra", node_id="alphabet"))
    state, again = apply_action(state, PauseProject(civ="veyra", node_id="alphabet"))
    assert paused.ok
    assert not again.ok
    state, resumed = apply_action(state, ResumeProject(civ="veyra", node_id="alphabet"))
    state, raised = apply_action(
        state, SetPriority(civ="veyra", node_id="alphabet", priority=Priority.HIGH)
    )
    assert resumed.ok
    assert raised.ok
    assert state.civs["veyra"].projects["alphabet"].priority is Priority.HIGH
    state, cancelled = apply_action(state, CancelProject(civ="veyra", node_id="alphabet"))
    assert cancelled.ok
    assert "alphabet" not in state.civs["veyra"].projects
    assert state.civs["veyra"].tech["alphabet"].stage is Stage.CONCEPT


def test_end_turn_advances_time_and_records_history(game: GameState) -> None:
    before = dumps(game)
    state, _ = end_turn(game)
    assert dumps(game) == before
    assert state.turn == 1
    assert state.year == game.year + 10
    assert [s.turn for s in state.civs["veyra"].history] == [0, 1]


def test_same_seed_and_actions_give_the_same_game(content: Content) -> None:
    first = play(new_game(content, "bronze_dawn", seed=11), turns=12)
    second = play(new_game(content, "bronze_dawn", seed=11), turns=12)
    other = play(new_game(content, "bronze_dawn", seed=12), turns=12)
    assert dumps(first) == dumps(second)
    assert dumps(first) != dumps(other)


def test_replay_rebuilds_the_game_exactly(content: Content) -> None:
    initial = new_game(content, "bronze_dawn", seed=5)
    final = play(initial, turns=10)
    rebuilt = replay(initial, final.action_log, until_turn=final.turn)
    assert dumps(rebuilt) == dumps(final)


def test_saving_mid_game_does_not_change_the_future(content: Content) -> None:
    midway = play(new_game(content, "bronze_dawn", seed=3), turns=5)
    straight = midway
    reloaded = loads(dumps(midway))
    for _ in range(5):
        straight, _ = end_turn(straight)
        reloaded, _ = end_turn(reloaded)
    assert dumps(reloaded) == dumps(straight)
