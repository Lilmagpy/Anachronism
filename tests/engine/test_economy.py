"""Tests for costs, workforce, project funding, production and starvation."""

from __future__ import annotations

from collections.abc import Callable

from anachronism.engine.actions import Priority
from anachronism.engine.economy import Costs, allocate, labour, project_costs, run_economy
from anachronism.engine.effects import civ_effects
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import apply_bp
from anachronism.engine.projects import advance_projects, hasten, hasten_cost
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState, Project

from .conftest import RuleOverride

Start = Callable[..., Project]


def test_costs_follow_complexity_category_and_anachronism(game: GameState) -> None:
    # Masonry: construction (heavy materials), complexity 2, already historical: no premium.
    assert project_costs(game, "masonry") == Costs(labour=18, materials=16, knowledge=10, wealth=6)
    # Paper is 1,100 years early: the premium is capped at +50%.
    assert project_costs(game, "paper") == Costs(labour=27, materials=12, knowledge=15, wealth=9)


def test_costs_scale_with_turn_length(game: GameState) -> None:
    game.world = game.world.model_copy(update={"years_per_turn": 20})
    assert project_costs(game, "masonry") == Costs(labour=36, materials=32, knowledge=20, wealth=12)


def test_workforce_surplus_and_unrest_penalty(game: GameState) -> None:
    effects = civ_effects(game, "veyra")
    calm = labour(game, "veyra", effects)
    assert 330 < calm.workforce < 420  # about one labour unit per 1,000 people
    assert calm.surplus == apply_bp(calm.workforce, 2_000)
    game.civs["veyra"].stats.unrest_bp = 10_000
    angry = labour(game, "veyra", effects)
    assert angry.workforce < calm.workforce * 0.6


def test_priority_tiers_are_funded_first_and_scarcest_input_limits(
    game: GameState, start: Start
) -> None:
    game.civs["veyra"].stockpiles.knowledge = 15
    start(game, "veyra", "alphabet").priority = Priority.HIGH  # needs 11 knowledge
    start(game, "veyra", "paper")  # needs 15 knowledge
    allocation = allocate(game, "veyra", workforce=1_000, stock=game.civs["veyra"].stockpiles)
    assert allocation.funding == {"alphabet": 10_000, "paper": 2_667}
    assert allocation.used.knowledge == 11 + 4


def test_diverting_labour_cuts_production(
    game: GameState, start: Start, rules: RuleOverride
) -> None:
    effects = civ_effects(game, "veyra")
    normal = run_economy(game.model_copy(deep=True), "veyra", effects)
    assert normal.production_bp == 10_000
    zero = (0, 0, 0, 0, 0)
    rules(
        game,
        projects={"labour": (1_000,) * 5, "materials": zero, "knowledge": zero, "wealth": zero},
    )
    start(game, "veyra", "alphabet")
    squeezed = run_economy(game, "veyra", effects)
    # Spending rounds down, so a worker or two can stay unassigned.
    assert squeezed.diversion_bp >= 9_900
    assert 3_000 <= squeezed.production_bp <= 3_100
    ratio = apply_bp(normal.produced.food, squeezed.production_bp)
    assert abs(squeezed.produced.food - ratio) <= 1


def test_running_out_of_food_kills_people(
    game: GameState, start: Start, rules: RuleOverride
) -> None:
    zero = (0, 0, 0, 0, 0)
    rules(
        game,
        projects={"labour": (1_000,) * 5, "materials": zero, "knowledge": zero, "wealth": zero},
    )
    start(game, "veyra", "alphabet")
    game.civs["veyra"].stockpiles.food = 0
    before = game.population("veyra")
    outcome = run_economy(game, "veyra", civ_effects(game, "veyra"))
    assert outcome.famine_bp > 0
    assert outcome.deaths > 0
    assert game.population("veyra") == before - outcome.deaths
    assert game.civs["veyra"].stockpiles.food == 0


def test_granary_caps_food_and_stocks_never_go_negative(game: GameState) -> None:
    civ = game.civs["veyra"]
    civ.stockpiles.food = 50_000
    civ.stockpiles.wealth = 0
    run_economy(game, "veyra", civ_effects(game, "veyra"))
    assert civ.stockpiles.food <= 1_000
    assert min(civ.stockpiles.model_dump().values()) >= 0


def test_steady_work_takes_only_spare_hands(
    game: GameState, start: Start, rules: RuleOverride
) -> None:
    # D-112: a low-priority project never pulls farmers off the fields
    zero = (0, 0, 0, 0, 0)
    rules(
        game,
        projects={"labour": (1_000,) * 5, "materials": zero, "knowledge": zero, "wealth": zero},
    )
    start(game, "veyra", "masonry").priority = Priority.LOW
    effects = civ_effects(game, "veyra")
    work = labour(game, "veyra", effects)
    outcome = run_economy(game.model_copy(deep=True), "veyra", effects)
    assert outcome.allocation.used.labour == work.surplus
    assert outcome.production_bp == 10_000
    assert outcome.shortfall_bp == 0  # going slowly strains no one


def test_steady_work_that_moves_does_not_decay(
    game: GameState, start: Start, rules: RuleOverride
) -> None:
    project = start(game, "veyra", "masonry", progress=3_000)
    project.priority = Priority.LOW
    civ = game.civs["veyra"]
    for _ in range(6):
        advance_projects(game, civ, {"masonry": 1_000}, GameRng(game.rng), EventLog(0, 0))
    assert civ.projects["masonry"].stalled_turns == 0
    assert civ.projects["masonry"].progress_bp > 3_000


def test_hastening_buys_a_turns_progress_once_a_turn(game: GameState, start: Start) -> None:
    # D-119: stores that would pile up become progress
    civ = game.civs["veyra"]
    civ.stockpiles.materials = civ.stockpiles.knowledge = civ.stockpiles.wealth = 100_000
    project = start(game, "veyra", "masonry")
    price = hasten_cost(game, "masonry")
    ok, message = hasten(game, civ, "masonry")
    assert ok, message
    assert project.progress_bp > 0
    assert civ.stockpiles.wealth == 100_000 - price.wealth
    ok, _ = hasten(game, civ, "masonry")
    assert not ok  # once a turn


def test_stores_far_beyond_use_waste_away(game: GameState) -> None:
    civ = game.civs["veyra"]
    civ.stockpiles.materials = 10_000_000
    run_economy(game, "veyra", civ_effects(game, "veyra"))
    assert civ.stockpiles.materials < 10_000_000
