"""Roman voices (F1 ideas): offices speak, named from the magistrates and gentes of the year."""

from __future__ import annotations

import re
from pathlib import Path

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.engine.game import new_game
from anachronism.tools.roman_speakers import OFFICES, gens_name, speaker_name

PACK = Path(__file__).resolve().parents[2] / "src" / "anachronism" / "content" / "packs" / "core"
ROMAN_SPEAKERS = {
    "scholar",
    "steward",
    "general",
    "diviner",
    "pontifex",
    "censor",
    "princeps",
    "tribune",
}
UNROMAN = re.compile(r"\b(Majesty|Heaven|oracle bones|throne|king's|royal)\b")


@pytest.fixture(scope="module")
def content() -> Content:
    return load_content()


def test_the_court_is_roman_offices(content: Content) -> None:
    assert set(content.speakers) == ROMAN_SPEAKERS
    assert content.speakers["pontifex"].title == "Pontifex maximus"
    assert content.speakers["tribune"].title == "Tribune of the plebs"
    used = {d.speaker for d in content.dialogue.values()}
    assert {"pontifex", "censor", "tribune", "princeps"} <= used


def test_dialogue_dilemmas_and_happenings_speak_in_roman_terms(content: Content) -> None:
    for moment in content.dialogue.values():
        for line in moment.lines:
            assert not UNROMAN.search(line), (moment.id, line)
    for dilemma in content.dilemmas.values():
        assert not UNROMAN.search(dilemma.text), dilemma.id
    for happening in content.happenings.values():
        assert not UNROMAN.search(happening.message), happening.id


def test_no_invented_roman_is_named_in_the_content() -> None:
    """Names come from the gentes of the year, never from the content's prose (brief F1)."""
    for name in ("speakers", "dialogue", "dilemmas", "happenings"):
        text = (PACK / f"{name}.yaml").read_text(encoding="utf-8")
        assert "Publius Claudius Caudex" not in text
    assert "Caudex" not in (PACK / "dilemmas.yaml").read_text(encoding="utf-8")


def test_every_dilemma_and_consequence_cites_a_source() -> None:
    authors = "Livy|Appian|Pliny|Dio|Suet|Cicero|Seneca|Polyb|Plut"
    cited = re.compile(r"^  - id: \w+\s+# .*(?:" + authors + ")", re.M)
    assert len(cited.findall((PACK / "dilemmas.yaml").read_text(encoding="utf-8"))) >= 10
    assert len(cited.findall((PACK / "happenings.yaml").read_text(encoding="utf-8"))) >= 18


def test_speakers_are_named_from_the_magistrates_of_the_year(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    assert state.republic is not None
    consuls = {m.name for m in state.republic.magistrates if m.office == "consul"}
    assert speaker_name(content, state, "general") in consuls
    for speaker, offices in OFFICES.items():
        name = speaker_name(content, state, speaker)
        assert name, speaker
        holders = {m.name for m in state.republic.magistrates if m.office in offices}
        if holders:
            assert name in holders, speaker
    # offices the engine does not seat take a man of a gens the content knows
    augur = speaker_name(content, state, "diviner")
    assert augur is not None
    assert any(augur.split()[1] == g.nomen for g in content.gentes.values())
    assert speaker_name(content, state, "diviner") == augur  # stable
    assert (
        gens_name(content, state, "x") != gens_name(content, state, "y") or len(content.gentes) == 1
    )


def test_no_names_outside_the_republic(content: Content) -> None:
    state = new_game(content, "punic_wars", seed=1)
    assert speaker_name(content, state, "general") is None
