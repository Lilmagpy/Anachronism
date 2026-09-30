"""Characters speak at the right moments, with the right names, deterministically."""

from __future__ import annotations

from pathlib import Path

import pytest

from anachronism.content.issues import ContentError
from anachronism.content.loader import Content, load_content
from anachronism.engine.game import new_game
from anachronism.engine.state import Event
from anachronism.tools.voices import speak, voices_for_turn
from tests.content.test_loader import edit, packs  # noqa: F401  (fixture)


@pytest.fixture(scope="module")
def content() -> Content:
    return load_content()


def event(kind: str, civ: str, subject: str = "") -> Event:
    return Event(turn=1, year=-340, civ=civ, kind=kind, message="", subject=subject)


def test_the_ruler_opens_the_game(content: Content) -> None:
    state = new_game(content, "warring_states", seed=1)
    voice = speak(content, state, "game_start")
    assert voice is not None
    assert voice["name"] == "Duke Xiao"
    assert voice["portrait"] == "court"
    assert "{" not in voice["text"]


def test_worst_news_first_and_at_most_two(content: Content) -> None:
    state = new_game(content, "warring_states", seed=1)
    events = [
        event("widespread", "qin", "Coinage"),
        event("adopted", "qin", "Paper"),
        event("riot", "qin"),
        event("setback", "qin", "Roads"),
    ]
    voices = voices_for_turn(content, state, events)
    assert [v["moment"] for v in voices] == ["riot", "adopted"]
    assert voices[0]["name"] == "General"
    assert "Paper" in voices[1]["text"]


def test_a_rival_boasts_about_ideas_ahead_of_their_time(content: Content) -> None:
    state = new_game(content, "warring_states", seed=1)
    voices = voices_for_turn(content, state, [event("adopted", "chu", "Paper")])
    assert [v["moment"] for v in voices] == ["rival_adopted"]
    assert voices[0]["name"] == "King Xuan"
    assert voices[0]["civ"] == "chu"
    assert "Chu" in voices[0]["text"]
    # an old idea is not worth a boast; a quiet turn gets the steward instead
    quiet = voices_for_turn(content, state, [event("adopted", "chu", "Writing")])
    assert [v["moment"] for v in quiet] == ["quiet"]


def test_lines_are_chosen_deterministically(content: Content) -> None:
    state = new_game(content, "warring_states", seed=4)
    first = [speak(content, state, "adopted", "Paper") for _ in range(3)]
    assert first[0] == first[1] == first[2]


def load(root: Path) -> list[str]:
    with pytest.raises(ContentError) as error:
        load_content(root=root)
    return [str(issue) for issue in error.value.issues]


def test_bad_dialogue_is_reported(packs: Path) -> None:  # noqa: F811
    edit(packs / "core" / "dialogue.yaml", "speaker: diviner", "speaker: jester")
    edit(packs / "core" / "dialogue.yaml", "{subject}? Fascinating.", "{idea}? Fascinating.")
    found = load(packs)
    assert any("unknown speaker 'jester'" in p for p in found)
    assert any("unknown placeholder(s) ['idea']" in p for p in found)
