"""The engine's public entry points: start, act, end turns, replay."""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Sequence

from anachronism.content.loader import Content
from anachronism.engine.actions import LoggedAction
from anachronism.engine.commands import apply_action
from anachronism.engine.reports import snapshot
from anachronism.engine.setup import build_state
from anachronism.engine.state import GameState
from anachronism.engine.turn import end_turn

__all__ = ["apply_action", "end_turn", "new_game", "replay"]


def new_game(content: Content, scenario_id: str, seed: int) -> GameState:
    """Start a scenario with a seed; the same inputs always give the same game."""
    state = build_state(content, scenario_id, seed)
    for civ_id in sorted(state.civs):
        state.civs[civ_id].history.append(snapshot(state, civ_id))
    return state


def replay(initial: GameState, log: Sequence[LoggedAction], until_turn: int) -> GameState:
    """Rebuild a game from its starting state and action log (D-021).

    Actions are re-applied in their original order at the turn they were taken, then turns
    are resolved until ``until_turn`` turns have been completed.
    """
    by_turn: dict[int, list[LoggedAction]] = defaultdict(list)
    for entry in log:
        by_turn[entry.turn].append(entry)
    state = initial
    while state.turn < until_turn:
        for entry in by_turn.get(state.turn, []):
            state, _ = apply_action(state, entry.action)
        state, _ = end_turn(state)
    for entry in by_turn.get(state.turn, []):
        state, _ = apply_action(state, entry.action)
    return state
