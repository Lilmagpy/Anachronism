"""Battle ground (D-270): what a river, hills, forest or open plain does in a field battle.

All numbers are in the core rules (``ArmyRules``); the terrain ids that count as high, rough
or open ground are rules data too.
"""

from __future__ import annotations

from dataclasses import dataclass

from anachronism.content.schema import Unit
from anachronism.content.schema.rules import ArmyRules
from anachronism.engine.deployment import LEFT, RIGHT
from anachronism.engine.fixed import BP
from anachronism.engine.state import GameState


@dataclass(frozen=True)
class Ground:
    """The ground of a battle."""

    terrain: str
    name: str
    river: bool
    high: bool
    rough: bool
    open: bool


def ground_of(state: GameState, province_id: str) -> Ground:
    """The ground of the battle in a province."""
    rules = state.world.rules.armies
    geo = state.world.geography[province_id]
    return Ground(
        terrain=geo.terrain,
        name=state.world.terrain[geo.terrain].name.lower(),
        river=geo.river,
        high=geo.terrain in rules.high_terrain,
        rough=geo.terrain in rules.rough_terrain,
        open=geo.terrain in rules.open_terrain,
    )


def adjust(
    rules: ArmyRules,
    ground: Ground,
    unit: Unit,
    attacking: bool,
    place: str,
    river_bp: int,
) -> int:
    """Extra power (bp, may be negative) a kind of soldier has on this ground in this place.

    ``river_bp`` is the share of the river's full penalty the attackers still feel.
    """
    out = 0
    horse = unit.kind == "mounted"
    if ground.river and attacking:
        out -= rules.river_attack_bp * river_bp // BP
        if horse:
            out -= rules.river_horse_bp * river_bp // BP
    if ground.high:
        if not attacking and unit.kind == "missile":
            out += rules.hill_missile_bp
        if attacking and horse:
            out -= rules.hill_charge_bp
    if ground.rough and unit.kind in ("mounted", "elephant"):
        out -= rules.rough_horse_bp
    if ground.open and horse and place in (LEFT, RIGHT):
        out += rules.open_horse_bp
    return out


def river_held(rules: ArmyRules, dug_in: bool) -> int:
    """The river's full penalty for the crossing (bp of the rule): more if the bank is held."""
    return BP + (rules.river_held_bp if dug_in else 0)


def text(state: GameState, ground: Ground, dug_in: bool = False) -> str:
    """The ground in a sentence for a battle report or the odds preview."""
    notes: list[str] = []
    if ground.river:
        notes.append(
            "The attackers must cross a river under the defenders' bank: horse suffer most."
            if not dug_in
            else "The defenders hold the river line, dug in: the crossing will be costly, "
            "and horse suffer most."
        )
    if ground.high:
        notes.append(
            f"On {ground.name} the defenders' archers shoot better and a horse charge "
            "uphill is blunted."
        )
    if ground.rough:
        notes.append(
            f"In the {ground.name} horse and elephants fight badly and no line can stretch."
        )
    if ground.open:
        notes.append(f"Open {ground.name}: horse are strong on the wings.")
    return " ".join(notes) if notes else f"Ordinary ground ({ground.name}): no great advantage."
