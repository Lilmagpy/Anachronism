"""Architecture rules from docs/ARCHITECTURE.md §1, checked on every test run.

Each layer of the game may only depend on certain others. These tests read the source code
(without running it) and fail with a clear message when a forbidden import appears.
"""

from __future__ import annotations

import ast
from collections.abc import Iterator
from pathlib import Path

import pytest

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
PACKAGE_DIR = SRC_DIR / "anachronism"

NETWORK = frozenset(
    {"socket", "ssl", "http", "urllib", "httpx", "requests", "aiohttp", "anthropic"}
)
PYGAME = frozenset({"pygame", "pygame_gui"})
# Anything that would make two runs with the same seed and actions differ.
NONDETERMINISM = frozenset(
    {
        "random",
        "secrets",
        "uuid",
        "time",
        "datetime",
        "threading",
        "asyncio",
        "concurrent",
        "multiprocessing",
    }
)


def _layers(*names: str) -> frozenset[str]:
    return frozenset(f"anachronism.{name}" for name in names)


FORBIDDEN_IMPORTS: dict[str, frozenset[str]] = {
    "engine": NETWORK | PYGAME | NONDETERMINISM | _layers("llm", "ui", "tools"),
    "content": NETWORK | PYGAME | _layers("engine", "llm", "ui", "tools"),
    "llm": PYGAME | _layers("ui", "tools"),
}


def module_name(path: Path) -> str:
    """Return the dotted module name of a file under src/, e.g. 'anachronism.engine.turn'."""
    parts = list(path.relative_to(SRC_DIR).with_suffix("").parts)
    if parts[-1] == "__init__":
        parts.pop()
    return ".".join(parts)


def imported_modules(
    source: str, module: str, *, is_package: bool = False
) -> Iterator[tuple[int, str]]:
    """Yield (line number, absolute module name) for every import statement in ``source``.

    ``from x import y`` yields both ``x`` and ``x.y`` so that ``from anachronism import llm``
    is caught. Relative imports are resolved against ``module``.
    """
    package = module if is_package else module.rpartition(".")[0]
    package_parts = package.split(".")
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            for alias in node.names:
                yield node.lineno, alias.name
        elif isinstance(node, ast.ImportFrom):
            base = node.module or ""
            if node.level:
                anchor = package_parts[: len(package_parts) - node.level + 1]
                base = ".".join([*anchor, base] if base else anchor)
            yield node.lineno, base
            for alias in node.names:
                yield node.lineno, f"{base}.{alias.name}"


def is_forbidden(name: str, banned: frozenset[str]) -> bool:
    """Return True if ``name`` is a banned module or one of its submodules."""
    return any(name == item or name.startswith(f"{item}.") for item in banned)


@pytest.mark.parametrize("layer", sorted(FORBIDDEN_IMPORTS))
def test_layer_package_exists(layer: str) -> None:
    assert (PACKAGE_DIR / layer / "__init__.py").is_file()


@pytest.mark.parametrize("layer", sorted(FORBIDDEN_IMPORTS))
def test_layer_respects_import_rules(layer: str) -> None:
    violations = [
        f"{path.relative_to(SRC_DIR)}:{line} imports {name}"
        for path in sorted((PACKAGE_DIR / layer).rglob("*.py"))
        for line, name in imported_modules(
            path.read_text(encoding="utf-8"),
            module_name(path),
            is_package=path.name == "__init__.py",
        )
        if is_forbidden(name, FORBIDDEN_IMPORTS[layer])
    ]
    assert not violations, (
        f"The {layer} layer broke an architecture rule (docs/ARCHITECTURE.md §1):\n"
        + "\n".join(violations)
    )


@pytest.mark.parametrize(
    ("source", "expected"),
    [
        ("import pygame.display", "pygame.display"),
        ("from ..llm import pipeline", "anachronism.llm"),
        ("from anachronism import ui", "anachronism.ui"),
        ("from . import rng", "anachronism.engine.rng"),
    ],
)
def test_import_scanner_resolves_names(source: str, expected: str) -> None:
    names = {name for _, name in imported_modules(source, "anachronism.engine.turn")}
    assert expected in names


def test_import_scanner_resolves_relative_imports_in_packages() -> None:
    names = {
        name
        for _, name in imported_modules(
            "from .rng import GameRng", "anachronism.engine", is_package=True
        )
    }
    assert "anachronism.engine.rng" in names


def test_forbidden_matching_is_exact_about_module_boundaries() -> None:
    assert is_forbidden("pygame.display", frozenset({"pygame"}))
    assert not is_forbidden("timeit", frozenset({"time"}))
