"""Tests for the ``anachronism`` launcher (the text console until Phase 3)."""

from __future__ import annotations

import pytest

from anachronism import __version__
from anachronism.__main__ import main


def test_version_flag_prints_version_and_exits(capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit) as exit_info:
        main(["--version"])
    assert exit_info.value.code == 0
    assert __version__ in capsys.readouterr().out


def test_launcher_starts_a_game_and_ends_cleanly_when_input_ends() -> None:
    lines: list[str] = []

    def no_more_input(prompt: str) -> str:
        raise EOFError

    assert main(["--seed", "1"], read=no_more_input, write=lines.append) == 0
    assert any("Kingdom of Veyra" in line for line in lines)
