"""Measured audit of the city of Rome dataset (F2): is everything there, and in the right place?

``uv run anachronism-city-audit`` reads the dataset (``data/rome/city``), the reference extracts
(``data/rome/sources``: Pleiades, CC BY; Platner-Ashby, public domain) and the curated verdicts
(``data/rome/sources/references.yaml``), and writes ``docs/reports/city_audit.md`` (for people)
and ``data/rome/city/audit.json`` (for tools). Sections:

1. Completeness: every Pleiades place within 3.5 km of the Forum with a period before AD 120, and
   every Platner-Ashby entry of a building kind with a date or reign before AD 120, matched to a
   dataset record (by Pleiades id, by the record's ``Platner-Ashby s.v.`` citations, by names) or
   explained in ``references.yaml``; the rest are **missing**, ranked by importance.
2. Position: our placed centre (``lat``/``lon`` plus ``offset_m``, as ``monuments.gd`` places it)
   against the Pleiades location, flagged over 20 m (10 m in the Forum and on the Capitol);
   orientation and size against the published measurements in ``references.yaml``, and against
   the outline of the remains where Pleiades has one; the relations the sources fix.
3. Placement in the built scene: what the Godot audit (``client/scripts/urbs/audit.gd``, run
   with ``--scene``) found overlapping, buried, floating, in the river or under a street.
4. Time: dates against the game's timeline (``rome/city_timeline.yaml``) and the counts standing
   in the standard years.

``--refresh`` downloads the references again (network) and rewrites the extracts.
"""

from __future__ import annotations

import argparse
import gzip
import html
import io
import json
import math
import re
import subprocess
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from collections import Counter
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[3]
CITY = ROOT / "data" / "rome" / "city"
SOURCES = ROOT / "data" / "rome" / "sources"
TIMELINE = ROOT / "src" / "anachronism" / "content" / "packs" / "rome" / "city_timeline.yaml"
PACKS = ROOT / "src" / "anachronism" / "content" / "packs" / "rome"
REPORT = ROOT / "docs" / "reports" / "city_audit.md"
AUDIT_JSON = CITY / "audit.json"
SCENE_JSON = ROOT / "docs" / "reports" / "city_scene_audit.json"
PLEIADES_FILE = SOURCES / "pleiades_rome.json"
PLATNER_FILE = SOURCES / "platner_ashby.json"
REFERENCES_FILE = SOURCES / "references.yaml"

# --- the frame (client/scripts/urbs/geo.gd: keep in step) -----------------------------------
ORIGIN_LAT = 41.8925
ORIGIN_LON = 12.4853
M_PER_DEG_LAT = 111_132.0
M_PER_DEG_LON = 82_850.0

RADIUS_M = 3500.0
"""Reference places within this distance of the Forum are audited."""
LAST_YEAR = 120
"""The dataset runs to about AD 120."""
SCENE_YEARS = (-509, -390, -264, -133, -44, -27)
COUNT_YEARS = (-509, -390, -264, -133, -44, -27, 80, 120)
FAR_TOL_M = 20.0
NEAR_TOL_M = 10.0
"""Position tolerance: 10 m in the Forum and on the Capitol, 20 m elsewhere."""
BEARING_TOL = 10.0
SIZE_TOL = 0.15

# Pleiades: the reference for places; the outline of the remains where it has one.
PLEIADES_DUMP = "https://atlantides.org/downloads/pleiades/dumps/pleiades-places-latest.csv.gz"
PLEIADES_PLACE = "https://pleiades.stoa.org/places/{}/json"
# Platner-Ashby on LacusCurtius (public domain text).
LACUS = "https://penelope.uchicago.edu/Thayer/"
PA_DIR = "E/Gazetteer/Places/Europe/Italy/Lazio/Roma/Rome/_Texts/PLATOP*/"


# =============================================================================================
# The frame and the placement (a port of UrbsGeo and UrbsMonuments._make)
# =============================================================================================


def to_local(lat: float, lon: float) -> tuple[float, float]:
    """Local (x east, z south) metres of a WGS84 point, as ``UrbsGeo.to_local``."""
    return ((lon - ORIGIN_LON) * M_PER_DEG_LON, -(lat - ORIGIN_LAT) * M_PER_DEG_LAT)


def to_latlon(x: float, z: float) -> tuple[float, float]:
    """WGS84 (lat, lon) of a local point, as ``UrbsGeo.to_latlon``."""
    return (ORIGIN_LAT - z / M_PER_DEG_LAT, ORIGIN_LON + x / M_PER_DEG_LON)


def placed_centre(rec: dict[str, Any], recs: dict[str, dict[str, Any]]) -> tuple[float, float]:
    """Where ``monuments.gd`` puts a monument's centre, local metres.

    ``place_like`` (or ``twin_of``) borrows another record's point; ``offset_m`` is ``[east,
    north]`` metres added to the point. The Servian gates are threaded on the wall through their
    own points, so they stand at their own point too.
    """
    like = recs.get(str(rec.get("place_like", rec.get("twin_of", ""))), rec)
    x, z = to_local(float(like["lat"]), float(like["lon"]))
    off = like.get("offset_m")
    if isinstance(off, list) and len(off) >= 2:
        x += float(off[0])
        z -= float(off[1])
    return (x, z)


def placed_bearing(rec: dict[str, Any], recs: dict[str, dict[str, Any]]) -> float | None:
    """The compass bearing the monument's front faces, as placed (``None`` when not given)."""
    like = recs.get(str(rec.get("place_like", rec.get("twin_of", ""))), rec)
    b = like.get("bearing_deg")
    return float(b) if isinstance(b, int | float) else None


def footprint(rec: dict[str, Any]) -> tuple[float, float] | None:
    """(length, width) of the footprint in metres (a radius gives a square of its diameter)."""
    fp = rec.get("footprint_m")
    if not isinstance(fp, dict):
        return None
    r = fp.get("radius")
    if isinstance(r, int | float) and r > 0 and not fp.get("length"):
        return (2.0 * float(r), 2.0 * float(r))
    ln, wd = fp.get("length"), fp.get("width")
    if isinstance(ln, int | float) and isinstance(wd, int | float) and ln > 0 and wd > 0:
        return (float(ln), float(wd))
    return None


def dist(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Distance between two local points."""
    return math.hypot(a[0] - b[0], a[1] - b[1])


def bearing_between(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Compass bearing from local point a to b (0 north, 90 east)."""
    return math.degrees(math.atan2(b[0] - a[0], -(b[1] - a[1]))) % 360.0


def angle_diff(a: float, b: float, period: float = 360.0) -> float:
    """Smallest difference between two angles (degrees) modulo ``period``."""
    d = (a - b) % period
    return min(d, period - d)


# =============================================================================================
# Geometry helpers
# =============================================================================================


def convex_hull(points: Sequence[tuple[float, float]]) -> list[tuple[float, float]]:
    """Convex hull (monotone chain), counter-clockwise, no repeated point."""
    pts = sorted(set(points))
    if len(pts) <= 2:
        return list(pts)

    def cross(o: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower: list[tuple[float, float]] = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper: list[tuple[float, float]] = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


@dataclass(frozen=True)
class Box:
    """An oriented rectangle in local metres: centre, long-axis bearing (0-180), long, short."""

    cx: float
    cz: float
    axis: float
    long: float
    short: float


def min_area_box(points: Sequence[tuple[float, float]]) -> Box | None:
    """The smallest-area rectangle round local points (rotating over the hull's edges)."""
    hull = convex_hull(points)
    if len(hull) < 3:
        return None
    best: tuple[float, Box] | None = None
    n = len(hull)
    for i in range(n):
        ax, az = hull[i]
        bx, bz = hull[(i + 1) % n]
        ex, ez = bx - ax, bz - az
        ln = math.hypot(ex, ez)
        if ln < 1e-9:
            continue
        ux, uz = ex / ln, ez / ln
        vx, vz = -uz, ux
        us = [p[0] * ux + p[1] * uz for p in hull]
        vs = [p[0] * vx + p[1] * vz for p in hull]
        du, dv = max(us) - min(us), max(vs) - min(vs)
        area = du * dv
        if best is None or area < best[0] - 1e-9:
            mu, mv = (max(us) + min(us)) / 2.0, (max(vs) + min(vs)) / 2.0
            cx, cz = mu * ux + mv * vx, mu * uz + mv * vz
            if du >= dv:
                axis = math.degrees(math.atan2(ux, -uz)) % 180.0
                long, short = du, dv
            else:
                axis = math.degrees(math.atan2(vx, -vz)) % 180.0
                long, short = dv, du
            best = (area, Box(cx, cz, axis, long, short))
    return best[1] if best else None


def seg_dist(p: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
    """Distance from p to segment ab."""
    ex, ez = b[0] - a[0], b[1] - a[1]
    ll = ex * ex + ez * ez
    t = 0.0 if ll <= 0 else max(0.0, min(1.0, ((p[0] - a[0]) * ex + (p[1] - a[1]) * ez) / ll))
    return math.hypot(p[0] - a[0] - ex * t, p[1] - a[1] - ez * t)


def line_dist(p: tuple[float, float], line: Sequence[tuple[float, float]]) -> float:
    """Distance from p to a polyline."""
    if len(line) == 1:
        return dist(p, line[0])
    return min(seg_dist(p, line[i - 1], line[i]) for i in range(1, len(line)))


def inside(p: tuple[float, float], poly: Sequence[tuple[float, float]]) -> bool:
    """Point in polygon (even-odd)."""
    res = False
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        if (a[1] > p[1]) != (b[1] > p[1]):
            x = a[0] + (p[1] - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
            if p[0] < x:
                res = not res
    return res


def simplify(line: Sequence[tuple[float, float]], tol: float) -> list[tuple[float, float]]:
    """Douglas-Peucker simplification of a polyline (local metres)."""
    if len(line) < 3:
        return list(line)
    dmax, idx = 0.0, 0
    for i in range(1, len(line) - 1):
        d = seg_dist(line[i], line[0], line[-1])
        if d > dmax:
            dmax, idx = d, i
    if dmax <= tol:
        return [line[0], line[-1]]
    return simplify(line[: idx + 1], tol)[:-1] + simplify(line[idx:], tol)


# =============================================================================================
# Names
# =============================================================================================

GENERIC = {
    "aedes",
    "templum",
    "delubrum",
    "fanum",
    "sacellum",
    "sacrarium",
    "aedicula",
    "aediculae",
    "ara",
    "arae",
    "lucus",
    "luci",
    "basilica",
    "porticus",
    "arcus",
    "fornix",
    "porta",
    "pons",
    "aqua",
    "via",
    "vicus",
    "clivus",
    "statua",
    "signum",
    "sacrum",
    "templa",
    "aedis",
    "in",
    "ad",
    "de",
    "et",
    "of",
    "the",
    "and",
    "on",
    "at",
    "to",
    "temple",
    "altar",
    "shrine",
    "grove",
    "gate",
    "bridge",
    "arch",
    "portico",
    "street",
    "statue",
    "hill",
    "house",
    "domus",
    "sepulcrum",
    "tomb",
    "mons",
    "s",
    "v",
    "aedem",
    "aede",
    "templo",
    "deae",
    "dei",
    "divi",
    "diuus",
    "diui",
    "divus",
    "atrium",
    "area",
    "campus",
    "forum",
    "theatrum",
    "circus",
    "thermae",
    "horrea",
    "curia",
    "columna",
    "rostra",
    "carcer",
    "aquae",
    "rome",
    "roman",
    "romanum",
    "romana",
    "great",
    "old",
    "new",
    "first",
    "second",
    "so",
    "called",
    "casa",
    "tugurium",
    "hut",
    "aula",
}
"""Words that say what kind of thing it is, not which one (dropped from name matching)."""

KIND_WORDS: dict[str, str] = {
    "aedes": "temple",
    "templum": "temple",
    "delubrum": "temple",
    "fanum": "temple",
    "sacellum": "shrine",
    "sacrarium": "shrine",
    "aedicula": "shrine",
    "sacrum": "shrine",
    "puteal": "shrine",
    "compitum": "shrine",
    "lapis": "shrine",
    "mundus": "shrine",
    "tigillum": "shrine",
    "volcanal": "shrine",
    "lupercal": "shrine",
    "ara": "altar",
    "arae": "altar",
    "lucus": "grove",
    "nemus": "grove",
    "basilica": "basilica",
    "porticus": "portico",
    "arcus": "arch",
    "fornix": "arch",
    "porta": "gate",
    "pons": "bridge",
    "aqua": "aqueduct",
    "anio": "aqueduct",
    "via": "street",
    "vicus": "street",
    "clivus": "street",
    "semita": "street",
    "scalae": "street",
    "gradus": "street",
    "statua": "statue",
    "statuae": "statue",
    "signum": "statue",
    "equus": "statue",
    "colossus": "statue",
    "columna": "statue",
    "curia": "building",
    "comitium": "building",
    "rostra": "building",
    "tabularium": "building",
    "carcer": "building",
    "atrium": "building",
    "regia": "building",
    "macellum": "building",
    "horrea": "building",
    "navalia": "building",
    "emporium": "building",
    "theatrum": "building",
    "circus": "building",
    "stadium": "building",
    "amphitheatrum": "building",
    "thermae": "building",
    "balneum": "building",
    "castra": "building",
    "saepta": "building",
    "septa": "building",
    "diribitorium": "building",
    "ovile": "building",
    "forum": "building",
    "graecostasis": "building",
    "senaculum": "building",
    "odeum": "building",
    "naumachia": "building",
    "nymphaeum": "fountain",
    "lacus": "fountain",
    "fons": "fountain",
    "meta": "fountain",
    "domus": "house",
    "sepulcrum": "tomb",
    "mausoleum": "tomb",
    "tumulus": "tomb",
    "murus": "wall",
    "agger": "wall",
    "cloaca": "sewer",
    "villa": "building",
    "mica": "building",
    "schola": "building",
    "tribunal": "building",
    "puticuli": "tomb",
    "ianus": "arch",
    "obeliscus": "statue",
    "horologium": "statue",
    "solarium": "statue",
    "mensa": "building",
    "tabernae": "building",
    "insula": "house",
    "aedes_": "temple",
    "ficus": "statue",
    "doliola": "shrine",
    "busta": "tomb",
    "bustum": "tomb",
    "pila": "statue",
    "tropaea": "statue",
    "trophaea": "statue",
    "lautumiae": "building",
    "piscina": "fountain",
    "sacra": "street",
}

KIND_OF_TYPE: dict[str, str] = {
    "temple": "temple",
    "shrine": "shrine",
    "altar": "altar",
    "grove": "grove",
    "basilica": "basilica",
    "portico": "portico",
    "arch": "arch",
    "gate": "gate",
    "bridge": "bridge",
    "aqueduct": "aqueduct",
    "road": "street",
    "street": "street",
    "statue": "statue",
    "column": "statue",
    "obelisk": "statue",
    "monument": "statue",
    "fountain": "fountain",
    "basin": "fountain",
    "house": "house",
    "tomb": "tomb",
    "wall": "wall",
    "sewer": "sewer",
}
"""Dataset ``type`` to the audit's kind (everything else is a ``building``)."""

ALIASES = {
    "iouis": "iuppiter",
    "iou": "iuppiter",
    "iuppiter": "iuppiter",
    "iupiter": "iuppiter",
    "jupiter": "iuppiter",
    "opis": "ops",
    "ops": "ops",
    "mars": "mars",
    "martis": "mars",
    "dioscuri": "castor",
    "castores": "castor",
    "castorum": "castor",
    "pollux": "castor",
    "pollucis": "castor",
    "hercules": "hercules",
    "hercle": "hercules",
    "minerva": "minerva",
    "athena": "minerva",
    "neptune": "neptunus",
    "vesta": "uesta",
    "juno": "iuno",
    "saturn": "saturnus",
    "concord": "concordia",
    "victory": "uictoria",
    "hope": "spes",
    "faith": "fides",
    "honour": "honos",
    "virtue": "uirtus",
    "piety": "pietas",
    "safety": "salus",
    "fortune": "fortuna",
    "health": "salus",
    "earth": "tellus",
    "moon": "luna",
    "sun": "sol",
    "peace": "pax",
    "liberty": "libertas",
    "mercury": "mercurius",
    "vulcan": "uolcanus",
    "volcanus": "uolcanus",
    "vulcanus": "uolcanus",
    "bellona": "bellona",
    "quirinus": "quirinus",
    "janus": "ianus",
}


def fold(s: str) -> str:
    """Lowercase ASCII with Latin i/j and u/v folded, punctuation to spaces."""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    s = s.replace("j", "i").replace("v", "u")
    return re.sub(r"[^a-z0-9]+", " ", s).strip()


def tokens(name: str) -> list[str]:
    """The name tokens of a name: folded, generic kind words dropped, aliases resolved."""
    out: list[str] = []
    for t in fold(name).split():
        if len(t) < 2 or t.isdigit() or fold_generic(t):
            continue
        out.append(ALIASES.get(t, ALIASES.get(t.replace("u", "v"), t)))
    return out


_GENERIC_FOLDED = {fold(g) for g in GENERIC}


def fold_generic(t: str) -> bool:
    """Whether a folded token is a generic word."""
    return t in _GENERIC_FOLDED


def tok_eq(a: str, b: str) -> bool:
    """Two Latin name tokens are the same word (allowing case endings)."""
    if a == b:
        return True
    if min(len(a), len(b)) < 4:
        return False
    n = 0
    for x, y in zip(a, b, strict=False):
        if x != y:
            break
        n += 1
    return n >= max(4, min(len(a), len(b)) - 2)


def names_match(a: Sequence[str], b: Sequence[str]) -> bool:
    """The two names have the same words (allowing case endings), at least one."""
    if not a or not b:
        return False
    return all(any(tok_eq(s, t) for t in b) for s in a) and all(
        any(tok_eq(s, t) for t in a) for s in b
    )


TEXT_KINDS: list[tuple[str, str]] = [
    (r"temple|aedes|templum|delubrum", "temple"),
    (r"shrine|sacellum|sacrarium|chapel|sanctuary|aedicula|sacred spot|lararium", "shrine"),
    (r"altars?\b|\bara\b", "altar"),
    (r"grove|lucus", "grove"),
    (r"basilica", "basilica"),
    (r"portico|porticus|colonnade", "portico"),
    (r"\barch\b|arcus|fornix|ianus", "arch"),
    (r"\bgate\b|porta\b", "gate"),
    (r"bridge|\bpons\b", "bridge"),
    (r"aqueduct", "aqueduct"),
    (r"street|road|\bvicus\b|clivus|\bway\b|stairway|flight of steps", "street"),
    (r"statue|column|obelisk|equestrian|colossus|bronze figure|monument", "statue"),
    (r"fountain|spring|basin|nymphaeum|pool|lacus", "fountain"),
    (r"tomb|sepulchre|sepulcrum|mausoleum|burial", "tomb"),
    (r"\bhouse\b|\bdomus\b|residence", "house"),
    (
        r"building|\bhall\b|market|storehouse|granar|warehouse|barracks|theatre|baths|"
        r"circus|stadium|amphitheatre|prison|curia|senate|office|school|camp|quarters",
        "building",
    ),
]


def kind_of_text(text: str) -> str:
    """The kind a P-A entry's first words give it ("a temple of ..." -> temple)."""
    first = text[:160].lower()
    best = ("other", 10**6)
    for pattern, kind in TEXT_KINDS:
        m = re.search(pattern, first)
        if m and m.start() < best[1]:
            best = (kind, m.start())
    return best[0]


def kind_of_heading(head: str) -> str:
    """The audit's kind of a Platner-Ashby heading ("Castor, aedes" -> temple)."""
    words = fold(head).split()
    # the heading's last comma-part names the kind in P-A's style ("Castor, aedes")
    parts = [fold(p) for p in head.split(",")]
    for part in reversed(parts):
        for w in part.split():
            if w in KIND_WORDS:
                return KIND_WORDS[w]
    for w in words:
        if w in KIND_WORDS:
            return KIND_WORDS[w]
    return "other"


def kind_of_record(rec: dict[str, Any]) -> str:
    """The audit's kind of a dataset record."""
    return KIND_OF_TYPE.get(str(rec.get("type", "")), "building")


COMPATIBLE: dict[str, set[str]] = {
    "temple": {"temple", "shrine"},
    "shrine": {"shrine", "temple", "altar", "grove", "statue", "fountain"},
    "altar": {"altar", "shrine"},
    "grove": {"grove", "shrine"},
    "statue": {"statue", "shrine", "arch"},
    "arch": {"arch", "statue", "gate"},
    "gate": {"gate", "arch"},
    "fountain": {"fountain", "shrine"},
    "building": {"building", "portico", "basilica"},
    "house": {"house"},
    "portico": {"portico", "building"},
    "basilica": {"basilica", "building"},
}


def kinds_fit(a: str, b: str) -> bool:
    """Whether a reference kind and a record kind can be the same thing."""
    return a == b or b in COMPATIBLE.get(a, set()) or a in COMPATIBLE.get(b, set())


# =============================================================================================
# The dataset
# =============================================================================================


@dataclass
class Dataset:
    """Everything the audit reads from ``data/rome/city`` and the timeline."""

    recs: dict[str, dict[str, Any]]
    empire: set[str]
    streets: dict[str, dict[str, Any]]
    topo: dict[str, Any]
    timeline: list[dict[str, Any]]
    regions: dict[str, Any] = field(default_factory=dict)


def load_dataset(city: Path = CITY, timeline: Path = TIMELINE) -> Dataset:
    """Read the monuments, streets, topography, regions and the timeline."""

    def load(name: str) -> Any:
        path = city / name
        return yaml.safe_load(path.read_text(encoding="utf-8")) if path.exists() else {}

    recs: dict[str, dict[str, Any]] = {}
    empire: set[str] = set()
    # monuments.yaml first, then every other monuments_*.yaml (the Empire, the great houses...)
    names = ["monuments.yaml", *sorted(p.name for p in city.glob("monuments_*.yaml"))]
    for name in names:
        for m in (load(name) or {}).get("monuments", []) or []:
            recs[str(m["id"])] = m
            if "empire" in name:
                empire.add(str(m["id"]))
    streets = {str(s["id"]): s for s in (load("streets.yaml") or {}).get("streets", [])}
    tl: list[dict[str, Any]] = []
    if timeline.exists():
        tl = (yaml.safe_load(timeline.read_text(encoding="utf-8")) or {}).get("city_timeline", [])
    return Dataset(recs, empire, streets, load("topography.yaml") or {}, tl, load("regions.yaml"))


def record_names(rec: dict[str, Any]) -> list[list[str]]:
    """Every name a record goes by, as token lists: latin, english, aka and its P-A s.v. titles."""
    out: list[list[str]] = []
    for key in ("latin", "english"):
        if rec.get(key):
            out.append(tokens(str(rec[key])))
    for alt in rec.get("aka", []) or []:
        out.append(tokens(str(alt)))
    for title in pa_titles(rec):
        out.append(tokens(title))
    return [t for t in out if t]


_SV = re.compile(r"(?:Platner-Ashby|P-A|P&A)\s+s\.\s?v\.\s+([^;:()\"\]]+)")


def pa_titles(rec: dict[str, Any]) -> list[str]:
    """The Platner-Ashby entries a record names as its own source.

    Only items of ``sources`` that begin "Platner-Ashby s.v. ..." count: a citation inside a
    note may be of a neighbour.
    """
    out: list[str] = []
    for src in rec.get("sources", []) or []:
        m = re.match(r"\s*(?:Platner-Ashby|P-A|P&A)\s+s\.\s?v\.\s+([^;:()\"\]]+)", str(src))
        if not m:
            continue
        t = m.group(1).strip().rstrip(".,")
        for piece in re.split(r"\s+and\s+|;", t):
            if piece.strip():
                out.append(piece.strip())
    return out


# =============================================================================================
# The references: loading, and refreshing them from the network
# =============================================================================================


def load_json(path: Path) -> Any:
    """A JSON file, or an empty dict when absent."""
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def load_references(path: Path = REFERENCES_FILE) -> dict[str, Any]:
    """The curated verdicts and measurements (``references.yaml``)."""
    if not path.exists():
        return {}
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def _get(url: str, retries: int = 3) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "anachronism-city-audit"})
    for i in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                data: bytes = r.read()
                return data
        except OSError:
            if i == retries - 1:
                raise
            time.sleep(2.0 * (i + 1))
    raise OSError(url)


def _geometry_points(g: dict[str, Any]) -> list[list[tuple[float, float]]]:
    """The (lon, lat) point lists of a GeoJSON geometry, one list per part."""
    t, c = g.get("type"), g.get("coordinates")
    if not c:
        return []
    if t == "Point":
        return [[(float(c[0]), float(c[1]))]]
    if t in ("LineString", "MultiPoint"):
        return [[(float(p[0]), float(p[1])) for p in c]]
    if t in ("MultiLineString", "Polygon"):
        return [[(float(p[0]), float(p[1])) for p in part] for part in c]
    if t == "MultiPolygon":
        return [[(float(p[0]), float(p[1])) for p in ring] for poly in c for ring in poly]
    return []


def extract_pleiades_place(
    row: dict[str, str], place: dict[str, Any], linear: bool
) -> dict[str, Any]:
    """The trimmed record of one Pleiades place.

    Names, periods, and per location its accuracy and its hull (for areas) or simplified line
    (for streets, walls and aqueducts), in WGS84.
    """
    names = sorted(
        {
            str(n.get(k) or "").strip()
            for n in place.get("names", [])
            for k in ("romanized", "attested")
            if n.get(k)
        }
        | {str(place.get("title", "")).strip()}
    )
    locs: list[dict[str, Any]] = []
    for loc in place.get("locations", []):
        g = loc.get("geometry") or {}
        parts = _geometry_points(g)
        if not parts:
            continue
        local = [[to_local(lat, lon) for lon, lat in part] for part in parts]
        entry: dict[str, Any] = {
            "title": loc.get("title", ""),
            "accuracy_m": loc.get("accuracy_value"),
            "geometry": g.get("type"),
            "review_state": loc.get("review_state"),
        }
        if linear and g.get("type") != "Point":
            lines = [simplify(part, 2.0) for part in local if len(part) >= 2]
            entry["lines"] = [
                [[round(a, 7) for a in to_latlon(x, z)] for x, z in line] for line in lines
            ]
        else:
            flat = [p for part in local for p in part]
            hull = convex_hull(flat) if len(flat) > 2 else flat
            entry["hull"] = [[round(a, 7) for a in to_latlon(x, z)] for x, z in hull]
        locs.append(entry)
    return {
        "id": row["id"],
        "title": row["title"],
        "names": [n for n in names if n],
        "feature_types": [t.strip() for t in row["featureTypes"].split(",") if t.strip()],
        "periods": [t.strip() for t in row["timePeriodsKeys"].split(",") if t.strip()],
        "min_date": int(float(row["minDate"])) if row["minDate"] else None,
        "max_date": int(float(row["maxDate"])) if row["maxDate"] else None,
        "precision": row["locationPrecision"],
        "repr": [round(float(row["reprLat"]), 7), round(float(row["reprLong"]), 7)],
        "description": str(place.get("description", ""))[:300],
        "locations": locs,
    }


LINEAR_TYPES = {"road", "street", "aqueduct", "city-wall", "wall", "river", "canal", "earthwork"}


def refresh_pleiades(dest: Path = PLEIADES_FILE, cache: Path | None = None) -> int:
    """Download Pleiades and write the trimmed extract; returns the number of places kept.

    Kept: places whose representative point is within ``RADIUS_M`` of the Forum and whose
    earliest period starts before AD 120. ``cache`` keeps the per-place JSON between runs.
    """
    import csv

    csv.field_size_limit(10**9)
    raw = gzip.decompress(_get(PLEIADES_DUMP)).decode("utf-8")
    kept: list[dict[str, Any]] = []
    for row in csv.DictReader(io.StringIO(raw)):
        try:
            lat, lon = float(row["reprLat"]), float(row["reprLong"])
        except ValueError:
            continue
        if math.hypot(*to_local(lat, lon)) > RADIUS_M:
            continue
        if not row["minDate"] or float(row["minDate"]) >= LAST_YEAR:
            continue
        path = cache / f"{row['id']}.json" if cache else None
        if path is not None and path.exists():
            place = json.loads(path.read_text(encoding="utf-8"))
        else:
            place = json.loads(_get(PLEIADES_PLACE.format(row["id"])))
            if path is not None:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(place), encoding="utf-8")
            time.sleep(0.3)
        if "locations" not in place:  # a withdrawn place's redirect
            continue
        linear = bool({t.strip() for t in row["featureTypes"].split(",")} & LINEAR_TYPES)
        kept.append(extract_pleiades_place(row, place, linear))
    kept.sort(key=lambda p: int(p["id"]))
    doc = {
        "source": "Pleiades: A Gazetteer of Past Places, https://pleiades.stoa.org",
        "licence": "CC BY 3.0 (attribution: the Pleiades contributors named on each place page)",
        "dump": PLEIADES_DUMP,
        "retrieved": time.strftime("%Y-%m-%d"),
        "filter": f"representative point within {RADIUS_M:.0f} m of the Forum ({ORIGIN_LAT} N "
        f"{ORIGIN_LON} E); earliest period before AD {LAST_YEAR}",
        "places": kept,
    }
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return len(kept)


# --- Platner-Ashby ---------------------------------------------------------------------------

_PA_ENTRY = re.compile(r'<SPAN CLASS="(?:entry|bold smallcaps)">\s*(.*?)\s*</SPAN>', re.S | re.I)
_YEAR_BC = re.compile(r"\b(\d{1,4})\s*B\.\s?C\b")
_YEAR_AD = re.compile(r"\bA\.\s?D\.\s*(\d{1,4})\b|\b(\d{1,4})\s*A\.\s?D\b")
_CENTURY = re.compile(r"\b(first|second|third|fourth|fifth|sixth)\s+century\s+B\.\s?C", re.I)
RULERS: dict[str, int] = {
    "Romulus": -753,
    "Numa": -715,
    "Tullus Hostilius": -673,
    "Ancus": -640,
    "Tarquinius Priscus": -616,
    "Servius Tullius": -578,
    "Tarquinius Superbus": -534,
    "Tarquin": -534,
    "Camillus": -396,
    "Sulla": -82,
    "Pompeius": -55,
    "Pompey": -55,
    "Caesar": -46,
    "Augustus": -27,
    "Agrippa": -27,
    "Tiberius": 14,
    "Caligula": 37,
    "Claudius": 41,
    "Nero": 54,
    "Vespasian": 69,
    "Titus": 79,
    "Domitian": 81,
    "Nerva": 96,
    "Trajan": 98,
    "Hadrian": 117,
    "Antoninus": 138,
    "Marcus Aurelius": 161,
    "Severus": 193,
    "Caracalla": 211,
    "Aurelian": 270,
    "Diocletian": 284,
    "Constantine": 306,
}
_ANCIENT = re.compile(
    r"\b(Liv|Livy|Cic|Varro|Dionys|Dion|Plin|Ov|Suet|Cass\. Dio|Dio|Tac|Fest|Serv|Macrob|Plut|"
    r"Vitr|App|Gell|Mart|Iuv|Juv|Prop|Hor|Verg|Sen|Val\. Max|Strabo|Frontin|Front|Not|Cur|"
    r"Mon\. Anc|Res Gestae|Asc|Sall|Vell|Polyb|Obseq|Fast|Hemerol|CIL|Eutrop|Oros|Hist\. Aug|"
    r"Solin|Paul\. ex Fest|Paulus|Gell|Lucan|Stat|Plaut|Ter|Enn|Cato)\.?\s",
)


def _pa_clean(s: str) -> str:
    s = re.sub(r'on(?:MouseOver|MouseOut)="[^"]*"', " ", s, flags=re.I)
    s = re.sub(r'<SPAN CLASS="pagenum">.*?</SPAN>', " ", s, flags=re.S | re.I)
    s = re.sub(r"<[^>]+>", " ", s)
    s = html.unescape(s).replace("\xa0", " ")
    return re.sub(r"\s+", " ", s).strip()


def pa_years(text: str) -> list[int]:
    """Years named in a P-A text: BC as negative, AD as positive, rulers by their first year."""
    years = [-int(m.group(1)) for m in _YEAR_BC.finditer(text) if int(m.group(1)) < 1000]
    for m in _YEAR_AD.finditer(text):
        y = int(m.group(1) or m.group(2))
        if 0 < y < 1600:
            years.append(y)
    for m in _CENTURY.finditer(text):
        n = ["first", "second", "third", "fourth", "fifth", "sixth"].index(m.group(1).lower())
        years.append(-100 * (n + 1))
    for name, y in RULERS.items():
        if re.search(r"\b" + name + r"\b", text):
            years.append(y)
    return sorted(set(years))


def parse_platner_page(page: str, text: str) -> list[dict[str, Any]]:
    """The entries of one LacusCurtius P-A page: heading, anchor, text."""
    body = text.split("</H4>", 2)[-1] if "</H4>" in text else text
    out: list[dict[str, Any]] = []
    ms = list(_PA_ENTRY.finditer(body))
    for i, m in enumerate(ms):
        end = ms[i + 1].start() if i + 1 < len(ms) else len(body)
        chunk = body[m.end() : end]
        chunk = re.split(r"<HR\b|<TABLE CLASS=\"footer", chunk, maxsplit=1, flags=re.I)[0]
        content = _pa_clean(chunk)
        head = _pa_clean(m.group(1)).rstrip(":").strip()
        ids = re.findall(r'ID="([^"]+)"', body[max(0, m.start() - 600) : m.start()])
        if re.match(r"^(see separate page|see\b)", content) and len(content) < 160:
            continue
        out.append({"head": head, "page": page, "anchor": ids[-1] if ids else "", "text": content})
    return out


def refresh_platner(dest: Path = PLATNER_FILE, cache: Path | None = None) -> int:
    """Crawl Platner-Ashby on LacusCurtius and write the entries of the kinds the city needs."""
    seen: set[str] = set()
    todo = ["home.html"]
    pages: dict[str, str] = {}
    while todo:
        nxt: list[str] = []
        for page in todo:
            if page in seen:
                continue
            seen.add(page)
            path = cache / page.replace("/", "__") if cache else None
            if path is not None and path.exists():
                text = path.read_text(encoding="utf-8", errors="replace")
            else:
                try:
                    url = LACUS + PA_DIR.replace("*", "%2A") + urllib.parse.quote(page)
                    text = _get(url).decode("utf-8", errors="replace")
                except OSError:
                    continue
                if path is not None:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(text, encoding="utf-8")
                time.sleep(0.25)
            pages[page] = text
            for link in re.findall(r'(?is)href\s*=\s*"\s*([^"]+)"', text):
                link = link.strip().split("#")[0]
                if "PLATOP*/" in link and link.endswith(".html"):
                    nxt.append(link.split("PLATOP*/", 1)[1])
        todo = [p for p in nxt if p not in seen]
    entries: list[dict[str, Any]] = []
    for page in sorted(pages):
        if page == "home.html":
            continue
        entries.extend(parse_platner_page(page, pages[page]))
    kept = dedupe_platner([summarise_platner(e) for e in entries])
    kept = [e for e in kept if e["in_scope"]]
    doc = {
        "source": "S. B. Platner and T. Ashby, A Topographical Dictionary of Ancient Rome "
        "(Oxford 1929), as transcribed on LacusCurtius by Bill Thayer",
        "licence": "public domain",
        "url": LACUS + PA_DIR + "home.html",
        "retrieved": time.strftime("%Y-%m-%d"),
        "filter": "entries of a building kind (temple, shrine, altar, grove, basilica, portico, "
        "arch, gate, bridge, aqueduct, street, statue, public building, fountain, tomb, wall) "
        f"whose text names a year or reign before AD {LAST_YEAR}, or cites an author writing "
        "before then; text cut at 900 characters",
        "entries": kept,
    }
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return len(kept)


def dedupe_platner(entries: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """LacusCurtius serves some pages under two spellings (statuae, Statuae): keep one of each."""
    seen: set[tuple[str, str]] = set()
    out: list[dict[str, Any]] = []
    for e in entries:
        k = (fold(str(e["head"])), str(e["text"])[:200])
        if k in seen:
            continue
        seen.add(k)
        out.append(e)
    return out


EARLY_AUTHORS = re.compile(
    r"\b(Liv|Cic|Varro|Dionys|Ov|Plaut|Fest|Vitr|Prop|Hor|Verg|Asc|Sall|Vell|Polyb|Cato|Enn|"
    r"Mon\. Anc|Strabo|Fast|Hemerol)\.?\s"
)
SCOPE_KINDS = {
    "temple",
    "shrine",
    "altar",
    "grove",
    "basilica",
    "portico",
    "arch",
    "gate",
    "bridge",
    "aqueduct",
    "street",
    "statue",
    "building",
    "fountain",
    "tomb",
    "wall",
    "sewer",
    "house",
}


PAGE_KINDS: dict[str, str] = {
    "domus": "house",
    "insulae": "house",
    "sepulcra": "tomb",
    "statuae": "statue",
    "obelisci": "statue",
    "luci": "grove",
    "vici": "street",
    "cliva": "street",
    "gradus_scalaeque": "street",
    "viae": "street",
    "porticus": "portico",
    "fora": "building",
    "atria": "building",
    "horti": "garden",
    "balnea": "building",
    "thermae": "building",
    "compita": "shrine",
    "arcus": "arch",
    "fornices": "arch",
    "portae": "gate",
    "horrea": "building",
    "scholae": "building",
    "curiae": "building",
    "bibliothecae": "building",
    "castra": "building",
    "naumachiae": "building",
    "amphitheatra": "building",
    "ludi": "building",
    "aquae": "aqueduct",
    "lacus": "fountain",
    "fontes": "fountain",
    "basilicae": "basilica",
    "campi": "area",
    "stationes_vigilum": "building",
}
"""LacusCurtius pages that gather one kind of thing (``domus.html``: houses)."""


def summarise_platner(e: dict[str, Any]) -> dict[str, Any]:
    """One P-A entry with its kind, the years it names and how many ancient sources it cites."""
    text = str(e["text"])
    page = str(e["page"]).removesuffix(".html").lower()
    kind = PAGE_KINDS.get(page) or kind_of_heading(str(e["head"]))
    if kind == "other":
        kind = kind_of_text(text)
    years = pa_years(text)
    early = [y for y in years if y < LAST_YEAR]
    n_src = len(_ANCIENT.findall(text))
    early_author = bool(EARLY_AUTHORS.search(text))
    in_scope = kind in SCOPE_KINDS and (bool(early) or early_author)
    return {
        "key": f"{e['page'].removesuffix('.html')}#{e['anchor']}" if e["anchor"] else e["page"],
        "head": e["head"],
        "url": LACUS + PA_DIR + e["page"] + (f"#{e['anchor']}" if e["anchor"] else ""),
        "kind": kind,
        "years": early,
        "earliest": min(early) if early else None,
        "dated": bool(early),
        "sources_cited": n_src,
        "in_scope": in_scope,
        "text": text[:900],
    }


# =============================================================================================
# Reference entries and the things in the dataset they are matched to
# =============================================================================================

PLEIADES_KIND: dict[str, str] = {
    "temple-2": "temple",
    "sanctuary": "temple",
    "shrine": "shrine",
    "altar": "altar",
    "grove": "grove",
    "basilica": "basilica",
    "arch": "arch",
    "city-gate": "gate",
    "bridge": "bridge",
    "aqueduct": "aqueduct",
    "road": "street",
    "street": "street",
    "monument": "statue",
    "fountain": "fountain",
    "cistern": "fountain",
    "townhouse": "house",
    "tomb": "tomb",
    "tumulus": "tomb",
    "pyramid": "tomb",
    "cemetery": "tomb",
    "city-wall": "wall",
    "earthwork": "wall",
    "sewer": "sewer",
    "hill": "hill",
    "valley": "valley",
    "plain": "area",
    "forum": "building",
    "plaza": "building",
    "theatre": "building",
    "circus": "building",
    "amphitheatre": "building",
    "bath": "building",
    "architecturalcomplex": "building",
    "building": "building",
    "palace-complex": "building",
    "palace": "building",
    "barracks": "building",
    "gymnasium": "building",
    "platform": "building",
    "port": "building",
    "fort-2": "building",
    "garden-hortus": "garden",
    "estate": "garden",
    "villa": "house",
    "cave": "shrine",
}
NOT_STRUCTURE = {
    "tribus",
    "region",
    "urban",
    "settlement",
    "district",
    "findspot",
    "production",
    "quarry",
    "station",
    "unknown",
}
"""Pleiades feature types that are no building, street or ground the city could show."""

CORE_ZONES: list[tuple[str, float, float, float]] = [
    ("Forum", 41.8925, 12.4853, 160.0),
    ("Capitol", 41.8934, 12.4828, 170.0),
    ("Palatine", 41.8892, 12.4875, 250.0),
    ("Circus", 41.8861, 12.4851, 330.0),
    ("Campus Martius", 41.8960, 12.4765, 450.0),
]
ZONE_WORDS: list[tuple[str, str]] = [
    ("Capitol", r"\bCapitol|\bArx\b|in Arce\b|Capitolium|in Capitolio"),
    (
        "Forum",
        r"\b[Ff]orum\b(?! (?:Boarium|Holitorium|Iulium|Julium|Augustum|Augusti|Pacis|"
        r"Traiani|Transitorium|Nervae|Piscarium|Cuppedinis|Esquilinum|Suarium|Vinarium))|"
        r"in [Ff]oro\b|Comitium|Sacra [Vv]ia",
    ),
    ("Palatine", r"Palatine|Palatium|Germalus|Cermalus|in Palatio"),
    ("Circus", r"Circus Maximus|circo [Mm]aximo|Circi Maximi"),
    (
        "Campus Martius",
        r"Campus Martius|campo Martio|circo Flaminio|Circus Flaminius|"
        r"Largo Argentina|Villa Publica",
    ),
]
PLACE_WORDS = [
    "forum",
    "foro",
    "capitol",
    "capitolio",
    "arce",
    "arx",
    "palati",
    "aventin",
    "quirinal",
    "esquili",
    "caeli",
    "viminal",
    "insula",
    "island",
    "flaminio",
    "flaminius",
    "campo martio",
    "campus martius",
    "boarium",
    "holitorium",
    "circo maximo",
    "circus maximus",
    "velia",
    "carinae",
    "subura",
    "vaticano",
    "transtiberim",
    "ianicul",
    "colle",
    "collina",
]
LINEAR_KINDS = {"street", "aqueduct", "wall", "sewer"}


@dataclass
class Ref:
    """One reference entry: a Pleiades place or a Platner-Ashby article."""

    source: str
    key: str
    title: str
    kind: str
    names: list[list[str]]
    earliest: int | None
    text: str = ""
    cited: int = 0
    point: tuple[float, float] | None = None
    accuracy: float | None = None
    hull: list[tuple[float, float]] = field(default_factory=list)
    lines: list[list[tuple[float, float]]] = field(default_factory=list)
    precise: bool = False
    url: str = ""
    feature_types: list[str] = field(default_factory=list)
    zone: str = ""
    places: set[str] = field(default_factory=set)
    years: list[int] = field(default_factory=list)


@dataclass
class Target:
    """Something in the dataset a reference can be matched to (a monument, street or hill)."""

    id: str
    kind: str
    names: list[list[str]]
    point: tuple[float, float]
    pleiades: set[str]
    titles: list[tuple[list[str], str]]
    places: set[str]
    rec: dict[str, Any]


def place_words(text: str) -> set[str]:
    """Which parts of the city a text names (for telling homonymous temples apart)."""
    t = fold(text)
    return {w for w in PLACE_WORDS if fold(w) in t}


def zone_of_point(p: tuple[float, float]) -> str:
    """The core zone a local point lies in, or ""."""
    for name, lat, lon, r in CORE_ZONES:
        if dist(p, to_local(lat, lon)) <= r:
            return name
    return ""


def zone_of_text(text: str) -> str:
    """The core zone a P-A text places its subject in (from its first 300 characters)."""
    head = text[:300]
    for name, pattern in ZONE_WORDS:
        if re.search(pattern, head):
            return name
    return ""


def pleiades_refs(doc: dict[str, Any]) -> list[Ref]:
    """The Pleiades places of the extract as references."""
    out: list[Ref] = []
    for p in doc.get("places", []):
        ftypes = [str(t).strip() for t in p.get("feature_types", [])]
        kind = next((PLEIADES_KIND[t] for t in ftypes if t in PLEIADES_KIND), "other")
        if kind == "other" and ftypes and all(t in NOT_STRUCTURE for t in ftypes):
            kind = "area"
        best: dict[str, Any] | None = None
        for loc in p.get("locations", []):
            acc = loc.get("accuracy_m")
            if best is None or (acc is not None and (best.get("accuracy_m") or 1e9) > acc):
                best = loc
        hull: list[tuple[float, float]] = []
        lines: list[list[tuple[float, float]]] = []
        point: tuple[float, float] | None = None
        if best is not None:
            hull = [to_local(float(a), float(b)) for a, b in best.get("hull", [])]
            if kind in LINEAR_KINDS:
                # a wall or a road is mapped as several stretches: keep them all
                for loc in p.get("locations", []):
                    for ln in loc.get("lines", []):
                        lines.append([to_local(float(a), float(b)) for a, b in ln])
                    lines.extend([[to_local(float(a), float(b))] for a, b in loc.get("hull", [])])
            else:
                lines = [
                    [to_local(float(a), float(b)) for a, b in ln] for ln in best.get("lines", [])
                ]
            if len(hull) >= 3:
                box = min_area_box(hull)
                point = (box.cx, box.cz) if box else None
            elif hull:
                point = (sum(h[0] for h in hull) / len(hull), sum(h[1] for h in hull) / len(hull))
        precise = p.get("precision") == "precise" and best is not None
        if point is None:
            point = to_local(float(p["repr"][0]), float(p["repr"][1]))
        names = [tokens(n) for n in [p["title"], *p.get("names", [])]]
        earliest = p.get("min_date")
        if earliest == -30:
            earliest = 1  # the start of Pleiades' 'roman' period (30 BC - AD 300), no building date
        out.append(
            Ref(
                source="pleiades",
                key=str(p["id"]),
                title=str(p["title"]),
                kind=kind,
                names=[n for n in names if n],
                earliest=earliest,
                text=str(p.get("description", "")),
                point=point,
                accuracy=(best or {}).get("accuracy_m"),
                hull=hull,
                lines=lines,
                precise=precise,
                url=f"https://pleiades.stoa.org/places/{p['id']}",
                feature_types=ftypes,
                zone=zone_of_point(point) if precise else "",
            )
        )
    return out


def platner_refs(doc: dict[str, Any]) -> list[Ref]:
    """The Platner-Ashby entries of the extract as references."""
    out: list[Ref] = []
    for e in doc.get("entries", []):
        head = str(e["head"])
        out.append(
            Ref(
                source="platner",
                key=str(e["key"]),
                title=head,
                kind=str(e["kind"]),
                names=[t for t in [tokens(head)] if t],
                earliest=e.get("earliest"),
                text=str(e.get("text", "")),
                cited=int(e.get("sources_cited", 0)),
                url=str(e.get("url", "")),
                zone=zone_of_text(str(e.get("text", ""))),
                places=place_words(str(e.get("text", ""))[:300]),
                years=[int(y) for y in e.get("years", [])],
            )
        )
    return out


def targets(ds: Dataset) -> dict[str, Target]:
    """The dataset's monuments, streets and named ground, as match targets."""
    out: dict[str, Target] = {}
    for mid in sorted(ds.recs):
        rec = ds.recs[mid]
        pl = rec.get("pleiades")
        ids = {str(pl)} if pl else set()
        ids |= {str(x) for x in rec.get("pleiades_also", []) or []}
        out[mid] = Target(
            id=mid,
            kind=kind_of_record(rec),
            names=record_names(rec),
            point=placed_centre(rec, ds.recs),
            pleiades=ids,
            titles=[(tokens(t), kind_of_heading(t)) for t in pa_titles(rec)],
            places=place_words(f"{rec.get('location', '')} {rec.get('latin', '')}"),
            rec=rec,
        )
    for sid in sorted(ds.streets):
        s = ds.streets[sid]
        pts = [to_local(float(a), float(b)) for a, b in s.get("points", [])]
        mid_pt = pts[len(pts) // 2] if pts else (0.0, 0.0)
        names = [tokens(str(s.get(k, ""))) for k in ("latin", "english")]
        pl = s.get("pleiades")
        out[f"street:{sid}"] = Target(
            id=f"street:{sid}",
            kind="street",
            names=[n for n in names if n],
            point=mid_pt,
            pleiades={str(pl)} if pl else set(),
            titles=[(tokens(t), "street") for t in pa_titles(s)],
            places=set(),
            rec=s,
        )
    for group, kind in (("hills", "hill"), ("valleys", "valley"), ("other", "area")):
        for h in ds.topo.get(group, []) or []:
            if not isinstance(h, dict) or "id" not in h or "lat" not in h:
                continue
            names = [tokens(str(h.get(k, ""))) for k in ("latin", "english")]
            pl = h.get("pleiades")
            out[f"{kind}:{h['id']}"] = Target(
                id=f"{kind}:{h['id']}",
                kind=kind,
                names=[n for n in names if n],
                point=to_local(float(h["lat"]), float(h["lon"])),
                pleiades={str(pl)} if pl else set(),
                titles=[],
                places=set(),
                rec=h,
            )
    return out


@dataclass
class Verdict:
    """What the audit concluded about one reference entry."""

    ref: Ref
    status: str  # matched | excluded | missing
    targets: list[str] = field(default_factory=list)
    how: str = ""
    reason: str = ""
    score: float = 0.0


def _ambiguous_pick(ref: Ref, cands: list[Target]) -> list[Target]:
    """Among several targets with the same name, those whose place words agree with the ref."""
    if len(cands) <= 1 or not ref.places:
        return cands
    agree = [c for c in cands if c.places & ref.places]
    return agree or cands


def match_refs(refs: list[Ref], tg: dict[str, Target], curated: dict[str, Any]) -> list[Verdict]:
    """Match every reference to dataset targets; curated verdicts first, then ids, then names."""
    by_pl: dict[str, list[str]] = {}
    for t in tg.values():
        for pid in t.pleiades:
            by_pl.setdefault(pid, []).append(t.id)
    # how many P-A entries share each heading (homonyms need their place words)
    heads = Counter(fold(r.title) for r in refs if r.source == "platner")
    out: list[Verdict] = []
    for ref in refs:
        cur = (curated.get(ref.source) or {}).get(ref.key)
        if isinstance(cur, dict):
            if cur.get("match"):
                ids = cur["match"] if isinstance(cur["match"], list) else [cur["match"]]
                missing = [i for i in ids if i not in tg]
                if missing:
                    out.append(
                        Verdict(
                            ref,
                            "missing",
                            how="curated",
                            reason=f"curated match to unknown id(s) {', '.join(missing)}",
                        )
                    )
                else:
                    out.append(
                        Verdict(ref, "matched", list(ids), "curated", str(cur.get("note", "")))
                    )
                continue
            if cur.get("skip"):
                out.append(Verdict(ref, "excluded", how="curated", reason=str(cur["skip"])))
                continue
            if cur.get("missing"):
                # the automatic match was wrong: nothing in the dataset is this entry yet
                out.append(Verdict(ref, "missing", how="curated", reason=str(cur["missing"])))
                continue
        if ref.source == "pleiades":
            if ref.kind == "area" or (
                ref.feature_types and all(t in NOT_STRUCTURE for t in ref.feature_types)
            ):
                out.append(
                    Verdict(
                        ref,
                        "excluded",
                        how="auto",
                        reason=f"not a structure ({', '.join(ref.feature_types)})",
                    )
                )
                continue
            if ref.key in by_pl:
                out.append(Verdict(ref, "matched", sorted(by_pl[ref.key]), "pleiades id"))
                continue
            if set(ref.feature_types) <= {"church-2", "church"}:
                out.append(Verdict(ref, "excluded", how="auto", reason="a church (after AD 120)"))
                continue
        cands: list[Target] = []
        how = ""
        if ref.source == "platner" and ref.names:
            cands = [
                t
                for t in tg.values()
                if any(
                    names_match(ref.names[0], ti)
                    and (len(ti) >= 2 or kinds_fit(ref.kind, tk) or "other" in (ref.kind, tk))
                    for ti, tk in t.titles
                    if ti
                )
            ]
            how = "P-A citation"
            if heads[fold(ref.title)] > 1:
                cands = [
                    c for c in cands if not ref.places or not c.places or c.places & ref.places
                ]
            if len(cands) > 1:
                named = [c for c in cands if any(names_match(ref.names[0], n) for n in c.names)]
                cands = named or cands
        if not cands:
            ref_names = ref.names or [fold(ref.title).split()]
            for t in tg.values():
                t_names = (
                    t.names
                    if ref.names
                    else t.names
                    + [fold(str(t.rec.get(k, ""))).split() for k in ("latin", "english")]
                )
                hit = [a for a in ref_names for b in t_names if names_match(a, b)]
                if not hit:
                    continue
                # a two-word name is enough on its own; one word needs the same kind of thing
                strong = any(len(a) >= 2 for a in hit)
                if not strong and not kinds_fit(ref.kind, t.kind) and ref.kind != "other":
                    continue
                if (
                    ref.source == "pleiades"
                    and ref.precise
                    and ref.kind not in LINEAR_KINDS
                    and t.kind not in LINEAR_KINDS
                    and dist(ref.point or (0, 0), t.point) > 600
                ):
                    continue
                cands.append(t)
            cands = _ambiguous_pick(ref, cands)
            how = "name"
        if cands:
            out.append(Verdict(ref, "matched", sorted(c.id for c in cands), how))
        else:
            out.append(Verdict(ref, "missing"))
    return out


KIND_WEIGHT = {
    "temple": 1.0,
    "basilica": 1.0,
    "building": 1.0,
    "gate": 1.0,
    "bridge": 1.0,
    "portico": 1.0,
    "arch": 0.9,
    "altar": 0.9,
    "aqueduct": 1.0,
    "wall": 1.0,
    "shrine": 0.8,
    "grove": 0.7,
    "fountain": 0.7,
    "street": 0.7,
    "statue": 0.5,
    "house": 0.5,
    "tomb": 0.5,
    "sewer": 0.8,
    "garden": 0.4,
    "hill": 0.6,
    "valley": 0.6,
    "other": 0.3,
}


def content_text(packs: Path = PACKS) -> str:
    """The rome pack's YAML text, folded (to see whether game events name a place)."""
    if not packs.exists():
        return ""
    return " ".join(fold(p.read_text(encoding="utf-8")) for p in sorted(packs.rglob("*.yaml")))


def score_missing(v: Verdict, cross: bool, events: str) -> float:
    """Importance of a missing entry: sources citing it, the core zones, game events, period."""
    r = v.ref
    s = min(r.cited, 12) / 2.0
    if r.zone:
        s += 3.0
    if cross:
        s += 2.0
    name = " ".join(r.names[0]) if r.names else ""
    if name and (len(r.names[0]) >= 2 or len(name) >= 6) and f" {name} " in f" {events} ":
        s += 2.0
    if r.earliest is not None and r.earliest <= -27:
        s += 1.0
    if r.source == "pleiades":
        s += 1.5
    return round(s * KIND_WEIGHT.get(r.kind, 0.5), 2)


def period_of(year: int | None) -> str:
    """The period an earliest year falls in."""
    if year is None:
        return "undated (attested by an early author)"
    if year < -509:
        return "regal (before 509 BC)"
    if year <= -27:
        return "Republic (509-27 BC)"
    return "Empire to AD 120"


# =============================================================================================
# Position, orientation and size
# =============================================================================================


def tolerance(p: tuple[float, float]) -> float:
    """10 m in the Forum and on the Capitol, 20 m elsewhere."""
    return NEAR_TOL_M if zone_of_point(p) in ("Forum", "Capitol") else FAR_TOL_M


def long_axis(rec: dict[str, Any], recs: dict[str, dict[str, Any]]) -> float | None:
    """The bearing (0-180) of the footprint's long side as placed."""
    b = placed_bearing(rec, recs)
    fp = footprint(rec)
    if b is None or fp is None:
        return None
    ln, wd = fp
    return (b if ln >= wd else b + 90.0) % 180.0


def check_positions(
    ds: Dataset, verdicts: list[Verdict], refs_by_key: dict[str, Ref]
) -> list[dict[str, Any]]:
    """Our placed centre against each matched Pleiades place with a location of its own."""
    rows: list[dict[str, Any]] = []
    seen: set[tuple[str, str]] = set()
    for v in verdicts:
        r = v.ref
        if r.source != "pleiades" or v.status != "matched" or not r.precise or r.point is None:
            continue
        for tid in v.targets:
            if tid not in ds.recs or (tid, r.key) in seen:
                continue
            rec = ds.recs[tid]
            if r.key not in {str(rec.get("pleiades"))} | {
                str(x) for x in rec.get("pleiades_also", []) or []
            }:
                continue  # matched by name only: listed under "Pleiades id to add"
            seen.add((tid, r.key))
            if (
                rec.get("route")
                or str(rec.get("model", "")) in ("wall", "aqueduct", "sewer")
                or str(rec.get("type", "")) in ("road", "street")
            ):
                continue  # a line, not a building: compared as a line below
            ours = placed_centre(rec, ds.recs)
            d = dist(ours, r.point)
            tol = tolerance(r.point)
            acc = r.accuracy
            status = "ok"
            if d > tol:
                status = "misplaced" if acc is None or d > acc else "within reference accuracy"
            if r.hull and len(r.hull) >= 3 and any(inside(ours, r.hull) for _ in [0]):
                status = "ok" if status != "ok" and d <= max(tol, 0.5 * _span(r.hull)) else status
            rows.append(
                {
                    "id": tid,
                    "pleiades": r.key,
                    "title": r.title,
                    "distance_m": round(d, 1),
                    "tolerance_m": tol,
                    "reference_accuracy_m": acc,
                    "status": status,
                    "ours": [round(ours[0], 1), round(ours[1], 1)],
                    "reference": [round(r.point[0], 1), round(r.point[1], 1)],
                    "bearing_to_reference": round(bearing_between(ours, r.point)),
                    "overrides": str(rec.get("precision", "")),
                }
            )
    rows.sort(key=lambda x: -float(x["distance_m"]))
    return rows


def _span(hull: Sequence[tuple[float, float]]) -> float:
    box = min_area_box(hull)
    return box.short if box else 0.0


def check_outlines(ds: Dataset, verdicts: list[Verdict], skip: set[str]) -> list[dict[str, Any]]:
    """Our footprint against the outline of the remains (Pleiades hull from OpenStreetMap)."""
    rows: list[dict[str, Any]] = []
    for v in verdicts:
        r = v.ref
        if r.source != "pleiades" or v.status != "matched" or len(r.hull) < 4:
            continue
        box = min_area_box(r.hull)
        if box is None or box.long < 8.0:
            continue
        for tid in v.targets:
            if tid not in ds.recs or tid in skip:
                continue
            rec = ds.recs[tid]
            fp = footprint(rec)
            ax = long_axis(rec, ds.recs)
            if fp is None:
                continue
            row: dict[str, Any] = {
                "id": tid,
                "pleiades": r.key,
                "outline_long_m": round(box.long, 1),
                "outline_short_m": round(box.short, 1),
                "outline_axis": round(box.axis, 1),
                "ours_long_m": round(max(fp), 1),
                "ours_short_m": round(min(fp), 1),
                "ours_axis": None if ax is None else round(ax, 1),
            }
            row["axis_diff"] = None
            if ax is not None and box.long / max(box.short, 0.1) >= 1.15:
                row["axis_diff"] = round(angle_diff(ax, box.axis, 180.0), 1)
            row["long_ratio"] = round(max(fp) / box.long, 2)
            row["short_ratio"] = round(min(fp) / max(box.short, 0.1), 2)
            flags = []
            if row["axis_diff"] is not None and row["axis_diff"] > BEARING_TOL:
                flags.append("axis")
            if abs(row["long_ratio"] - 1.0) > SIZE_TOL or abs(row["short_ratio"] - 1.0) > SIZE_TOL:
                flags.append("size")
            row["flags"] = flags
            rows.append(row)
    rows.sort(key=lambda x: (not x["flags"], x["id"]))
    return rows


def check_measured(ds: Dataset, measured: dict[str, Any]) -> list[dict[str, Any]]:
    """Bearings and sizes against the published measurements in ``references.yaml``."""
    rows: list[dict[str, Any]] = []
    for mid in sorted(measured):
        m = measured[mid] or {}
        rec = ds.recs.get(mid)
        if rec is None:
            rows.append({"id": mid, "flags": ["unknown id"], "source": m.get("source", "")})
            continue
        row: dict[str, Any] = {"id": mid, "source": m.get("source", ""), "flags": []}
        ours_b = placed_bearing(rec, ds.recs)
        if m.get("bearing") is not None:
            period = 180.0 if m.get("axis_only") else 360.0
            row["bearing_ref"] = m["bearing"]
            row["bearing_ours"] = ours_b
            if ours_b is None:
                row["flags"].append("no bearing")
            else:
                row["bearing_diff"] = round(angle_diff(ours_b, float(m["bearing"]), period), 1)
                if row["bearing_diff"] > BEARING_TOL:
                    row["flags"].append("bearing")
        fp = footprint(rec)
        for key, idx in (("length", 0), ("width", 1)):
            if m.get(key) is None:
                continue
            row[f"{key}_ref"] = m[key]
            if fp is None:
                row["flags"].append("no footprint")
                continue
            ours = fp[idx]
            row[f"{key}_ours"] = ours
            ratio = ours / float(m[key])
            row[f"{key}_ratio"] = round(ratio, 2)
            if abs(ratio - 1.0) > SIZE_TOL:
                row["flags"].append(key)
        rows.append(row)
    return rows


def check_lines(ds: Dataset, verdicts: list[Verdict]) -> list[dict[str, Any]]:
    """Streets, walls and aqueducts: our polyline against the Pleiades line (mean, max m)."""
    rows: list[dict[str, Any]] = []
    for v in verdicts:
        r = v.ref
        if r.source != "pleiades" or v.status != "matched" or not r.lines:
            continue
        # inside the audited radius only: an aqueduct's mapped line runs 20 km out
        theirs = [p for ln in r.lines for p in ln if math.hypot(*p) <= RADIUS_M]
        if not theirs:
            continue
        for tid in v.targets:
            pts: list[tuple[float, float]] = []
            if tid.startswith("street:"):
                s = ds.streets[tid.split(":", 1)[1]]
                pts = [to_local(float(a), float(b)) for a, b in s.get("points", [])]
            elif tid in ds.recs and ds.recs[tid].get("route"):
                pts = [to_local(float(a), float(b)) for a, b in ds.recs[tid]["route"]]
            if len(pts) < 2:
                continue
            # how far the mapped line (theirs) lies from ours, point by point
            back = [line_dist(q, pts) for q in theirs]
            rows.append(
                {
                    "id": tid,
                    "pleiades": r.key,
                    "title": r.title,
                    "mean_m": round(sum(back) / len(back), 1),
                    "max_m": round(max(back), 1),
                    "points": len(theirs),
                    "accuracy_m": r.accuracy,
                }
            )
    rows.sort(key=lambda x: -float(x["mean_m"]))
    return rows


# =============================================================================================
# Relations the sources fix
# =============================================================================================


@dataclass
class Relation:
    """One relation a source fixes, checked on the placed centres."""

    name: str
    source: str
    ok: bool | None
    detail: str


def _street_pts(ds: Dataset, sid: str) -> list[tuple[float, float]]:
    s = ds.streets.get(sid)
    return [to_local(float(a), float(b)) for a, b in s.get("points", [])] if s else []


def _route(ds: Dataset, mid: str) -> list[tuple[float, float]]:
    rec = ds.recs.get(mid, {})
    return [to_local(float(a), float(b)) for a, b in rec.get("route", []) or []]


def gate_circuit(ds: Dataset) -> list[tuple[float, float]]:
    """The Servian wall as ``monuments.gd`` draws it (``_circuit``).

    The gates in order round (150, 350), threaded along ``route_measured`` when every gate is
    one of its points (within 2 m) in the same order; otherwise straight from gate to gate.
    """
    pts = [
        placed_centre(r, ds.recs) for r in ds.recs.values() if r.get("snap_to") == "murus_servianus"
    ]
    pts.sort(key=lambda p: math.atan2(p[1] - 350.0, p[0] - 150.0))
    gates = [*pts, pts[0]] if pts else []
    wall = ds.recs.get("murus_servianus") or {}
    meas = [to_local(float(a), float(b)) for a, b in wall.get("route_measured") or []]
    if len(meas) <= len(pts):
        return gates
    if dist(meas[0], meas[-1]) > 0.5:
        meas.append(meas[0])
    last = -1
    for g in pts:
        k = min(range(len(meas) - 1), key=lambda i: dist(meas[i], g))
        if dist(meas[k], g) > 2.0 or k <= last:
            return gates
        last = k
    return meas


def river_course(ds: Dataset) -> list[tuple[float, float]]:
    """The Tiber's course (topography.yaml) in local metres."""
    t = ds.topo.get("tiber") or {}
    return [to_local(float(a), float(b)) for a, b in t.get("course", [])]


def river_half_width(ds: Dataset) -> float:
    """Half the Tiber's modelled width."""
    t = ds.topo.get("tiber") or {}
    return float((t.get("banks") or {}).get("half_width_m", 45.0))


def check_relations(
    ds: Dataset, pl_lines: dict[str, list[list[tuple[float, float]]]]
) -> list[Relation]:
    """Every relation the sources fix, as a check on the placed centres."""
    out: list[Relation] = []

    def pos(mid: str) -> tuple[float, float] | None:
        rec = ds.recs.get(mid)
        return placed_centre(rec, ds.recs) if rec else None

    def rel(name: str, source: str, ids: Sequence[str], fn: Any) -> None:
        pts = [pos(i) for i in ids]
        if any(p is None for p in pts):
            missing = [i for i, p in zip(ids, pts, strict=True) if p is None]
            out.append(Relation(name, source, None, f"not in the dataset: {', '.join(missing)}"))
            return
        ok, detail = fn(*pts)
        out.append(Relation(name, source, bool(ok), detail))

    # Saturn at the foot of the Clivus Capitolinus (the clivus starts by the temple)
    clivus = _street_pts(ds, "clivus_capitolinus")

    def saturn(sat: tuple[float, float]) -> tuple[bool, str]:
        if not clivus:
            return (False, "no Clivus Capitolinus in streets.yaml")
        d = line_dist(sat, clivus)
        foot = min(clivus, key=lambda p: dist(p, (0.0, 0.0)))
        return (
            d <= 25.0 and dist(sat, foot) <= 60.0,
            f"{d:.0f} m from the clivus, {dist(sat, foot):.0f} m from its foot",
        )

    rel(
        "Saturn at the foot of the Clivus Capitolinus",
        "Platner-Ashby s.v. Saturnus, Aedes; Clivus Capitolinus",
        ["aedes_saturni"],
        saturn,
    )

    def castor(c: tuple[float, float], j: tuple[float, float]) -> tuple[bool, str]:
        d = dist(c, j)
        return (
            d <= 45.0 and bearing_between(c, j) % 360 < 200,
            f"{d:.0f} m apart, the Lacus at bearing {bearing_between(c, j):.0f} from Castor",
        )

    rel(
        "Castor beside the Lacus Iuturnae (east of it)",
        "Platner-Ashby s.v. Iuturnae Lacus; Castor, Aedes",
        ["aedes_castoris", "lacus_iuturnae"],
        castor,
    )

    sacra = _street_pts(ds, "via_sacra")

    def sacra_end(r: tuple[float, float], v: tuple[float, float]) -> tuple[bool, str]:
        if not sacra:
            return (False, "no Via Sacra in streets.yaml")
        dr, dv = line_dist(r, sacra), line_dist(v, sacra)
        # P-A s.v. Sacra Via: from the summa Sacra via (the Velia) down to the east end of the
        # Forum, "near the regia, the temple of Vesta, or the arch of Fabius"
        return (
            dr <= 35.0 and dv <= 45.0 and r[0] > 40.0 and v[0] > 40.0,
            f"Regia {dr:.0f} m and Vesta {dv:.0f} m from the Sacra Via; {r[0]:.0f} and "
            f"{v[0]:.0f} m east of the Forum's centre",
        )

    rel(
        "The Regia and Vesta where the Sacra Via reaches the Forum's east end",
        "Platner-Ashby s.v. Sacra Via; Regia; Vesta, Aedes",
        ["regia", "aedes_vestae"],
        sacra_end,
    )

    def curia(cu: tuple[float, float], co: tuple[float, float]) -> tuple[bool, str]:
        b = bearing_between(co, cu)
        return (
            dist(cu, co) <= 70.0 and angle_diff(b, 0.0) <= 60.0,
            f"Curia {dist(cu, co):.0f} m from the Comitium's centre at bearing {b:.0f}",
        )

    rel(
        "The Curia Hostilia on the Comitium's north side",
        "Platner-Ashby s.v. Comitium; Curia Hostilia",
        ["curia_hostilia", "comitium"],
        curia,
    )
    rel(
        "The Curia Iulia on the Comitium's north side",
        "Platner-Ashby s.v. Curia Iulia",
        ["curia_iulia", "comitium"],
        curia,
    )

    def rostra(
        ro: tuple[float, float], co: tuple[float, float], fo: tuple[float, float]
    ) -> tuple[bool, str]:
        d_line = seg_dist(ro, co, fo)
        t = ((ro[0] - co[0]) * (fo[0] - co[0]) + (ro[1] - co[1]) * (fo[1] - co[1])) / max(
            dist(co, fo) ** 2, 1.0
        )
        return (
            d_line <= 30.0 and 0.0 <= t <= 0.8,
            f"{d_line:.0f} m off the Comitium-Forum line, at {t:.2f} of the way",
        )

    rel(
        "The Republican Rostra between the Comitium and the Forum",
        "Platner-Ashby s.v. Rostra",
        ["rostra_republic", "comitium", "forum_romanum"],
        rostra,
    )

    def sides(
        a: tuple[float, float], i: tuple[float, float], f: tuple[float, float]
    ) -> tuple[bool, str]:
        # the Forum's long axis runs about 110 deg (WNW-ESE); north is to the left of it
        ax = (math.sin(math.radians(110)), -math.cos(math.radians(110)))
        nrm = (ax[1], -ax[0])  # left-hand normal: north-north-east

        def side(p: tuple[float, float]) -> float:
            return (p[0] - f[0]) * nrm[0] + (p[1] - f[1]) * nrm[1]

        return (
            side(a) > 15.0 and side(i) < -15.0,
            f"Aemilia {side(a):.0f} m north of the Forum's axis, Iulia {-side(i):.0f} m south",
        )

    rel(
        "The Basilica Aemilia north and the Iulia south of the Forum",
        "Platner-Ashby s.v. Basilica Aemilia; Basilica Iulia",
        ["basilica_aemilia", "basilica_iulia", "forum_romanum"],
        sides,
    )

    def carcer(c: tuple[float, float], cap: tuple[float, float]) -> tuple[bool, str]:
        return (
            dist(c, (0.0, 0.0)) < 160.0 and c[0] < -40.0 and dist(c, cap) < 300.0,
            f"{-c[0]:.0f} m west of the Forum centre, {dist(c, cap):.0f} m from the Capitol",
        )

    rel(
        "The Carcer under the Capitol, at the Forum's north-west corner",
        "Platner-Ashby s.v. Carcer",
        ["carcer", "aedes_iovis_capitolini"],
        carcer,
    )

    def circus(c: tuple[float, float]) -> tuple[bool, str]:
        pal = to_local(41.8892, 12.4875)
        av = to_local(41.8825, 12.4825)
        between = seg_dist(c, pal, av) < 120.0
        rec = ds.recs["circus_maximus"]
        b = placed_bearing(rec, ds.recs)
        # the model's front (+z at yaw 0, the bearing) is the curved end; the carceres are behind
        carceres_dir = None if b is None else (b + 180.0) % 360.0
        west = carceres_dir is not None and angle_diff(carceres_dir, 270.0) <= 60.0
        return (
            between and west,
            f"{seg_dist(c, pal, av):.0f} m off the Palatine-Aventine line; "
            f"carceres face {carceres_dir if carceres_dir is None else round(carceres_dir)}",
        )

    rel(
        "The Circus Maximus between Palatine and Aventine, carceres at the west",
        "Platner-Ashby s.v. Circus Maximus",
        ["circus_maximus"],
        circus,
    )

    # the Servian wall: monuments.gd threads it through the gates in order round the city, along
    # route_measured, so every stretch that survives (Pleiades, from OpenStreetMap) lies on it
    circ = gate_circuit(ds)
    wall = ds.recs.get("murus_servianus") or {}
    measured_wall = [to_local(float(a), float(b)) for a, b in wall.get("route_measured") or []]
    for k, stretch in enumerate(pl_lines.get("103808101", [])):
        if not circ:
            break
        d = max(line_dist(q, circ) for q in stretch)
        c = stretch[len(stretch) // 2]
        near = min(
            (g for g in ds.recs if ds.recs[g].get("snap_to") == "murus_servianus"),
            key=lambda g: dist(placed_centre(ds.recs[g], ds.recs), c),
        )
        detail = f"up to {d:.0f} m from the drawn wall, at ({c[0]:.0f}, {c[1]:.0f})"
        if measured_wall:
            dm = max(line_dist(q, measured_wall) for q in stretch)
            detail += f"; {dm:.0f} m from the measured line (route_measured)"
        out.append(
            Relation(
                f"surviving stretch {k + 1} of the Servian wall (near {near}) on the wall "
                "drawn through the gates",
                "Pleiades 103808101 (Murus Servii Tullii, OpenStreetMap tracts); Platner-Ashby "
                "s.v. Murus Servii Tullii",
                d <= 60.0,
                detail,
            )
        )

    course = river_course(ds)
    hw = river_half_width(ds)
    for b in sorted(m for m, r in ds.recs.items() if str(r.get("type")) == "bridge"):
        rec = ds.recs[b]
        p = placed_centre(rec, ds.recs)
        d = line_dist(p, course) if course else 1e9
        fp = footprint(rec)
        span = max(fp) if fp else 0.0
        island = (ds.topo.get("tiber") or {}).get("island") or {}
        to_island = dist(p, to_local(float(island.get("lat", 0)), float(island.get("lon", 0))))
        ok = d <= hw or to_island < 150.0
        out.append(
            Relation(
                f"{b} spans the Tiber",
                f"topography.yaml tiber.course; Platner-Ashby s.v. {rec.get('latin', b)}",
                ok and (span >= hw or to_island < 150),
                f"centre {d:.0f} m from the river's line (half width {hw:.0f} m), "
                f"length {span:.0f} m",
            )
        )

    def aqueduct_at(
        mid: str, place: str, pt: tuple[float, float], limit: float, source: str
    ) -> None:
        route = _route(ds, mid)
        if not route:
            out.append(Relation(f"{mid} reaches {place}", source, None, "no route"))
            return
        d = line_dist(pt, route)
        out.append(
            Relation(
                f"{mid} reaches {place}", source, d <= limit, f"route passes {d:.0f} m from it"
            )
        )

    cap = pos("porta_capena")
    if cap is not None:
        aqueduct_at(
            "aqua_appia",
            "the Porta Capena",
            cap,
            120.0,
            "Frontinus 1.5 (Platner-Ashby s.v. Aqua Appia)",
        )
    trig = pos("porta_trigemina")
    if trig is not None and _route(ds, "aqua_appia"):
        end = _route(ds, "aqua_appia")[-1]
        d = dist(end, trig)
        out.append(
            Relation(
                "aqua_appia ends ad Salinas by the Porta Trigemina",
                "Frontinus 1.5 (Platner-Ashby s.v. Aqua Appia)",
                d <= 250.0,
                f"its end is {d:.0f} m from the Porta Trigemina",
            )
        )
    return out


# =============================================================================================
# Time
# =============================================================================================

FAR = -100000


def state_at(mid: str, year: int, recs: dict[str, dict[str, Any]]) -> str:
    """A port of ``UrbsMonuments.state_at``: "" when absent, else the state drawn in ``year``."""
    m = recs.get(mid)
    if not m:
        return ""
    model = str(m.get("model", "none"))
    if model == "none":
        return ""
    twin = str(m.get("twin_of", ""))
    if twin and twin in recs and state_at(twin, year, recs):
        return ""
    built = m.get("built")
    first = FAR
    if isinstance(built, dict) and built.get("year") is not None:
        first = int(built["year"])
    elif isinstance(built, dict) and built.get("not_before") is not None:
        first = int(built["not_before"])
    begun = first
    cons = m.get("construction")
    if isinstance(cons, dict):
        begun = int(cons["begun"])
        first = int(cons["completed"])
    if year < begun:
        return ""
    ended = m.get("ended")
    if isinstance(ended, dict) and ended.get("year") is not None and year >= int(ended["year"]):
        return ""
    st = "standing" if year >= first else "building"
    gone = False
    for ph in m.get("phases", []) or []:
        if year < int(ph["from"]):
            break
        s = str(ph["state"])
        gone = s == "gone"
        if gone:
            continue
        st = s
    if gone:
        return ""
    if st == "standing" and year < first:
        st = "building"
    return st


def check_dates(ds: Dataset) -> list[dict[str, Any]]:
    """Dates that disagree: the client's drawing against the engine's timeline, order, events."""
    from anachronism.content.schema.monuments import CityTimeline, Monument
    from anachronism.engine.city import marks_for, status_at

    rows: list[dict[str, Any]] = []
    tl = [CityTimeline.model_validate(t) for t in ds.timeline]
    by_mon: dict[str, list[CityTimeline]] = {}
    for t in tl:
        by_mon.setdefault(t.monument, []).append(t)
        if t.monument not in ds.recs:
            rows.append({"id": t.monument, "issue": f"timeline entry {t.id} names no monument"})
    # the same building in both files must be drawn once (twin_of), never twice
    for mid in sorted(ds.empire):
        rid = str(ds.recs[mid].get("republican_id") or "")
        if rid in ds.recs:
            both = [
                y for y in COUNT_YEARS if state_at(mid, y, ds.recs) and state_at(rid, y, ds.recs)
            ]
            if both:
                rows.append(
                    {
                        "id": mid,
                        "issue": f"drawn twice with {rid} in "
                        f"{', '.join(_yr(y) for y in both)} (no twin_of)",
                    }
                )
    for mid in sorted(ds.recs):
        rec = ds.recs[mid]
        built = rec.get("built") if isinstance(rec.get("built"), dict) else {}
        year = built.get("year") if built else None
        cons = rec.get("construction")
        if isinstance(cons, dict):
            if int(cons["begun"]) > int(cons["completed"]):
                rows.append({"id": mid, "issue": "construction begun after it was completed"})
            if year is not None and int(cons["completed"]) != int(year):
                rows.append(
                    {
                        "id": mid,
                        "issue": f"construction completed {cons['completed']} "
                        f"but built.year {year}",
                    }
                )
        ended = rec.get("ended")
        if (
            isinstance(ended, dict)
            and ended.get("year") is not None
            and year is not None
            and int(ended["year"]) < int(year)
        ):
            rows.append({"id": mid, "issue": f"ended {ended['year']} before built {year}"})
        froms = [int(p["from"]) for p in rec.get("phases", []) or []]
        if froms != sorted(froms):
            rows.append({"id": mid, "issue": "phases out of order"})
        if year is not None:
            for e in rec.get("events", []) or []:
                if e.get("year") is None:
                    continue
                ey = int(e["year"])
                if ey < int(year) - 2 and not re.search(
                    r"vow|contract|begun|begin|start|site|land|bought|first|earlier|old|"
                    r"origin|founded|consecrat|carceres|wood|prodig|before|unfinished",
                    str(e["what"]),
                    re.I,
                ):
                    rows.append(
                        {
                            "id": mid,
                            "issue": f"event in {ey} before it was built "
                            f"({year}): {str(e['what'])[:80]}",
                        }
                    )
        # the client draws what the engine says stands
        try:
            mon = Monument.model_validate(rec)
        except ValueError as exc:
            rows.append({"id": mid, "issue": f"the engine cannot read it: {exc}"})
            continue
        marks = marks_for(mon, by_mon.get(mid, []))
        known = year is not None or (built or {}).get("not_before") is not None
        for y in COUNT_YEARS:
            eng = status_at(marks, y, known).state
            cli = state_at(mid, y, ds.recs)
            if str(rec.get("model", "none")) == "none" or rec.get("twin_of"):
                continue
            eng_up = eng in ("standing", "burnt", "building", "ruined")
            cli_up = cli != ""
            if eng == "ruined" and not cli_up:
                continue
            # burned and never rebuilt: the engine keeps a burnt shell, the client draws nothing
            ended = (rec.get("ended") or {}).get("year")
            if eng == "burnt" and not cli_up and ended is not None and int(ended) <= y:
                continue
            if eng_up != cli_up:
                rows.append(
                    {"id": mid, "issue": f"{_yr(y)}: engine {eng}, drawn {cli or 'absent'}"}
                )
        for t in by_mon.get(mid, []):
            in_events = any(e.get("year") == t.year for e in rec.get("events", []) or [])
            in_phases = any(int(p["from"]) == t.year for p in rec.get("phases", []) or [])
            in_ended = (rec.get("ended") or {}).get("year") == t.year
            if t.kind == "fire" and not in_events and not in_phases and not in_ended:
                issue = f"timeline fire {_yr(t.year)} is in neither its events nor its phases"
                rows.append({"id": mid, "issue": issue})
    return rows


def _yr(y: int | None) -> str:
    if y is None:
        return "?"
    return f"{-y} BC" if y < 0 else f"AD {y}"


def counts_by_year(ds: Dataset) -> dict[str, dict[str, int]]:
    """How many monuments are drawn in each standard year, by state and by type."""
    out: dict[str, dict[str, int]] = {}
    for y in COUNT_YEARS:
        c: Counter[str] = Counter()
        for mid in sorted(ds.recs):
            st = state_at(mid, y, ds.recs)
            if st:
                c[st] += 1
                c["total"] += 1
        out[_yr(y)] = dict(sorted(c.items()))
    return out


def check_pa_dates(ds: Dataset, verdicts: list[Verdict]) -> list[dict[str, Any]]:
    """Our building year against the years the matched P-A article names (a pointer to reread)."""
    rows: list[dict[str, Any]] = []
    for v in verdicts:
        r = v.ref
        if r.source != "platner" or v.status != "matched" or not r.years:
            continue
        for tid in v.targets:
            rec = ds.recs.get(tid)
            if rec is None or not isinstance(rec.get("built"), dict):
                continue
            y = rec["built"].get("year")
            if y is None or y > -27 or tid in ds.empire:
                continue
            bc = [x for x in r.years if x < 0]
            if bc and not any(abs(int(y) - x) <= 2 for x in r.years):
                rows.append(
                    {"id": tid, "built": int(y), "pa": r.title, "pa_key": r.key, "pa_years": bc[:8]}
                )
    return rows


# =============================================================================================
# Ground, and the built scene (from the Godot audit)
# =============================================================================================


def check_topography(ds: Dataset, scene: dict[str, Any]) -> list[dict[str, Any]]:
    """Summit heights and valley floors: topography.yaml against the ridges and the built ground."""
    rows: list[dict[str, Any]] = []
    ridges = {str(r.get("id")): r for r in (ds.topo.get("terrain_model") or {}).get("ridges", [])}
    ground = {str(t["id"]): t for t in scene.get("terrain", [])}
    for group, key in (
        ("hills", "height_m"),
        ("other_heights", "height_m"),
        ("valleys", "floor_m"),
    ):
        for h in ds.topo.get(group, []) or []:
            if not isinstance(h, dict) or h.get(key) is None:
                continue
            row: dict[str, Any] = {"id": h["id"], "kind": group, "expected_m": h[key]}
            r = ridges.get(str(h["id"]))
            if r is not None and r.get("pts"):
                row["ridge_top_m"] = max(float(p[2]) for p in r["pts"])
            g = ground.get(str(h["id"]))
            if g is not None:
                row["scene_m"] = g.get("height")
                row["scene_max_m"] = g.get("max")
            ref = row.get("scene_max_m") if group != "valleys" else row.get("scene_m")
            row["diff_m"] = None if ref is None else round(float(ref) - float(h[key]), 1)
            row["flag"] = row["diff_m"] is not None and abs(float(row["diff_m"])) > 3.0
            rows.append(row)
    return rows


def load_scene(path: Path = SCENE_JSON) -> dict[str, Any]:
    """The Godot audit's findings, {} when it has not been run."""
    data = load_json(path)
    return data if isinstance(data, dict) else {}


def run_scene(
    godot: str,
    client: Path = ROOT / "client",
    years: Iterable[int] = SCENE_YEARS,
    dest: Path = SCENE_JSON,
) -> dict[str, Any]:
    """Run ``audit.gd`` for each year (headless Godot) and save what it found."""
    out: dict[str, Any] = {"years": {}, "terrain": []}
    for y in years:
        res = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(client),
                "-s",
                "res://scripts/urbs/audit.gd",
                "--",
                f"--urbs-audit={y}",
            ],
            capture_output=True,
            text=True,
            timeout=3600,
            check=False,
        )
        line = next((ln for ln in res.stdout.splitlines() if ln.startswith("URBS_AUDIT ")), "")
        if not line:
            raise RuntimeError(
                f"audit.gd printed no result for {y}:\n{res.stdout[-3000:]}\n{res.stderr[-3000:]}"
            )
        data = json.loads(line.removeprefix("URBS_AUDIT "))
        out["years"][str(y)] = data.get("year", data)
        if data.get("terrain"):
            out["terrain"] = data["terrain"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    return out


# --- F2: terraces for monuments on steep ground --------------------------------------------------

TOPOGRAPHY = CITY / "topography.yaml"
TERRACE_DROP_M = 3.0
"""Where the ground falls more than this under a monument, it stands on a terrace cut into the
hill (a platform of topography.yaml, with retaining and substructure walls); below it, on a
podium or foundation of its own (monuments.gd)."""
TERRACE_MARGIN_M = 6.0
TERRACE_SKIP = {"area_capitolina", "forum_iulium", "tabularium"}
"""Plazas whose own platform in topography.yaml is their outline (edited by hand), and the
Tabularium, built against the hill (monuments.gd AGAINST_HILL)."""
TERRACE_SKIP_MODELS = {"quay", "bridge_stone", "bridge_timber", "circus_maximus", "arch"}
"""Built on the bank or across the river, or in the valley: no terrace. (F3: nor an arch, which
stands across its street and follows the street's own cut.)"""
_TERRACE_START = (
    "  # F2 TERRACES (generated by `uv run anachronism-city-audit --terraces`; do not edit by hand)"
)
_TERRACE_END = "  # END F2 TERRACES"


def terrace_entries(scene: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """A terrace for every monument that stands on steep ground in any audited year.

    The floor is the ground at the monument's centre before any terrace (the hill is cut on the
    uphill side and built up on the downhill side); the outline is its footprint grown by
    ``TERRACE_MARGIN_M``. One entry per monument (the year where the ground falls most).
    """
    worst: dict[str, dict[str, Any]] = {}
    for data in (scene.get("years") or {}).values():
        for s in data.get("slopes", []) or []:
            if (
                s["id"] in TERRACE_SKIP
                or s.get("model") in TERRACE_SKIP_MODELS
                or s.get("platform")
            ):
                continue
            if float(s["drop"]) <= TERRACE_DROP_M:
                continue
            if s["id"] not in worst or float(s["drop"]) > float(worst[s["id"]]["drop"]):
                worst[s["id"]] = s
    out: dict[str, dict[str, Any]] = {}
    for mid in sorted(worst):
        s = worst[mid]
        yaw = float(s["yaw"])
        ax = (math.cos(yaw), -math.sin(yaw))
        az = (math.sin(yaw), math.cos(yaw))
        hx = float(s["hx"]) + TERRACE_MARGIN_M
        hz = float(s["hz"]) + TERRACE_MARGIN_M
        poly = []
        for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
            x = float(s["x"]) + ax[0] * hx * sx + az[0] * hz * sz
            z = float(s["z"]) + ax[1] * hx * sx + az[1] * hz * sz
            lat, lon = to_latlon(x, z)
            poly.append([round(lat, 6), round(lon, 6)])
        out[mid] = {
            "polygon": poly,
            "level": round(float(s["ground"]), 1),
            "drop": float(s["drop"]),
        }
    return out


def update_terraces(scene: dict[str, Any], path: Path = TOPOGRAPHY) -> int:
    """Write the generated terraces into ``topography.yaml`` (terrain_model.platforms).

    Terraces written earlier are kept (once a terrace is cut the ground under the monument is
    level, so it no longer shows as steep); new ones are added. Returns the number written.
    """
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    kept: dict[str, str] = {}
    if _TERRACE_START in lines:
        i = lines.index(_TERRACE_START)
        j = lines.index(_TERRACE_END)
        for ln in lines[i + 1 : j]:
            m = re.search(r"monument: (\w+)", ln)
            if m:
                kept[m.group(1)] = ln
        del lines[i : j + 1]
    else:
        i = next(k for k, ln in enumerate(lines) if ln.startswith("  # STREET CUTS"))
    for mid, e in terrace_entries(scene).items():
        if mid in kept:
            continue
        kept[mid] = (
            f"  - {{id: f2_terrace_{mid}, monument: {mid}, polygon: {json.dumps(e['polygon'])}, "
            f'level: [{e["level"]}, {e["level"]}], blend: 4, walls: true, note: "F2: the ground '
            f"fell {e['drop']:.1f} m under the monument; cut and built up to the level at its "
            f'centre, walled"}}'
        )

    # the lower terraces first: where two meet, the higher one keeps its edge (terrain.gd stamps
    # the platforms in order) and the lower is walled against it
    def level_of(line: str) -> float:
        m = re.search(r"level: \[([-0-9.]+)", line)
        return float(m.group(1)) if m else 0.0

    block = [
        _TERRACE_START,
        *sorted(kept.values(), key=lambda ln: (level_of(ln), ln)),
        _TERRACE_END,
    ]
    lines[i:i] = block
    path.write_text("\n".join(lines), encoding="utf-8")
    return len(kept)


# --- end F2 terraces ---------------------------------------------------------------------------


# --- F3 houses --------------------------------------------------------------------------------
# What the F3 houses checks of audit.gd (``_f3_houses``: the fill, the trees and the street life by
# their real meshes) found, in the summary and in section 3 of the report.

F3_HOUSES_KINDS = [
    ("house_house", "buildings of the fill interpenetrating"),
    ("house_monument", "buildings of the fill inside a monument's solids"),
    ("house_wall", "terrace, platform or clivus walls, steps or quays inside a building"),
    ("house_street", "buildings on a footway (beyond awning poles) or over a carriageway"),
    ("house_river", "buildings in the river"),
    ("house_base", "buildings whose floor is under the ground at the front or whose parts float"),
    ("awning_pole", "shop awnings on tall poles over ground falling away in front"),
    ("shop_alone", "lean-to shops with no house behind them to lean on"),
    ("tree_building", "trees with their trunk inside a building or their crown through it"),
    ("tree_street", "trees in a carriageway"),
    ("tree_river", "trees in the river"),
    ("tree_wall", "trees with their trunk or crown in the Servian wall"),
    ("life_solid", "people, stalls or the walkers' and carts' lanes inside a solid"),
    ("stall_street", "stalls in a carriageway, or sunk into or floating over their ground"),
    ("lamp_smoke", "lamps on no wall, kitchen smoke rising from no roof"),
]
"""``audit.gd`` F3 houses kinds: key in ``f3_houses.counts`` and a label for the report."""


def f3_houses_counts(scene: dict[str, Any]) -> dict[str, int]:
    """Totals of the F3 houses findings over the audited years, by kind."""
    out = {k: 0 for k, _ in F3_HOUSES_KINDS}
    for data in (scene.get("years") or {}).values():
        counts = (data.get("f3_houses") or {}).get("counts") or {}
        for k in out:
            out[k] += int(counts.get(k, 0))
    return out


def f3_houses_rows(scene: dict[str, Any]) -> list[str]:
    """Rows of the summary table (one per kind), or none when the checks have not run."""
    if not any((d.get("f3_houses") or {}) for d in (scene.get("years") or {}).values()):
        return []
    totals = f3_houses_counts(scene)
    return [
        f"| scene (F3 houses): {label} (all years) | {totals[k]} |" for k, label in F3_HOUSES_KINDS
    ]


def f3_houses_section(scene: dict[str, Any], keep: int = 10) -> list[str]:
    """Section 3's part on the F3 houses checks: counts by year and the worst findings."""
    years = {
        y: d["f3_houses"]
        for y, d in (scene.get("years") or {}).items()
        if isinstance(d.get("f3_houses"), dict)
    }
    if not years:
        return []
    out = [
        "### The fill, the trees and the street life (F3 houses)",
        "",
        "`audit.gd` `_f3_houses`: every building of the fill (houses, shops, workshops, horrea,",
        "horti, tombs, farm steadings), every tree (all three levels of detail) and the street",
        "life (people, stalls, the walkers' and carts' lanes, lamps, smoke), tested by their real",
        "meshes (each mesh's triangles clipped into 1 m height bands).",
        "",
        "| year | buildings | " + " | ".join(k for k, _ in F3_HOUSES_KINDS) + " |",
        "|---|---|" + "---|" * len(F3_HOUSES_KINDS),
    ]
    for y, f in sorted(years.items(), key=lambda kv: int(kv[0])):
        counts = f.get("counts") or {}
        out.append(
            f"| {_yr(int(y))} | {f.get('buildings', '')} | "
            + " | ".join(str(counts.get(k, 0)) for k, _ in F3_HOUSES_KINDS)
            + " |"
        )
    out.append("")
    for k, label in F3_HOUSES_KINDS:
        items: dict[str, list[str]] = {}
        for y, f in years.items():
            for txt in ((f.get("worst") or {}).get(k) or [])[:keep]:
                items.setdefault(str(txt), []).append(_yr(int(y)))
        if not items:
            continue
        out.append(f"**{label}** (the worst, at most {keep} a year)")
        out.append("")
        for txt, ys in sorted(items.items()):
            out.append(f"- {_md_escape(txt)} ({', '.join(ys)})")
        out.append("")
    return out


# --- end F3 houses -----------------------------------------------------------------------------


SCENE_KINDS = [
    ("overlaps", "monuments whose solids overlap another standing monument"),
    ("floating", "monuments whose base is more than 0.5 m above the ground under a corner"),
    ("buried", "monuments whose base is more than 1 m below the ground under a corner"),
    ("houses_in_monuments", "houses standing inside a monument's footprint"),
    ("houses_on_streets", "houses standing on a street"),
    ("in_river", "monuments standing in the river"),
    ("streets_through", "streets passing through a monument"),
]

# F3 monuments (begin): the checks of client/scripts/urbs/monument_audit.gd (audit.gd runs them)
F3_MONUMENT_KINDS = [
    ("part_overlaps", "monuments whose parts (real mesh pieces) run through another's"),
    ("parts_floating", "monuments with parts resting on nothing"),
    ("parts_sunk", "monuments with columns sunk into what they stand on"),
    ("coplanar", "faces of two materials in one plane that can be seen (they flicker)"),
    ("view_inside", "monuments whose --at street camera stands inside a solid or a house"),
    ("view_misses", "monuments whose --at street camera does not see the front"),
    ("interior_voids", "interiors with sight lines from the door that meet nothing (black)"),
    ("interior_figures", "interiors with figures through a wall or floor"),
    ("interior_missing", "enterable monuments with no interior"),
    ("interior_starts", "interiors whose visitor starts outside, against or facing a wall"),
]
SCENE_KINDS.extend(F3_MONUMENT_KINDS)
# F3 monuments (end)
# F3 ground (begin): the ground and what is laid on it (audit.gd, the F3 ground checks)
SCENE_KINDS += [
    ("bank_sawtooth", "F3 ground: 100 m stretches of a Tiber bank with a saw-toothed water line"),
    ("zfight", "F3 ground: surfaces within 5 cm of each other (paving, streets, quays, water)"),
    ("ground_holes", "F3 ground: ground missing where the camera can see it"),
    ("empty_terraces", "F3 ground: terrace walls with nothing standing on the terrace"),
    ("platform_steps", "F3 ground: platforms more than 1 m off the street or ground in front"),
    ("stair_ends", "F3 ground: steps that do not meet the ground at both ends"),
    ("chunk_seams", "F3 ground: chunk edges where two levels of detail do not meet"),
    ("streets_ground", "F3 ground: stretches of street sunk under or floating over the ground"),
    (
        "wall_feet",
        "F3 ground: 100 m squares with walls footed above a level of detail's ground",
    ),
    (
        "meadow_fronts",
        "F3 ground: 250 m squares with house or shop lots with meadow at their fronts",
    ),
]
# F3 ground (end)


# =============================================================================================
# The audit and its report
# =============================================================================================


@dataclass
class Audit:
    """Everything the audit found."""

    verdicts: list[Verdict]
    positions: list[dict[str, Any]]
    outlines: list[dict[str, Any]]
    measured: list[dict[str, Any]]
    lines: list[dict[str, Any]]
    relations: list[Relation]
    dates: list[dict[str, Any]]
    pa_dates: list[dict[str, Any]]
    counts: dict[str, dict[str, int]]
    topography: list[dict[str, Any]]
    scene: dict[str, Any]
    explained: dict[str, Any]
    dataset_size: dict[str, int]

    def summary(self) -> dict[str, Any]:
        """The headline counts."""
        missing = [v for v in self.verdicts if v.status == "missing"]
        s: dict[str, Any] = {
            "references": {
                src: {
                    st: sum(1 for v in self.verdicts if v.ref.source == src and v.status == st)
                    for st in ("matched", "excluded", "missing")
                }
                for src in ("pleiades", "platner")
            },
            "missing": len(missing),
            "missing_republic": sum(
                1 for v in missing if v.ref.earliest is not None and v.ref.earliest <= -27
            ),
            "misplaced": sum(
                1
                for p in self.positions
                if p["status"] == "misplaced" and p["id"] not in self.explained.get("positions", {})
            ),
            "outline_flags": sum(1 for o in self.outlines if o["flags"]),
            "measured_flags": sum(1 for m in self.measured if m["flags"]),
            "relations_failed": sum(1 for r in self.relations if r.ok is False),
            "date_issues": len(self.dates),
            "dataset": self.dataset_size,
        }
        for key, _ in SCENE_KINDS:
            s[f"scene_{key}"] = sum(
                len(y.get(key, [])) for y in self.scene.get("years", {}).values()
            )
        s.update({f"f3_{k}": v for k, v in f3_houses_counts(self.scene).items()})  # F3 houses
        return s


def run_audit(
    ds: Dataset | None = None,
    pleiades: dict[str, Any] | None = None,
    platner: dict[str, Any] | None = None,
    refs: dict[str, Any] | None = None,
    scene: dict[str, Any] | None = None,
    events: str | None = None,
) -> Audit:
    """Run every check (no network, no Godot: the scene findings are read from disk)."""
    ds = ds or load_dataset()
    pleiades = pleiades if pleiades is not None else load_json(PLEIADES_FILE)
    platner = platner if platner is not None else load_json(PLATNER_FILE)
    refs = refs if refs is not None else load_references()
    scene = scene if scene is not None else load_scene()
    events = events if events is not None else content_text()
    all_refs = pleiades_refs(pleiades) + platner_refs(platner)
    tg = targets(ds)
    verdicts = match_refs(all_refs, tg, refs.get("verdicts", {}))
    # a missing entry is more important when the other reference has it too
    pl_names = [r.names for r in all_refs if r.source == "pleiades"]
    for v in verdicts:
        if v.status == "missing":
            other = (
                pl_names
                if v.ref.source == "platner"
                else [r.names for r in all_refs if r.source == "platner"]
            )
            cross = any(names_match(a, b) for ns in other for a in ns for b in v.ref.names)
            v.score = score_missing(v, cross, events)
    by_key = {f"{r.source}:{r.key}": r for r in all_refs}
    pl_lines = {r.key: r.lines for r in all_refs if r.source == "pleiades" and r.lines}
    explained = refs.get("explained", {}) or {}
    return Audit(
        verdicts=verdicts,
        positions=check_positions(ds, verdicts, by_key),
        outlines=check_outlines(ds, verdicts, set((refs.get("outline_skip") or {}).keys())),
        measured=check_measured(ds, refs.get("measured", {}) or {}),
        lines=check_lines(ds, verdicts),
        relations=check_relations(ds, pl_lines),
        dates=check_dates(ds),
        pa_dates=check_pa_dates(ds, verdicts),
        counts=counts_by_year(ds),
        topography=check_topography(ds, scene),
        scene=scene,
        explained=explained,
        dataset_size={
            "monuments": len(ds.recs) - len(ds.empire),
            "empire": len(ds.empire),
            "streets": len(ds.streets),
        },
    )


def _md_escape(s: str) -> str:
    return s.replace("|", "/").replace("\n", " ")


def render_markdown(a: Audit) -> str:
    """The human report."""
    s = a.summary()
    ex = a.explained
    lines: list[str] = []
    w = lines.append
    w("# City audit: is everything in Rome there, and in the right place?")
    w("")
    w(
        "Generated by `uv run anachronism-city-audit` (`src/anachronism/tools/city_audit.py`); "
        "machine-readable copy in `data/rome/city/audit.json`. Do not edit by hand: fix the data "
        "or explain the item in `data/rome/sources/references.yaml` and re-run."
    )
    w("")
    w(
        "References: **Pleiades** (CC BY 3.0; places within 3.5 km of the Forum with a period "
        "before AD 120; https://pleiades.stoa.org) and **Platner-Ashby**, *A Topographical "
        "Dictionary of Ancient Rome* (1929, public domain; LacusCurtius); extracts in "
        "`data/rome/sources/`."
    )
    w("")
    w("## Summary")
    w("")
    w("| check | count |")
    w("|---|---|")
    w(
        f"| dataset: Republican records / Empire records / streets | {s['dataset']['monuments']} / "
        f"{s['dataset']['empire']} / {s['dataset']['streets']} |"
    )
    for src, label in (("pleiades", "Pleiades places"), ("platner", "Platner-Ashby entries")):
        r = s["references"][src]
        w(
            f"| {label}: matched / excluded with a reason / missing | {r['matched']} / "
            f"{r['excluded']} / {r['missing']} |"
        )
    w(
        f"| **missing** (all; of them dated before 27 BC) | **{s['missing']}** "
        f"({s['missing_republic']}) |"
    )
    w(
        f"| **misplaced** (beyond tolerance and beyond the reference's own accuracy) | "
        f"**{s['misplaced']}** |"
    )
    w(f"| orientation or size against published measurements | {s['measured_flags']} |")
    w(f"| orientation or size against the outline of the remains | {s['outline_flags']} |")
    w(f"| relations the sources fix, failed | {s['relations_failed']} |")
    w(f"| date issues | {s['date_issues']} |")
    for key, label in SCENE_KINDS:
        w(f"| scene: {label} (all years) | {s.get('scene_' + key, 0)} |")
    for row in f3_houses_rows(a.scene):  # F3 houses
        w(row)
    if not a.scene.get("years"):
        w("| scene audit | not run (`--scene`) |")
    w("")

    # --- completeness
    w("## 1. Completeness")
    w("")
    missing = [v for v in a.verdicts if v.status == "missing"]
    w(
        f"{len(missing)} reference entries have no record in the dataset. Ranked by importance "
        "(sources citing it, in the Forum / Capitol / Palatine / Circus / Campus Martius core, "
        "named by the game's events, in both references, dated in the campaign), grouped by "
        "period and kind."
    )
    w("")
    for period in (
        "regal (before 509 BC)",
        "Republic (509-27 BC)",
        "Empire to AD 120",
        "undated (attested by an early author)",
    ):
        group = [v for v in missing if period_of(v.ref.earliest) == period]
        if not group:
            continue
        w(f"### Missing: {period} ({len(group)})")
        w("")
        kinds = Counter(v.ref.kind for v in group)
        for kind, _ in kinds.most_common():
            kg = sorted(
                (v for v in group if v.ref.kind == kind), key=lambda v: (-v.score, v.ref.title)
            )
            w(f"**{kind}** ({len(kg)})")
            w("")
            w("| score | entry | source | earliest | zone | link |")
            w("|---|---|---|---|---|---|")
            for v in kg:
                r = v.ref
                w(
                    f"| {v.score} | {_md_escape(r.title)} | {r.source} | {_yr(r.earliest)} | "
                    f"{r.zone} | [{r.key}]({r.url}) |"
                )
            w("")
    excl = [v for v in a.verdicts if v.status == "excluded"]
    w(f"### Excluded with a reason ({len(excl)})")
    w("")
    w("| entry | source | reason |")
    w("|---|---|---|")
    for v in sorted(excl, key=lambda v: (v.ref.source, v.ref.title)):
        w(f"| {_md_escape(v.ref.title)} | {v.ref.source} {v.ref.key} | {_md_escape(v.reason)} |")
    w("")

    # --- position
    w("## 2. Position")
    w("")
    w(
        "Our placed centre (`lat`/`lon` plus `offset_m`, as `monuments.gd` places it) against the "
        "matched Pleiades place's own location (the centre of the outline of the remains where "
        "Pleiades has one). Tolerance 10 m in the Forum and on the Capitol, 20 m elsewhere. "
        "*Misplaced* means beyond the tolerance and beyond the reference's own accuracy; *within "
        "reference accuracy* is not corrected towards a rougher reference."
    )
    w("")
    w("| id | Pleiades | distance m | tolerance | reference accuracy m | status | note |")
    w("|---|---|---|---|---|---|---|")
    for p in a.positions:
        if p["status"] == "ok":
            continue
        note = (ex.get("positions") or {}).get(p["id"], "")
        w(
            f"| {p['id']} | [{p['pleiades']}](https://pleiades.stoa.org/places/{p['pleiades']}) "
            f"{_md_escape(p['title'])} | {p['distance_m']} (towards {p['bearing_to_reference']}) | "
            f"{p['tolerance_m']:.0f} | {p['reference_accuracy_m']} | {p['status']} | "
            f"{_md_escape(str(note))} |"
        )
    ok = sum(1 for p in a.positions if p["status"] == "ok")
    w("")
    w(f"{ok} of {len(a.positions)} compared records are within tolerance.")
    w("")
    w("### Streets, walls and aqueducts against the Pleiades lines")
    w("")
    w("How far the mapped line (Pleiades, inside the audited radius) lies from ours.")
    w("")
    w("| id | Pleiades | mean m | max m | accuracy m | note |")
    w("|---|---|---|---|---|---|")
    for ln in a.lines:
        note = (ex.get("lines") or {}).get(ln["id"], "")
        w(
            f"| {ln['id']} | {ln['pleiades']} {_md_escape(ln['title'])} | {ln['mean_m']} | "
            f"{ln['max_m']} | {ln['accuracy_m']} | {_md_escape(str(note))} |"
        )
    w("")
    w("### Orientation and size: published measurements")
    w("")
    w("| id | bearing ours / ref (diff) | length ours / ref | width ours / ref | flags | source |")
    w("|---|---|---|---|---|---|")
    for m in a.measured:
        b = (
            f"{m.get('bearing_ours')} / {m.get('bearing_ref')} ({m.get('bearing_diff')})"
            if "bearing_ref" in m
            else ""
        )
        ln_ = f"{m.get('length_ours')} / {m.get('length_ref')}" if "length_ref" in m else ""
        wd = f"{m.get('width_ours')} / {m.get('width_ref')}" if "width_ref" in m else ""
        w(
            f"| {m['id']} | {b} | {ln_} | {wd} | {', '.join(m['flags'])} | "
            f"{_md_escape(str(m['source']))} |"
        )
    w("")
    w("### Orientation and size: the outline of the remains (Pleiades / OpenStreetMap)")
    w("")
    w(
        "The smallest rectangle round the remains as mapped; the remains may be only part of the "
        "building (a podium, a corner), so a flag here is a pointer, not a verdict."
    )
    w("")
    w("| id | outline long x short, axis | ours long x short, axis | axis diff | flags | note |")
    w("|---|---|---|---|---|---|")
    for o in a.outlines:
        note = (ex.get("outlines") or {}).get(o["id"], "")
        w(
            f"| {o['id']} | {o['outline_long_m']} x {o['outline_short_m']}, {o['outline_axis']} | "
            f"{o['ours_long_m']} x {o['ours_short_m']}, {o['ours_axis']} | {o['axis_diff']} | "
            f"{', '.join(o['flags'])} | {_md_escape(str(note))} |"
        )
    w("")
    w("### Relations the sources fix")
    w("")
    w("| relation | result | detail | source | note |")
    w("|---|---|---|---|---|")
    rel_notes = ex.get("relations") or {}
    for r in a.relations:
        res = "ok" if r.ok else ("FAILED" if r.ok is False else "not checked")
        # a note applies to every relation whose name contains its key
        note = (
            next((v for k, v in sorted(rel_notes.items()) if k in r.name), "") if not r.ok else ""
        )
        w(
            f"| {_md_escape(r.name)} | {res} | {_md_escape(r.detail)} | {_md_escape(r.source)} | "
            f"{_md_escape(str(note))} |"
        )
    w("")
    w("### Ground")
    w("")
    w("| id | expected m | ridge top m | built scene m | diff | flag |")
    w("|---|---|---|---|---|---|")
    for t in a.topography:
        w(
            f"| {t['id']} | {t['expected_m']} | {t.get('ridge_top_m', '')} | "
            f"{t.get('scene_m' if t['kind'] == 'valleys' else 'scene_max_m', '')} | "
            f"{t.get('diff_m')} | "
            f"{'FLAG' if t['flag'] else ''} |"
        )
    w("")
    w(
        "The repository has no modern elevation model; the ground is built from `topography.yaml` "
        "(`terrain.gd`), so the built scene is compared with the heights the sources give there."
    )
    w("")

    # --- scene
    w("## 3. Placement in the built scene")
    w("")
    if not a.scene.get("years"):
        w(
            "Not run: `uv run anachronism-city-audit --scene` runs `client/scripts/urbs/audit.gd` "
            "in headless Godot for 509, 390, 264, 133, 44 and 27 BC."
        )
    else:
        w("| year | " + " | ".join(k for k, _ in SCENE_KINDS) + " |")
        w("|---|" + "---|" * len(SCENE_KINDS))
        for y, data in sorted(a.scene["years"].items(), key=lambda kv: int(kv[0])):
            w(
                f"| {_yr(int(y))} | "
                + " | ".join(str(len(data.get(k, []))) for k, _ in SCENE_KINDS)
                + " |"
            )
        w("")
        for key, label in SCENE_KINDS:
            items: dict[str, list[str]] = {}
            for y, data in a.scene["years"].items():
                for it in data.get(key, []):
                    txt = it if isinstance(it, str) else json.dumps(it, sort_keys=True)
                    items.setdefault(txt, []).append(_yr(int(y)))
            if not items:
                continue
            w(f"**{label}**")
            w("")
            for txt, years in sorted(items.items()):
                # a note is keyed "kind:id" (one kind of finding), "id" (all of them) or
                # "kind:*" (every finding of that kind)
                first = txt.split(" ")[0]
                sc = ex.get("scene") or {}
                note = sc.get(f"{key}:{first}", sc.get(first, sc.get(f"{key}:*", "")))
                w(f"- {_md_escape(txt)} ({', '.join(years)}){' - ' + note if note else ''}")
            w("")
        # F2: not faults, the cure for them: what stands on a podium, foundation or terrace
        last = max(a.scene["years"], key=int)
        founded = a.scene["years"][last].get("founded") or []
        if founded:
            w(
                f"**monuments on sloping ground, {_yr(int(last))}** ({len(founded)}): each "
                "stands on a"
            )
            w("podium or foundation down to its lowest ground (monuments.gd), and where the ground")
            w("falls more than 3 m on a terrace cut into the hill with retaining walls")
            w("(topography.yaml `F2 TERRACES`, `--terraces`); the figure is the fall that is left.")
            w("")
            for txt in founded:
                w(f"- {_md_escape(str(txt))}")
            w("")
        for row in f3_houses_section(a.scene):  # F3 houses
            w(row)
    # --- time
    w("## 4. Time")
    w("")
    w("Monuments drawn in each standard year (`monuments.gd` `state_at`, ported to Python):")
    w("")
    states = sorted({k for c in a.counts.values() for k in c if k != "total"})
    w("| year | total | " + " | ".join(states) + " |")
    w("|---|---|" + "---|" * len(states))
    for y, c in a.counts.items():
        w(f"| {y} | {c.get('total', 0)} | " + " | ".join(str(c.get(k, 0)) for k in states) + " |")
    w("")
    w(f"### Date issues ({len(a.dates)})")
    w("")
    for d in a.dates:
        note = (ex.get("dates") or {}).get(d["id"], "")
        w(f"- `{d['id']}`: {_md_escape(d['issue'])}{' - ' + _md_escape(str(note)) if note else ''}")
    w("")
    w(f"### Building years not named in the matched Platner-Ashby article ({len(a.pa_dates)})")
    w("")
    w(
        "A pointer to re-read the article, not an error: P-A often gives the date only through the "
        "consul's name, or the record's year comes from another source."
    )
    w("")
    w("| id | our year | P-A entry | years P-A names | note |")
    w("|---|---|---|---|---|")
    for d in a.pa_dates:
        note = (ex.get("dates") or {}).get(d["id"], "")
        w(
            f"| {d['id']} | {_yr(d['built'])} | {_md_escape(d['pa'])} | "
            f"{', '.join(_yr(y) for y in d['pa_years'])} | {_md_escape(str(note))} |"
        )
    w("")
    return "\n".join(lines) + "\n"


def audit_json(a: Audit) -> dict[str, Any]:
    """The machine-readable audit."""
    return {
        "summary": a.summary(),
        "missing": [
            {
                "source": v.ref.source,
                "key": v.ref.key,
                "title": v.ref.title,
                "kind": v.ref.kind,
                "earliest": v.ref.earliest,
                "zone": v.ref.zone,
                "score": v.score,
                "url": v.ref.url,
            }
            for v in sorted(a.verdicts, key=lambda v: -v.score)
            if v.status == "missing"
        ],
        "matched": sorted(
            [
                {
                    "source": v.ref.source,
                    "key": v.ref.key,
                    "title": v.ref.title,
                    "targets": v.targets,
                    "how": v.how,
                }
                for v in a.verdicts
                if v.status == "matched"
            ],
            key=lambda x: (str(x["source"]), str(x["key"])),
        ),
        "excluded": sorted(
            [
                {"source": v.ref.source, "key": v.ref.key, "title": v.ref.title, "reason": v.reason}
                for v in a.verdicts
                if v.status == "excluded"
            ],
            key=lambda x: (str(x["source"]), str(x["key"])),
        ),
        "positions": a.positions,
        "lines": a.lines,
        "measured": a.measured,
        "outlines": a.outlines,
        "relations": [r.__dict__ for r in a.relations],
        "dates": a.dates,
        "pa_dates": a.pa_dates,
        "counts": a.counts,
        "topography": a.topography,
    }


def main(argv: Sequence[str] | None = None) -> int:
    """Command-line entry point."""
    ap = argparse.ArgumentParser(prog="anachronism-city-audit", description=__doc__)
    ap.add_argument(
        "--refresh",
        action="store_true",
        help="download Pleiades and Platner-Ashby again and rewrite the extracts",
    )
    ap.add_argument("--cache", type=Path, help="keep downloaded pages here between refreshes")
    ap.add_argument(
        "--scene",
        action="store_true",
        help="run the Godot audit (client/scripts/urbs/audit.gd) for the six years",
    )
    ap.add_argument(
        "--terraces",
        action="store_true",
        help="cut a terrace (topography.yaml) under every monument on steep ground, from the "
        "last --scene run, re-export the city data and run --scene again",
    )
    ap.add_argument("--godot", default="/tmp/claude-0/godot", help="the Godot binary")
    ap.add_argument("--report", type=Path, default=REPORT)
    ap.add_argument("--json", type=Path, default=AUDIT_JSON)
    args = ap.parse_args(argv)
    if args.refresh:
        cache = args.cache
        print(f"Pleiades: {refresh_pleiades(cache=cache / 'pleiades' if cache else None)} places")
        print(
            f"Platner-Ashby: {refresh_platner(cache=cache / 'platner' if cache else None)} entries"
        )
    if args.scene:
        run_scene(args.godot)
    if args.terraces:
        from anachronism.tools import city_export

        print(f"terraces: {update_terraces(load_scene())}")
        city_export.export()
        run_scene(args.godot)
    a = run_audit()
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(render_markdown(a), encoding="utf-8")
    args.json.write_text(
        json.dumps(audit_json(a), indent=1, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    s = a.summary()
    print(
        f"missing {s['missing']}, misplaced {s['misplaced']}, relations failed "
        f"{s['relations_failed']}, date issues {s['date_issues']}; wrote "
        f"{args.report.relative_to(ROOT) if args.report.is_relative_to(ROOT) else args.report}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
