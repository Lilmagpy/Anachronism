"""The drafting tool: proposals go to drafts/, and only reviewed ones reach a pack."""

from __future__ import annotations

from pathlib import Path

import yaml

from anachronism.content.loader import load_content
from anachronism.llm.fake import FakeProvider
from anachronism.tools.draft import DRAFT_NOTE, draft, promote

PROPOSALS = {
    "nodes": [
        {"name": "Paper", "category": "craft", "complexity": 2, "year": -100},  # already known
        {
            "name": "Wheelbarrow",
            "category": "agriculture",
            "complexity": 2,
            "year": -150,
            "prerequisites": ["ox_plough", "not_real"],
            "effects": [{"type": "food_output", "percent": 6}],
            "flavour": "One wheel, two handles, and one man moves what took three.",
            "keywords": ["wheelbarrow", "barrow", "one wheel cart"],
            "note": "Han dynasty wheelbarrows (Needham)",
        },
    ]
}


def test_drafts_skip_known_ideas_and_are_marked(tmp_path: Path) -> None:
    content = load_content()
    entries = draft(FakeProvider(PROPOSALS), "East Asia", "classical", 2, content.techs)
    assert [e["id"] for e in entries] == ["wheelbarrow"]
    entry = entries[0]
    assert entry["prerequisites"] == ["ox_plough"]
    assert DRAFT_NOTE in entry["sources"]
    assert entry["effects"] == [{"type": "food_output", "bp": 600}]


def test_only_reviewed_drafts_are_promoted(tmp_path: Path) -> None:
    content = load_content()
    entries = draft(FakeProvider(PROPOSALS), "East Asia", "classical", 2, content.techs)
    unreviewed = tmp_path / "draft.yaml"
    unreviewed.write_text(yaml.safe_dump({"schema_version": 1, "techs": entries}))
    pack = tmp_path / "pack"
    problems = promote(unreviewed, pack)
    assert problems
    assert not (pack / "techs" / "drafted.yaml").exists()
    entries[0]["sources"] = ["Needham, Science and Civilisation in China, vol. 6.2"]
    reviewed = tmp_path / "reviewed.yaml"
    reviewed.write_text(yaml.safe_dump({"schema_version": 1, "techs": entries}))
    assert promote(reviewed, pack) == []
    written = yaml.safe_load((pack / "techs" / "drafted.yaml").read_text())
    assert written["techs"][0]["id"] == "wheelbarrow"
    assert written["techs"][0]["provenance"] == "library"
