"""Build the client's small emblem font: only the characters that civilisation emblems use.

Usage: uv run --with fonttools python scripts/build_emblem_font.py NOTO_SERIF_SC_VARIABLE.ttf

The full Noto Serif SC font (SIL Open Font Licence, from github.com/google/fonts) is 25 MB;
the game needs a few dozen characters. Re-run after adding a civilisation whose emblem uses
new characters (a test checks that every emblem character is in the font).
"""

from __future__ import annotations

import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

from anachronism.content.loader import load_content

OUT = Path(__file__).resolve().parents[1] / "client" / "fonts" / "emblems.ttf"


def main() -> None:
    """Instance the variable font at bold and keep only the emblem characters."""
    characters = sorted({ch for civ in load_content().civs.values() for ch in civ.emblem})
    font = instancer.instantiateVariableFont(TTFont(sys.argv[1]), {"wght": 700})
    options = subset.Options()
    options.layout_features = []
    options.name_IDs = ["*"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(text="".join(characters))
    subsetter.subset(font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT)
    OUT.with_suffix(".txt").write_text("".join(characters) + "\n", encoding="utf-8")
    print(f"{len(characters)} characters -> {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
