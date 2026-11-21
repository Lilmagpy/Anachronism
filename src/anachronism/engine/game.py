"""The engine's public entry points: start, act, end turns, replay."""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Sequence

from anachronism.content.loader import Content
from anachronism.engine.actions import LoggedAction
from anachronism.engine.armies import standing_armies
from anachronism.engine.campaign import advance, almanac
from anachronism.engine.commands import apply_action
from anachronism.engine.events import EventLog
from anachronism.engine.navies import standing_fleets
from anachronism.engine.reports import snapshot
from anachronism.engine.setup import build_state
from anachronism.engine.state import GameState
from anachronism.engine.turn import end_turn
from anachronism.engine.victory import record_start

__all__ = ["apply_action", "end_turn", "new_game", "replay"]


def new_game(
    content: Content,
    scenario_id: str,
    seed: int,
    player_civ: str | None = None,
    difficulty: str = "normal",
    chronicle: bool = False,
) -> GameState:
    """Start a scenario with a seed; the same inputs always give the same game.

    ``player_civ`` picks which civilisation the player guides (default: the scenario's);
    ``difficulty`` a level from the rules (``easy``, ``normal``, ``hard``); ``chronicle``
    plays along history in chapters (D-120), where the scenario has a campaign.
    """
    state = build_state(content, scenario_id, seed, player_civ, difficulty, chronicle)
    standing_armies(state)
    standing_fleets(state)
    for civ_id in sorted(state.civs):
        state.civs[civ_id].history.append(snapshot(state, civ_id))
    record_start(state)
    if chronicle:  # the first chapter, and the world as it stands, open the game (D-120)
        opening = EventLog(turn=state.turn, year=state.year)
        almanac(state, state.year - 1, opening)
        advance(state, opening)
        state.events.extend(opening.items)
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
