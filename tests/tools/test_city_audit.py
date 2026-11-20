"""The city audit (F2): the placement arithmetic, the matching and the checks, without network."""

# ruff: noqa: PT018

from __future__ import annotations

import math
import re
from pathlib import Path
from typing import Any

from anachronism.tools import city_audit as ca

ROOT = Path(__file__).resolve().parents[2]


def test_frame_matches_urbs_geo() -> None:
    """The Python port uses the same constants as client/scripts/urbs/geo.gd."""
    geo = (ROOT / "client" / "scripts" / "urbs" / "geo.gd").read_text(encoding="utf-8")

    def const(name: str) -> float:
        m = re.search(rf"const {name} := ([0-9_.]+)", geo)
        assert m, name
        return float(m.group(1).replace("_", ""))

    assert const("ORIGIN_LAT") == ca.ORIGIN_LAT
    assert const("ORIGIN_LON") == ca.ORIGIN_LON
    assert const("M_PER_DEG_LAT") == ca.M_PER_DEG_LAT
    assert const("M_PER_DEG_LON") == ca.M_PER_DEG_LON
    # x east, z south: a point north-east of the origin has x > 0 and z < 0
    x, z = ca.to_local(ca.ORIGIN_LAT + 0.001, ca.ORIGIN_LON + 0.001)
    assert math.isclose(x, 82.85) and math.isclose(z, -111.132)
    lat, lon = ca.to_latlon(x, z)
    assert math.isclose(lat, ca.ORIGIN_LAT + 0.001) and math.isclose(lon, ca.ORIGIN_LON + 0.001)


def test_placed_centre_follows_monuments_gd() -> None:
    """offset_m is [east, north]; place_like borrows another record's point and offset."""
    recs = {
        "a": {
            "id": "a",
            "lat": ca.ORIGIN_LAT,
            "lon": ca.ORIGIN_LON,
            "offset_m": [10, 5],
            "bearing_deg": 90,
        },
        "b": {"id": "b", "lat": 0.0, "lon": 0.0, "place_like": "a"},
    }
    assert ca.placed_centre(recs["a"], recs) == (10.0, -5.0)
    assert ca.placed_centre(recs["b"], recs) == (10.0, -5.0)
    assert ca.placed_bearing(recs["b"], recs) == 90.0


def test_min_area_box_finds_axis_and_size() -> None:
    # a 40 x 10 rectangle whose long side runs at bearing 30
    a = math.radians(30)
    u = (math.sin(a), -math.cos(a))
    v = (math.cos(a), math.sin(a))
    pts = [
        (u[0] * s * 20 + v[0] * t * 5, u[1] * s * 20 + v[1] * t * 5)
        for s in (-1, 1)
        for t in (-1, 1)
    ]
    box = ca.min_area_box(pts)
    assert box is not None
    assert math.isclose(box.long, 40.0, abs_tol=1e-6)
    assert math.isclose(box.short, 10.0, abs_tol=1e-6)
    assert ca.angle_diff(box.axis, 30.0, 180.0) < 1e-6


def test_names_allow_case_endings_and_aliases() -> None:
    assert ca.names_match(ca.tokens("Aedes Castoris"), ca.tokens("Castor, aedes"))
    assert ca.names_match(ca.tokens("Aedes Iovis Statoris"), ca.tokens("Iuppiter Stator, aedes"))
    assert not ca.names_match(ca.tokens("Aqua Marcia"), ca.tokens("Column of Marcus Aurelius"))
    assert ca.kind_of_heading("Castor, aedes") == "temple"
    assert ca.kind_of_heading("Porta Capena") == "gate"


def test_platner_years_and_page_parsing() -> None:
    years = ca.pa_years("dedicated in 179 B.C. and restored by Augustus; burned A.D. 64")
    assert -179 in years and -27 in years and 64 in years
    page = (
        '</H4><P CLASS="justify" ID="Saturnus"><SPAN CLASS="entry">Saturnus, aedes:</SPAN>'
        " the temple of Saturn at the foot of the Capitol, dedicated in 497 B.C. (Liv. II.21)."
        '<P CLASS="justify" ID="x"><SPAN CLASS="entry">Saturnus, ara:</SPAN> see Saturnus.'
    )
    entries = ca.parse_platner_page("S.html", page)
    assert [e["head"] for e in entries] == ["Saturnus, aedes"]
    s = ca.summarise_platner(entries[0])
    assert s["kind"] == "temple" and s["earliest"] == -497 and s["in_scope"]
    assert s["key"] == "S#Saturnus"


def test_state_at_port() -> None:
    recs: dict[str, dict[str, Any]] = {
        "t": {
            "model": "temple_round",
            "built": {"year": -100},
            "construction": {"begun": -110, "completed": -100},
            "phases": [{"from": -80, "state": "burnt"}, {"from": -70, "state": "standing"}],
            "ended": {"year": 50},
        },
        "twin": {"model": "temple_round", "built": {"year": -200}, "twin_of": "t"},
        "none": {"model": "none", "built": {"year": -300}},
    }
    assert ca.state_at("t", -120, recs) == ""
    assert ca.state_at("t", -105, recs) == "building"
    assert ca.state_at("t", -90, recs) == "standing"
    assert ca.state_at("t", -75, recs) == "burnt"
    assert ca.state_at("t", -60, recs) == "standing"
    assert ca.state_at("t", 60, recs) == ""
    # the twin is drawn only while the Republican record is absent
    assert ca.state_at("twin", -150, recs) == "standing"
    assert ca.state_at("twin", -90, recs) == ""
    assert ca.state_at("none", 0, recs) == ""


def _ref(key: str, title: str, kind: str = "temple", source: str = "pleiades") -> ca.Ref:
    return ca.Ref(
        source=source,
        key=key,
        title=title,
        kind=kind,
        names=[ca.tokens(title)],
        earliest=-300,
        point=(0.0, 0.0),
        precise=True,
        feature_types=["temple-2"],
    )


def test_matching_by_id_name_and_curation() -> None:
    ds = ca.Dataset(
        recs={
            "aedes_saturni": {
                "id": "aedes_saturni",
                "latin": "Aedes Saturni",
                "type": "temple",
                "lat": ca.ORIGIN_LAT,
                "lon": ca.ORIGIN_LON,
                "pleiades": 1,
            },
            "aedes_castoris": {
                "id": "aedes_castoris",
                "latin": "Aedes Castoris",
                "type": "temple",
                "lat": ca.ORIGIN_LAT,
                "lon": ca.ORIGIN_LON,
            },
        },
        empire=set(),
        streets={},
        topo={},
        timeline=[],
    )
    tg = ca.targets(ds)
    refs = [
        _ref("1", "Temple of Saturn"),
        _ref("2", "Castor, aedes"),
        _ref("3", "Vesta, aedes"),
        _ref("4", "tribus Pollia"),
    ]
    refs[3].feature_types = ["tribus"]
    curated = {"pleiades": {"3": {"skip": "test"}}}
    v = {x.ref.key: x for x in ca.match_refs(refs, tg, curated)}
    assert v["1"].status == "matched" and v["1"].how == "pleiades id"
    assert v["2"].status == "matched" and v["2"].targets == ["aedes_castoris"]
    assert v["3"].status == "excluded" and v["3"].reason == "test"
    assert v["4"].status == "excluded"


def test_audit_runs_on_the_real_data_without_network() -> None:
    a = ca.run_audit(scene={}, events="")
    s = a.summary()
    assert s["dataset"]["monuments"] > 100
    assert s["references"]["pleiades"]["matched"] > 50
    names = {r.name for r in a.relations}
    assert "Saturn at the foot of the Clivus Capitolinus" in names
    md = ca.render_markdown(a)
    assert "## 1. Completeness" in md and "## 4. Time" in md
    js = ca.audit_json(a)
    assert js["summary"]["missing"] == len(js["missing"])
    # every standard year has a count
    assert set(a.counts) == {ca._yr(y) for y in ca.COUNT_YEARS}


def test_curated_references_name_real_records() -> None:
    """Every id the curated file names exists, so a rename cannot hide a missing monument."""
    ds = ca.load_dataset()
    tg = ca.targets(ds)
    refs = ca.load_references()
    for source in ("pleiades", "platner"):
        for key, verdict in ((refs.get("verdicts") or {}).get(source) or {}).items():
            assert isinstance(verdict, dict), key
            assert verdict.get("match") or verdict.get("skip") or verdict.get("missing"), key
            ids = verdict.get("match") or []
            for mid in ids if isinstance(ids, list) else [ids]:
                assert mid in tg, (key, mid)
    for mid in refs.get("measured") or {}:
        assert mid in ds.recs, mid
