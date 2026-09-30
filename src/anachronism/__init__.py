"""Anachronism: a turn-based historical strategy game.

Layers (see docs/ARCHITECTURE.md):
    engine   pure, deterministic game rules; no pygame, no network
    content  data-pack schemas, loading and validation
    llm      talks to language models; proposes, never decides
    ui       pygame view/controller only
    tools    command-line utilities (content linter, simulator, console play)
"""

from importlib.metadata import version

__version__ = version("anachronism")
