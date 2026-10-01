"""Armies, battles, sieges and supply (D-099)."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.content.schema import RelationStatus
from anachronism.engine.actions import ArmyStance, DeclareWar, DisbandArmy, MarchArmy, RaiseArmy
from anachronism.engine.armies import (
    available_units,
    battle,
    raise_army,
    route,
    siege_progress,
    sieges,
    unit_power,
)
from anachronism.engine.events import EventLog
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.rivals import status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import Army, GameState


@pytest.fixture
def warring(content: Content) -> GameState:
    return new_game(content, "warring_states", seed=1, player_civ="qin")


def log(state: GameState) -> EventLog:
    return EventLog(state.turn, state.year)


def test_every_state_starts_with_an_army_at_its_capital(warring: GameState) -> None:
    for civ_id, civ in warring.civs.items():
        mine = [a for a in warring.armies.values() if a.owner == civ_id]
        assert len(mine) == 1
        assert mine[0].province == civ.capital
        assert mine[0].men > 0


def test_soldiers_need_their_advancements_and_resources(warring: GameState) -> None:
    kinds = {u.id for u in available_units(warring, "qin")}
    assert "levy" in kinds
    assert "musketeers" not in kinds  # nobody has muskets in 350 BC
    for pid in warring.owned_provinces("qin"):
        warring.provinces[pid].resources.pop("horses", None)
    assert "cavalry" not in {u.id for u in available_units(warring, "qin")}


def test_raising_takes_men_and_stores(warring: GameState) -> None:
    capital = warring.civs["qin"].capital
    people = warring.provinces[capital].population
    wealth = warring.civs["qin"].stockpiles.wealth
    state, logged = apply_action(warring, RaiseArmy(civ="qin", province=capital, size="small"))
    assert logged.ok
    assert state.provinces[capital].population < people
    assert state.civs["qin"].stockpiles.wealth <= wealth
    # men raised where an army stands join it rather than form a new one
    assert len([a for a in state.armies.values() if a.owner == "qin"]) == 1


def test_armies_may_not_march_into_neutral_land(warring: GameState) -> None:
    from anachronism.engine.rivals import frontier

    army = next(a for a in warring.armies.values() if a.owner == "qin")
    target = frontier(warring, "qin", "wei")[0]
    _, logged = apply_action(warring, MarchArmy(civ="qin", army=army.id, target=target))
    assert not logged.ok
    state, _ = apply_action(warring, DeclareWar(civ="qin", target="wei"))
    assert route(state, "qin", army.province, target)
    state, logged = apply_action(state, MarchArmy(civ="qin", army=army.id, target=target))
    assert logged.ok


def test_spears_stop_horse_and_chariots_founder_in_the_hills(content: Content) -> None:
    units = content.units
    horse = {"mounted": 10_000}
    spear_vs_horse = unit_power(units["spearmen"], 1000, False, horse, "plains")
    sword_vs_horse = unit_power(units["swordsmen"], 1000, False, horse, "plains")
    assert spear_vs_horse > sword_vs_horse
    on_plain = unit_power(units["chariots"], 1000, True, {}, "plains")
    in_hills = unit_power(units["chariots"], 1000, True, {}, "mountains")
    assert in_hills * 2 < on_plain


def test_the_stronger_side_wins_and_the_loser_falls_back(warring: GameState) -> None:
    state, _ = apply_action(warring, DeclareWar(civ="qin", target="wei"))
    field = state.civs["wei"].capital
    behind = state.civs["qin"].capital
    big = Army(
        id="q", owner="qin", name="Big", province=field, came_from=behind, troops={"levy": 50_000}
    )
    small = Army(id="w", owner="wei", name="Small", province=field, troops={"levy": 2_000})
    state.armies = {"q": big, "w": small}
    winner = battle(state, field, [big], [small], GameRng(state.rng), log(state))
    assert winner == "qin"
    assert big.men < 50_000  # nobody wins for free
    assert "w" not in state.armies or state.armies["w"].province != field


def test_a_beaten_attacker_falls_back_the_way_it_came(warring: GameState) -> None:
    state, _ = apply_action(warring, DeclareWar(civ="qin", target="wei"))
    field = state.civs["wei"].capital
    behind = state.civs["qin"].capital
    weak = Army(
        id="q", owner="qin", name="Weak", province=field, came_from=behind, troops={"levy": 1_000}
    )
    strong = Army(id="w", owner="wei", name="Strong", province=field, troops={"spearmen": 60_000})
    state.armies = {"q": weak, "w": strong}
    battle(state, field, [weak], [strong], GameRng(state.rng), log(state))
    if "q" in state.armies:
        assert state.armies["q"].province == behind


def test_a_siege_takes_the_province_in_time(warring: GameState) -> None:
    state, _ = apply_action(warring, DeclareWar(civ="qin", target="wei"))
    target = next(p for p in state.owned_provinces("wei") if p != state.civs["wei"].capital)
    state.armies = {
        "q": Army(
            id="q",
            owner="qin",
            name="Siege",
            province=target,
            troops={"levy": 80_000, "siege_engines": 5_000},
        )
    }
    assert siege_progress(state, state.armies["q"]) > 0
    for _ in range(10):
        sieges(state, log(state))
        if state.provinces[target].owner == "qin":
            break
    assert state.provinces[target].owner == "qin"


def test_disbanding_sends_the_men_home(warring: GameState) -> None:
    army = next(a for a in warring.armies.values() if a.owner == "qin")
    people = warring.provinces[army.province].population
    state, logged = apply_action(warring, DisbandArmy(civ="qin", army=army.id))
    assert logged.ok
    assert state.provinces[army.province].population == people + army.men
    assert army.id not in state.armies


def test_holding_and_defending(warring: GameState) -> None:
    army = next(a for a in warring.armies.values() if a.owner == "qin")
    state, logged = apply_action(warring, ArmyStance(civ="qin", army=army.id, stance="hold"))
    assert logged.ok
    assert state.armies[army.id].stance == "hold"


def test_wars_of_armies_replay_identically(warring: GameState) -> None:
    from anachronism.engine.save import dumps

    state, _ = apply_action(warring, DeclareWar(civ="qin", target="wei"))
    capital = state.civs["qin"].capital
    state, _ = apply_action(
        state, RaiseArmy(civ="qin", province=capital, size="large", style="mounted")
    )
    a, b = state, state.model_copy(deep=True)
    for _ in range(4):
        a, _ = end_turn(a)
        b, _ = end_turn(b)
    assert dumps(a) == dumps(b)
    assert status(a, "qin", "wei") in (RelationStatus.WAR, RelationStatus.HOSTILE)
    for army in a.armies.values():
        assert army.men > 0
        assert army.province in a.provinces


def test_raise_army_respects_the_cap(warring: GameState) -> None:
    capital = warring.civs["qin"].capital
    army, _ = raise_army(warring, "qin", capital, 10**9, free=True)
    assert army is not None
    total = sum(a.men for a in warring.armies.values() if a.owner == "qin")
    from anachronism.engine.armies import mobilisation_cap

    assert total <= mobilisation_cap(warring, "qin") + 1


def test_new_armies_take_the_next_general(content: Content) -> None:
    state = new_game(content, "punic_wars", seed=1)
    carthage = state.civs["carthage"]
    royal = next(a for a in state.armies.values() if a.owner == "carthage")
    assert royal.general == "Hamilcar Barca"
    assert royal.trait == "bold"
    pool = [g.name for g in carthage.generals]
    army, _ = raise_army(
        state,
        "carthage",
        "num_massyli" if state.provinces["num_massyli"].owner == "carthage" else carthage.capital,
        5000,
        free=True,
    )
    if army is not None and army.id != royal.id:
        assert army.general == pool[0]
        state, _ = apply_action(state, DisbandArmy(civ="carthage", army=army.id))
        assert state.civs["carthage"].generals[0].name == pool[0]  # back at court


def test_a_horse_master_makes_cavalry_fight_harder(warring: GameState) -> None:
    from anachronism.engine.armies import side_power

    field = warring.civs["qin"].capital
    plain = Army(id="a", owner="qin", name="A", province=field, troops={"cavalry": 10_000})
    gifted = plain.model_copy(update={"id": "b", "trait": "horse"})
    foe = [Army(id="c", owner="wei", name="C", province=field, troops={"levy": 10_000})]
    assert (
        side_power(warring, [gifted], foe, True, field)[0]
        > side_power(warring, [plain], foe, True, field)[0]
    )


def test_mercenaries_serve_their_contract_then_leave(warring: GameState) -> None:
    from anachronism.engine.actions import HireMercenaries

    warring.civs["qin"].stockpiles.wealth = 100_000
    people = warring.population("qin")
    state, logged = apply_action(warring, HireMercenaries(civ="qin"))
    assert logged.ok
    company = [a for a in state.armies.values() if a.owner == "qin" and a.contract]
    assert len(company) == 1
    assert state.population("qin") == people  # not our own men
    for _ in range(state.world.rules.rivals.mercenary_turns):
        state, _ = end_turn(state)
    assert not [a for a in state.armies.values() if a.owner == "qin" and a.contract]


def test_a_losing_enemy_cedes_the_land_we_hold(warring: GameState) -> None:
    from anachronism.engine.actions import MakePeace
    from anachronism.engine.rivals import frontier, relation

    state, _ = apply_action(warring, DeclareWar(civ="qin", target="wei"))
    held = frontier(state, "qin", "wei")[0]
    state.armies["q"] = Army(id="q", owner="qin", name="Q", province=held, troops={"levy": 5000})
    rel = relation(state, "qin", "wei")
    assert rel is not None
    _, logged = apply_action(state, MakePeace(civ="qin", target="wei", terms="cede"))
    assert not logged.ok  # they have lost nothing yet
    rel.losses["wei"] = 3
    rel.weariness["wei"] = 9000
    state, logged = apply_action(state, MakePeace(civ="qin", target="wei", terms="cede"))
    assert logged.ok
    assert state.provinces[held].owner == "qin"
    assert status(state, "qin", "wei") is not RelationStatus.WAR
