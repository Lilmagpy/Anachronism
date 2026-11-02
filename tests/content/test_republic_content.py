"""The rome pack's Fasti, families and people agree with each other (F1)."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import Confidence, Issue, Order

SENIOR = {"consul", "consular_tribune", "dictator", "magister_equitum", "censor", "decemvir"}


@pytest.fixture(scope="module")
def content() -> Content:
    return load_content()


def test_every_family_has_a_stance_on_every_issue(content: Content) -> None:
    for gens in content.gentes.values():
        assert set(gens.stances) == set(Issue), gens.id
        assert gens.sources, gens.id
        assert gens.notes, gens.id
        assert gens.praenomina, gens.id
        assert gens.standing, gens.id
        for branch in gens.branches:
            assert branch.to_year is None or branch.to_year >= branch.from_year, gens.id
    patricians = [g for g in content.gentes.values() if g.order is Order.PATRICIAN]
    assert 30 <= len(patricians) <= 45
    assert {"cornelii", "fabii", "claudii", "aemilii", "sempronii", "caecilii", "iulii"} <= set(
        content.gentes
    )


def test_the_fasti_and_the_people_agree(content: Content) -> None:
    by_year = {f.year: f for f in content.fasti.values()}
    listed: dict[tuple[str, int], set[str]] = {}
    offices: set[str]
    for entry in by_year.values():
        for college in entry.colleges:
            for holder in college.holders:
                if holder.person:
                    listed.setdefault((holder.person, entry.year), set()).add(college.office)
    for (pid, year), offices in listed.items():
        person = content.people[pid]
        in_people = {h.office for h in person.offices if h.year == year}
        assert offices <= in_people, f"{pid} is in the Fasti of {year} as {offices}, not in people"
    for person in content.people.values():
        for office in person.offices:
            if office.office in SENIOR:
                assert office.office in listed.get((person.id, office.year), set()), (
                    f"{person.id}: {office.office} {office.year} is not in the Fasti"
                )
            if person.born is not None:
                assert 17 <= office.year - person.born <= 85, (person.id, office)


def test_gap_years_and_confidence(content: Content) -> None:
    years = {f.year: f for f in content.fasti.values()}
    assert all(years[y].gap == "anarchy" for y in range(-375, -370))
    assert all(years[y].gap == "dictator_year" for y in (-333, -324, -309, -301))
    for entry in years.values():
        assert entry.sources, entry.id
        if entry.year > -300:
            assert (
                entry.confidence is not Confidence.LOW
                or "disputed" in entry.notes.lower()
                or (entry.gap)
            ), entry.id
    low = sum(1 for f in years.values() if f.confidence is Confidence.LOW)
    assert 100 < low < 200  # the fifth and early fourth centuries are the tradition's


def test_the_starts_find_their_magistrates(content: Content) -> None:
    years = {f.year: f for f in content.fasti.values()}
    consuls = {
        -509: {"l_iunius_brutus", "l_tarquinius_collatinus"},
        -264: {"ap_claudius_caudex", "m_fulvius_flaccus_264"},
        -133: {"p_mucius_scaevola_133", "l_calpurnius_piso_frugi"},
        -49: {"c_claudius_marcellus_49", "l_cornelius_lentulus_crus"},
    }
    for year, ids in consuls.items():
        college = next(c for c in years[year].colleges if c.office == "consul")
        assert ids <= {h.person for h in college.holders if h.person}, year
    assert next(c for c in years[-390].colleges if c.office == "dictator").holders[0].person == (
        "m_furius_camillus"
    )
    assert next(c for c in years[-340].colleges if c.office == "consul").holders[0].person in (
        "t_manlius_torquatus",
        "p_decius_mus_340",
    )
