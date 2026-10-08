"""Content linter: ``uv run anachronism-lint`` checks every pack and lists all problems."""

from __future__ import annotations

import argparse
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Protocol

from anachronism.content.issues import ContentError
from anachronism.content.loader import PACKS_DIR, Content, load_content
from anachronism.content.schema import Confidence


def main(argv: Sequence[str] | None = None) -> int:
    """Check content packs; print a summary or every problem. Returns 0 when clean."""
    parser = argparse.ArgumentParser(
        prog="anachronism-lint", description="Check content packs for errors."
    )
    parser.add_argument("packs", nargs="*", help="pack ids to check (default: all)")
    parser.add_argument("--root", type=Path, default=PACKS_DIR, help="folder holding the packs")
    parser.add_argument(
        "--review", action="store_true", help="list what still needs a source (brief §2.14)"
    )
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
    if args.review:
        review(content)
    return 0


class _Reviewed(Protocol):
    @property
    def sources(self) -> tuple[str, ...]: ...

    @property
    def confidence(self) -> Confidence: ...


def review(content: Content) -> None:
    """Print the source-review checklist: confidence tiers, and entries with no source."""
    groups: dict[str, Mapping[str, _Reviewed]] = {
        "advancements": content.techs,
        "civilisations": content.civs,
        "scenarios": content.scenarios,
    }
    for label, entries in groups.items():
        tiers = dict.fromkeys(Confidence, 0)
        unsourced: list[str] = []
        for entry_id, entry in sorted(entries.items()):
            tiers[entry.confidence] += 1
            if not entry.sources:
                unsourced.append(entry_id)
        counts = ", ".join(f"{n} {tier.value}" for tier, n in tiers.items())
        print(f"  {label}: {counts}; {len(unsourced)} without a source")
        if unsourced:
            print("    " + ", ".join(unsourced))


if __name__ == "__main__":
    raise SystemExit(main())
