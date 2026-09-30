"""Tests for the JSON-lines engine bridge used by the 3D client."""

from __future__ import annotations

import io
import json
from pathlib import Path
from typing import Any

from anachronism.content.loader import load_content
from anachronism.tools.server import Session, serve


def talk(requests: list[dict[str, Any] | str], tmp_path: Path) -> list[dict[str, Any]]:
    session = Session(load_content(), tmp_path)
    lines = [r if isinstance(r, str) else json.dumps(r) for r in requests]
    out = io.StringIO()
    serve((line + "\n" for line in lines), out, session)
    return [json.loads(line) for line in out.getvalue().splitlines()]


def test_a_game_through_the_bridge(tmp_path: Path) -> None:
    replies = talk(
        [
            {"id": 1, "cmd": "new_game", "args": {"seed": 3}},
            {"id": 2, "cmd": "act", "args": {"action": {"kind": "start", "node_id": "alphabet"}}},
            {
                "id": 3,
                "cmd": "act",
                "args": {"action": {"kind": "start", "node_id": "iron_working"}},
            },
            {"id": 4, "cmd": "end_turn"},
            {"id": 5, "cmd": "view"},
            {"id": 6, "cmd": "quit"},
            {"id": 7, "cmd": "view"},
        ],
        tmp_path,
    )
    assert [r["id"] for r in replies] == [1, 2, 3, 4, 5, 6]  # nothing after quit
    assert all(r["ok"] for r in replies)
    start = replies[0]["result"]
    assert start["year"] == -1200
    assert start["status"]["name"] == "Kingdom of Veyra"
    assert len(start["provinces"]) == 20
    assert all(p["position"] for p in start["provinces"])
    assert replies[1]["result"]["accepted"]
    assert not replies[2]["result"]["accepted"]
    assert "Iron ore" in replies[2]["result"]["message"]
    assert replies[3]["result"]["year"] == -1190
    assert replies[4]["result"]["projects"][0]["id"] == "alphabet"


def test_ideas_show_costs_and_blockers(tmp_path: Path) -> None:
    [reply] = talk([{"id": 1, "cmd": "new_game", "args": {"seed": 1}}], tmp_path)
    ideas = {idea["id"]: idea for idea in reply["result"]["ideas"]}
    assert ideas["paper"]["ready"]
    assert ideas["paper"]["cost"]["labour"] > 0
    assert ideas["writing"]["stage"] == "adopted"
    assert not ideas["writing"]["ready"]


def test_errors_are_replies_not_crashes(tmp_path: Path) -> None:
    replies = talk(
        [
            "not json",
            "[1, 2]",
            {"id": 1, "cmd": "view"},
            {"id": 2, "cmd": "dance"},
            {"id": 3, "cmd": "new_game", "args": {"scenario": "atlantis"}},
            {"id": 4, "cmd": "new_game"},
            {"id": 5, "cmd": "act", "args": {"action": {"kind": "fly"}}},
            {"id": 6, "cmd": "load", "args": {"name": "../../etc/passwd"}},
            {"id": 7, "cmd": "load", "args": {"name": "missing"}},
        ],
        tmp_path,
    )
    assert [r["ok"] for r in replies] == [
        False,
        False,
        False,
        False,
        False,
        True,
        False,
        False,
        False,
    ]
    assert "no game yet" in replies[2]["error"]
    assert "unknown command 'dance'" in replies[3]["error"]
    assert "unknown scenario 'atlantis'" in replies[4]["error"]
    assert "bad action" in replies[6]["error"]
    assert "letters, digits" in replies[7]["error"]
    assert "no save called missing.json" in replies[8]["error"]


def test_save_and_load(tmp_path: Path) -> None:
    replies = talk(
        [
            {"id": 1, "cmd": "new_game", "args": {"seed": 2}},
            {"id": 2, "cmd": "end_turn"},
            {"id": 3, "cmd": "save", "args": {"name": "slot_1"}},
            {"id": 4, "cmd": "end_turn"},
            {"id": 5, "cmd": "load", "args": {"name": "slot_1"}},
        ],
        tmp_path,
    )
    assert all(r["ok"] for r in replies)
    assert (tmp_path / "slot_1.json").is_file()
    assert replies[4]["result"]["year"] == replies[1]["result"]["year"]
