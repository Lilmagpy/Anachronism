"""Buildings in provinces (D-111)."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.content.schema import Stage
from anachronism.engine import buildings
from anachronism.engine.actions import Build
from anachronism.engine.armies import pillage, raise_army
from anachronism.engine.economy import production
from anachronism.engine.effects import civ_effects
from anachronism.engine.events import EventLog
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.save import dumps, loads
from anachronism.engine.state import Army, GameState, TechState
from anachronism.engine.timeflow import turns_for

LATIUM = "rom_latium"


@pytest.fixture
def punic(content: Content) -> GameState:
    return new_game(content, "punic_wars", seed=1, player_civ="rome")


def log(state: GameState) -> EventLog:
    return EventLog(state.turn, state.year)


def rich(state: GameState, civ: str = "rome") -> GameState:
    state.civs[civ].stockpiles.materials = 100_000
    state.civs[civ].stockpiles.wealth = 100_000
    return state


def finish(state: GameState, province: str, building: str) -> None:
    state.provinces[province].buildings.append(building)


def test_every_building_is_valid_content(content: Content) -> None:
    assert len(content.buildings) >= 15
    for kind in content.buildings.values():
        assert kind.materials + kind.wealth > 0, kind.id
        if kind.replaces is not None:
            assert kind.replaces in content.buildings


def test_building_pays_up_front_and_opens_after_its_time(punic: GameState) -> None:
    rich(punic)
    before = punic.civs["rome"].stockpiles.materials
    materials, _ = buildings.cost(punic, LATIUM, "market")
    punic, logged = apply_action(punic, Build(civ="rome", province=LATIUM, building="market"))
    assert logged.ok, logged.message
    assert punic.civs["rome"].stockpiles.materials == before - materials
    assert punic.provinces[LATIUM].works is not None
    for _ in range(turns_for(punic, 1)):
        punic, events = end_turn(punic)
    assert "market" in punic.provinces[LATIUM].buildings
    assert any(e.kind == "building" and e.civ == "rome" for e in events)


def test_cannot_build_without_stores_techs_coast_or_room(punic: GameState) -> None:
    punic.civs["rome"].stockpiles.materials = 0
    ok, message = buildings.start(punic, "rome", LATIUM, "market")
    assert not ok
    assert "materials" in message
    assert buildings.why_not(punic, "rome", LATIUM, "bank") == "needs Banks and bills of exchange"
    foreign = next(p for p in punic.owned_provinces("carthage"))
    assert buildings.why_not(punic, "rome", foreign, "market") is not None
    inland = next(p for p in sorted(punic.provinces) if not punic.world.geography[p].coastal)
    punic.provinces[inland].owner = "rome"
    assert buildings.why_not(punic, "rome", inland, "harbour") == "needs a coast"
    punic.provinces[LATIUM].population = 10_000
    punic.provinces[LATIUM].buildings = ["temple", "granary"]
    assert buildings.why_not(punic, "rome", LATIUM, "market") == "no room: the city must grow first"


def test_bigger_cities_hold_more_buildings(punic: GameState) -> None:
    rules = punic.world.rules.buildings
    punic.provinces[LATIUM].population = 10_000
    assert buildings.slots(punic, LATIUM) == rules.base_slots
    punic.provinces[LATIUM].population = rules.people_per_slot * 3
    assert buildings.slots(punic, LATIUM) == rules.base_slots + 3
    punic.provinces[LATIUM].population = 10**9
    assert buildings.slots(punic, LATIUM) == rules.max_slots


def test_each_building_makes_the_next_dearer(punic: GameState) -> None:
    first = buildings.cost(punic, LATIUM, "market")
    finish(punic, LATIUM, "temple")
    second = buildings.cost(punic, LATIUM, "market")
    assert second[0] > first[0]
    assert second[1] > first[1]


def test_buildings_raise_their_province_output(punic: GameState) -> None:
    effects = civ_effects(punic, "rome")
    before = production(punic, "rome", effects, 10_000)
    finish(punic, LATIUM, "market")
    finish(punic, LATIUM, "granary")
    after = production(punic, "rome", effects, 10_000)
    assert after.wealth > before.wealth
    assert after.food > before.food
    assert after.materials == before.materials


def test_upgrades_take_the_place_of_the_old_building(punic: GameState) -> None:
    rich(punic)
    punic.civs["rome"].tech["banking"] = TechState(stage=Stage.ADOPTED)
    assert "market" in (buildings.why_not(punic, "rome", LATIUM, "bank") or "")
    finish(punic, LATIUM, "market")
    ok, message = buildings.start(punic, "rome", LATIUM, "bank")
    assert ok, message
    for _ in range(turns_for(punic, 1)):
        buildings.advance_works(punic, log(punic))
    assert "bank" in punic.provinces[LATIUM].buildings
    assert "market" not in punic.provinces[LATIUM].buildings
    assert buildings.why_not(punic, "rome", LATIUM, "market") == "a better one already stands here"


def test_temples_calm_the_realm(punic: GameState) -> None:
    calm = buildings.weighted(punic, "rome", "calm_bp")
    assert calm == 0
    for province in punic.owned_provinces("rome"):
        finish(punic, province, "temple")
    assert buildings.weighted(punic, "rome", "calm_bp") == punic.world.buildings["temple"].calm_bp
    quiet = punic.model_copy(deep=True)
    loud = punic.model_copy(deep=True)
    for province in loud.owned_provinces("rome"):
        loud.provinces[province].buildings = []
    quiet.civs["rome"].stats.unrest_bp = loud.civs["rome"].stats.unrest_bp = 4_000
    quiet, _ = end_turn(quiet)
    loud, _ = end_turn(loud)
    assert quiet.civs["rome"].stats.unrest_bp < loud.civs["rome"].stats.unrest_bp


def test_barracks_train_new_soldiers(punic: GameState) -> None:
    rich(punic)
    punic.civs["rome"].stockpiles.food = 100_000
    finish(punic, LATIUM, "barracks")
    for old in [a for a in punic.armies.values() if a.province == LATIUM]:
        del punic.armies[old.id]
    army, message = raise_army(punic, "rome", LATIUM, 5_000)
    assert army is not None, message
    assert army.veterancy_bp == punic.world.buildings["barracks"].veterans_bp


def test_pillage_burns_the_newest_building(punic: GameState) -> None:
    finish(punic, LATIUM, "temple")
    finish(punic, LATIUM, "market")
    raider = Army(id="x", owner="carthage", name="Raiders", province=LATIUM, troops={})
    events = log(punic)
    pillage(punic, raider, "rome", events)
    assert punic.provinces[LATIUM].buildings == ["temple"]
    assert any("market burned" in e.message for e in events.items)


def test_rival_courts_build_and_saves_keep_buildings(punic: GameState) -> None:
    for _ in range(4):
        punic, _ = end_turn(punic)
    rival_built = [
        b
        for pid, p in punic.provinces.items()
        if p.owner not in (None, "rome")
        for b in p.buildings
    ]
    assert rival_built, "rival courts with full stores should build"
    assert dumps(loads(dumps(punic))) == dumps(punic)
