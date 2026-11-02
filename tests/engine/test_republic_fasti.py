"""The Roman state as Rome had it (F1): the full Fasti, the people, names, ages, the Senate."""

# ruff: noqa: PT018

from __future__ import annotations

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import Issue
from anachronism.engine.game import end_turn, new_game
from anachronism.engine.republic import (
    family_leaning,
    family_weight,
    senate_vote,
    senate_weights,
)
from anachronism.engine.republic_state import RepublicState
from anachronism.engine.senate import available, has_met
from anachronism.engine.state import GameState
from anachronism.tools.republic_view import republic_view

STARTS = ("rome_509", "rome_390", "rome_340", "rome_264", "rome_133", "rome_49")
GAP_YEARS = {-375, -374, -373, -372, -371, -333, -324, -309, -301}


@pytest.fixture(scope="module")
def content() -> Content:
    return load_content()


def names(state: GameState, office: str, year: int | None = None) -> list[str]:
    rep = state.republic
    assert rep is not None
    year = state.year if year is None else year
    return sorted(m.name for m in rep.magistrates if m.office == office and m.year == year)


def fasti_names(content: Content, year: int, office: str) -> list[str]:
    entry = next(f for f in content.fasti.values() if f.year == year)
    out = []
    for college in entry.colleges:
        if college.office != office:
            continue
        for h in college.holders:
            out.append(content.people[h.person].name if h.person else h.name)
    return sorted(out)


def run(state: GameState, turns: int) -> GameState:
    for _ in range(turns):
        state, _ = end_turn(state)
    return state


# ---------------------------------------------------------------- the Fasti


def test_the_fasti_cover_every_year(content: Content) -> None:
    years = {f.year: f for f in content.fasti.values()}
    assert set(years) == set(range(-509, -26))
    assert {y for y, f in years.items() if f.gap} == GAP_YEARS
    for year, entry in years.items():
        offices = [c.office for c in entry.colleges]
        if entry.gap:
            assert "consul" not in offices and "consular_tribune" not in offices
        else:
            assert "consul" in offices or "consular_tribune" in offices or year in (-451, -450)
    assert len(content.gentes) >= 160
    assert len(content.people) >= 80


@pytest.mark.parametrize("scenario", STARTS)
def test_each_start_seats_the_fasti_magistrates(content: Content, scenario: str) -> None:
    state = new_game(content, scenario, seed=1, chronicle=True)
    rep = state.republic
    assert rep is not None
    year = state.year
    for office in ("consul", "consular_tribune", "dictator", "censor"):
        assert names(state, office) == fasti_names(content, year, office), (scenario, office)
    assert all(m.by_fasti for m in rep.magistrates if m.office in ("consul", "consular_tribune"))


def test_264_begins_with_caudex_and_flaccus(content: Content) -> None:
    state = new_game(content, "rome_264", seed=3, chronicle=True)
    assert names(state, "consul") == ["Appius Claudius Caudex", "Marcus Fulvius Flaccus"]
    assert names(state, "censor") == []  # the censors of 265 are the Fasti's, not elected
    state = run(state, 3)  # two years a turn in the chronicle
    assert state.year == -258
    assert names(state, "consul") == ["Aulus Atilius Caiatinus", "Gaius Sulpicius Paterculus"]


def test_the_anarchy_seats_no_curule_magistrates(content: Content) -> None:
    state = new_game(content, "rome_390", seed=2, chronicle=True)
    seen = False
    while state.year > -371:
        state, events = end_turn(state)
        if state.year in GAP_YEARS:
            seen = True
            assert names(state, "consul") == [] and names(state, "consular_tribune") == []
            assert names(state, "tribune_plebs"), "the tribunes of the plebs go on"
            assert any(e.kind == "anarchy" for e in events)
            view = republic_view(state)
            assert view is not None and view["year_gap"] == "anarchy"
    assert seen


def test_disputed_years_say_so_in_the_view(content: Content) -> None:
    early = new_game(content, "rome_509", seed=1, chronicle=True)
    view = republic_view(early)
    assert view is not None and view["year_disputed"]
    assert all(m["disputed"] for m in view["magistrates"] if m["office"] == "consul")
    late = new_game(content, "rome_49", seed=1, chronicle=True)
    view = republic_view(late)
    assert view is not None and not view["year_disputed"]


# ---------------------------------------------------------------- the people


def test_caesar_holds_office_in_44_and_dies_in_it(content: Content) -> None:
    state = new_game(content, "rome_49", seed=1, chronicle=True)
    rep = state.republic
    assert rep is not None
    assert "Gaius Iulius Caesar" in names(state, "dictator")
    deaths: dict[int, list[str]] = {}
    while state.year < -42:
        state, events = end_turn(state)
        deaths[state.year] = [e.message for e in events if e.kind == "death"]
        if state.year == -44:
            assert "Gaius Iulius Caesar" in names(state, "consul")
            assert "Marcus Antonius" in names(state, "consul")
        if state.year == -43:
            assert names(state, "consul")[:2] == [
                "Aulus Hirtius",
                "Gaius Vibius Pansa Caetronianus",
            ]
            assert names(state, "triumvir") == [
                "Gaius Iulius Caesar Octavianus",
                "Marcus Aemilius Lepidus",
                "Marcus Antonius",
            ]
    rep = state.republic
    assert rep is not None
    assert not rep.people["c_iulius_caesar"].alive and rep.people["c_iulius_caesar"].died == -44
    assert any("Gaius Iulius Caesar is murdered." in m for m in deaths[-44])
    assert any("Marcus Tullius Cicero is proscribed" in m for m in deaths[-43])
    assert not rep.diverged, "history kept to the Fasti"


def test_recorded_lower_offices_are_honoured(content: Content) -> None:
    state = new_game(content, "rome_133", seed=1, chronicle=True)
    rep = state.republic
    assert rep is not None
    assert "Tiberius Sempronius Gracchus" in names(state, "tribune_plebs")
    tribune = next(m for m in rep.magistrates if m.person == "ti_sempronius_gracchus_133")
    assert tribune.office == "tribune_plebs" and tribune.by_fasti
    while state.year > -115:
        state, _ = end_turn(state)
    rep = state.republic
    assert rep is not None
    assert state.year == -115
    marius = next(m for m in rep.magistrates if m.person == "c_marius")
    assert marius.office == "praetor" and marius.by_fasti
    assert not rep.people["ti_sempronius_gracchus_133"].alive


def test_persons_have_births_deaths_causes_and_sources(content: Content) -> None:
    for person in content.people.values():
        assert person.sources, person.id
        assert person.gens in content.gentes, person.id
        if person.died is not None and not person.legendary:
            assert person.died_of, f"{person.id} dies of nothing"
    famous = {
        "m_furius_camillus",
        "ap_claudius_caecus",
        "q_fabius_maximus_cunctator",
        "m_claudius_marcellus",
        "p_cornelius_scipio_africanus",
        "m_porcius_cato",
        "l_aemilius_paullus_macedonicus",
        "ti_sempronius_gracchus_133",
        "c_sempronius_gracchus",
        "c_marius",
        "l_cornelius_sulla",
        "cn_pompeius_magnus",
        "m_licinius_crassus",
        "m_tullius_cicero",
        "c_iulius_caesar",
        "m_porcius_cato_uticensis",
        "p_clodius_pulcher",
        "m_antonius",
        "c_iulius_caesar_octavianus",
        "m_iunius_brutus",
        "c_cassius_longinus",
        "m_aemilius_lepidus_triumvir",
        "m_vipsanius_agrippa",
    }
    assert famous <= set(content.people)


# ---------------------------------------------------------------- the bugs


def _all_people(state: GameState) -> RepublicState:
    rep = state.republic
    assert rep is not None
    return rep


@pytest.mark.parametrize("scenario", ["rome_509", "rome_264", "rome_49"])
@pytest.mark.parametrize("chronicle", [False, True])
def test_one_office_per_man_unique_names_and_plausible_ages(
    content: Content, scenario: str, chronicle: bool
) -> None:
    state = new_game(content, scenario, seed=4, chronicle=chronicle)
    rules = state.world.republic_rules
    mags = state.world.magistracies
    modelled = {hp.name for hp in content.people.values()}
    for _ in range(8):
        state, _ = end_turn(state)
        rep = _all_people(state)
        year = state.year
        elected = [m for m in rep.magistrates if m.year == year and not m.by_fasti]
        ids = [m.person for m in elected]
        assert len(ids) == len(set(ids)), f"{year}: a man holds two offices"
        for m in elected:
            assert m.person not in {f.person for f in rep.magistrates if f.by_fasti}
        # living men carry different names, and no generated man a modelled person's name
        living = [p for p in rep.people.values() if p.alive]
        living_names = [p.name for p in living]
        assert len(living_names) == len(set(living_names)), year
        for p in living:
            if not p.historical:
                assert p.name not in modelled, f"{p.name} born {p.born} duplicates a real man"
        # ages: elected cursus men within the law; nobody over the limit stands
        for m in elected:
            person = rep.people[m.person]
            age = year - person.born
            mag = mags[m.office]
            if mag.cursus:
                assert rules.pre_villia_min_age <= age <= rules.max_office_age, (m.name, age)
            else:
                assert rules.adult_age <= age <= rules.max_office_age, (m.name, age)
        for m in rep.magistrates:
            assert year - rep.people[m.person].born < 90, m.name


def test_generated_men_are_of_their_era(content: Content) -> None:
    state = new_game(content, "rome_509", seed=7)
    state = run(state, 60)  # 300 years at five a turn
    assert state.year == -209
    rep = _all_people(state)
    suffixes = {"Minor", "Nepos", "Tertius", "Quartus", "Quintus", "Sextus"}
    for p in rep.people.values():
        if p.historical or not p.alive:
            continue
        assert p.born > state.year - 100
        gens = state.world.gentes[p.gens]
        parts = p.name.split()
        rest = [
            t for t in parts[parts.index(gens.nomen) + 1 :] if t not in suffixes and not t.isdigit()
        ]
        allowed = set(gens.cognomina_at(p.born))
        assert set(rest) <= allowed, (p.name, p.born, allowed)
        assert gens.alive_in(p.born), p.name
    # no consul of 209 bears a cognomen the family had lost by then
    for m in rep.magistrates:
        if m.office == "consul":
            person = rep.people[m.person]
            gens = state.world.gentes[person.gens]
            assert (
                person.historical
                or set(person.name.split()[2:3]) <= set(gens.cognomina_at(person.born)) | suffixes
            )


def test_a_dead_man_is_not_reelected_under_his_name(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1, chronicle=True)
    state = run(state, 12)
    rep = _all_people(state)
    brutus = rep.people["l_iunius_brutus"]
    assert not brutus.alive
    assert not any(p.name == brutus.name and p.id != brutus.id for p in rep.people.values()), (
        "a namesake took Brutus' name"
    )
    assert "Lucius Iunius Brutus" not in [m.name for m in rep.record if m.year > -509]


# ---------------------------------------------------------------- the Senate


def test_forecasts_differ_by_issue_and_by_era(content: Content) -> None:
    results = {}
    for scenario in ("rome_509", "rome_264", "rome_133"):
        state = new_game(content, scenario, seed=1, chronicle=True)
        votes = {issue: senate_vote(state, issue).yes_bp for issue in Issue}
        assert len(set(votes.values())) >= 4, (scenario, votes)
        assert min(votes.values()) > 0 and max(votes.values()) < 10_000, votes
        results[scenario] = votes
    assert results["rome_509"][Issue.LAND] != results["rome_133"][Issue.LAND]
    # the land question splits the orders and later the optimates and populares
    early = new_game(content, "rome_509", seed=1, chronicle=True)
    assert (
        family_leaning(early, "claudii", Issue.LAND)
        < 0
        < family_leaning(early, "icilii", Issue.LAND)
    )
    late = new_game(content, "rome_133", seed=1, chronicle=True)
    assert (
        family_leaning(late, "caecilii", Issue.LAND)
        < 0
        < family_leaning(late, "sempronii", Issue.LAND)
    )
    view = republic_view(late)
    assert view is not None
    assert {f["id"] for f in view["senate"]["factions"]} == {"optimates", "populares"}


def test_families_weigh_by_their_senators(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1, chronicle=True)
    rep = _all_people(state)
    weights = senate_weights(state)
    fid = rep.people["ap_claudius_caudex"].gens
    senators = sum(1 for p in rep.people.values() if p.alive and p.gens == fid and p.offices)
    assert senators >= 1
    assert weights[fid] > family_weight(rep.families[fid])


def test_war_is_only_proposed_against_states_rome_has_met(content: Content) -> None:
    state = new_game(content, "rome_509", seed=1, chronicle=True)
    offered = {p.proposal for p in available(state) if p.issue is Issue.WAR}
    far = [cid for cid in state.civs if "parth" in cid or "seleuc" in cid or "ptolem" in cid]
    for cid in far:
        assert f"war_with:{cid}" not in offered, cid
        assert not has_met(state, "rome", cid)
    assert offered, "Rome has neighbours to fight"
    view = republic_view(state)
    assert view is not None
    for p in view["proposals"]:
        assert "tribune_note" in p and "tribune_name" in p
        if p["tribune"]:
            assert p["tribune_name"] and "%" in p["tribune_note"]
        else:
            assert p["tribune_note"].startswith("no tribune")
