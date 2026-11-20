"""Religion and the state (R4, F1): priesthoods, auspices, prodigies, the Books, new cults."""

# ruff: noqa: PT018

from __future__ import annotations

import dataclasses

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.engine.events import EventLog
from anachronism.engine.game import end_turn, new_game
from anachronism.engine.religion import (
    auspice_chance_bp,
    auspices,
    books_open,
    consult_books,
    holders,
    is_augur,
    may_command,
    prodigies_of_year,
)
from anachronism.engine.rng import GameRng
from anachronism.engine.save import dumps
from anachronism.engine.state import Army, GameState

SEEDS = (1, 2, 3)
STARTS = (("rome_509", -509), ("rome_300", -300), ("rome_218", -218), ("rome_84", -84))


@pytest.fixture(scope="module")
def content() -> Content:
    """The real packs plus one-year-a-turn Republic scenarios made from the Punic Wars one."""
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
        for sid, year in STARTS
    }
    return dataclasses.replace(base, scenarios={**base.scenarios, **scenarios})


def run(state: GameState, turns: int) -> GameState:
    for _ in range(turns):
        state, _ = end_turn(state)
    return state


def society(state: GameState):  # type: ignore[no-untyped-def]
    assert state.rome_society is not None
    return state.rome_society


def test_no_society_outside_the_republic(content: Content) -> None:
    state = new_game(content, "punic_wars", seed=1)
    assert state.rome_society is None


def test_the_content_is_loaded_and_sourced(content: Content) -> None:
    society_content = content.rome_society
    assert society_content.present
    assert len(society_content.prodigies) >= 60
    dated = [p for p in society_content.prodigies.values() if p.year is not None]
    assert len(dated) >= 60
    assert all(p.sources for p in society_content.prodigies.values())
    assert {
        "pontifices",
        "augures",
        "decemviri_sacris_faciundis",
        "flamines_maiores",
        "vestales",
    } <= set(society_content.priesthoods)
    assert {"aesculapius", "magna_mater", "venus_erycina", "bacchanalia"} <= set(
        society_content.cults
    )


def test_the_colleges_are_filled_at_the_start_and_kept_full(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1)
    rel = society(state).religion
    colleges = state.world.rome_society.priesthoods
    for cid, college in colleges.items():
        era = college.era_at(state.year)
        assert era is not None
        assert len(holders(rel, cid)) == era.seats, cid
    # patricians only before the Lex Ogulnia; every pontiff is a living man of the Republic
    assert state.republic is not None
    for priest in holders(rel, "pontifices"):
        person = state.republic.people[priest.person]
        assert person.alive and person.order.value == "patrician"
    assert rel.pontifex_maximus in {p.person for p in holders(rel, "pontifices")}
    # the Vestals are daughters, not men
    assert all(p.person == "" and p.gens for p in holders(rel, "vestales"))
    state = run(state, 12)
    rel = society(state).religion
    for cid, college in colleges.items():
        era = college.era_at(state.year)
        assert era is not None
        assert len(holders(rel, cid)) == era.seats, cid
    assert state.republic is not None
    assert all(state.republic.people[p.person].alive for p in rel.priests if p.person)


def test_the_lex_ogulnia_opens_the_colleges_to_plebeians(content: Content) -> None:
    state = new_game(content, "rome_300", seed=2)
    rel = society(state).religion
    assert state.republic is not None
    pontiffs = holders(rel, "pontifices")
    assert len(pontiffs) == 8
    plebeians = [p for p in pontiffs if state.republic.people[p.person].order.value == "plebeian"]
    assert len(plebeians) >= 4
    assert len(holders(rel, "augures")) == 9


def test_a_flamen_may_not_command_and_an_augur_shapes_the_odds(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1)
    rel = society(state).religion
    flamen = holders(rel, "flamines_maiores")[0]
    assert not may_command(state, flamen.person)
    augur = holders(rel, "augures")[0]
    assert is_augur(state, augur.person)
    assert may_command(state, augur.person)
    assert state.republic is not None
    rules = state.world.rome_society.rites.auspices
    plain = Army(
        id="x", owner="rome", name="x", province=state.civs["rome"].capital, troops={"levy": 1000}
    )
    led = plain.model_copy(update={"general": state.republic.people[augur.person].name})
    assert auspice_chance_bp(state, led) == auspice_chance_bp(state, plain) + rules.augur_bp


def test_the_auspices_move_morale_and_are_recorded(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1)
    rules = state.world.rome_society.rites.auspices
    capital = state.civs["rome"].capital
    mine = Army(id="rome-9", owner="rome", name="Legio", province=capital, troops={"levy": 2000})
    foe_civ = next(c for c in sorted(state.civs) if c != "rome")
    theirs = Army(id="foe-9", owner=foe_civ, name="Host", province=capital, troops={"levy": 2000})
    events = EventLog(turn=1, year=state.year)
    rng = GameRng(state.rng)
    out = auspices(state, capital, [theirs], [mine], [8000, 8000], rng, events)
    assert out[0] == 8000  # the enemy takes no Roman auspices
    assert out[1] in (8000 + rules.favourable_morale_bp, 8000 + rules.unfavourable_morale_bp)
    (record,) = society(state).religion.auspices
    assert record.army == "rome-9" and record.morale_bp == out[1] - 8000
    assert [e.kind for e in events.items] == ["auspices"]


def test_dated_prodigies_fire_in_their_year_and_cost_wealth(content: Content) -> None:
    state = new_game(content, "rome_218", seed=1)
    state.civs["rome"].stockpiles.wealth = 10_000
    before = state.civs["rome"].stockpiles.wealth
    state, events = end_turn(state)  # into 217: the spring prodigies and Trasimene's consultation
    rel = society(state).religion
    fired = {r.prodigy for r in rel.prodigies if r.year == -217}
    assert {"p217_spring", "p217_trasimene"} <= fired
    assert all(r.expiated for r in rel.prodigies if r.year == -217)
    assert state.civs["rome"].stockpiles.wealth < before
    kinds = [e.kind for e in events]
    assert kinds.count("prodigy") >= 2
    assert state.city is not None
    assert any(e.kind == "sacrifice" and e.ref == "expiation" for e in state.city.events)
    # the Books were opened for Venus Erycina, whose cult came that year
    assert -217 in rel.consultations
    assert rel.cults.get("venus_erycina") == -217
    assert any(
        e.kind == "sacrifice" and e.ref == "cult" and e.monument == "aedes_veneris_erycinae_capitol"
        for e in state.city.events
    )


def test_an_unpaid_prodigy_breeds_unrest_until_it_is_expiated(content: Content) -> None:
    state = new_game(content, "rome_218", seed=1)
    civ = state.civs["rome"]
    civ.stockpiles.wealth = 0
    events = EventLog(turn=1, year=-217)
    unrest = civ.stats.unrest_bp
    prodigies_of_year(state, GameRng(state.rng), events, -217)
    rel = society(state).religion
    assert rel.unexpiated >= 2
    assert civ.stats.unrest_bp > unrest
    assert not any(r.expiated for r in rel.prodigies if r.year == -217)
    civ.stockpiles.wealth = 10_000
    prodigies_of_year(state, GameRng(state.rng), EventLog(turn=2, year=-216), -216)
    assert rel.unexpiated == 0


def test_the_books_burn_with_the_capitol_and_are_restored(content: Content) -> None:
    state = new_game(content, "rome_84", seed=1)
    assert books_open(state, -84)
    assert not books_open(state, -83)
    assert not books_open(state, -77)
    assert books_open(state, -76)
    state.civs["rome"].stockpiles.wealth = 1000
    assert consult_books(state, EventLog(turn=1, year=-84), -84, "famine")
    assert not consult_books(state, EventLog(turn=2, year=-80), -80, "famine")
    assert society(state).religion.books_lost


def test_cults_come_on_their_dates_and_the_bacchanalia_are_put_down(content: Content) -> None:
    state = new_game(content, "rome_218", seed=3)
    assert "aesculapius" in society(state).religion.cults  # already come by 218
    assert "magna_mater" not in society(state).religion.cults
    state.year = -205
    society(state).year = -205
    assert state.city is not None
    state.city.year = -205
    state.civs["rome"].stockpiles.wealth = 10_000
    state, _ = end_turn(state)  # 204: the Idaean Mother is received (or 205's stones brought her)
    rel = society(state).religion
    assert rel.cults.get("magna_mater") in (-205, -204)
    state.year = -187
    society(state).year = -187
    assert state.city is not None
    state.city.year = -187
    state, events = end_turn(state)
    assert society(state).religion.cults.get("bacchanalia") == -186
    assert any(e.kind == "cult" and "Bacchanalia" in e.message for e in events)


@pytest.mark.parametrize("seed", SEEDS)
def test_religion_is_deterministic_and_saves_round_trip(content: Content, seed: int) -> None:
    first = run(new_game(content, "rome_218", seed=seed), 8)
    again = run(new_game(content, "rome_218", seed=seed), 8)
    assert dumps(first) == dumps(again)
    rel = society(first).religion
    assert rel.prodigies  # 218-210 are Livy's busiest years
    civ = first.civs["rome"]
    assert 0 <= civ.stats.unrest_bp <= 10_000
    assert civ.stockpiles.wealth >= 0


def test_the_real_rome_264_start_runs_with_the_society(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1, chronicle=True)
    assert state.rome_society is not None
    state = run(state, 3)
    rel = society(state).religion
    assert holders(rel, "pontifices")
    assert state.rome_society is not None and state.rome_society.year == state.year


def test_the_society_view_is_json_ready(content: Content) -> None:
    import json

    from anachronism.tools.view import build_view

    state = run(new_game(content, "rome_218", seed=1), 3)
    view = build_view(state)["rome_society"]
    assert view is not None
    json.dumps(view)
    assert {
        "priests",
        "prodigies",
        "land",
        "grain",
        "coinage",
        "debt",
        "army_era",
        "recruitment",
    } <= set(view)
    assert view["army_era"]["id"] == "manipular"
    assert any(p["chief"] for p in view["priests"])
    assert build_view(new_game(content, "punic_wars", seed=1))["rome_society"] is None
