"""The fall is not the end (D-113, after D-011): dynasties fall and states rise again.

A state that collapses from within, but still holds land, is taken over by a new dynasty:
the old order's failures are forgiven (revolts are counted afresh, unrest eases) but the new
house's mandate is untested (low legitimacy). A state destroyed by conquest lives on while
its people remember it: where they rise against their conquerors, the state is restored,
with that province as its capital. Only when no people anywhere remember it is it gone.
"""

from __future__ import annotations

from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.state import GameState


def renew(state: GameState, events: EventLog) -> None:
    """Every collapsed state that still holds land passes to a new dynasty."""
    rules = state.world.rules.society
    for civ_id in sorted(state.civs):
        civ = state.civs[civ_id]
        owned = state.owned_provinces(civ_id)
        if not civ.collapsed or not owned:
            continue
        civ.collapsed = False
        civ.dynasties += 1
        civ.revolts = 0
        civ.starting_provinces = len(owned)
        civ.stats.unrest_bp = clamp(
            civ.stats.unrest_bp - apply_bp(civ.stats.unrest_bp, rules.dynasty_unrest_relief_bp),
            0,
            BP,
        )
        civ.stats.legitimacy_bp = rules.dynasty_legitimacy_bp
        civ.ruler = ""
        civ.ruler_age = 35
        civ.rulers += 1
        events.add(
            civ_id,
            "dynasty",
            f"From the ruins of the old order a new dynasty takes the {civ.adjective} throne.",
            civ.name,
        )


def remembered_in(state: GameState, civ_id: str) -> list[str]:
    """Provinces under foreign rule whose people still think of themselves as this state's."""
    return [
        pid
        for pid in sorted(state.provinces)
        if state.provinces[pid].people == civ_id and state.provinces[pid].owner != civ_id
    ]


def restore(state: GameState, civ_id: str, province_id: str) -> None:
    """A fallen state rises again in a province whose people remember it."""
    civ = state.civs[civ_id]
    province = state.provinces[province_id]
    province.owner = civ_id
    province.held_since = state.turn
    civ.capital = province_id
    civ.collapsed = False
    civ.revolts = 0
    civ.starting_provinces = 1
    civ.dynasties += 1
    civ.stats.legitimacy_bp = state.world.rules.society.dynasty_legitimacy_bp
