"""Tests for feasibility, goals, stubs, adoption and spread."""

from __future__ import annotations

from anachronism.content.schema import Access, Category, Stage
from anachronism.engine.effects import civ_effects
from anachronism.engine.events import EventLog
from anachronism.engine.state import GameState
from anachronism.engine.tech import add_stub, adopt, feasibility, propose, spread_step

from .conftest import Give


def test_materials_block_iron_working_for_veyra_but_not_kessrin(game: GameState) -> None:
    veyra = feasibility(game, "veyra", "iron_working")
    assert veyra.missing_materials == ("iron",)
    assert veyra.missing_prerequisites == ()
    assert veyra.blocked
    assert not feasibility(game, "kessrin", "iron_working").blocked


def test_literacy_is_a_soft_requirement(game: GameState) -> None:
    game.civs["veyra"].stats.literacy_bp = 100
    result = feasibility(game, "veyra", "schools")
    assert result.literacy_shortfall_bp == 200
    assert not result.blocked


def test_widespread_infrastructure_is_required(game: GameState) -> None:
    result = feasibility(game, "veyra", "aqueduct")
    assert result.missing_widespread == ("masonry",)
    assert result.blocked


def test_proposing_marks_missing_prerequisites_as_free_goals(game: GameState) -> None:
    before = game.civs["veyra"].stockpiles.model_copy()
    result = propose(game, "veyra", "iron_plough")
    civ = game.civs["veyra"]
    assert result.missing_prerequisites == ("iron_working",)
    assert civ.tech["iron_plough"].stage is Stage.CONCEPT
    assert civ.tech["iron_working"].stage is Stage.CONCEPT
    assert civ.tech["iron_working"].goal
    assert civ.stockpiles == before


def test_proposing_something_known_keeps_its_stage(game: GameState) -> None:
    propose(game, "veyra", "writing")
    assert game.civs["veyra"].tech["writing"].stage is Stage.ADOPTED


def test_stubs_are_blocked_until_ruled_on(game: GameState) -> None:
    stub = add_stub(game, "steam_power", "Steam power", Category.CRAFT)
    assert stub.stub
    assert feasibility(game, "veyra", "steam_power").blocked
    assert add_stub(game, "steam_power", "Another name", Category.CRAFT) is stub


def test_ore_prospecting_reveals_iron_in_owned_provinces_only(game: GameState) -> None:
    events = EventLog(turn=1, year=game.year)
    adopt(game, game.civs["veyra"], "ore_prospecting", events)
    assert game.provinces["veyra_upper_river"].resources["iron"] is Access.ACCESSIBLE
    assert game.provinces["ushkai_high_pasture"].resources["iron"] is Access.UNEXPLORED
    assert not feasibility(game, "veyra", "iron_working").blocked
    assert [e.kind for e in events.items] == ["adopted", "discovery"]


def test_adoption_starts_spread_and_opposition_raises_unrest(game: GameState) -> None:
    civ = game.civs["veyra"]
    before = civ.stats.unrest_bp
    adopt(game, civ, "alphabet", EventLog(turn=1, year=game.year))
    assert civ.tech["alphabet"].stage is Stage.ADOPTED
    assert civ.tech["alphabet"].spread_bp == 2_000
    # Clergy influence 45% x resistance level 1 x 300 bp.
    assert civ.stats.unrest_bp == before + 135


def test_spread_turns_adopted_into_widespread(game: GameState, give: Give) -> None:
    civ = game.civs["veyra"]
    civ.tech.clear()
    give(game, "veyra", "writing", Stage.ADOPTED, spread=7_500)
    events = EventLog(turn=1, year=game.year)
    spread_step(game, civ, civ_effects(game, "veyra"), events)
    # 10% base + 40% x 3% literacy = 11.2% per decade.
    assert civ.tech["writing"].spread_bp == 8_620
    assert civ.tech["writing"].stage is Stage.WIDESPREAD
    assert [e.kind for e in events.items] == ["widespread"]
