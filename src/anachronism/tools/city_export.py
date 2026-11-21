"""Export the city of Rome dataset (``data/rome/city``) to JSON for the Godot client.

Godot has no YAML reader, so ``uv run anachronism-city-export`` writes
``client/data/city/<name>.json`` for every YAML file in the dataset. The JSON files are
committed; run this after editing the dataset. Keys and values are copied unchanged.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "data" / "rome" / "city"
TARGET = ROOT / "client" / "data" / "city"


def export(source: Path = SOURCE, target: Path = TARGET) -> list[Path]:
    """Write one JSON file per YAML file and return the files written."""
    target.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for path in sorted(source.glob("*.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        out = target / (path.stem + ".json")
        out.write_text(json.dumps(data, ensure_ascii=False, indent=0, sort_keys=True) + "\n")
        written.append(out)
    return written


def main() -> int:
    """Command-line entry point."""
    for path in export():
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
