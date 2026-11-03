"""The Roman Republic's government (R2): elections, offices, people, the Fasti, the Senate."""

# ruff: noqa: PT018

from __future__ import annotations

import dataclasses

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import Issue, Order
from anachronism.engine.game import end_turn, new_game
from anachronism.engine.republic import (
    back_candidate,
    declare_emergency,
    eligible,
    kill_person,
    persuade,
    senate_mood,
    senate_vote,
)
from anachronism.engine.republic_state import Held
from anachronism.engine.save import dumps, loads
from anachronism.engine.state import GameState
from anachronism.tools.republic_view import republic_view

SEEDS = (1, 2)


@pytest.fixture(scope="module")
def content() -> Content:
    """The real packs, plus two Republic scenarios made from the Punic Wars one."""
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
        for sid, year in (("rome_509", -509), ("rome_264", -264))
    }
    return dataclasses.replace(base, scenarios={**base.scenarios, **scenarios})


def college(state: GameState, office: str) -> list[str]:
    assert state.republic is not None
    return [m.person for m in state.republic.magistrates if m.office == office]


def run(state: GameState, turns: int) -> GameState:
    for _ in range(turns):
        state, _ = end_turn(state)
    return state


def test_old_scenarios_have_no_republic(content: Content) -> None:
    state = new_game(content, "punic_wars", seed=1)
    assert state.republic is None
    assert republic_view(state) is None


def test_two_consuls_each_year_and_the_ruler_reads_as_them(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1)
    for _ in range(12):
        assert len(college(state, "consul")) == 2
        assert state.civs["rome"].ruler.count(" and ") == 1
        state, _ = end_turn(state)


@pytest.mark.parametrize("seed", SEEDS)
def test_elections_are_deterministic(content: Content, seed: int) -> None:
    first = run(new_game(content, "rome_509", seed=seed), 25)
    again = run(new_game(content, "rome_509", seed=seed), 25)
    assert dumps(first) == dumps(again)


def test_different_seeds_elect_different_men(content: Content) -> None:
    runs = {
        tuple(m.name for m in run(new_game(content, "rome_509", seed=s), 20).republic.record)  # type: ignore[union-attr]
        for s in (1, 2, 3, 4)
    }
    assert len(runs) > 1


@pytest.mark.parametrize("seed", SEEDS)
def test_early_consuls_are_patricians_and_tribunes_plebeians(content: Content, seed: int) -> None:
    state = new_game(content, "rome_509", seed=seed)
    for _ in range(60):
        rep = state.republic
        assert rep is not None
        for m in rep.magistrates:
            order = rep.people[m.person].order
            if m.office == "consul":
                assert order is Order.PATRICIAN, (state.year, m.name)
            if m.office == "tribune_plebs":
                assert order is Order.PLEBEIAN
        state, _ = end_turn(state)
    assert any(m.office == "tribune_plebs" for m in state.republic.magistrates)  # type: ignore[union-attr]


def test_eligibility_changes_with_the_laws(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    rep = state.republic
    assert rep is not None
    consul = state.world.magistracies["consul"]
    pleb = next(p for p in rep.people.values() if p.order is Order.PLEBEIAN)
    patrician = next(p for p in rep.people.values() if p.order is Order.PATRICIAN)
    for year, pleb_ok in ((-400, False), (-370, False), (-360, True), (-300, True)):
        era = consul.era_at(year)
        assert era is not None
        for man in (pleb, patrician):
            man.born = year - 45
            man.offices.clear()
        assert eligible(state, patrician, consul, era, year)
        assert eligible(state, pleb, consul, era, year) is pleb_ok


def test_lex_villia_sets_ages_and_gaps(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    rep = state.republic
    assert rep is not None
    consul = state.world.magistracies["consul"]
    man = next(p for p in rep.people.values() if p.order is Order.PATRICIAN)
    man.offices.clear()
    before, after = consul.era_at(-200), consul.era_at(-150)
    assert before is not None and after is not None
    man.born = -200 - 35  # before the law only adulthood and the usual age count
    assert eligible(state, man, consul, before, -200)
    man.born = -150 - 38  # after it a consul must be 42 ...
    man.offices.append(Held(office="praetor", year=-155))
    assert not eligible(state, man, consul, after, -150)
    man.born = -150 - 45  # ... and have been praetor, with two clear years between
    man.offices[0] = Held(office="praetor", year=-152)
    assert not eligible(state, man, consul, after, -150)
    man.offices[0] = Held(office="praetor", year=-153)
    assert eligible(state, man, consul, after, -150)
    man.offices.append(Held(office="consul", year=-155))
    assert not eligible(state, man, consul, after, -150)  # ten years before the same office again


def test_dictator_serves_six_months_with_a_master_of_horse(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    found = None
    for _ in range(40):
        declare_emergency(state, 10_000)
        state, events = end_turn(state)
        rep = state.republic
        assert rep is not None
        if college(state, "dictator"):
            found = state
            break
    assert found is not None and found.republic is not None
    dictator = next(m for m in found.republic.magistrates if m.office == "dictator")
    horse = next(m for m in found.republic.magistrates if m.office == "magister_equitum")
    assert dictator.term_months == 6 and dictator.appointed
    assert horse.master == dictator.person
    assert dictator.person != horse.person
    found, events = end_turn(found)
    after = found.republic
    assert after is not None
    assert all(m.person != dictator.person or m.office != "dictator" for m in after.magistrates)
    assert any(m.person == dictator.person and m.office == "dictator" for m in after.record)
    assert any(e.kind == "term_ended" for e in events)


@pytest.mark.parametrize("seed", SEEDS)
def test_people_age_and_die(content: Content, seed: int) -> None:
    state = run(new_game(content, "rome_509", seed=seed), 120)
    rep = state.republic
    assert rep is not None
    dead = [p for p in rep.people.values() if not p.alive]
    assert dead, "nobody died in 120 years"
    for p in rep.people.values():
        if p.alive:
            assert state.year - p.born < 110
        else:
            assert p.died is not None and p.died >= p.born
    assert all(len(p.name) > 3 for p in rep.people.values())
    # births: some men were born in play
    assert any(p.born > -509 and not p.historical for p in rep.people.values())
    # nobody in office is dead
    assert all(rep.people[m.person].alive for m in rep.magistrates)


def test_chronicle_follows_the_fasti(content: Content) -> None:
    state = new_game(content, "rome_509", seed=3, chronicle=True)
    names = [state.republic.people[p].name for p in college(state, "consul")]  # type: ignore[union-attr]
    assert names[:2] == ["Lucius Iunius Brutus", "Lucius Tarquinius Collatinus"]
    assert "Publius Valerius Publicola" in names  # the suffects follow
    state, _ = end_turn(state)
    rep = state.republic
    assert rep is not None
    assert [rep.people[p].name for p in college(state, "consul")] == [
        "Publius Valerius Publicola",
        "Titus Lucretius Tricipitinus",
    ]
    assert not rep.diverged
    state = run(state, 7)  # 501: consuls, the first dictator and his master of the horse
    rep = state.republic
    assert rep is not None and state.year == -501
    assert [rep.people[p].name for p in college(state, "dictator")] == ["Titus Larcius Flavus"]
    assert [rep.people[p].name for p in college(state, "magister_equitum")] == [
        "Spurius Cassius Vecellinus"
    ]
    assert college(state, "magister_equitum") and rep.magistrates


def test_chronicle_264_has_the_historical_consuls(content: Content) -> None:
    state = new_game(content, "rome_264", seed=5, chronicle=True)
    names = [state.republic.people[p].name for p in college(state, "consul")]  # type: ignore[union-attr]
    assert names == ["Appius Claudius Caudex", "Marcus Fulvius Flaccus"]
    state = run(state, 4)
    names = [state.republic.people[p].name for p in college(state, "consul")]  # type: ignore[union-attr]
    assert names == ["Gnaeus Cornelius Scipio Asina", "Gaius Duilius"]
    # 259 has no Fasti entry in the sample: the year is elected freely
    state = run(state, 1)
    assert len(college(state, "consul")) == 2


def test_changes_to_history_replace_the_historical_consul(content: Content) -> None:
    state = new_game(content, "rome_264", seed=5, chronicle=True)
    assert kill_person(state, "c_duilius")
    state = run(state, 3)  # 261
    rep = state.republic
    assert rep is not None and rep.diverged
    state, _ = end_turn(state)  # 260: Duilius cannot serve
    rep = state.republic
    assert rep is not None
    names = [rep.people[p].name for p in college(state, "consul")]
    assert len(names) == 2 and "Gaius Duilius" not in names
    assert "Gnaeus Cornelius Scipio Asina" in names


def test_backing_a_man_displaces_a_historical_consul(content: Content) -> None:
    state = new_game(content, "rome_264", seed=5, chronicle=True)
    rep = state.republic
    assert rep is not None
    # a consul of 263 (not in the Fasti) is won for 262 by the player
    state = run(state, 1)
    rep = state.republic
    assert rep is not None
    man = next(p for p in rep.people.values() if p.order is Order.PATRICIAN and p.alive)
    man_id, man_name = man.id, man.name
    man.born = -262 - 50
    man.offices.clear()
    rep.influence = 10_000
    ok, message = back_candidate(state, man_id, "consul", -262)
    assert ok, message
    state = run(state, 1)
    assert man_id in college(state, "consul")
    names = [state.republic.people[p].name for p in college(state, "consul")]  # type: ignore[union-attr]
    assert man_name in names
    assert state.republic.diverged  # type: ignore[union-attr]


def test_save_and_load_are_byte_identical(content: Content) -> None:
    state = run(new_game(content, "rome_509", seed=9), 30)
    text = dumps(state)
    assert dumps(loads(text)) == text
    # saving mid-game changes nothing about what happens next
    a = run(loads(text), 10)
    b = run(state, 10)
    assert dumps(a) == dumps(b)


def test_senate_votes_and_persuasion(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1)
    before = senate_vote(state, Issue.LAND)
    assert 0 <= before.yes_bp + before.no_bp <= 10_000
    rep = state.republic
    assert rep is not None
    rep.influence = 100_000
    for fid in sorted(rep.families):
        for _ in range(4):
            assert persuade(state, fid, Issue.LAND)[0]
    after = senate_vote(state, Issue.LAND)
    assert after.passes and after.yes_bp >= before.yes_bp
    assert persuade(state, "nosuch", Issue.LAND)[0] is False
    rep.influence = 0
    assert persuade(state, "iunii", Issue.LAND)[0] is False
    mood = senate_mood(state)
    assert [f.id for f in mood] == ["patricians", "plebeians"]
    assert sum(f.weight_bp for f in mood) <= 10_000


def test_the_view_shows_the_republic(content: Content) -> None:
    state = run(new_game(content, "rome_264", seed=2, chronicle=True), 2)
    view = republic_view(state)
    assert view is not None
    assert view["year_label"] == "262 BC"
    consuls = [m for m in view["magistrates"] if m["office"] == "consul"]
    assert [m["name"] for m in consuls] == ["Lucius Postumius Megellus", "Quintus Mamilius Vitulus"]
    assert {f["id"] for f in view["senate"]["factions"]} == {"nobiles"} or view["senate"][
        "factions"
    ]
    assert view["notable"] and view["families"]


def test_invariants_over_many_years(content: Content) -> None:
    for seed in SEEDS:
        state = new_game(content, "rome_264", seed=seed)
        for _ in range(60):
            state, _ = end_turn(state)
            rep = state.republic
            assert rep is not None
            assert rep.influence >= 0
            for f in rep.families.values():
                assert f.dignitas_bp >= 0 and f.auctoritas_bp >= 0 and f.wealth >= 0
            for p in rep.people.values():
                assert p.gens in state.world.gentes
            ids = [m.person for m in rep.magistrates if m.office == "consul"]
            assert len(ids) == len(set(ids)) == 2
