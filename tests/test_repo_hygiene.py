"""Repository hygiene: rules from the brief that are easy to break by accident."""

from __future__ import annotations

import re
import socket
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
API_KEY = re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}")
PERSISTENT_DOCS = ["BRIEF", "DESIGN", "ARCHITECTURE", "PLAN", "DECISIONS", "CONTENT_GUIDE"]


def _git(*args: str) -> subprocess.CompletedProcess[bytes]:
    try:
        return subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True, check=False)
    except FileNotFoundError:
        pytest.skip("git is not installed")


def test_claude_md_stays_short() -> None:
    lines = (REPO_ROOT / "CLAUDE.md").read_text(encoding="utf-8").splitlines()
    assert len(lines) <= 100, "CLAUDE.md must stay under ~100 lines; move detail into docs/."


@pytest.mark.parametrize("name", PERSISTENT_DOCS)
def test_persistent_doc_exists(name: str) -> None:
    assert (REPO_ROOT / "docs" / f"{name}.md").is_file()


def test_no_api_keys_in_tracked_files() -> None:
    listing = _git("ls-files", "-z")
    if listing.returncode != 0:
        pytest.skip("not a git checkout")
    offenders = [
        name
        for name in listing.stdout.decode().split("\0")
        if name
        and (REPO_ROOT / name).is_file()
        and API_KEY.search((REPO_ROOT / name).read_text(encoding="utf-8", errors="ignore"))
    ]
    assert not offenders, f"Possible API key committed in: {offenders}"


def test_env_file_is_git_ignored() -> None:
    result = _git("check-ignore", "--quiet", ".env")
    if result.returncode == 128:
        pytest.skip("not a git checkout")
    assert result.returncode == 0, ".env holds secrets and must be listed in .gitignore"


def test_network_is_blocked_in_tests() -> None:
    with (
        socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock,
        pytest.raises(RuntimeError, match="must not use the network"),
    ):
        sock.connect(("192.0.2.1", 80))  # reserved documentation address, never routable
