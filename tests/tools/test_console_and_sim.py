"""Tests for the text console and the simulation tool."""

from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path

import pytest

from anachronism.content.schema import EffectType
from anachronism.tools.console import describe_effect, main, plural, year_text
from anachronism.tools.simulate import main as simulate


def play(commands: list[str], tmp_path: Path) -> list[str]:
    """Run the console with scripted commands and return everything it printed."""
    feed: Iterator[str] = iter(commands)
    output: list[str] = []

    def read(prompt: str) -> str:
        try:
            return next(feed)
        except StopIteration:
            raise EOFError from None

    assert main(["--seed", "7", "--saves", str(tmp_path)], read=read, write=output.append) == 0
    return output


def test_a_short_game_session(tmp_path: Path) -> None:
    output = play(
        [
            "help",
            "ideas",
            "about iron working",
            "start alphabet high",
            "start iron working",
            "about iron",
            "fly to the moon",
            "end",
            "world",
            "quit",
        ],
        tmp_path,
    )
    text = "\n".join(output)
    assert "Kingdom of Veyra ── 1200 BC ── turn 1" in text
    assert "Commands" in text
    assert "Phonetic alphabet" in text
    assert "Status: blocked — needs access to Iron ore" in text
    assert "Work begins on Phonetic alphabet." in text
    assert "Cannot do that: cannot start Iron working: needs access to Iron ore." in text
    assert "could mean: Iron-tipped plough, Iron working" in text
    assert "Unknown command 'fly'" in text
    assert "1190 BC ── turn 2" in text
    assert "Kingdom of Veyra (you)" in text
    assert output[-1] == "Farewell."


def test_projects_can_be_paused_prioritised_and_cancelled(tmp_path: Path) -> None:
    text = "\n".join(
        play(
            [
                "start paper",
                "pause paper",
                "resume paper",
                "priority paper low",
                "priority paper",
                "cancel paper",
                "cancel paper",
            ],
            tmp_path,
        )
    )
    assert "Work on Paper is paused." in text
    assert "Work on Paper resumes." in text
    assert "Paper now has low priority." in text
    assert "Usage: priority <idea> high|normal|low" in text
    assert "Work on Paper is abandoned." in text
    assert "Cannot do that: there is no project for Paper." in text


def test_save_and_load_round_trip(tmp_path: Path) -> None:
    text = "\n".join(
        play(["start alphabet", "end", "save test", "end", "load test", "load nothing"], tmp_path)
    )
    assert (tmp_path / "test.json").is_file()
    assert "Saved to" in text
    assert "Loaded" in text
    assert "No save called nothing.json." in text


def test_formatting_helpers() -> None:
    assert year_text(-1200) == "1200 BC"
    assert year_text(300) == "AD 300"
    assert plural(1, "turn") == "1 turn"
    assert plural(3, "turn") == "3 turns"
    assert describe_effect(EffectType.FOOD_OUTPUT, 1_200, None) == "food +12%"
    assert describe_effect(EffectType.UNREST, -100, None) == "unrest -1.0 points per decade"
    assert describe_effect(EffectType.UNLOCKS_RESOURCE, 0, "iron") == "unlocks iron"


def test_simulation_tool_prints_tables_and_events(capsys: pytest.CaptureFixture[str]) -> None:
    assert simulate(["--turns", "4", "--every", "2", "--player", "greedy"]) == 0
    text = capsys.readouterr().out
    assert "Bots: player greedy, rivals growth" in text
    assert "1180 BC (turn 2)" in text
    assert "veyra" in text
    assert "Events:" in text
