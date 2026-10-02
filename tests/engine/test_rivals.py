"""Rivals: news and awareness, scripts and their dependencies, war, diplomacy, victory."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.content.schema import Preconditions, RelationStatus, Script, ScriptGoal
from anachronism.engine.actions import DeclareWar, MakePeace, Priority, ProposeAlliance, SendEnvoy
from anachronism.engine.economy import project_costs
from anachronism.engine.events import EventLog
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.reports import capacity
from anachronism.engine.rivals import (
    contact_pairs,
    deliver_news,
    hops,
    key,
    relation,
    rival_decrees,
    run_scripts,
    spread_news,
    start_project,
    status,
    strength,
)
from anachronism.engine.rng import GameRng
from anachronism.engine.state import Awareness, Event, GameState
from anachronism.engine.victory import check_outcome, progress
from anachronism.engine.war import capture


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
    from anachronism.engine.armies import raise_army

    state = apply_action(warring, DeclareWar(civ="chu", target="yue"))[0]
    assert status(state, "chu", "yue") is RelationStatus.WAR
    state.civs["chu"].martial_bp = 60_000  # a great host
    raise_army(state, "chu", state.civs["chu"].capital, 400_000, free=True)
    start = len(state.owned_provinces("yue"))
    for _ in range(15):
        state, _ = end_turn(state)
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
    _, logged = apply_action(state, SendEnvoy(civ="qin", target="wei"))
    assert not logged.ok  # one embassy a turn
    state, logged = apply_action(state, ProposeAlliance(civ="qin", target="han"))
    assert not logged.ok  # trade a while first
    state.turn += state.world.rules.rivals.alliance_trust_turns
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


def test_economic_victory_needs_allies_and_a_great_economy(warring: GameState) -> None:
    from anachronism.engine.rivals import set_status

    events = EventLog(turn=0, year=warring.year)
    others = [c for c in sorted(warring.civs) if c != "qin"]
    for other in others:
        set_status(warring, "qin", other, RelationStatus.TRADING)
    trading = progress(warring)["economic"]
    for other in others:
        set_status(warring, "qin", other, RelationStatus.ALLIED)
    allied = progress(warring)["economic"]
    assert allied["share_bp"] > trading["share_bp"]  # trading partners count only in part
    assert allied["partners"] == len(others)
    assert allied["income"] > 0
    check_outcome(warring, events)
    if allied["richest"]:
        assert warring.outcome is not None
        assert warring.outcome.path == "economic"
    else:
        assert warring.outcome is None


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


def test_the_player_is_asked_not_dragged_into_wars(warring: GameState) -> None:
    warring.relations[key("han", "qin")].status = RelationStatus.ALLIED
    state, _ = apply_action(warring, DeclareWar(civ="wei", target="han"))
    assert status(state, "qin", "wei") is not RelationStatus.WAR
    assert any(e.kind == "ally_attacked" and e.civ == "qin" for e in state.events)


def test_capitals_and_mountains_are_harder_to_take(warring: GameState) -> None:
    from anachronism.engine.war import defence_bp

    capital = warring.civs["chu"].capital
    other = next(p for p in warring.owned_provinces("chu") if p != capital)
    assert defence_bp(warring, "chu", capital) > defence_bp(warring, "chu", other) or (
        warring.world.geography[other].terrain == "mountains"
    )
    rules = warring.world.rules.rivals
    assert defence_bp(warring, "chu", capital) >= rules.capital_defence_bp


def test_a_last_province_holds_out_and_the_player_has_grace(warring: GameState) -> None:
    from anachronism.engine.war import defence_bp

    capital = warring.civs["chu"].capital
    walled = defence_bp(warring, "chu", capital)
    for pid in warring.owned_provinces("chu"):
        if pid != capital:
            warring.provinces[pid].owner = "qin"
    assert defence_bp(warring, "chu", capital) > walled  # the last stand
    # in the opening turns an enemy court does not march on the player
    from anachronism.engine.armies import command

    state, _ = apply_action(warring, DeclareWar(civ="chu", target="qin"))
    command(state, {})
    qin_land = set(state.owned_provinces("qin"))
    assert not any(a.target in qin_land for a in state.armies.values() if a.owner == "chu")


def test_faiths_start_from_the_scenario_and_spread(content: Content) -> None:
    from anachronism.engine.culture import spread_faiths

    state = new_game(content, "three_kingdoms", seed=1)
    assert state.civs["goguryeo"].faith == "buddhism"
    assert state.civs["silla"].faith == "korean_shamanism"
    override = state.world.rules.rivals.model_copy(update={"faith_spread_bp": 10_000})
    state.world = state.world.model_copy(
        update={"rules": state.world.rules.model_copy(update={"rivals": override})}
    )
    events = EventLog(turn=0, year=state.year)
    spread_faiths(state, {}, GameRng(state.rng), events)
    assert any(e.kind == "faith" for e in events.items)


def test_courts_of_world_faiths_hold_to_them(content: Content) -> None:
    from anachronism.engine.culture import spread_faiths

    state = new_game(content, "year_1000", seed=1)
    override = state.world.rules.rivals.model_copy(
        update={"faith_spread_bp": 10_000, "faith_rooted_resistance_bp": 0}
    )
    state.world = state.world.model_copy(
        update={"rules": state.world.rules.model_copy(update={"rivals": override})}
    )
    before = {c: civ.faith for c, civ in state.civs.items()}
    spread_faiths(state, {}, GameRng(state.rng), EventLog(turn=0, year=state.year))
    for civ_id, faith in before.items():
        if faith and state.world.faiths[faith].spreads:
            assert state.civs[civ_id].faith == faith, civ_id  # no world faith gives way
    assert any(state.civs[c].faith != f for c, f in before.items())  # the Norse gods do


def test_the_players_faith_changes_only_by_choice(content: Content) -> None:
    from anachronism.engine.culture import spread_faiths

    state = new_game(content, "kadesh", seed=1)
    override = state.world.rules.rivals.model_copy(update={"faith_spread_bp": 10_000})
    state.world = state.world.model_copy(
        update={"rules": state.world.rules.model_copy(update={"rivals": override})}
    )
    faith = state.civs["egypt"].faith
    for turn in range(5):
        spread_faiths(state, {}, GameRng(state.rng), EventLog(turn=turn, year=state.year))
    assert state.civs["egypt"].faith == faith


def test_rivals_league_against_a_dominant_player(warring: GameState) -> None:
    from anachronism.engine.rivals import coalitions

    events = EventLog(turn=0, year=warring.year)
    coalitions(warring, GameRng(warring.rng), events)
    assert not events.items  # Qin is not yet feared
    for pid in sorted(warring.provinces)[: len(warring.provinces) * 2 // 3]:
        if warring.provinces[pid].owner is not None:
            warring.provinces[pid].owner = "qin"
    override = warring.world.rules.rivals.model_copy(update={"coalition_chance_bp": 10_000})
    warring.world = warring.world.model_copy(
        update={"rules": warring.world.rules.model_copy(update={"rivals": override})}
    )
    coalitions(warring, GameRng(warring.rng), events)
    assert [e.kind for e in events.items] == ["coalition"]


def test_a_far_weaker_court_pays_tribute(warring: GameState) -> None:
    from anachronism.engine.actions import DemandTribute

    _, logged = apply_action(warring, DemandTribute(civ="qin", target="chu"))
    assert not logged.ok  # Chu is no weakling
    small = next(c for c in sorted(warring.civs) if c != "qin" and status(warring, "qin", c))
    warring.civs["qin"].mercenaries = 0
    for pid in warring.owned_provinces(small)[1:]:
        warring.provinces[pid].owner = "qin"  # leave it one province
    if strength(warring, "qin") < strength(warring, small) * 3:
        warring.civs["qin"].martial_bp = 100_000
    state, logged = apply_action(warring, DemandTribute(civ="qin", target=small))
    assert logged.ok
    assert status(state, "qin", small) is RelationStatus.TRIBUTARY


def test_trade_pays_both_sides(warring: GameState) -> None:
    from anachronism.engine.culture import trade

    warring.relations[key("han", "zhao")].status = RelationStatus.TRADING
    before = warring.civs["han"].stockpiles.wealth, warring.civs["zhao"].stockpiles.wealth
    trade(warring)
    assert warring.civs["han"].stockpiles.wealth > before[0]
    assert warring.civs["zhao"].stockpiles.wealth > before[1]


def test_missionaries(content: Content) -> None:
    from anachronism.engine.actions import SendMissionaries

    state = new_game(content, "three_kingdoms", seed=2)
    state, logged = apply_action(state, SendMissionaries(civ="goguryeo", target="silla"))
    assert logged.ok
    assert state.civs["silla"].faith == "buddhism" or "home" in logged.message
    state, logged = apply_action(state, SendMissionaries(civ="goguryeo", target="baekje"))
    assert not logged.ok  # Baekje is already Buddhist
    khan = new_game(content, "great_khan", seed=1)
    _, logged = apply_action(khan, SendMissionaries(civ="mongols", target="jurchen_jin"))
    assert not logged.ok  # Tengri seeks no converts


def test_decrees_spend_the_treasury(warring: GameState) -> None:
    from anachronism.engine.actions import HireMercenaries, HoldFestival

    qin = warring.civs["qin"]
    qin.stockpiles.wealth = 100_000
    qin.stats.unrest_bp = 3000
    state, logged = apply_action(warring, HoldFestival(civ="qin"))
    assert logged.ok
    assert state.civs["qin"].stats.unrest_bp < 3000
    assert state.civs["qin"].stockpiles.wealth < 100_000
    before = strength(state, "qin")
    state, logged = apply_action(state, HireMercenaries(civ="qin"))
    assert logged.ok
    assert strength(state, "qin") > before
    state, logged = apply_action(state, HireMercenaries(civ="qin"))
    assert not logged.ok  # still serving
    poor = warring.model_copy(deep=True)
    poor.civs["qin"].stockpiles.wealth = 0
    _, logged = apply_action(poor, HoldFestival(civ="qin"))
    assert not logged.ok


def test_rival_courts_issue_decrees(warring: GameState) -> None:
    state, _ = apply_action(warring, DeclareWar(civ="wei", target="han"))
    state.civs["wei"].stockpiles.wealth = 100_000
    state.civs["chu"].stockpiles.wealth = 100_000
    state.civs["chu"].stats.unrest_bp = 5000
    state.civs["yan"].stockpiles.wealth = 0
    state.civs["yan"].stats.unrest_bp = 5000
    rival_decrees(state, EventLog(state.turn, state.year))
    assert state.civs["wei"].mercenaries > 0
    assert state.civs["wei"].stockpiles.wealth >= 50_000  # half kept in reserve
    assert state.civs["chu"].stats.unrest_bp < 5000
    assert state.civs["yan"].stats.unrest_bp == 5000  # cannot afford it
    assert state.civs["qin"].mercenaries == 0  # the player decides for themselves


def test_rival_courts_never_start_work_they_cannot_staff(content: Content) -> None:
    # D-112: work beyond the surplus is taken on only as steady (low-priority) work, so no
    # rival starves itself chasing an idea it heard of
    state = new_game(content, "punic_wars", seed=1, player_civ="rome")
    node = "crop_rotation"
    assert project_costs(state, node).labour > capacity(state, "pergamon").free_labour
    assert start_project(state, "pergamon", node)
    assert state.civs["pergamon"].projects[node].priority is Priority.LOW
    assert not start_project(state, "pergamon", "quarantine")  # one steady task at a time
