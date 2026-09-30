"""Content linter: ``uv run anachronism-lint`` checks every pack and lists all problems."""

from __future__ import annotations

import argparse
from collections.abc import Sequence
from pathlib import Path

from anachronism.content.issues import ContentError
from anachronism.content.loader import PACKS_DIR, load_content


def main(argv: Sequence[str] | None = None) -> int:
    """Check content packs; print a summary or every problem. Returns 0 when clean."""
    parser = argparse.ArgumentParser(
        prog="anachronism-lint", description="Check content packs for errors."
    )
    parser.add_argument("packs", nargs="*", help="pack ids to check (default: all)")
    parser.add_argument("--root", type=Path, default=PACKS_DIR, help="folder holding the packs")
    args = parser.parse_args(argv)
    try:
        content = load_content(args.packs or None, root=args.root)
    except ContentError as error:
        print(f"{len(error.issues)} problem(s) found:")
        for issue in error.issues:
            print(f"  {issue}")
        return 1
    pack_names = ", ".join(f"{pack.id} v{pack.version}" for pack in content.packs)
    print(f"OK: {pack_names}")
    print(
        f"  {len(content.techs)} techs, {len(content.provinces)} provinces, "
        f"{len(content.civs)} civs, {len(content.scenarios)} scenarios, "
        f"{len(content.terrain)} terrain types, {len(content.resources)} resources"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
