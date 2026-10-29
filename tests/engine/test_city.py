"""The city of Rome (U7): what stands in which year, the turn's events, saves, determinism."""

# ruff: noqa: PT018

from __future__ import annotations

import dataclasses

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import Issue, Stage
from anachronism.engine.city import status_at, status_map
from anachronism.engine.events import EventLog
from anachronism.engine.game import end_turn, new_game
from anachronism.engine.republic import kill_person, senate_vote
from anachronism.engine.republic import run_year as republic_run_year
from anachronism.engine.rng import GameRng
from anachronism.engine.save import dumps, loads
from anachronism.engine.state import GameState, TechState
from anachronism.tools.view import build_view

START_YEARS = (("rome_509", -509), ("rome_313", -313), ("rome_264", -264))


@pytest.fixture(scope="module")
def content() -> Content:
    """The real packs plus Republic scenarios starting in different years."""
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
        for sid, year in START_YEARS
    }
    return dataclasses.replace(base, scenarios={**base.scenarios, **scenarios})


def state_in(state: GameState, year: int, monument: str) -> str:
    return status_map(state.world, year)[monument].state


def run(state: GameState, turns: int) -> GameState:
    for _ in range(turns):
        state, _ = end_turn(state)
    return state


def test_no_city_outside_the_republic(content: Content) -> None:
    state = new_game(content, "punic_wars", seed=1)
    assert state.city is None
    assert build_view(state)["city"] is None


def test_the_dataset_is_in_the_content(content: Content) -> None:
    assert len(content.monuments) >= 160
    assert content.monuments["aqua_appia"].built_year == -312


def test_capitoline_temple_stands_burns_and_is_rebuilt(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1)
    assert state.city is not None
    assert state.city.standing["aedes_iovis_capitolini"].state == "standing"
    jove = "aedes_iovis_capitolini"
    assert state_in(state, -84, jove) == "standing"
    for year in (-83, -78, -70):
        assert state_in(state, year, jove) == "burnt"
    assert status_map(state.world, -75)[jove].years_left == 6
    assert state_in(state, -69, jove) == "standing"


def test_monuments_appear_in_their_year(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1)
    assert state_in(state, -313, "aqua_appia") == "planned"
    assert state_in(state, -312, "aqua_appia") == "standing"
    assert state_in(state, -56, "theatrum_pompei") == "planned"
    assert state_in(state, -55, "theatrum_pompei") == "standing"
    # begun before it is dedicated: building, with the years left
    veiovis = status_map(state.world, -193)["aedes_veiovis"]
    assert (veiovis.state, veiovis.years_left) == ("building", 1)
    assert state_in(state, -192, "aedes_veiovis") == "standing"
    # Caesar began the Curia Iulia in 44; it was dedicated in 29
    assert state_in(state, -40, "curia_iulia") == "building"
    assert state_in(state, -29, "curia_iulia") == "standing"
    # a monument with no known date has always stood
    assert state_in(state, -509, "curia_hostilia") == "standing"
    assert state_in(state, -45, "curia_hostilia") == "ruined"


def test_status_helper_without_marks() -> None:
    assert status_at([], 0, built_known=False).state == "standing"
    assert status_at([], 0, built_known=True).state == "planned"


def test_a_dedication_is_a_sacrifice_and_the_yearly_step_notices(content: Content) -> None:
    state = new_game(content, "rome_313", seed=1)
    state, _ = end_turn(state)  # into -312
    assert state.city is not None
    assert "aqua_appia" in state.city.changed
    assert state.city.standing["aqua_appia"].state == "standing"
    sacrifices = [e for e in state.city.events if e.kind == "sacrifice"]
    assert ("dedication", "aqua_appia") in [(e.ref, e.monument) for e in sacrifices]
    view = build_view(state)["city"]
    assert "aqua_appia" in view["changed"]
    assert {"id": "aqua_appia", "status": "standing", "years_left": 0} in view["monuments"]
    state, _ = end_turn(state)
    assert state.city is not None
    assert state.city.changed == []
    assert not [e for e in state.city.events if e.ref == "dedication"]


def test_the_ludi_romani_are_held_every_year(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    for _ in range(8):
        assert state.city is not None
        games = [e for e in state.city.events if e.kind == "games" and e.ref == "ludi_romani"]
        assert len(games) == 1
        assert games[0].year == state.year and games[0].monument == "circus_maximus"
        state, _ = end_turn(state)


def test_the_ludi_plebeii_begin_in_216(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    state.year = -217
    state.city.year = -217  # type: ignore[union-attr]
    state, _ = end_turn(state)
    assert state.city is not None
    refs = {e.ref: e.monument for e in state.city.events if e.ref != "munus"}
    assert refs == {"ludi_romani": "circus_maximus", "ludi_plebeii": "circus_flaminius"}


def test_a_senate_vote_is_a_senate_event(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    assert state.city is not None
    senate_vote(state, Issue.WAR)  # looking is not voting
    assert not [e for e in state.city.events if e.kind == "senate"]
    vote = senate_vote(state, Issue.WAR, record=True)
    (event,) = [e for e in state.city.events if e.kind == "senate"]
    assert (event.ref, event.value, event.other) == ("war", vote.yes_bp, vote.no_bp)
    assert event.monument == "curia_hostilia"


def test_a_dead_consular_gets_funeral_games(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    rep = state.republic
    assert rep is not None
    consul = next(m.person for m in rep.magistrates if m.office == "consul")
    assert kill_person(state, consul)
    state, _ = end_turn(state)
    assert state.city is not None
    munus = [e for e in state.city.events if e.ref == "munus"]
    assert (consul, "forum_boarium") in [(e.person, e.monument) for e in munus]
    state, _ = end_turn(state)
    assert state.city is not None
    assert not [e for e in state.city.events if e.ref == "munus" and e.person == consul]
    assert consul in state.city.funerals


def test_a_project_that_builds_leaves_an_anachronism(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1)
    state.civs["rome"].tech["concrete"] = TechState(stage=Stage.ADOPTED, adopted_year=state.year)
    state, _ = end_turn(state)
    assert state.city is not None
    (work,) = state.city.anachronisms
    assert (work.builds, work.tech, work.year) == ("dome", "concrete", -509)
    assert work.ahead == 309
    view = build_view(state)["city"]
    assert view["anachronisms"][0]["name"] == "Hydraulic concrete"
    assert any(e["monument"] == work.id for e in view["events"])
    state, _ = end_turn(state)
    assert state.city is not None
    assert len(state.city.anachronisms) == 1


def test_a_taken_capital_earns_a_triumph(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    events = EventLog(turn=state.turn, year=state.year + 1)
    events.add("rome", "spoils", "taken", "Carthage", spoils={"capital": True, "wealth": 900})
    events.add("rome", "battle_won", "won", "Zama", sides={"decisive": "1"})
    events.add("rome", "battle_won", "won", "Elsewhere", sides={"winner": "a"})
    events.add("carthage", "spoils", "taken", "Rome", spoils={"capital": True, "wealth": 5})
    state.year += 1
    republic_run_year(state, GameRng(state.rng), events, state.year)
    assert state.city is not None
    triumphs = [e for e in state.city.events if e.kind == "triumph"]
    assert [(t.ref, t.value) for t in triumphs] == [("capital", 900), ("battle", 0)]
    assert triumphs[0].person and triumphs[0].person in state.republic.people  # type: ignore[union-attr]


@pytest.mark.parametrize("seed", [1, 2])
def test_the_city_saves_and_replays_identically(content: Content, seed: int) -> None:
    first = run(new_game(content, "rome_313", seed=seed), 6)
    text = dumps(first)
    assert dumps(loads(text)) == text
    assert loads(text).city == first.city
    again = run(new_game(content, "rome_313", seed=seed), 6)
    assert dumps(again) == text


def test_monument_schema_keeps_fields_the_client_adds() -> None:
    from anachronism.content.schema import Monument

    m = Monument.model_validate(
        {"id": "x", "built": {"year": -5, "model": "temple_tuscan"}, "model": "tuscan", "scale": 2}
    )
    assert m.built_year == -5
    assert m.model_dump()["scale"] == 2


def test_view_has_top_level_year_and_dataset_ids(content: Content) -> None:
    import yaml

    state = new_game(content, "rome_264", seed=1)
    view = build_view(state)
    assert view["year"] == -264
    path = "data/rome/city/monuments.yaml"
    with open(path, encoding="utf-8") as f:
        ids = {m["id"] for m in yaml.safe_load(f)["monuments"]}
    shown = {m["id"] for m in view["city"]["monuments"]}
    assert shown
    assert shown <= ids
