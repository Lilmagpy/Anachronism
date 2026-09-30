"""Command-line entry point: ``uv run anachronism`` or ``python -m anachronism``."""

from __future__ import annotations

import argparse
import platform
from collections.abc import Sequence

from anachronism import __version__


def describe_platform() -> str:
    """Return a human-readable description of the operating system, e.g. 'macOS 15.1 (arm64)'."""
    system = platform.system()
    if system == "Darwin":
        return f"macOS {platform.mac_ver()[0]} ({platform.machine()})"
    return f"{system} {platform.release()} ({platform.machine()})"


def main(argv: Sequence[str] | None = None) -> int:
    """Run the launcher and return a process exit code.

    Args:
        argv: Command-line arguments without the program name; ``None`` reads ``sys.argv``.
    """
    parser = argparse.ArgumentParser(
        prog="anachronism",
        description="A turn-based strategy game about ideas ahead of their time.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    parser.parse_args(argv)

    print(f"Anachronism {__version__}")
    print(f"Python {platform.python_version()} on {describe_platform()}")
    print("Setup works. There is nothing to play yet: the game engine arrives in Phase 1.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
