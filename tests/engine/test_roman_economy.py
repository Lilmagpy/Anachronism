"""Land, slaves, grain, coin and debt (R4, F1)."""

# ruff: noqa: PT018

from __future__ import annotations

import dataclasses

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.engine.events import EventLog
from anachronism.engine.game import end_turn, new_game
from anachronism.engine.rng import GameRng
from anachronism.engine.roman_economy import (
    conquests,
    estates_bp,
    run_year,
    supply_bp,
    tribute_due,
)
from anachronism.engine.rome_society_state import RomeSocietyState
from anachronism.engine.save import dumps
from anachronism.engine.state import GameState

SEEDS = (1, 2, 3)


@pytest.fixture(scope="module")
def content() -> Content:
    base = load_content()
    punic = base.scenarios["punic_wars"]
    scenarios = {
        sid: punic.model_copy(
            update={
                "id": sid,
                "start_year": year,
                "years_per_turn": 1,
                "campaign_years_per_turn": None,
                "republic": True,
            }
        )
        for sid, year in (("rome_495", -495), ("rome_250", -250), ("rome_136", -136))
    }
    return dataclasses.replace(base, scenarios={**base.scenarios, **scenarios})


def society(state: GameState) -> RomeSocietyState:
    assert state.rome_society is not None
    return state.rome_society


def run(state: GameState, turns: int) -> GameState:
    for _ in range(turns):
        state, _ = end_turn(state)
    return state


def test_the_land_starts_from_the_people_and_the_rich_take_it(content: Content) -> None:
    state = new_game(content, "rome_250", seed=1)
    land = society(state).land
    assert land.ager_publicus > 0
    before = estates_bp(state)
    assidui = land.assidui_bp
    state = run(state, 10)
    assert estates_bp(state) > before
    assert society(state).land.assidui_bp < assidui


def test_a_land_law_gives_the_estates_back(content: Content) -> None:
    state = new_game(content, "rome_136", seed=1)
    state = run(state, 2)
    assert state.republic is not None
    land = society(state).land
    estates = land.latifundia
    assidui = land.assidui_bp
    state.republic.laws["land_reform"] = state.year
    state, events = end_turn(state)
    land = society(state).land
    assert land.latifundia < estates
    assert land.assidui_bp > assidui
    assert land.reform_applied == state.year - 1
    assert any(e.kind == "land_reform" and "Licinian" in e.message for e in events)


def test_conquests_bring_land_and_slaves(content: Content) -> None:
    state = new_game(content, "rome_250", seed=1)
    land = society(state).land
    ager, slaves = land.ager_publicus, land.slaves
    pid = state.owned_provinces("rome")[0]
    events = EventLog(turn=1, year=state.year)
    events.add("rome", "conquest", "x", state.world.geography[pid].name)
    events.add("rome", "spoils", "x", "y", spoils={"sacked": 4000})
    conquests(state, events)
    assert land.ager_publicus > ager
    assert land.slaves == slaves + state.provinces[pid].population // 1000 * 25 + 4000


def test_the_dated_slave_wars_rise_when_there_are_slaves(content: Content) -> None:
    state = new_game(content, "rome_136", seed=2)
    society(state).land.slaves = 50_000
    state, events = end_turn(state)  # 135: Eunus
    assert society(state).land.revolts == [-135]
    assert any(e.kind == "slave_revolt" for e in events)


def test_sicily_feeds_the_city_once_held(content: Content) -> None:
    state = new_game(content, "rome_250", seed=1)
    base, held = supply_bp(state, -250)
    assert held == []
    sicily = [p for p in state.provinces if p.startswith("si_") or p in ("syr_syracuse", "messana")]
    for pid in sicily:
        state.provinces[pid].owner = "rome"
    before, _ = supply_bp(state, -242)
    after, held = supply_bp(state, -241)
    assert before == base  # not yet a province
    assert after > base and "sicily" in held


def test_a_shortage_raises_unrest_and_the_dole_steadies_it(content: Content) -> None:
    state = new_game(content, "rome_136", seed=1)
    assert state.republic is not None
    civ = state.civs["rome"]
    civ.stockpiles.wealth = 100_000
    grain = society(state).grain
    assert grain.shortfall_bp > 0  # a city of 300,000 outgrows Latium
    civ.stats.unrest_bp = 5000
    run_year(state, GameRng(state.rng), EventLog(turn=1, year=-135), -135)
    without = civ.stats.unrest_bp
    civ.stats.unrest_bp = 5000
    state.republic.laws["grain_dole"] = -135
    run_year(state, GameRng(state.rng), EventLog(turn=2, year=-134), -134)
    assert civ.stats.unrest_bp < without
    assert society(state).grain.dole_cost > 0
    assert society(state).grain.dole_since == -135


def test_the_denarius_and_tribute_pay_the_treasury(content: Content) -> None:
    state = new_game(content, "rome_250", seed=1)
    coin = society(state).coin
    assert coin.reforms == ["silver_coinage"]
    assert tribute_due(state) == 0
    pid = state.owned_provinces("rome")[0]
    state.provinces[pid].people = "carthage"
    assert tribute_due(state) == state.provinces[pid].population // 1000 * 3
    state.year = -212
    society(state).year = -212
    assert state.city is not None
    state.city.year = -212
    state, events = end_turn(state)
    assert society(state).coin.reforms == ["silver_coinage", "denarius"]
    assert any(e.kind == "coinage" for e in events)


def test_debt_rises_in_war_and_the_first_secession_comes(content: Content) -> None:
    state = new_game(content, "rome_495", seed=1)
    land = society(state).land
    land.debt_bp = 4000
    state, events = end_turn(state)  # 494: the Sacred Mount
    assert society(state).land.secessions == [-494]
    assert any(e.kind == "secession" for e in events)
    state.republic.laws["debt_relief"] = state.year  # type: ignore[union-attr]
    debt = society(state).land.debt_bp
    state, events = end_turn(state)
    assert society(state).land.debt_bp < debt
    assert any(e.kind == "debt_relief" for e in events)


@pytest.mark.parametrize("seed", SEEDS)
def test_the_economy_is_deterministic_and_keeps_the_invariants(content: Content, seed: int) -> None:
    first = run(new_game(content, "rome_136", seed=seed), 8)
    again = run(new_game(content, "rome_136", seed=seed), 8)
    assert dumps(first) == dumps(again)
    land = society(first).land
    assert land.slaves >= 0 and land.latifundia <= land.ager_publicus
    assert 0 <= land.debt_bp <= 10_000 and 0 <= land.assidui_bp <= 10_000
    assert first.civs["rome"].stockpiles.wealth >= 0
