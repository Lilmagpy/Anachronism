"""Tests for the command-line launcher."""

from __future__ import annotations

import pytest

from anachronism import __version__
from anachronism.__main__ import describe_platform, main


def test_launcher_reports_version_and_status(capsys: pytest.CaptureFixture[str]) -> None:
    assert main([]) == 0
    out = capsys.readouterr().out
    assert f"Anachronism {__version__}" in out
    assert "nothing to play yet" in out


def test_version_flag_prints_version_and_exits(capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit) as exit_info:
        main(["--version"])
    assert exit_info.value.code == 0
    assert __version__ in capsys.readouterr().out


def test_platform_description_is_readable() -> None:
    assert describe_platform().strip()
