"""Provinces and governors (R3, F1), and the colonies of Rome."""

# ruff: noqa: PT018

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.content.schema import RelationStatus
from anachronism.content.schema.italy import ColonyKind
from anachronism.engine import allies, colonies, provinces_rome
from anachronism.engine.events import EventLog
from anachronism.engine.game import end_turn, new_game
from anachronism.engine.rivals import grievance, set_status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState
from anachronism.tools.italy_view import italy_view
from tests.engine.test_allies import log, run, set_italy_rules

SEEDS = (1, 2, 3)


@pytest.fixture
def rome133(content: Content) -> GameState:
    return new_game(content, "rome_133", seed=1)


# ---------------------------------------------------------------- provinces


def test_provinces_rome_holds_at_the_start_have_governors(rome133: GameState) -> None:
    provinciae = allies.italy_of(rome133).provinciae
    assert {"sicilia", "sardinia_corsica", "hispania_citerior", "macedonia", "africa"} <= set(
        provinciae
    )
    assert "gallia_cisalpina" not in provinciae, "its own year (81) has not come"
    assert "syria" not in provinciae, "Rome holds none of it"
    governors = [p.governor for p in provinciae.values() if p.governor]
    assert governors and len(governors) == len(set(governors)), "one province each"
    assert rome133.republic is not None
    praetors = {m.person for m in rome133.republic.magistrates if m.office == "praetor"}
    assert praetors & set(governors), "the year's praetors take the provinces first"


def test_a_conquered_overseas_land_becomes_a_province_from_227(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    assert not allies.italy_of(state).provinciae
    state.provinces["si_lilybaeum"].owner = "rome"
    provinces_rome.run_year(state, GameRng(state.rng), log(state), -240)
    assert "sicilia" not in allies.italy_of(state).provinciae, "not before 227 (Per. 20.7)"
    events = log(state)
    provinces_rome.run_year(state, GameRng(state.rng), events, -227)
    sicily = allies.italy_of(state).provinciae["sicilia"]
    assert sicily.since == -227 and any(e.kind == "provincia" for e in events.items)
    state.provinces["si_lilybaeum"].owner = "carthage"
    provinces_rome.run_year(state, GameRng(state.rng), events, -226)
    assert "sicilia" not in allies.italy_of(state).provinciae


def test_governors_change_yearly_with_the_magistrates(rome133: GameState) -> None:
    state = rome133
    assert state.republic is not None
    before = {p: v.governor for p, v in allies.italy_of(state).provinciae.items()}
    state, _ = end_turn(state)  # ten years: ten colleges of praetors
    after = allies.italy_of(state).provinciae
    assert any(after[p].governor != before[p] for p in before if p in after)
    for provincia in after.values():
        assert provincia.governor_since >= state.year - state.world.years_per_turn + 1
        if provincia.governor:
            assert provincia.office in ("praetor", "propraetor")


def test_tribute_reaches_the_treasury(rome133: GameState) -> None:
    state = rome133
    set_italy_rules(state, extortion_chance_bp=0, revolt_chance_bp=0, triumph_hunger_bp=0)
    wealth = state.civs["rome"].stockpiles.wealth
    provinces_rome.run_year(state, GameRng(state.rng), log(state), -132)
    provinciae = allies.italy_of(state).provinciae
    paid = sum(p.tribute for p in provinciae.values())
    per_1000 = state.world.italy_rules.tribute_per_1000
    assert paid == sum(provinces_rome.people_of(state, p) // 1000 * per_1000 for p in provinciae)
    assert paid > 0 and state.civs["rome"].stockpiles.wealth == wealth + paid


def test_an_extorting_governor_enriches_his_family_and_may_be_prosecuted(
    rome133: GameState,
) -> None:
    state = rome133
    assert state.republic is not None
    set_italy_rules(
        state,
        extortion_chance_bp=10_000,
        prosecution_chance_bp=10_000,
        conviction_bp=10_000,
        revolt_chance_bp=0,
        triumph_hunger_bp=0,
    )
    rules = state.world.italy_rules
    sicily = allies.italy_of(state).provinciae["sicilia"]
    governor = state.republic.people[sicily.governor]
    family = state.republic.families[governor.gens]
    family_wealth, loyalty = family.wealth, sicily.loyalty_bp
    events = log(state)
    provinces_rome.run_year(state, GameRng(state.rng), events, -133)  # he stays this year
    assert sicily.extorted > 0 and sicily.extorted_total == sicily.extorted
    assert family.wealth == family_wealth + sicily.extorted // rules.wealth_per_talent
    assert sicily.loyalty_bp < loyalty
    assert any(e.kind == "extortion" and e.subject == governor.name for e in events.items)
    # a new year, new praetors: he lays down his province and is tried (149: Cic. Brut. 106)
    state, _ = end_turn(state)
    its = allies.italy_of(state)
    assert its.prosecutions, "every extorting governor was tried"
    first = its.prosecutions[0]
    assert first.convicted and first.amount > 0 and first.year >= -132
    assert any(e.kind == "repetundae" for e in state.events)
    view = italy_view(state)
    assert view is not None and view["citizenship"]["prosecutions"]


def test_no_prosecution_before_the_lex_calpurnia(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    state.provinces["si_lilybaeum"].owner = "rome"
    set_italy_rules(state, extortion_chance_bp=10_000, prosecution_chance_bp=10_000)
    rng = GameRng(state.rng)
    provinces_rome.run_year(state, rng, log(state), -227)
    sicily = allies.italy_of(state).provinciae["sicilia"]
    sicily.governor = "nobody-else"  # force a change of governor next year
    provinces_rome.run_year(state, rng, log(state), -226)
    assert not allies.italy_of(state).prosecutions


def test_a_disaffected_province_may_revolt(rome133: GameState) -> None:
    state = rome133
    set_italy_rules(state, extortion_chance_bp=0, revolt_chance_bp=10_000, triumph_hunger_bp=0)
    sicily = allies.italy_of(state).provinciae["sicilia"]
    sicily.loyalty_bp = 0
    events = log(state)
    provinces_rome.run_year(state, GameRng(state.rng), events, -132)
    assert sicily.revolts == 1
    lost = [e for e in events.items if e.kind == "province_revolt"]
    assert lost and any(
        state.provinces[p].owner is None for p in state.world.provinciae["sicilia"].provinces
    )
    assert sicily.loyalty_bp == state.world.italy_rules.province_baseline_loyalty_bp


def test_a_governor_hungry_for_a_triumph_provokes_a_neighbour(rome133: GameState) -> None:
    state = rome133
    set_italy_rules(state, extortion_chance_bp=0, revolt_chance_bp=0, triumph_hunger_bp=10_000)
    provoked = {
        pid: provinces_rome._neighbours(state, pid)
        for pid in allies.italy_of(state).provinciae
        if provinces_rome._neighbours(state, pid)
    }
    if not provoked:
        pytest.skip("no neighbour to provoke in this start")
    before = {c: grievance(state, c, "rome") for cs in provoked.values() for c in cs}
    events = log(state)
    provinces_rome.run_year(state, GameRng(state.rng), events, -132)
    hungry = [e for e in events.items if e.kind == "triumph_hunger"]
    assert hungry and all(grievance(state, e.subject, "rome") > before[e.subject] for e in hungry)


# ---------------------------------------------------------------- colonies


def test_colonies_standing_at_the_start(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    standing = allies.italy_of(state).colonies
    assert {"col_cales", "col_ariminum", "col_luceria", "col_beneventum"} <= set(standing)
    assert "col_placentia" not in standing, "218 BC has not come"
    assert all(c.historical and c.year <= -264 for c in standing.values())
    assert standing["col_cales"].settlers == 2500, "Livy 8.16.14"


def test_default_history_founds_the_colonies_in_their_years(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    rome_before = state.population("rome")
    state = run(state, 5)  # 264 -> 214: Placentia and Cremona in 218
    its = allies.italy_of(state)
    assert "col_placentia" in its.colonies or "col_placentia" in its.lapsed
    if "col_placentia" in its.colonies:
        placentia = its.colonies["col_placentia"]
        assert placentia.year == -218 and placentia.kind is ColonyKind.LATIN
        assert placentia.settlers >= 6000
        assert state.provinces["it_boii"].owner in ("rome", "e2_boii")
    assert any(e.kind == "colony" for e in state.events)
    assert state.population("rome") > 0 and rome_before > 0


def test_a_colony_needs_land_in_roman_or_allied_hands(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    events = log(state)
    assert colonies.found(
        state, "x_carthage", "X", "car_carthage", ColonyKind.CITIZEN, -264, 300, events,
        historical=False,
    ) is None, "Carthage holds it"
    # unowned land becomes Roman when a colony is planted there
    assert state.provinces["it_taurini"].owner is None
    colony = colonies.found(
        state, "x_taurini", "X", "it_taurini", ColonyKind.LATIN, -264, None, events,
        historical=False,
    )
    assert colony is not None and colony.settlers == state.world.italy_rules.latin_settlers
    assert state.provinces["it_taurini"].owner == "rome"
    assert state.provinces["it_taurini"].garrison_bp == 10_000
    assert colony.garrison == colony.settlers * state.world.italy_rules.colony_garrison_bp // 10_000
    # in an ally's land the colony stands, and the ally without a land share resents it
    samnites = allies.italy_of(state).treaties["e2_samnites"]
    loyalty = samnites.loyalty_bp
    assert colonies.found(
        state, "x_samnium", "X", "it_samnium", ColonyKind.LATIN, -264, None, events,
        historical=True,
    )
    assert state.provinces["it_samnium"].owner == "e2_samnites"
    assert samnites.loyalty_bp == loyalty - state.world.italy_rules.colony_in_ally_land_bp
    assert sum(1 for e in events.items if e.kind == "colony") == 2


def test_the_senates_resolution_founds_a_real_colony(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    assert state.republic is not None
    state.republic.colonies["it_picenum"] = -264
    pop = state.provinces["it_picenum"].population
    roman = state.population("rome")
    events = log(state)
    colonies.run_year(state, GameRng(state.rng), events, -264)
    colony = allies.italy_of(state).colonies["senate_it_picenum"]
    assert colony.kind is ColonyKind.LATIN and not colony.historical
    assert state.provinces["it_picenum"].population > pop
    assert state.population("rome") == roman, "settlers move within Roman land"
    state.republic.colonies["it_latium"] = -150
    colonies.run_year(state, GameRng(state.rng), events, -150)
    assert allies.italy_of(state).colonies["senate_it_latium"].kind is ColonyKind.CITIZEN


def test_history_lapses_where_the_senate_was_first(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    assert state.republic is not None
    state.republic.colonies["it_boii"] = -230
    colonies.run_year(state, GameRng(state.rng), log(state), -230)
    assert state.provinces["it_boii"].owner == "e2_boii", "the Boii keep their land"
    assert "senate_it_boii" not in allies.italy_of(state).colonies, "the land was not Rome's"
    state.provinces["it_boii"].owner = "rome"
    colonies.run_year(state, GameRng(state.rng), log(state), -229)
    assert "senate_it_boii" in allies.italy_of(state).colonies
    colonies.run_year(state, GameRng(state.rng), log(state), -218)
    assert allies.italy_of(state).lapsed.get("col_placentia") == -218


def test_a_colony_in_enemy_hands_is_lost(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    ariminum = allies.italy_of(state).colonies["col_ariminum"]
    state.provinces[ariminum.province].owner = "e2_boii"
    set_status(state, "rome", "e2_boii", RelationStatus.WAR)
    events = log(state)
    colonies.run_year(state, GameRng(state.rng), events, -263)
    assert "col_ariminum" not in allies.italy_of(state).colonies
    assert any(e.kind == "colony_lost" for e in events.items)


def test_disaffected_colonies_refuse_their_levy(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    for colony in allies.italy_of(state).colonies.values():
        colony.loyalty_bp = 0
    events = EventLog(turn=state.turn, year=state.year)
    set_status(state, "rome", "carthage", RelationStatus.WAR)
    colonies.run_year(state, GameRng(state.rng), events, state.year)
    assert any(e.kind == "colony_refuses" for e in events.items), "Livy 27.9.7"
    assert all(c.refusals == 1 for c in allies.italy_of(state).colonies.values())


@pytest.mark.parametrize("seed", SEEDS)
def test_the_late_republic_runs_to_augustus(content: Content, seed: int) -> None:
    state = new_game(content, "rome_133", seed=seed)
    start_year = state.year
    from tests.engine.test_simulation import check_invariants

    for _ in range(10):
        state, _ = end_turn(state)
        check_invariants(state, start_year)
        its = allies.italy_of(state)
        for provincia in its.provinciae.values():
            assert 0 <= provincia.loyalty_bp <= 10_000 and provincia.tribute >= 0
            assert provincia.extorted_total >= provincia.extorted >= 0
            assert provincia.id in state.world.provinciae
        if state.republic is not None and state.republic.families:
            assert all(f.wealth >= 0 for f in state.republic.families.values())
    assert state.year == -33
    view = italy_view(state)
    assert view is not None and view["provinces"]
