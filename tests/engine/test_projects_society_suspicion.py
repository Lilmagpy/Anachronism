"""Tests for project progress, society (strain, unrest, riots, revolts) and suspicion."""

from __future__ import annotations

from collections.abc import Callable

from anachronism.content.schema import Stage
from anachronism.engine.economy import Allocation, Costs, EconomyOutcome, Labour, Production
from anachronism.engine.effects import civ_effects
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP
from anachronism.engine.projects import project_turns, setback_chance_bp
from anachronism.engine.rng import GameRng
from anachronism.engine.society import update_society
from anachronism.engine.state import Framing, GameState, Project
from anachronism.engine.suspicion import adoption_suspicion_bp, update_suspicion
from anachronism.engine.turn import end_turn

from .conftest import RuleOverride

Start = Callable[..., Project]


def calm_outcome(**changes: int) -> EconomyOutcome:
    values: dict[str, int] = {
        "diverted": 0,
        "production_bp": BP,
        "food_needed": 100,
        "famine_bp": 0,
        "deaths": 0,
        "wealth_shortfall_bp": 0,
    }
    values.update(changes)
    return EconomyOutcome(
        labour=Labour(workforce=100, surplus=20),
        allocation=Allocation(funding={}, requested=Costs(), used=Costs()),
        produced=Production(food=100, materials=10, wealth=10, knowledge=10),
        **values,
    )


# --- projects -----------------------------------------------------------------------------


def test_fully_funded_project_finishes_on_schedule(game: GameState, start: Start) -> None:
    start(game, "veyra", "alphabet")
    assert project_turns(game, "alphabet") == 2
    after_one, _ = end_turn(game)
    assert after_one.civs["veyra"].projects["alphabet"].progress_bp == 5_000
    after_two, events = end_turn(after_one)
    assert "alphabet" not in after_two.civs["veyra"].projects
    assert after_two.civs["veyra"].tech["alphabet"].stage is Stage.ADOPTED
    assert any(e.kind == "adopted" and "Phonetic alphabet" in e.message for e in events)


def test_starved_project_stalls_then_decays(
    game: GameState, start: Start, rules: RuleOverride
) -> None:
    rules(game, projects={"knowledge": (5_000,) * 5})
    start(game, "veyra", "alphabet", progress=5_000)
    state = game
    kinds: list[list[str]] = []
    progress: list[int] = []
    for _ in range(4):
        state, events = end_turn(state)
        kinds.append([e.kind for e in events if e.civ == "veyra"])
        progress.append(state.civs["veyra"].projects["alphabet"].progress_bp)
    assert "stalled" not in kinds[1]
    assert "stalled" in kinds[2]
    assert progress[3] < progress[2]


def test_paused_project_decays_and_costs_nothing(game: GameState, start: Start) -> None:
    start(game, "veyra", "alphabet", progress=5_000).paused = True
    knowledge = game.civs["veyra"].stockpiles.knowledge
    after, _ = end_turn(game)
    assert after.civs["veyra"].projects["alphabet"].progress_bp == 4_500
    assert after.civs["veyra"].stockpiles.knowledge > knowledge


def test_setback_chance_grows_with_literacy_shortfall(game: GameState) -> None:
    # Luck is off in the fixture (base 0); movable type wants 8% literacy, Veyra has 3%.
    assert setback_chance_bp(game, game.civs["veyra"], "movable_type") == 750
    assert setback_chance_bp(game, game.civs["veyra"], "alphabet") == 0


# --- society ------------------------------------------------------------------------------


def test_strain_moves_toward_its_target_and_feeds_unrest(game: GameState) -> None:
    civ = game.civs["veyra"]
    civ.stats.unrest_bp = 0
    outcome = calm_outcome(diverted=80)  # all 80 non-surplus workers diverted
    update_society(
        game, civ, outcome, civ_effects(game, "veyra"), GameRng(game.rng), EventLog(1, 0)
    )
    assert civ.stats.strain_bp == 4_000  # half of the way to the 80% target
    assert civ.stats.unrest_bp > 0


def test_famine_raises_unrest_and_hurts_legitimacy(game: GameState) -> None:
    civ = game.civs["veyra"]
    unrest, legitimacy = civ.stats.unrest_bp, civ.stats.legitimacy_bp
    update_society(
        game,
        civ,
        calm_outcome(famine_bp=5_000),
        civ_effects(game, "veyra"),
        GameRng(game.rng),
        EventLog(1, 0),
    )
    assert civ.stats.unrest_bp > unrest
    assert civ.stats.legitimacy_bp < legitimacy


def test_extreme_unrest_brings_riots_and_revolts(game: GameState, rules: RuleOverride) -> None:
    rules(
        game, society={"riot_chance_per_excess_bp": 100_000, "revolt_chance_per_excess_bp": 100_000}
    )
    civ = game.civs["veyra"]
    civ.stats.unrest_bp = 10_000
    materials = civ.stockpiles.materials
    events = EventLog(1, game.year)
    update_society(game, civ, calm_outcome(), civ_effects(game, "veyra"), GameRng(game.rng), events)
    kinds = [e.kind for e in events.items]
    assert "riot" in kinds
    assert "revolt" in kinds
    assert civ.stockpiles.materials < materials
    assert len(game.owned_provinces("veyra")) == 5
    assert game.provinces[civ.capital].owner == "veyra"


def test_losing_half_the_provinces_to_revolt_is_collapse(game: GameState) -> None:
    civ = game.civs["veyra"]
    for province_id in ("veyra_coast", "veyra_marshes", "veyra_delta"):
        game.provinces[province_id].owner = "kessrin"  # lost in war: not a collapse
    calm = EventLog(1, game.year)
    update_society(game, civ, calm_outcome(), civ_effects(game, "veyra"), GameRng(game.rng), calm)
    assert not civ.collapsed
    civ.revolts = 3  # the same three broke away instead
    events = EventLog(1, game.year)
    update_society(game, civ, calm_outcome(), civ_effects(game, "veyra"), GameRng(game.rng), events)
    assert civ.collapsed
    assert [e.kind for e in events.items] == ["collapse"]


# --- suspicion ----------------------------------------------------------------------------


def test_adoption_suspicion_depends_on_how_early_and_how_visible(game: GameState) -> None:
    # Alphabet: 150 years early x 5 bp, visibility 1 halves it.
    assert adoption_suspicion_bp(game, game.tech_nodes["alphabet"]) == 375
    # Stirrups: 1,500 years early, capped at 15 points.
    assert adoption_suspicion_bp(game, game.tech_nodes["stirrup"]) == 1_500
    # Writing is long established.
    assert adoption_suspicion_bp(game, game.tech_nodes["writing"]) == 0


def test_suspicion_fades_faster_with_legitimacy(game: GameState) -> None:
    civ = game.civs["veyra"]
    civ.stats.suspicion_bp = 1_000
    civ.stats.legitimacy_bp = 6_000
    update_suspicion(game, civ, GameRng(game.rng), EventLog(1, game.year))
    assert civ.stats.suspicion_bp == 1_000 - 80 - 120


def test_high_suspicion_settles_on_a_framing_then_clears(game: GameState) -> None:
    civ = game.civs["veyra"]
    civ.stats.suspicion_bp = 6_000
    events = EventLog(1, game.year)
    update_suspicion(game, civ, GameRng(game.rng), events)
    assert civ.framing is not Framing.NONE
    assert [e.kind for e in events.items] == ["framing"]
    civ.stats.suspicion_bp = 100
    update_suspicion(game, civ, GameRng(game.rng), events)
    assert game.civs["veyra"].framing is Framing.NONE


def test_witchcraft_raises_unrest_and_fraud_lowers_legitimacy(game: GameState) -> None:
    civ = game.civs["veyra"]
    civ.stats.suspicion_bp = 5_000
    civ.stats.unrest_bp = 1_000
    civ.framing = Framing.WITCHCRAFT
    update_suspicion(game, civ, GameRng(game.rng), EventLog(1, game.year))
    assert civ.stats.unrest_bp > 1_000
    civ.framing = Framing.FRAUD
    legitimacy = civ.stats.legitimacy_bp
    update_suspicion(game, civ, GameRng(game.rng), EventLog(1, game.year))
    assert civ.stats.legitimacy_bp < legitimacy
