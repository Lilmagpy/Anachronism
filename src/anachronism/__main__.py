"""Command-line entry point: ``uv run anachronism`` or ``python -m anachronism``.

Until the game window arrives in Phase 3, this starts the text console.
"""

from anachronism.tools.console import main

__all__ = ["main"]

if __name__ == "__main__":
    raise SystemExit(main())
