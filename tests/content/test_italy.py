"""The rome pack's treaties, colonies and provinces (R3, F1): sourced and consistent."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import RelationStatus
from anachronism.content.schema.italy import AllyStatus, ColonyKind

ROME_SCENARIOS = ("rome_509", "rome_390", "rome_340", "rome_264", "rome_133", "rome_49")


@pytest.fixture(scope="module")
def content() -> Content:
    return load_content()


def test_every_entry_carries_a_source(content: Content) -> None:
    for group in (content.treaties, content.colonies, content.provinciae):
        for entry_id, entry in group.items():
            assert entry.sources, entry_id
            for step in getattr(entry, "steps", ()):
                assert step.sources, f"{entry_id}: step {step.year}"
    assert content.italy_rules.sources


def test_treaties_name_real_civs_and_cover_every_italian_ally(content: Content) -> None:
    by_civ = {t.civ: t for t in content.treaties.values()}
    assert len(by_civ) == len(content.treaties), "one treaty per civ"
    for civ_id in by_civ:
        assert civ_id in content.civs, civ_id
    for sid in ROME_SCENARIOS:
        scenario = content.scenarios[sid]
        for rel in scenario.relations:
            if rel.status is not RelationStatus.ALLIED or "rome" not in (rel.a, rel.b):
                continue
            ally = rel.b if rel.a == "rome" else rel.a
            if scenario.civs[ally].capital.startswith("it_"):
                assert ally in by_civ, f"{sid}: {ally} is allied to Rome without a treaty"


def test_the_ladder_steps_are_in_order_and_climb(content: Content) -> None:
    for treaty in content.treaties.values():
        rank = treaty.status.rank
        for step in treaty.steps:
            assert step.status.rank > rank, f"{treaty.id}: {step.year} does not climb"
            rank = step.status.rank
    caere = next(t for t in content.treaties.values() if t.civ == "e5_caere")
    assert [(s.year, s.status) for s in caere.steps] == [(-353, AllyStatus.SINE_SUFFRAGIO)]
    hernici = next(t for t in content.treaties.values() if t.civ == "e3_hernici")
    assert hernici.steps[0].year == -306, "Livy 9.43.24"


def test_the_levies_follow_polybius(content: Content) -> None:
    by_civ = {t.civ: t for t in content.treaties.values()}
    assert by_civ["e2_samnites"].levy_bp > by_civ["e2_etruscans"].levy_bp, "Polybius 2.24.5, 10"
    assert by_civ["e2_italiote_greeks"].levy_bp < by_civ["e2_samnites"].levy_bp, "naval allies"
    assert content.italy_rules.allied_ratio_bp >= 10_000, "the allies at least match the citizens"


def test_colonies_sit_on_real_provinces_in_order(content: Content) -> None:
    years = []
    for colony in content.colonies.values():
        assert colony.province in content.provinces, colony.id
        assert -509 <= colony.year <= -27, colony.id
        years.append((colony.year, colony.id))
    names = {(c.name, c.year) for c in content.colonies.values()}
    assert len(names) == len(content.colonies)
    first = {c.name: c for c in content.colonies.values()}
    assert first["Cales"].year == -334 and first["Cales"].settlers == 2500
    assert first["Luceria"].year == -314 and first["Luceria"].kind is ColonyKind.LATIN
    assert first["Ariminum"].year == -268 and first["Brundisium"].year == -244
    assert first["Placentia"].year == -218 and first["Cremona"].year == -218
    assert first["Aquileia"].year == -181 and first["Aquileia"].settlers == 3000
    assert first["Puteoli"].kind is ColonyKind.CITIZEN and first["Puteoli"].settlers == 300
    assert all(
        c.kind is ColonyKind.CITIZEN
        for c in content.colonies.values()
        if c.year > content.italy_rules.latin_until_year
    ), "no Latin colony after Luca (Velleius 1.15.2)"


def test_provinciae_are_made_of_real_provinces(content: Content) -> None:
    seen: set[str] = set()
    for provincia in content.provinciae.values():
        for pid in provincia.provinces:
            assert pid in content.provinces, f"{provincia.id}: {pid}"
            assert pid not in seen, f"{pid} is in two provinciae"
            seen.add(pid)
        assert provincia.from_year >= content.italy_rules.provinces_from_year
        assert provincia.office in content.magistracies
    assert content.provinciae["sicilia"].historical_year == -227
    assert content.provinciae["africa"].historical_year == -146
    assert content.italy_rules.lex_calpurnia_year == -149, "Cicero, Brutus 106"
    assert content.italy_rules.social_war_year == -91


@pytest.mark.parametrize(
    ("scenario", "civ", "script", "year"),
    [
        ("rome_509", "carthage", "r509_carthage_defends_sicily", -266),
        ("rome_509", "e5_tarentum", "r509_tarentum_vs_rome", -283),
        ("rome_390", "carthage", "r390_hannibals_war", -222),
        ("rome_390", "e5_samnites", "r390_samnites_second_war", -328),
        ("rome_340", "carthage", "carthage_defends_sicily", -266),
        ("rome_340", "macedon", "philip_allies_hannibal", -216),
        ("rome_340", "epirus", "pyrrhus_in_italy", -281),
        ("rome_264", "numidia", "jugurtha_vs_rome", -112),
        ("rome_264", "pontus", "mithridates_invades_asia", -89),
        ("rome_264", "seleucid", "antiochus_in_greece", -193),
        ("rome_133", "pontus", "mithridates_invades_asia", -89),
        ("rome_133", "e1_cimbri", "cimbri_migrate", -113),
        ("rome_49", "e1_parthia", "labienus_pacorus_invasion", -41),
    ],
)
def test_the_overseas_powers_act_when_history_has_them_act(
    content: Content, scenario: str, civ: str, script: str, year: int
) -> None:
    scripts = {s.id: s for s in content.scenarios[scenario].civs[civ].scripts}
    assert script in scripts, f"{scenario}: {civ} lacks {script}"
    assert scripts[script].preconditions.after_year == year
    assert scripts[script].note, "every script step is sourced in its note"
