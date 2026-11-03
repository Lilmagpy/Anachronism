"""Convert Natural Earth rivers (public domain) to pixel polylines on a game height map.

Usage: uv run python scripts/build_rivers.py RIVERS.geojson BOUNDS.json OUT.json [MAX_RANK]
Keeps rivers with scalerank <= MAX_RANK (default 9; lower = more important), including
the stretches that run through lakes so rivers have no gaps.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from typing import Any


def mercator(lat: float) -> float:
    """Web Mercator y for a latitude in degrees (unscaled)."""
    return math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))


def main() -> None:
    """Read the rivers and the height-map bounds, write pixel polylines."""
    rivers_path, bounds_path, out_path = sys.argv[1:4]
    max_rank = int(sys.argv[4]) if len(sys.argv) > 4 else 9
    bounds = json.loads(Path(bounds_path).read_text(encoding="utf-8"))
    west, east = bounds["west"], bounds["east"]
    top, bottom = mercator(bounds["north"]), mercator(bounds["south"])
    width, height = bounds["width"], bounds["height"]

    def to_pixel(lon: float, lat: float) -> list[float]:
        x = (lon - west) / (east - west) * width
        y = (top - mercator(lat)) / (top - bottom) * height
        return [round(x, 1), round(y, 1)]

    features = json.loads(Path(rivers_path).read_text(encoding="utf-8"))["features"]
    out: list[dict[str, Any]] = []
    for feature in features:
        props = feature["properties"]
        if props.get("featurecla") not in {"River", "Lake Centerline"}:
            continue
        if (props.get("scalerank") or 99) > max_rank:
            continue
        geometry = feature["geometry"]
        coords = geometry["coordinates"]
        lines = coords if geometry["type"] == "MultiLineString" else [coords]
        for line in lines:
            points = [to_pixel(lon, lat) for lon, lat, *_ in line]
            inside = [p for p in points if 0 <= p[0] <= width and 0 <= p[1] <= height]
            if len(inside) >= 2:
                name = props.get("name_en") or props.get("name") or ""
                out.append({"name": name, "rank": props["scalerank"], "points": inside})
    result = {"source": "Natural Earth 10m rivers (public domain)", "rivers": out}
    Path(out_path).write_text(json.dumps(result, separators=(",", ":")), encoding="utf-8")
    names = sorted({r["name"] for r in out if r["name"]})
    print(f"{len(out)} river lines, names: {names[:25]}")


if __name__ == "__main__":
    main()
