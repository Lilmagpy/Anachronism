"""Fixtures for engine tests: real content, a fresh game, and rule overrides."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import Stage
from anachronism.engine.game import new_game
from anachronism.engine.state import GameState, Project, TechState

RuleOverride = Callable[..., None]
Give = Callable[..., None]


@pytest.fixture(scope="session")
def content() -> Content:
    return load_content()


@pytest.fixture
def game(content: Content) -> GameState:
    """A new Bronze Dawn game (seed 1), with luck switched off for exact outcomes."""
    state = new_game(content, "bronze_dawn", seed=1)
    override_rules(state, projects={"setback_chance_bp": 0, "breakthrough_chance_bp": 0})
    return state


def override_rules(state: GameState, **sections: dict[str, Any]) -> None:
    """Replace some rule values in a game, e.g. ``projects={"stall_turns": 1}``."""
    rules = state.world.rules
    updates = {
        name: getattr(rules, name).model_copy(update=values) for name, values in sections.items()
    }
    state.world = state.world.model_copy(update={"rules": rules.model_copy(update=updates)})


@pytest.fixture
def rules() -> RuleOverride:
    """The :func:`override_rules` helper, for tests that need other rule values."""
    return override_rules


def give_tech(state: GameState, civ_id: str, node_id: str, stage: Stage, spread: int = 0) -> None:
    """Put an advancement at a stage for a civilisation."""
    state.civs[civ_id].tech[node_id] = TechState(stage=stage, spread_bp=spread)


def start_project(state: GameState, civ_id: str, node_id: str, progress: int = 0) -> Project:
    """Create a project directly (bypassing feasibility), for focused tests."""
    project = Project(node_id=node_id, started_turn=state.turn, progress_bp=progress)
    state.civs[civ_id].projects[node_id] = project
    state.civs[civ_id].tech[node_id] = TechState(stage=Stage.EXPERIMENTING)
    return project


@pytest.fixture
def give() -> Give:
    """The :func:`give_tech` helper."""
    return give_tech


@pytest.fixture
def start() -> Callable[..., Project]:
    """The :func:`start_project` helper."""
    return start_project
