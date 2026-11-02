"""The army's three systems and the census-class levy (R4, F1)."""

# ruff: noqa: PT018

from __future__ import annotations

import dataclasses

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import Stage
from anachronism.engine.armies import raise_army
from anachronism.engine.events import EventLog
from anachronism.engine.game import end_turn, new_game
from anachronism.engine.legions import (
    after_battle,
    assidui,
    era_at,
    threshold_at,
    would_march_on_rome,
)
from anachronism.engine.rome_society_state import RomeSocietyState
from anachronism.engine.save import dumps
from anachronism.engine.state import Army, GameState, TechState

SEEDS = (1, 2, 3)


@pytest.fixture(scope="module")
def content() -> Content:
    base = load_content()
    punic = base.scenarios["punic_wars"]
    early = base.scenarios["rome_509"]  # the phalanx only: the eras come by year
    scenarios = {
        sid: (early if year == -345 else punic).model_copy(
            update={
                "id": sid,
                "start_year": year,
                "years_per_turn": 1,
                "campaign_years_per_turn": None,
                "republic": True,
            }
        )
        for sid, year in (("rome_345", -345), ("rome_110", -110))
    }
    return dataclasses.replace(base, scenarios={**base.scenarios, **scenarios})


def society(state: GameState) -> RomeSocietyState:
    assert state.rome_society is not None
    return state.rome_society


def run(state: GameState, turns: int) -> GameState:
    for _ in range(turns):
        state, _ = end_turn(state)
    return state


def test_the_eras_come_in_their_years(content: Content) -> None:
    state = new_game(content, "rome_345", seed=1)
    legions = society(state).legions
    assert legions.era == "phalanx"
    assert threshold_at(state, -345) is not None
    assert threshold_at(state, -345).asses == 11000  # type: ignore[union-attr]
    state = run(state, 6)  # into 339
    legions = society(state).legions
    assert legions.era == "manipular"
    assert legions.era_since == -340
    assert state.civs["rome"].tech["manipular_legion"].stage.is_adopted


def test_the_marian_reform_can_come_early_as_an_anachronism(content: Content) -> None:
    state = new_game(content, "rome_345", seed=1)
    state.civs["rome"].tech["cohort_legion"] = TechState(stage=Stage.ADOPTED, adopted_year=-345)
    state, events = end_turn(state)
    assert society(state).legions.era == "cohort"
    assert society(state).legions.proletarii
    assert any(e.kind == "army_era" and "before its time" in e.message for e in events)


def test_the_threshold_falls_and_the_proletarii_serve_after_marius(content: Content) -> None:
    state = new_game(content, "rome_110", seed=1)
    legions = society(state).legions
    assert legions.threshold_asses == 1500
    assert not legions.proletarii
    pool = assidui(state, -110)
    state = run(state, 4)  # into 106
    legions = society(state).legions
    assert legions.era == "cohort" and legions.threshold_asses == 0 and legions.proletarii
    assert assidui(state, -106) > pool


def test_the_levy_is_made_up_as_the_eras_legion_and_capped_by_the_pool(content: Content) -> None:
    state = new_game(content, "rome_345", seed=1)
    civ = state.civs["rome"]
    civ.stockpiles.food = civ.stockpiles.materials = civ.stockpiles.wealth = 10_000_000
    army, _ = raise_army(state, "rome", civ.capital, 5000)
    assert army is not None
    assert set(army.troops) <= {"servian_hoplites", "census_skirmishers", "roman_equites"}
    assert "servian_hoplites" in army.troops
    state = run(state, 6)
    civ = state.civs["rome"]
    civ.stockpiles.food = civ.stockpiles.materials = civ.stockpiles.wealth = 10_000_000
    army, _ = raise_army(state, "rome", civ.capital, 5000)
    assert army is not None
    assert {"hastati", "principes", "triarii", "velites"} <= set(army.troops)
    pool = society(state).legions.assidui
    big, _ = raise_army(state, "rome", civ.capital, pool)
    assert big is None or big.men <= pool * 2500 // 10_000


def test_the_latifundia_shrink_the_pool_and_a_land_law_restores_it(content: Content) -> None:
    state = new_game(content, "rome_110", seed=1)
    society(state).land.assidui_bp = 3000
    shrunk = assidui(state, -110)
    society(state).land.assidui_bp = 7000
    assert assidui(state, -110) > shrunk


def test_victories_bind_the_men_to_their_general_after_marius(content: Content) -> None:
    state = new_game(content, "rome_110", seed=1)
    state = run(state, 4)
    capital = state.civs["rome"].capital
    army = Army(
        id="rome-7",
        owner="rome",
        name="x",
        province=capital,
        troops={"levy": 5000},
        general="Gaius Marius",
    )
    events = EventLog(turn=1, year=state.year)
    after_battle(state, [army], [], events)
    loyalty = society(state).legions.loyalty
    assert loyalty["Gaius Marius"] == 600 + 1000
    for _ in range(4):
        after_battle(state, [army], [], events)
    assert would_march_on_rome(state) == ["Gaius Marius"]
    # before the professional era nothing binds
    early = new_game(content, "rome_345", seed=1)
    after_battle(early, [army], [], events)
    assert society(early).legions.loyalty == {}


@pytest.mark.parametrize("seed", SEEDS)
def test_the_legions_are_deterministic(content: Content, seed: int) -> None:
    first = run(new_game(content, "rome_110", seed=seed), 6)
    again = run(new_game(content, "rome_110", seed=seed), 6)
    assert dumps(first) == dumps(again)
    assert era_at(first, first.year) is not None
