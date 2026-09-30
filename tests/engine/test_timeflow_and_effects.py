"""Tests for eras, turn-length scaling and combining effects."""

from __future__ import annotations

from anachronism.content.schema import Category, Effect, EffectType, Stage, TechNode
from anachronism.engine.effects import civ_effects
from anachronism.engine.state import GameState
from anachronism.engine.timeflow import era_at, per_turn, rate_per_turn, turns_for

from .conftest import Give


def make_node(node_id: str, *effects: tuple[EffectType, int]) -> TechNode:
    return TechNode(
        id=node_id,
        name=node_id.title(),
        category=Category.CRAFT,
        year=-2000,
        complexity=1,
        effects=tuple(Effect(type=kind, bp=bp) for kind, bp in effects),
    )


def test_era_boundaries(game: GameState) -> None:
    eras = game.world.eras
    assert era_at(eras, -501).id == "ancient"
    assert era_at(eras, -500).id == "classical"
    assert era_at(eras, 499).id == "classical"
    assert era_at(eras, 500).id == "medieval"
    assert era_at(eras, 1400).id == "early_modern"
    assert era_at(eras, 3000).id == "early_modern"


def test_flows_scale_with_turn_length(game: GameState) -> None:
    assert per_turn(game, 100) == 100
    game.world = game.world.model_copy(update={"years_per_turn": 20})
    assert per_turn(game, 100) == 200
    assert rate_per_turn(game, 6_000) == 10_000
    assert turns_for(game, 3) == 2
    game.world = game.world.model_copy(update={"years_per_turn": 5})
    assert per_turn(game, 100) == 50
    assert turns_for(game, 3) == 6
    assert turns_for(game, 0) == 1


def test_effects_scale_with_spread_and_ignore_unadopted(game: GameState, give: Give) -> None:
    game.tech_nodes["a"] = make_node("a", (EffectType.FOOD_OUTPUT, 800))
    game.tech_nodes["b"] = make_node("b", (EffectType.FOOD_OUTPUT, 800))
    game.civs["veyra"].tech.clear()
    give(game, "veyra", "a", Stage.ADOPTED, spread=5_000)
    give(game, "veyra", "b", Stage.CONCEPT)
    assert civ_effects(game, "veyra")[EffectType.FOOD_OUTPUT] == 400


def test_effects_are_capped_by_the_current_era(game: GameState, give: Give) -> None:
    game.tech_nodes["big"] = make_node("big", (EffectType.FOOD_OUTPUT, 5_000))
    game.civs["veyra"].tech.clear()
    give(game, "veyra", "big", Stage.WIDESPREAD, spread=10_000)
    assert civ_effects(game, "veyra")[EffectType.FOOD_OUTPUT] == 1_000
    game.year = 1_000
    assert civ_effects(game, "veyra")[EffectType.FOOD_OUTPUT] == 1_500


def test_same_type_effects_stack_with_diminishing_returns(game: GameState, give: Give) -> None:
    game.civs["veyra"].tech.clear()
    for node_id in ("a", "b", "c"):
        game.tech_nodes[node_id] = make_node(node_id, (EffectType.FOOD_OUTPUT, 1_000))
        give(game, "veyra", node_id, Stage.WIDESPREAD, spread=10_000)
    assert civ_effects(game, "veyra")[EffectType.FOOD_OUTPUT] == 1_000 + 800 + 640


def test_negative_effects_count_and_unlocks_are_not_numbers(game: GameState, give: Give) -> None:
    game.civs["veyra"].tech.clear()
    game.tech_nodes["calm"] = make_node("calm", (EffectType.UNREST, -100))
    game.tech_nodes["unlock"] = TechNode(
        id="unlock",
        name="Unlock",
        category=Category.CRAFT,
        year=-2000,
        complexity=1,
        effects=(Effect(type=EffectType.UNLOCKS_BUILDING, target="granary"),),
    )
    give(game, "veyra", "calm", Stage.WIDESPREAD, spread=10_000)
    give(game, "veyra", "unlock", Stage.WIDESPREAD, spread=10_000)
    effects = civ_effects(game, "veyra")
    assert effects[EffectType.UNREST] == -100
    assert EffectType.UNLOCKS_BUILDING not in effects
