"""Fighting power (D-099, D-270): what soldiers are worth in a battle.

``side_power`` weighs a whole side as one mass (the skirmish, the odds of a hopeless fight).
``wing_powers`` weighs the same men wing by wing as they stand in the line, so that each
wing meets only the kinds of soldier opposite it (spears against the horse across from them).
"""

from __future__ import annotations

from collections.abc import Callable

from anachronism.content.schema import Unit
from anachronism.engine.deployment import FACING, LINE, PLACES
from anachronism.engine.fixed import BP, apply_bp
from anachronism.engine.ground import Ground, adjust
from anachronism.engine.state import Army, GameState

Parts = dict[str, list[tuple[Army, dict[str, int]]]]
"""One side in the line: place -> (army, its men there by unit id)."""


def trait_bp(state: GameState, army: Army, trait: str) -> int:
    """The strength of a general's gift for this army (0 if its general lacks it)."""
    return state.world.rules.armies.trait_bp.get(trait, 0) if army.trait == trait else 0


def kinds(state: GameState, armies: list[Army]) -> dict[str, int]:
    """Share of each kind of soldier among these armies (bp)."""
    total = sum(a.men for a in armies) or 1
    out: dict[str, int] = {}
    for army in armies:
        for unit_id, men in army.troops.items():
            kind = state.world.units[unit_id].kind
            out[kind] = out.get(kind, 0) + men * BP // total
    return out


def unit_power(
    unit: Unit, men: int, attacking: bool, enemy_kinds: dict[str, int], terrain: str
) -> int:
    """The fighting power of ``men`` soldiers of one kind in a battle (before morale)."""
    base = (unit.attack if attacking else unit.defence) * men
    bonus = sum(apply_bp(swing, enemy_kinds.get(kind, 0)) for kind, swing in unit.bonus_vs.items())
    bonus += unit.terrain.get(terrain, 0)
    return max(0, base * (BP + bonus) // BP)


def army_power(
    state: GameState,
    army: Army,
    troops: dict[str, int],
    enemy_kinds: dict[str, int],
    attacking: bool,
    terrain: str,
    ground: Callable[[Unit], int] | None = None,
) -> tuple[int, dict[str, int]]:
    """One army's power for the men in ``troops`` (morale, general, veterans and camp counted).

    Returns the total and each unit type's share of it. ``ground`` gives a unit's extra
    bp on this ground and in this place (wings only).
    """
    rules = state.world.rules.armies
    power = 0
    by_unit: dict[str, int] = {}
    horse = trait_bp(state, army, "horse")
    for unit_id, men in sorted(troops.items()):
        unit = state.world.units[unit_id]
        p = unit_power(unit, men, attacking, enemy_kinds, terrain)
        if ground is not None:
            p = max(0, p * (BP + ground(unit)) // BP)
        if horse and unit.kind == "mounted":
            p = p * (BP + horse) // BP
        by_unit[unit_id] = by_unit.get(unit_id, 0) + p
        power += p
    power = power * (5000 + army.morale_bp // 2) // BP
    power = power * (BP + army.skill * rules.general_skill_bp) // BP
    power = power * (BP + army.veterancy_bp) // BP
    if attacking:
        power = power * (BP + trait_bp(state, army, "bold")) // BP
    else:
        gift = trait_bp(state, army, "shield") - trait_bp(state, army, "bold") // 2
        if army.dug_in:  # a fortified camp (D-267)
            gift += rules.dug_in_bp
        power = power * (BP + gift) // BP
    return power, by_unit


def field_factor(state: GameState, armies: list[Army], province_id: str, attacking: bool) -> int:
    """The defenders' hold on the ground (hills, mountains, marsh) as a bp multiplier."""
    if attacking:
        return BP
    owner = state.provinces[province_id].owner
    if owner is None or not armies or armies[0].owner != owner:
        return BP
    rules = state.world.rules.armies
    ground = state.world.terrain[state.world.geography[province_id].terrain]
    extra = ground.defence_bp - BP
    return BP + apply_bp(max(0, extra), rules.field_defence_share_bp)


def side_power(
    state: GameState, armies: list[Army], enemies: list[Army], attacking: bool, province_id: str
) -> tuple[int, dict[str, int]]:
    """A side's total power in a battle, and each unit type's share of it."""
    terrain = state.world.geography[province_id].terrain
    enemy_kinds = kinds(state, enemies)
    total = 0
    by_unit: dict[str, int] = {}
    for army in armies:
        power, shares = army_power(state, army, army.troops, enemy_kinds, attacking, terrain)
        for unit_id, p in shares.items():
            by_unit[unit_id] = by_unit.get(unit_id, 0) + p
        total += power
    total = total * field_factor(state, armies, province_id, attacking) // BP
    return total, by_unit


def men_in(parts: Parts, place: str) -> int:
    """Men standing in one place of the line."""
    return sum(sum(t.values()) for _, t in parts.get(place, []))


def kinds_in(state: GameState, parts: Parts, places: tuple[str, ...]) -> dict[str, int]:
    """Share of each kind of soldier (bp) among the men in these places."""
    mass: dict[str, int] = {}
    for place in places:
        for _, troops in parts.get(place, []):
            for unit_id, men in troops.items():
                kind = state.world.units[unit_id].kind
                mass[kind] = mass.get(kind, 0) + men
    total = sum(mass.values())
    return {k: n * BP // total for k, n in mass.items()} if total else {}


def wing_powers(
    state: GameState,
    armies: list[Army],
    parts: Parts,
    enemy: Parts,
    attacking: bool,
    province_id: str,
    ground: Ground,
    river_bp: int,
) -> dict[str, int]:
    """Each place's power, the men there meeting the kinds standing opposite them.

    ``river_bp`` is how much of the river's penalty the attackers still feel (bp of its full
    rule); the reserve meets the enemy's line as a whole.
    """
    rules = state.world.rules.armies
    terrain = ground.terrain
    whole = kinds_in(state, enemy, LINE)
    factor = field_factor(state, armies, province_id, attacking)
    out: dict[str, int] = {}
    for place in PLACES:
        facing = kinds_in(state, enemy, (FACING[place],)) if place in FACING else {}
        enemy_kinds = facing or whole

        def extra(unit: Unit, here: str = place) -> int:
            return adjust(rules, ground, unit, attacking, here, river_bp)

        total = 0
        for army, troops in parts.get(place, []):
            power, _ = army_power(state, army, troops, enemy_kinds, attacking, terrain, extra)
            total += power
        out[place] = total * factor // BP
    return out
