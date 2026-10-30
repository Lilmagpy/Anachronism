"""Long headless games: invariants hold for every bot and seed, and the balance claims hold.

Balance claims (DESIGN §5): trying to build everything at once collapses a civilisation;
careful growth stays stable and keeps advancing; doing nothing is stable.
"""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.content.schema import Stage
from anachronism.engine.bots import Bot, make_bot, play_turn
from anachronism.engine.fixed import BP
from anachronism.engine.game import new_game, replay
from anachronism.engine.save import dumps, loads
from anachronism.engine.state import Event, GameState
from tests.engine.conftest import override_rules

SEEDS = (1, 2, 3)


def check_invariants(state: GameState, start_year: int) -> None:
    assert state.year == start_year + state.turn * state.world.years_per_turn
    for province_id, province in state.provinces.items():
        assert province.population >= 0, province_id
        assert province.owner is None or province.owner in state.civs, province_id
    for civ_id, civ in state.civs.items():
        assert min(civ.stockpiles.model_dump().values()) >= 0, civ_id
        assert all(0 <= value <= BP for value in civ.stats.model_dump().values()), civ_id
        if state.owned_provinces(civ_id):
            assert state.provinces[civ.capital].owner == civ_id, "a living civ keeps its capital"
        assert len(civ.history) == state.turn + 1
        for node_id, tech in civ.tech.items():
            assert node_id in state.tech_nodes
            assert 0 <= tech.spread_bp <= BP
            assert (tech.stage is Stage.EXPERIMENTING) == (node_id in civ.projects), node_id
        for project in civ.projects.values():
            assert 0 <= project.progress_bp < BP


def run(
    content: Content, seed: int, bots: dict[str, Bot], turns: int
) -> tuple[GameState, list[Event]]:
    state = new_game(content, "bronze_dawn", seed)
    history: list[Event] = []
    for _ in range(turns):
        state, events = play_turn(state, bots)
        history.extend(events)
    return state, history


@pytest.mark.parametrize("bot", ["idle", "growth", "military", "greedy"])
@pytest.mark.parametrize("seed", SEEDS)
def test_long_games_keep_every_invariant(content: Content, bot: str, seed: int) -> None:
    state = new_game(content, "bronze_dawn", seed)
    start_year = state.year
    bots = {civ_id: make_bot(bot) for civ_id in state.civs}
    for turn in range(100):
        state, _ = play_turn(state, bots)
        check_invariants(state, start_year)
        if turn % 50 == 49:
            assert dumps(loads(dumps(state))) == dumps(state)


@pytest.mark.parametrize("seed", SEEDS)
def test_building_everything_at_once_collapses(content: Content, seed: int) -> None:
    bots = {"veyra": make_bot("greedy"), "ushkai": make_bot("idle"), "kessrin": make_bot("idle")}
    state, events = run(content, seed, bots, turns=30)
    veyra = [e.kind for e in events if e.civ == "veyra"]
    assert max(s.unrest_bp for s in state.civs["veyra"].history) >= 9_000
    assert "riot" in veyra
    assert len(state.owned_provinces("veyra")) < 6


@pytest.mark.parametrize("seed", SEEDS)
def test_careful_growth_is_stable_and_advances(content: Content, seed: int) -> None:
    bots = {"veyra": make_bot("growth"), "ushkai": make_bot("idle"), "kessrin": make_bot("idle")}
    initial = new_game(content, "bronze_dawn", seed)
    state, events = run(content, seed, bots, turns=30)
    veyra = [e.kind for e in events if e.civ == "veyra"]
    assert not {"riot", "revolt", "famine", "collapse"} & set(veyra)
    adopted_now = sum(t.stage.is_adopted for t in state.civs["veyra"].tech.values())
    adopted_then = sum(t.stage.is_adopted for t in initial.civs["veyra"].tech.values())
    assert adopted_now >= adopted_then + 8
    assert state.population("veyra") > initial.population("veyra")


@pytest.mark.parametrize("seed", SEEDS)
def test_doing_nothing_is_stable(content: Content, seed: int) -> None:
    """The economy alone is calm: chance events and deaths of rulers are switched off."""
    bots = {civ_id: make_bot("idle") for civ_id in ("veyra", "ushkai", "kessrin")}
    state = new_game(content, "bronze_dawn", seed)
    override_rules(
        state, society={"happening_frequency_bp": 0, "death_chance_per_year_of_age_bp": 0}
    )
    events = []
    for _ in range(30):
        state, new = play_turn(state, bots)
        events.extend(new)
    assert not {"riot", "revolt", "famine", "collapse"} & {e.kind for e in events}
    assert all(s.unrest_bp < 2_000 for civ in state.civs.values() for s in civ.history)


def test_bot_games_replay_exactly(content: Content) -> None:
    bots = {
        "veyra": make_bot("growth"),
        "ushkai": make_bot("military"),
        "kessrin": make_bot("greedy"),
    }
    initial = new_game(content, "bronze_dawn", seed=9)
    state = initial
    for _ in range(20):
        state, _ = play_turn(state, bots)
    assert dumps(replay(initial, state.action_log, until_turn=state.turn)) == dumps(state)


def test_unknown_bot_name_is_a_clear_error() -> None:
    with pytest.raises(ValueError, match="unknown bot 'wizard'"):
        make_bot("wizard")
