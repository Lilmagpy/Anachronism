"""The socii and the Latins (R3, F1): treaties, levies, loyalty, the ladder, the Social War."""

# ruff: noqa: PT018

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.content.schema import RelationStatus
from anachronism.content.schema.italy import AllyStatus
from anachronism.engine import allies, italy
from anachronism.engine.armies import raise_army
from anachronism.engine.events import EventLog
from anachronism.engine.game import end_turn, new_game
from anachronism.engine.rivals import declare_war, status
from anachronism.engine.rng import GameRng
from anachronism.engine.save import dumps, loads
from anachronism.engine.state import GameState
from anachronism.engine.war import make_peace
from anachronism.tools.italy_view import italy_view
from tests.engine.test_simulation import check_invariants

SEEDS = (1, 2, 3)


def set_italy_rules(state: GameState, **update: object) -> None:
    """Change the frozen alliance rules of a game (a test fixture)."""
    rules = state.world.italy_rules.model_copy(update=update)
    state.world = state.world.model_copy(update={"italy_rules": rules})


def log(state: GameState) -> EventLog:
    return EventLog(turn=state.turn, year=state.year)


def run(state: GameState, turns: int) -> GameState:
    for _ in range(turns):
        state, _ = end_turn(state)
    return state


@pytest.fixture
def rome264(content: Content) -> GameState:
    return new_game(content, "rome_264", seed=1)


# ---------------------------------------------------------------- treaties


def test_starting_alliances_get_their_treaties(rome264: GameState) -> None:
    treaties = allies.italy_of(rome264).treaties
    assert {"e2_samnites", "e2_etruscans", "e2_southern_italics", "massalia"} <= set(treaties)
    samnites = treaties["e2_samnites"]
    assert samnites.levy_bp == 1100, "Polybius 2.24.10: the Samnite obligation from content"
    assert samnites.status is AllyStatus.ALLY and samnites.italian
    assert not treaties["massalia"].italian, "Massalia is outside Italy"
    assert all(t.since == -264 for t in treaties.values())


def test_a_new_alliance_gets_default_terms_and_a_broken_one_loses_them(
    rome264: GameState,
) -> None:
    state = rome264
    from anachronism.engine.rivals import set_status

    set_status(state, "rome", "e2_boii", RelationStatus.ALLIED)
    allies.sync_treaties(state, -260)
    boii = allies.italy_of(state).treaties["e2_boii"]
    assert boii.levy_bp == 800 and boii.since == -260, "no content entry: the default terms"
    set_status(state, "rome", "e2_boii", RelationStatus.NEUTRAL)
    allies.sync_treaties(state, -259)
    assert "e2_boii" not in allies.italy_of(state).treaties
    declare_war(state, "e2_samnites", "rome", log(state))
    allies.sync_treaties(state, -259)
    assert allies.italy_of(state).treaties["e2_samnites"].revolted


# ---------------------------------------------------------------- levies


@pytest.mark.parametrize("seed", SEEDS)
def test_allied_contingents_join_roman_armies_at_war_and_go_home_at_peace(
    content: Content, seed: int
) -> None:
    state = new_game(content, "rome_264", seed=seed)
    army, _ = raise_army(state, "rome", "it_roma", 20_000, free=True)
    assert army is not None
    citizens = army.men
    events = log(state)
    declare_war(state, "carthage", "rome", events)
    before = {c: state.population(c) for c in allies.italy_of(state).treaties}
    allies.run_year(state, GameRng(state.rng), events, state.year)
    ratio = state.world.italy_rules.allied_ratio_bp
    serving = allies.allied_men(state, army.id)
    assert serving > 0 and army.men == citizens + serving
    assert serving <= citizens * ratio // 10_000
    assert any(e.kind == "levy" for e in events.items)
    treaties = allies.italy_of(state).treaties
    assert sum(t.serving for t in treaties.values()) == serving
    for civ_id, treaty in treaties.items():
        assert state.population(civ_id) == before[civ_id] - treaty.serving, civ_id
        assert treaty.serving <= state.population(civ_id) * treaty.levy_bp // 10_000 + 1
    # peace: everyone goes home and the population returns
    make_peace(state, "carthage", "rome", events)
    allies.run_year(state, GameRng(state.rng), events, state.year)
    assert army.men == citizens and allies.allied_men(state, army.id) == 0
    assert all(t.serving == 0 for t in treaties.values())
    assert all(state.population(c) == before[c] for c in treaties)


def test_a_disloyal_ally_sends_no_men(rome264: GameState) -> None:
    state = rome264
    raise_army(state, "rome", "it_roma", 20_000, free=True)
    for treaty in allies.italy_of(state).treaties.values():
        treaty.loyalty_bp = 1000
    events = log(state)
    declare_war(state, "carthage", "rome", events)
    allies.levies_year(state, events)
    assert all(t.serving == 0 for t in allies.italy_of(state).treaties.values())


# ---------------------------------------------------------------- loyalty


def test_victories_raise_and_defeats_lower_loyalty(rome264: GameState) -> None:
    state = rome264
    rules = state.world.italy_rules
    treaties = allies.italy_of(state).treaties
    start = {c: t.loyalty_bp for c, t in treaties.items()}
    events = log(state)
    events.add("rome", "battle_won", "a victory")
    allies.loyalty_year(state, events, state.year)
    for civ_id, treaty in treaties.items():
        gain = rules.victory_bp * (2 if treaty.booty_share else 1)
        drift = (rules.baseline_loyalty_bp - start[civ_id]) * rules.loyalty_drift_bp // 10_000
        assert treaty.loyalty_bp == start[civ_id] + gain + drift, civ_id
    events = log(state)
    events.add("rome", "battle_lost", "a defeat")
    now = {c: t.loyalty_bp for c, t in treaties.items()}
    allies.loyalty_year(state, events, state.year)
    assert all(treaties[c].loyalty_bp < now[c] for c in treaties)


def test_refused_citizenship_and_confiscations_wear_loyalty(rome264: GameState) -> None:
    state = rome264
    rules = state.world.italy_rules
    treaties = allies.italy_of(state).treaties
    samnites = treaties["e2_samnites"]
    samnites.loyalty_bp = rules.baseline_loyalty_bp  # no drift
    allies.loyalty_year(state, log(state), -120)  # the law is open from 125 and not passed
    assert samnites.loyalty_bp == rules.baseline_loyalty_bp - rules.refused_citizenship_bp
    assert state.republic is not None
    state.republic.laws["land_reform"] = -133
    samnites.loyalty_bp = rules.baseline_loyalty_bp
    allies.loyalty_year(state, log(state), -130)
    expect = rules.baseline_loyalty_bp - rules.refused_citizenship_bp - rules.confiscation_bp
    assert samnites.loyalty_bp == expect
    assert treaties["massalia"].loyalty_bp >= 0


# ---------------------------------------------------------------- the ladder of rights


def test_the_ladder_changes_levies_census_and_land(rome264: GameState) -> None:
    state = rome264
    share = state.world.republic_rules.census_citizen_share_bp
    treaties = allies.italy_of(state).treaties
    events = log(state)
    assert allies.grant_status(state, "e2_umbrians", AllyStatus.LATIN, -250, events)
    assert treaties["e2_umbrians"].levy_bp == allies.LATIN_LEVY_BP
    assert not allies.grant_status(state, "e2_umbrians", AllyStatus.ALLY, -250), "never down"
    men = state.population("e2_umbrians") * share // 10_000
    assert allies.grant_status(state, "e2_umbrians", AllyStatus.SINE_SUFFRAGIO, -240, events)
    assert treaties["e2_umbrians"].citizens == men
    assert italy.extra_citizens(state) == men
    assert allies.italy_of(state).citizens_added == men
    pop_before = state.population("rome")
    land = state.owned_provinces("e2_umbrians")
    assert allies.grant_status(state, "e2_umbrians", AllyStatus.CITIZEN, -230, events)
    assert all(state.provinces[p].owner == "rome" for p in land)
    assert all(state.provinces[p].people == "rome" for p in land)
    assert not state.owned_provinces("e2_umbrians") and state.civs["e2_umbrians"].collapsed
    assert state.population("rome") > pop_before
    assert italy.extra_citizens(state) == 0, "their men are counted as Rome's own now"
    assert [e.kind for e in events.items].count("citizenship") == 3


def test_the_census_counts_the_new_citizens(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    allies.grant_status(state, "e2_umbrians", AllyStatus.SINE_SUFFRAGIO, -264)
    extra = italy.extra_citizens(state)
    assert extra > 0
    for _ in range(3):  # a 10-year turn: censors every five years
        state, _ = end_turn(state)
        assert state.republic is not None
        if state.republic.census:
            break
    assert state.republic is not None and state.republic.census
    share = state.world.republic_rules.census_citizen_share_bp
    record = state.republic.census[-1]
    assert record.citizens > state.population("rome") * share // 10_000
    assert italy_view(state)["citizenship"]["extra_citizens"] == extra


def test_the_citizenship_law_absorbs_the_italian_allies(rome264: GameState) -> None:
    state = rome264
    assert state.republic is not None
    state.republic.laws["grant_citizenship"] = -200
    italians = [c for c, t in allies.italy_of(state).treaties.items() if t.italian]
    assert italians
    events = log(state)
    allies.run_year(state, GameRng(state.rng), events, -200)
    treaties = allies.italy_of(state).treaties
    assert all(treaties[c].status is AllyStatus.CITIZEN for c in italians)
    assert all(not state.owned_provinces(c) for c in italians)
    assert treaties["massalia"].status is AllyStatus.ALLY, "Massalia is not Italian"
    assert allies.italy_of(state).citizenship_year == -200


def test_default_history_gives_caere_the_citizenship_without_the_vote(content: Content) -> None:
    state = new_game(content, "rome_390", seed=1)
    treaties = allies.italy_of(state).treaties
    assert treaties["e5_caere"].status is AllyStatus.ALLY
    assert treaties["e5_latins"].status is AllyStatus.LATIN
    state = run(state, 8)  # five-year turns: 390 -> 350
    assert state.year == -350
    treaties = allies.italy_of(state).treaties
    if "e5_caere" in treaties and not treaties["e5_caere"].revolted:
        assert treaties["e5_caere"].status is AllyStatus.SINE_SUFFRAGIO, "Livy 7.20, 353 BC"
        assert treaties["e5_caere"].since == -353


# ---------------------------------------------------------------- the Social War


@pytest.mark.parametrize("seed", SEEDS)
def test_the_social_war_and_the_lex_iulia_follow_refused_citizenship(
    content: Content, seed: int
) -> None:
    state = new_game(content, "rome_133", seed=seed)
    socii = allies.italy_of(state).treaties["e1_socii"]
    assert socii.italian and socii.status is AllyStatus.ALLY
    state = run(state, 5)  # 133 -> 83
    its = allies.italy_of(state)
    assert state.republic is not None
    assert its.social_war_year == -91, "Appian BC 1.38-39: the allies rise in 91"
    assert state.republic.laws["grant_citizenship"] == -90, "the Lex Iulia of 90"
    assert its.citizenship_year == -90
    assert any(e.kind == "social_war" for e in state.events)
    state = run(state, 4)  # the risen lay down their arms for the citizenship
    socii = allies.italy_of(state).treaties["e1_socii"]
    assert socii.status is AllyStatus.CITIZEN and not socii.revolted
    assert not state.owned_provinces("e1_socii")
    assert status(state, "rome", "e1_socii") is not RelationStatus.WAR


def test_loyal_allies_do_not_rise(content: Content) -> None:
    state = new_game(content, "rome_133", seed=1)
    assert state.republic is not None
    state.republic.laws["grant_citizenship"] = -125  # the player gave it in time
    state = run(state, 5)
    assert allies.italy_of(state).social_war_year is None
    assert allies.italy_of(state).treaties["e1_socii"].status is AllyStatus.CITIZEN


def test_the_social_war_needs_a_bloc(rome264: GameState) -> None:
    state = rome264
    state.year = -91
    treaties = allies.italy_of(state).treaties
    for t in treaties.values():
        t.loyalty_bp = 9000
    treaties["e2_samnites"].loyalty_bp = 1000  # one grievance is not a war of all Italy
    allies.social_war(state, log(state), -91)
    assert allies.italy_of(state).social_war_year is None
    for t in treaties.values():
        if t.italian:
            t.loyalty_bp = 1000
    events = log(state)
    allies.social_war(state, events, -91)
    assert allies.italy_of(state).social_war_year == -91
    for civ_id, t in treaties.items():
        if t.italian:
            assert t.revolted and status(state, "rome", civ_id) is RelationStatus.WAR, civ_id
        else:
            assert not t.revolted, civ_id
    assert state.republic is not None and state.republic.extra_emergency_bp > 0


# ---------------------------------------------------------------- the whole system


@pytest.mark.parametrize("seed", SEEDS)
def test_republic_games_keep_the_invariants_and_save_byte_identical(
    content: Content, seed: int
) -> None:
    state = new_game(content, "rome_264", seed=seed)
    start_year = state.year
    twin = new_game(content, "rome_264", seed=seed)
    for _ in range(4):
        state, _ = end_turn(state)
        twin, _ = end_turn(twin)
        check_invariants(state, start_year)
        its = allies.italy_of(state)
        for army_id, by_civ in its.levies.items():
            assert army_id in state.armies
            assert sum(by_civ.values()) <= state.armies[army_id].men
        for civ_id, treaty in its.treaties.items():
            assert 0 <= treaty.loyalty_bp <= 10_000 and treaty.serving >= 0, civ_id
        for colony in its.colonies.values():
            assert colony.province in state.provinces and colony.settlers > 0
    assert dumps(state) == dumps(twin), "the same seed gives the same world"
    assert dumps(loads(dumps(state))) == dumps(state)
    view = italy_view(state)
    assert view is not None and view["allies"] and view["colonies"]
    assert {"allies", "colonies", "provinces", "citizenship", "events"} <= set(view)
