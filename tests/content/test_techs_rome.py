"""The ideas library measured against Rome (F1 ideas, docs/plans/rome.md target 8).

Every node is dated by the year Rome had it, told from Roman sources with citations, and
carries the words a player might use; the works that raise a building in the city map to a
form the Urbs kit can draw, on the site of the real building that came later.
"""

from __future__ import annotations

import dataclasses
import json
from pathlib import Path

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.engine.city import BUILD_FORMS, work_form

REPO = Path(__file__).resolve().parents[2]
FORMS_JSON = REPO / "client" / "data" / "city" / "anachronism_forms.json"
ANACHRONISMS_GD = REPO / "client" / "scripts" / "urbs" / "anachronisms.gd"

ROMAN_YEARS = {
    "aqueduct": -312,  # Aqua Appia (Frontinus, Aq. 5; Livy 9.29.6)
    "roads": -312,  # Via Appia (Livy 9.29.5-6)
    "concrete": -200,  # opus caementicium
    "fortification": -3000,  # walls older than Rome; the Servian wall of 378 is in the history
    "written_law": -450,  # the Twelve Tables (Livy 3.34, 3.57)
    "republic": -509,
    "citizen_assembly": -287,  # lex Hortensia (Gellius 15.27.4)
    "coinage": -269,  # Pliny NH 33.44
    "denarius": -211,
    "military_pay": -406,  # Livy 4.59-60
    "sundial": -293,  # Pliny NH 7.213
    "water_clock": -159,  # Pliny NH 7.215
    "water_wheel": -25,  # Vitruvius 10.5.2
    "glassmaking": -50,
    "hypocaust": -100,  # Sergius Orata (Pliny NH 9.168)
    "stone_theatre": -55,  # Theatre of Pompey (Plut. Pomp. 42.4; the ban: Livy Per. 48)
    "julian_calendar": -46,  # Suet. Iul. 40.1
    "shorthand": -63,  # Plut. Cato Min. 23.3
    "public_library": -39,  # Asinius Pollio (Pliny NH 7.115)
    "codex": 85,  # Martial 14.184-192
    "postal_relay": -20,  # Suet. Aug. 49.3
    "vigiles": 6,  # Dio 55.26.4-5
    "paper": 1150,  # never Roman: Europe's first mill
    "gunpowder": 1267,  # never Roman: Roger Bacon
    "printing_press": 1450,  # never Roman: Gutenberg
    "crossbow": -212,  # torsion artillery at Syracuse (Polybius 8.5-7)
}

ROMAN_IDEAS = {
    "tribunate", "censorship", "praetor_peregrinus", "cursus_honorum", "jury_courts",
    "secret_ballot", "provincial_governor", "grain_dole", "acta_diurna", "military_pay",
    "denarius", "provincial_coinage", "grain_fleet", "slave_estates", "greek_medicine",
    "julian_calendar", "shorthand", "codex", "greek_library", "public_library", "sundial",
    "water_clock", "latin_literature", "annals", "greek_philosophy", "rhetoric_school",
    "centuriation", "veteran_colonies", "street_paving", "basilica", "stone_bridge",
    "stone_theatre", "amphitheatre", "hypocaust", "public_baths", "concrete_dome",
    "commemorative_arch", "marble_temple", "portico_hall", "granary", "harbour_works",
    "vigiles", "marching_camp", "siege_works", "eagle_standard", "corvus", "quinquereme",
}  # fmt: skip


@pytest.fixture(scope="module")
def content() -> Content:
    return load_content()


def test_every_node_has_a_source_a_year_keywords_and_a_history(content: Content) -> None:
    assert len(content.techs) >= 150
    for node in content.techs.values():
        assert node.sources, node.id
        assert isinstance(node.year, int), node.id
        assert len(node.keywords) >= 2, node.id
        assert node.history, node.id
        assert node.flavour, node.id


def test_the_library_is_dated_for_rome(content: Content) -> None:
    for node_id, year in ROMAN_YEARS.items():
        assert content.techs[node_id].year == year, node_id


def test_the_roman_ideas_are_there_and_sourced(content: Content) -> None:
    assert len(ROMAN_IDEAS) >= 30
    missing = ROMAN_IDEAS - set(content.techs)
    assert not missing
    for node_id in ROMAN_IDEAS:
        node = content.techs[node_id]
        assert node.sources, node_id
        assert node.history, node_id
        assert node.keywords, node_id
        assert -509 <= node.year <= 130, node_id  # within or just after the campaign


def test_nothing_rome_started_with_is_ahead_of_its_time(content: Content) -> None:
    """A 509 BC start holds these adopted; none may count as early (suspicion, D-022)."""
    start = content.scenarios["rome_509"].civs["rome"].techs
    for node_id, stage in start.items():
        if stage.is_adopted and node_id != "written_law":
            assert content.techs[node_id].year <= -509, node_id
    # the scenario starts Rome with written law; the Twelve Tables are of 450 BC (Livy 3.34),
    # so the lead's rome_509 should start it as a concept (reported); the date stays honest
    assert content.techs["written_law"].year == -450


def test_re_skinned_nodes_keep_their_ids_and_say_what_rome_had(content: Content) -> None:
    assert "scorpio" in content.techs["crossbow"].keywords
    assert "cursus publicus" in content.techs["postal_relay"].keywords
    assert "lex hortensia" in content.techs["citizen_assembly"].keywords
    assert "twelve tables" in content.techs["written_law"].keywords
    assert "cloaca" in content.techs["sanitation"].keywords


def test_every_work_an_idea_builds_has_a_form_and_a_site(content: Content) -> None:
    kinds = {node.builds for node in content.techs.values() if node.builds}
    assert kinds >= {"aqueduct", "road", "basilica", "theatre_stone", "dome", "sundial"}
    for kind in sorted(kinds):
        form = work_form(kind)
        assert form is not None, kind
        assert form.site, kind
        assert form.source, kind
        assert form.latin, kind
        assert form.length or form.width or form.radius or form.route_of, kind
        if form.twin:
            assert form.twin in content.monuments, (kind, form.twin)
        if form.route_of:
            assert form.route_of in content.monuments, (kind, form.route_of)


def test_the_client_mirror_of_the_forms_is_in_step() -> None:
    """anachronisms.gd reads data/city/anachronism_forms.json for renders without the engine."""
    mirror = json.loads(FORMS_JSON.read_text(encoding="utf-8"))["forms"]
    forms = {k: dataclasses.asdict(v) for k, v in BUILD_FORMS.items()}
    assert mirror == json.loads(json.dumps(forms))  # tuples become lists
    gd = ANACHRONISMS_GD.read_text(encoding="utf-8")
    assert "class_name UrbsAnachronisms" in gd
    assert "anachronism_forms.json" in gd
