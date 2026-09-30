"""Rivals: news and awareness, scripts and their dependencies, war, diplomacy, victory."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.content.schema import Preconditions, RelationStatus, Script, ScriptGoal
from anachronism.engine.actions import DeclareWar, MakePeace, ProposeAlliance, SendEnvoy
from anachronism.engine.events import EventLog
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.rivals import (
    contact_pairs,
    deliver_news,
    hops,
    key,
    relation,
    run_scripts,
    spread_news,
    status,
    strength,
)
from anachronism.engine.rng import GameRng
from anachronism.engine.state import Awareness, Event, GameState
from anachronism.engine.victory import check_outcome, progress
from anachronism.engine.war import capture, resolve_wars


@pytest.fixture
def warring(content: Content) -> GameState:
    return new_game(content, "warring_states", seed=1, player_civ="qin")


def only_scripts(state: GameState, civ: str, *scripts: Script) -> None:
    state.world = state.world.model_copy(update={"scripts": {civ: tuple(scripts)}})


def test_relations_start_from_the_scenario_and_geography(warring: GameState) -> None:
    owners = {pid: p.owner for pid, p in warring.provinces.items()}
    for a, b in contact_pairs(warring.world, owners):
        assert key(a, b) in warring.relations
    assert status(warring, "qin", "wei") is RelationStatus.HOSTILE
    assert relation(warring, "wei", "qin").grievance["wei"] > 0  # type: ignore[union-attr]
    assert warring.civs["qin"].disposition == "aggressive"
    assert warring.world.scripts["qin"]


def test_news_travels_with_delay_and_makes_rivals_aware(warring: GameState) -> None:
    node = next(
        n for n in sorted(warring.tech_nodes) if warring.tech_nodes[n].year - warring.year > 1000
    )
    adopted = Event(
        turn=1,
        year=warring.year,
        civ="qin",
        kind="adopted",
        message="",
        subject=warring.tech_nodes[node].name,
    )
    spread_news(warring, [adopted], {}, GameRng(warring.rng))
    assert warring.news
    near = min(warring.news, key=lambda n: n.arrives_turn)
    far = max(warring.news, key=lambda n: n.arrives_turn)
    assert hops(warring, "qin", near.to_civ) <= hops(warring, "qin", far.to_civ)  # type: ignore[operator]
    events = EventLog(turn=0, year=warring.year)
    deliver_news(warring, events)
    assert all(c.awareness is Awareness.ON_SCRIPT for c in warring.civs.values())  # not yet
    warring.turn = far.arrives_turn
    deliver_news(warring, events)
    heard = [c for c in warring.civs.values() if c.heard]
    assert heard
    assert all(
        c.awareness is not Awareness.ON_SCRIPT
        for c in heard
        if any(not h.garbled for h in c.heard) or c.heard
    )
    assert any(e.kind == "news" for e in events.items)


def test_ordinary_adoptions_are_not_news(warring: GameState) -> None:
    old = next(n for n in sorted(warring.tech_nodes) if warring.tech_nodes[n].year < warring.year)
    adopted = Event(
        turn=1,
        year=warring.year,
        civ="qin",
        kind="adopted",
        message="",
        subject=warring.tech_nodes[old].name,
    )
    spread_news(warring, [adopted], {}, GameRng(warring.rng))
    assert not warring.news


def test_scripts_fire_on_their_preconditions(warring: GameState) -> None:
    only_scripts(
        warring,
        "chu",
        Script(id="chu_now", goal=ScriptGoal.CONQUER, target="yue"),
        Script(
            id="chu_later",
            goal=ScriptGoal.CONQUER,
            target="lu",
            preconditions=Preconditions(after_year=-100),
        ),
        Script(id="chu_after", goal=ScriptGoal.ALLY, target="song", depends_on=("chu_later",)),
    )
    events = EventLog(turn=0, year=warring.year)
    strengths = {c: strength(warring, c) for c in warring.civs}
    run_scripts(warring, strengths, events)
    assert "chu_now" in warring.scripts_fired
    assert status(warring, "chu", "yue") is RelationStatus.WAR
    assert "chu_later" not in warring.scripts_fired
    assert "chu_after" not in warring.scripts_fired


def test_lapsed_scripts_pull_down_their_dependents(warring: GameState) -> None:
    only_scripts(
        warring,
        "chu",
        Script(
            id="gone",
            goal=ScriptGoal.CONQUER,
            target="yue",
            preconditions=Preconditions(before_year=-400),
        ),
        Script(id="built_on_it", goal=ScriptGoal.ALLY, target="song", depends_on=("gone",)),
    )
    run_scripts(warring, {}, EventLog(turn=0, year=warring.year))
    assert set(warring.scripts_lapsed) == {"gone", "built_on_it"}


def test_free_agents_leave_their_scripts(warring: GameState) -> None:
    only_scripts(warring, "chu", Script(id="chu_now", goal=ScriptGoal.CONQUER, target="yue"))
    warring.civs["chu"].awareness = Awareness.FREE_AGENT
    run_scripts(warring, {}, EventLog(turn=0, year=warring.year))
    assert not warring.scripts_fired


def test_war_takes_provinces_and_ends_in_peace(warring: GameState) -> None:
    events = EventLog(turn=0, year=warring.year)
    rng = GameRng(warring.rng)
    apply = apply_action(warring, DeclareWar(civ="chu", target="yue"))[0]
    state = apply
    assert status(state, "chu", "yue") is RelationStatus.WAR
    strengths = {"chu": 1_000_000, "yue": 1}
    start = len(state.owned_provinces("yue"))
    for _ in range(8):
        resolve_wars(state, strengths, rng, events)
        if status(state, "chu", "yue") is not RelationStatus.WAR:
            break
    assert len(state.owned_provinces("yue")) < start
    assert status(state, "chu", "yue") is not RelationStatus.WAR  # weariness made peace
    assert relation(state, "chu", "yue").grievance.get("yue", 0) > 0  # type: ignore[union-attr]


def test_losing_a_capital_moves_the_court(warring: GameState) -> None:
    events = EventLog(turn=0, year=warring.year)
    capital = warring.civs["chu"].capital
    capture(warring, "qin", capital, events)
    assert warring.civs["chu"].capital != capital
    assert warring.provinces[warring.civs["chu"].capital].owner == "chu"
    assert warring.civs["chu"].awareness is Awareness.FREE_AGENT


def test_allies_join_defensive_wars(warring: GameState) -> None:
    state, logged = apply_action(warring, DeclareWar(civ="wei", target="han"))
    assert logged.ok
    # Han and Zhao trade but are not allied, so Zhao stays out
    assert status(state, "zhao", "wei") is not RelationStatus.WAR
    state.relations[key("han", "zhao")].status = RelationStatus.ALLIED
    state, _ = apply_action(state, DeclareWar(civ="wei", target="zhao"))
    assert status(state, "han", "wei") is RelationStatus.WAR


def test_player_diplomacy(warring: GameState) -> None:
    state, logged = apply_action(warring, SendEnvoy(civ="qin", target="han"))
    assert logged.ok
    assert state.civs["qin"].stockpiles.wealth < warring.civs["qin"].stockpiles.wealth
    assert status(state, "qin", "han") is RelationStatus.TRADING
    state, logged = apply_action(state, ProposeAlliance(civ="qin", target="han"))
    assert logged.ok
    assert status(state, "qin", "han") is RelationStatus.ALLIED
    state, logged = apply_action(state, DeclareWar(civ="qin", target="shu"))
    assert logged.ok
    assert state.civs["shu"].awareness is Awareness.FREE_AGENT
    state, logged = apply_action(state, MakePeace(civ="qin", target="shu"))
    assert logged.ok or "scorns" in logged.message
    state, logged = apply_action(state, DeclareWar(civ="qin", target="qin"))
    assert not logged.ok


def test_victory_needs_ground_gained(warring: GameState) -> None:
    paths = progress(warring)
    for path, values in paths.items():
        assert (
            values["target_bp"]
            >= warring.victory_start[path] + warring.world.rules.rivals.victory_margin_bp
            or values["target_bp"] == 10_000
        ), path
    events = EventLog(turn=0, year=warring.year)
    check_outcome(warring, events)
    assert warring.outcome is None
    for pid in sorted(warring.provinces):
        if warring.provinces[pid].owner is not None:
            warring.provinces[pid].owner = "qin"
    check_outcome(warring, events)
    assert warring.outcome is not None
    assert warring.outcome.result == "victory"
    assert warring.outcome.path == "military"


def test_losing_everything_is_defeat(warring: GameState) -> None:
    for pid in warring.owned_provinces("qin"):
        warring.provinces[pid].owner = "wei"
    check_outcome(warring, EventLog(turn=0, year=warring.year))
    assert warring.outcome is not None
    assert warring.outcome.result == "defeat"


def test_turns_with_rivals_stay_deterministic(content: Content) -> None:
    a = new_game(content, "year_1000", seed=3)
    b = new_game(content, "year_1000", seed=3)
    for _ in range(4):
        a, _ = end_turn(a)
        b, _ = end_turn(b)
    assert a == b
    assert a.scripts_fired
