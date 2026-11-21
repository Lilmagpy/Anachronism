"""The F3 houses part of the city audit report (``city_audit.py`` ``# F3 houses`` block).

The checks themselves run in Godot (``client/scripts/urbs/audit.gd`` ``_f3_houses``); these tests
cover how their findings reach the summary and the report, on a scene built by hand.
"""

from typing import Any

from anachronism.tools import city_audit as ca


def _scene() -> dict[str, Any]:
    kinds = [k for k, _ in ca.F3_HOUSES_KINDS]
    return {
        "years": {
            "-44": {
                "f3_houses": {
                    "buildings": 120,
                    "counts": {k: (2 if k == "house_house" else 0) for k in kinds},
                    "worst": {
                        "house_house": [
                            "insula:gable:3:0:0@1,2 overlaps casa:tile@3,4 by 0.4 m (3 m up)",
                            "casa:tile@5,6 overlaps casa:tile@7,8 by 0.3 m (2 m up)",
                        ]
                    },
                }
            },
            "-264": {
                "f3_houses": {
                    "buildings": 80,
                    "counts": {k: (1 if k == "tree_street" else 0) for k in kinds},
                    "worst": {"tree_street": ["oak tree at (9, 9) in the carriageway of x"]},
                }
            },
            "-509": {"overlaps": []},  # a year audited before the F3 checks existed
        }
    }


def test_counts_sum_over_years() -> None:
    counts = ca.f3_houses_counts(_scene())
    assert counts["house_house"] == 2
    assert counts["tree_street"] == 1
    assert set(counts) == {k for k, _ in ca.F3_HOUSES_KINDS}


def test_rows_and_section_name_every_kind_and_the_worst() -> None:
    rows = ca.f3_houses_rows(_scene())
    assert len(rows) == len(ca.F3_HOUSES_KINDS)
    assert any("interpenetrating" in r and r.endswith("| 2 |") for r in rows)
    section = "\n".join(ca.f3_houses_section(_scene()))
    assert f"| {ca._yr(-44)} | 120 |" in section
    assert "insula:gable:3:0:0@1,2 overlaps casa:tile@3,4" in section
    assert "oak tree at (9, 9)" in section


def test_nothing_when_the_checks_have_not_run() -> None:
    scene: dict[str, Any] = {"years": {"-44": {"overlaps": []}}}
    assert ca.f3_houses_rows(scene) == []
    assert ca.f3_houses_section(scene) == []
    assert ca.f3_houses_counts({}) == {k: 0 for k, _ in ca.F3_HOUSES_KINDS}


def test_summary_carries_the_counts() -> None:
    a = ca.run_audit(scene=_scene(), events="")
    s = a.summary()
    assert s["f3_house_house"] == 2
    assert "scene (F3 houses)" in ca.render_markdown(a)
