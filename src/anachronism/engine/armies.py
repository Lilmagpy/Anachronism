"""Armies, battles, sieges and supply (D-099).

Wars are fought by armies that stand in provinces. An army is raised from a province's
people, costs food and wealth to keep, marches along the map, and fights any enemy army it
meets. A battle weighs each side's soldiers (what they are good against, and where they
fight well), the ground, the defenders' hills and walls, morale, the general, and fortune.
An army alone in an enemy province besieges it; when the walls fall, the province changes
hands. Armies far from home waste away, faster in deserts and mountains and when the land
cannot feed them.

Every rival court commands its armies with simple, readable rules; the player gives orders.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from typing import Any, Literal

from anachronism.content.schema import Formation, General, RelationStatus, Tactic, Unit
from anachronism.content.schema.rules import ArmyRules
from anachronism.engine.actions import (
    ArmyAssault,
    ArmyDeploy,
    ArmyEngage,
    ArmyFormation,
    ArmyPlan,
    ArmyStance,
    BuildFleet,
    DisbandArmy,
    Fortify,
    Orders,
    RaiseArmy,
    SailFleet,
    ScuttleFleet,
)
from anachronism.engine.aid import aiding, on_battle
from anachronism.engine.buildings import bonus as building_bonus
from anachronism.engine.buildings import ruin_newest
from anachronism.engine.deployment import CHOICES as DEPLOY_CHOICES
from anachronism.engine.deployment import (
    LINE,
    PLACE_NAMES,
    SIEGE,
    place_side,
)
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.formations import AUTO as FORMATION_AUTO
from anachronism.engine.formations import edge as formation_edge
from anachronism.engine.formations import formations as pick_formations
from anachronism.engine.formations import power as formation_power
from anachronism.engine.ground import Ground, ground_of, river_held
from anachronism.engine.ground import text as ground_text
from anachronism.engine.navies import SIZES, build_fleet, can_cross, sea_route
from anachronism.engine.power import Parts, kinds_in, men_in, wing_powers
from anachronism.engine.power import side_power as side_power
from anachronism.engine.power import trait_bp as trait_bp
from anachronism.engine.power import unit_power as unit_power
from anachronism.engine.rivals import alive, at_war, frontier, province_links, relation, status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import Army, GameState
from anachronism.engine.tactics import AUTO, bonus, commander, edge, plans
from anachronism.engine.tales import tell
from anachronism.engine.tech import is_adopted, usable_resources
from anachronism.engine.war import defence_bp
from anachronism.engine.wings import Clash, Line, WingResult, contest

STYLES = ("balanced", "infantry", "missile", "mounted", "siege")
"""How a levy is made up: an even mix, or weighted toward one kind of soldier."""

_STYLE_WEIGHTS: dict[str, dict[str, int]] = {
    "balanced": {"infantry": 3, "spear": 3, "missile": 2, "mounted": 2, "elephant": 1, "siege": 1},
    "infantry": {"infantry": 6, "spear": 4, "missile": 1, "mounted": 1, "elephant": 1},
    "missile": {"missile": 6, "spear": 2, "infantry": 2, "mounted": 1},
    "mounted": {"mounted": 6, "elephant": 2, "missile": 1, "spear": 1},
    "siege": {"siege": 4, "infantry": 3, "spear": 2, "missile": 1},
}


# --- what a state can raise ----------------------------------------------------------------


def available_units(state: GameState, civ_id: str) -> list[Unit]:
    """The kinds of soldier ``civ_id`` can raise now, in id order."""
    civ = state.civs[civ_id]
    have = usable_resources(state, civ_id)
    return [
        unit
        for unit_id, unit in sorted(state.world.units.items())
        if all(is_adopted(civ, t) for t in unit.needs_techs)
        and all(r in have for r in unit.needs_resources)
    ]


def _best_of_kind(units: list[Unit]) -> dict[str, Unit]:
    best: dict[str, Unit] = {}
    for unit in units:
        held = best.get(unit.kind)
        if held is None or (unit.attack + unit.defence, unit.id) > (
            held.attack + held.defence,
            held.id,
        ):
            best[unit.kind] = unit
    return best


def composition(state: GameState, civ_id: str, men: int, style: str = "balanced") -> dict[str, int]:
    """How ``men`` would be divided among the best soldiers of each kind the state has."""
    best = _best_of_kind(available_units(state, civ_id))
    weights = _STYLE_WEIGHTS.get(style, _STYLE_WEIGHTS["balanced"])
    picks = [(best[kind], w) for kind, w in sorted(weights.items()) if kind in best]
    if not picks:
        levy = state.world.units.get("levy")
        return {levy.id: men} if levy else {}
    total = sum(w for _, w in picks)
    troops: dict[str, int] = {}
    for unit, w in picks:
        troops[unit.id] = troops.get(unit.id, 0) + men * w // total
    leftover = men - sum(troops.values())
    first = picks[0][0].id
    troops[first] += leftover
    return {u: n for u, n in sorted(troops.items()) if n > 0}


def raise_cost(state: GameState, troops: dict[str, int]) -> tuple[int, int, int]:
    """Food, materials and wealth to raise these troops."""
    food = materials = wealth = 0
    for unit_id, men in troops.items():
        unit = state.world.units[unit_id]
        food += unit.food * men // 1000
        materials += unit.materials * men // 1000
        wealth += unit.wealth * men // 1000
    return food, materials, wealth


def under_arms(state: GameState, civ_id: str) -> int:
    """Men in all of a state's armies."""
    return sum(a.men for a in state.armies.values() if a.owner == civ_id)


def mobilisation_cap(state: GameState, civ_id: str) -> int:
    """The most men the state can keep under arms."""
    rules = state.world.rules.armies
    people = state.population(civ_id) + under_arms(state, civ_id)  # soldiers are people too
    return apply_bp(apply_bp(people, rules.max_under_arms_bp), state.civs[civ_id].martial_bp)


def levy_size(state: GameState, civ_id: str, province_id: str, size: str) -> int:
    """Men a small, medium or large levy calls up from a province."""
    rules = state.world.rules.armies
    share = {
        "small": rules.raise_small_bp,
        "medium": rules.raise_medium_bp,
        "large": rules.raise_large_bp,
    }.get(size, rules.raise_medium_bp)
    people = state.provinces[province_id].population
    return apply_bp(apply_bp(people, share), state.civs[civ_id].martial_bp)


def raise_army(
    state: GameState,
    civ_id: str,
    province_id: str,
    men: int,
    style: str = "balanced",
    *,
    free: bool = False,
    general: str = "",
    skill: int = 1,
) -> tuple[Army | None, str]:
    """Call up ``men`` from a province into a new army (or reinforce one standing there)."""
    province = state.provinces.get(province_id)
    civ = state.civs[civ_id]
    if province is None or province.owner != civ_id:
        return None, "armies are raised in your own provinces"
    room = mobilisation_cap(state, civ_id) - under_arms(state, civ_id)
    men = min(men, room, province.population // 2)
    if men < state.world.rules.armies.min_army:
        return None, "the realm cannot spare more men under arms"
    troops = composition(state, civ_id, men, style)
    food, materials, wealth = raise_cost(state, troops)
    stores = civ.stockpiles
    if not free:
        if stores.food < food or stores.materials < materials or stores.wealth < wealth:
            return (
                None,
                f"raising them needs {food} food, {materials} materials and {wealth} wealth",
            )
        stores.food -= food
        stores.materials -= materials
        stores.wealth -= wealth
        # every family that loses a son to the levy grumbles (warlike peoples less)
        rules = state.world.rules.armies
        share = men * 100 * BP // max(1, state.population(civ_id))  # bp of a 1% unit
        unrest = rules.levy_unrest_bp * share // BP * BP // max(BP, civ.martial_bp)
        civ.stats.unrest_bp = clamp(civ.stats.unrest_bp + unrest, 0, BP)
    province.population -= men
    here = [
        a
        for a in sorted(state.armies.values(), key=lambda a: a.id)
        if a.owner == civ_id and a.province == province_id
    ]
    if here:
        army = here[0]
        old = army.men
        for unit_id, n in troops.items():
            army.troops[unit_id] = army.troops.get(unit_id, 0) + n
        trained = building_bonus(state, province_id).veterans_bp  # raw recruits, or drilled
        army.veterancy_bp = (army.veterancy_bp * old + trained * men) // max(1, army.men)
        return army, f"{men:,} men join the {army.name}."
    civ.armies_raised += 1
    place = state.world.geography[province_id].name.split(" (")[0]
    name = "Royal Army" if civ.armies_raised == 1 else f"Army of {place}"
    trait = ""
    if not general and civ.generals:  # the next free commander takes it
        chosen = civ.generals.pop(0)
        general, skill, trait = chosen.name, chosen.skill, chosen.trait or ""
    army = Army(
        id=f"{civ_id}-{civ.armies_raised}",
        owner=civ_id,
        name=name,
        province=province_id,
        troops=troops,
        general=general,
        skill=skill,
        trait=trait,
        raised_turn=state.turn,
        veterancy_bp=building_bonus(state, province_id).veterans_bp,  # trained in barracks
    )
    state.armies[army.id] = army
    return army, f"The {name} musters {men:,} men in {place}."


def disband(state: GameState, army_id: str) -> str:
    """Send an army home: the men return to the province (if it is their own)."""
    army = state.armies.pop(army_id)
    release(state, army)
    if army.contract:
        return "The mercenaries are paid off and leave."
    province = state.provinces.get(army.province)
    if province is not None and province.owner == army.owner:
        province.population += army.men
        return f"The {army.name} goes home to its fields."
    return f"The {army.name} disbands far from home; few find their way back."


def hire_company(state: GameState, civ_id: str, turns: int) -> Army | None:
    """Hired swords muster at the capital: professionals, keen, and not your people."""
    civ = state.civs[civ_id]
    if civ.capital not in state.provinces:
        return None
    men = apply_bp(state.population(civ_id), state.world.rules.armies.mercenary_men_bp)
    if men < state.world.rules.armies.min_army:
        return None
    civ.armies_raised += 1
    army = Army(
        id=f"{civ_id}-{civ.armies_raised}",
        owner=civ_id,
        name="Mercenary Company",
        province=civ.capital,
        troops=composition(state, civ_id, men, "balanced"),
        morale_bp=BP,
        skill=2,
        raised_turn=state.turn,
        contract=turns,
        veterancy_bp=state.world.rules.armies.mercenary_veterancy_bp,
    )
    state.armies[army.id] = army
    return army


def release(state: GameState, army: Army) -> None:
    """A general whose army is gone returns to the court, free for another command."""
    civ = state.civs[army.owner]
    if army.general and army.general != civ.ruler:
        trait = army.trait if army.trait in TRAITS else None
        civ.generals.insert(0, General(name=army.general, skill=army.skill, trait=trait))
    army.general, army.skill, army.trait = "", 1, ""


TRAITS = ("horse", "siege", "shield", "bold", "quartermaster", "beloved")


def standing_armies(state: GameState) -> None:
    """Give every state the army it kept at the start of the scenario."""
    rules = state.world.rules.armies
    for civ_id in sorted(state.civs):
        civ = state.civs[civ_id]
        if not state.owned_provinces(civ_id) or civ.capital not in state.provinces:
            continue
        people = state.population(civ_id)
        men = apply_bp(apply_bp(people, rules.standing_army_bp), civ.martial_bp)
        if men >= rules.min_army:
            general = civ.ruler if civ.disposition.value == "aggressive" else ""
            army, _ = raise_army(
                state,
                civ_id,
                civ.capital,
                men,
                free=True,
                general=general,
                skill=2 if general else 1,
            )
            if army is not None:
                army.veterancy_bp = rules.standing_veterancy_bp


# --- movement ------------------------------------------------------------------------------


def can_enter(state: GameState, civ_id: str, province_id: str) -> bool:
    """Armies march through their own land, allies' land, unclaimed land and enemies' land."""
    owner = state.provinces[province_id].owner
    if owner is None or owner == civ_id:
        return True
    found = status(state, civ_id, owner)
    return found in (RelationStatus.WAR, RelationStatus.ALLIED) or aiding(state, civ_id, owner)


def route(state: GameState, civ_id: str, start: str, goal: str) -> list[str]:
    """The shortest way from ``start`` to ``goal`` (not including ``start``); [] if none.

    Sea crossings need sailing (and end the turn's march).
    """
    if start == goal:
        return []
    sailing = is_adopted(state.civs[civ_id], "sailing")
    links = province_links(state.world) if sailing else None
    came: dict[str, str] = {start: start}
    queue = deque([start])
    while queue:
        here = queue.popleft()
        land = state.world.geography[here].neighbours
        nexts = sorted(set(land) | (links.get(here, set()) if links else set()))
        for nxt in nexts:
            if nxt in came or nxt not in state.provinces:
                continue
            if not can_enter(state, civ_id, nxt):
                continue
            came[nxt] = here
            if nxt == goal:
                path = [goal]
                while came[path[-1]] != start:
                    path.append(came[path[-1]])
                return path[::-1]
            queue.append(nxt)
    return []


def mobility(state: GameState, army: Army) -> int:
    """Provinces the army can march this turn: as fast as its slowest soldiers (roads help)."""
    slowest = min((state.world.units[u].mobility for u in army.troops), default=2)
    if is_adopted(state.civs[army.owner], "roads"):
        slowest += 1
    if army.forced and army.target is not None:  # a forced march: one more province (D-267)
        slowest += 1
    return max(1, slowest)


def _by_sea(state: GameState, a: str, b: str) -> bool:
    return b not in state.world.geography[a].neighbours


def at_war_with(state: GameState, a: str, b: str) -> bool:
    """True when two states are at war."""
    return a != b and status(state, a, b) is RelationStatus.WAR


def _enemies_here(state: GameState, army: Army) -> list[Army]:
    return [
        other
        for other in state.armies.values()
        if other.province == army.province and at_war_with(state, army.owner, other.owner)
    ]


def march(state: GameState, rng: GameRng, events: EventLog) -> None:
    """Move every army along its route, a step at a time; armies that meet fight."""
    rules = state.world.rules.armies
    for army_id in sorted(state.armies):  # the toll of a forced march, once a turn
        tired = state.armies[army_id]
        if tired.forced and tired.target is not None:
            tired.morale_bp = clamp(tired.morale_bp - rules.forced_march_morale_bp, 1000, BP)
            _casualties(tired, rules.forced_march_attrition_bp)
    start = {a.id: a.province for a in state.armies.values()}
    steps = {a.id: mobility(state, a) for a in state.armies.values()}
    for _ in range(max(steps.values(), default=0)):
        for army_id in sorted(state.armies):
            army = state.armies.get(army_id)
            if army is None or steps.get(army_id, 0) <= 0 or army.target is None:
                continue
            if _enemies_here(state, army):
                continue  # engaged: it must fight before it can move on
            path = route(state, army.owner, army.province, army.target)
            if not path:
                army.target = None
                continue
            nxt = path[0]
            by_sea = _by_sea(state, army.province, nxt)
            if by_sea and not can_cross(state, army.owner, army.province, nxt):
                army.target = None  # the enemy commands the sea
                place = state.world.geography[nxt].name
                events.add(
                    army.owner,
                    "crossing_barred",
                    f"Enemy warships bar the crossing to {place}.",
                    place,
                )
                continue
            steps[army_id] = 0 if by_sea else steps[army_id] - 1
            army.came_from = army.province
            army.arrived_turn = state.turn
            army.province = nxt
            army.siege_bp = 0
            army.dug_in = False
            if nxt == army.target:
                army.target = None
        fight_battles(state, rng, events)
    for camp in state.armies.values():
        if camp.target is None:
            camp.forced = False
        # an army that stood a whole turn without marching has dug a fortified camp
        stood = start.get(camp.id) == camp.province and camp.target is None
        camp.dug_in = stood and camp.raised_turn < state.turn


# --- battles -------------------------------------------------------------------------------


def _sides(state: GameState, province_id: str) -> tuple[list[Army], list[Army]] | None:
    """The two sides of a battle in a province: (attackers, defenders), or None."""
    here = sorted(
        (a for a in state.armies.values() if a.province == province_id), key=lambda a: a.id
    )
    owner = state.provinces[province_id].owner
    for a in here:
        for b in here:
            if a.id < b.id and at_war_with(state, a.owner, b.owner):
                first, second = a.owner, b.owner
                # the province's owner (or its ally) defends; otherwise whoever came first
                if owner == first or (
                    owner
                    and (
                        status(state, owner, first) is RelationStatus.ALLIED
                        or aiding(state, first, owner)
                    )
                ):
                    first, second = second, first
                attackers = [
                    x
                    for x in here
                    if x.owner == first or _allied_against(state, x.owner, first, second)
                ]
                defenders = [
                    x
                    for x in here
                    if x.owner == second or _allied_against(state, x.owner, second, first)
                ]
                return attackers, defenders
    return None


def _allied_against(state: GameState, civ: str, friend: str, foe: str) -> bool:
    return (
        civ not in (friend, foe)
        and (status(state, civ, friend) is RelationStatus.ALLIED or aiding(state, civ, friend))
        and at_war_with(state, civ, foe)
    )


def fight_battles(state: GameState, rng: GameRng, events: EventLog) -> None:
    """Every province where enemies stand together sees a battle (in id order)."""
    for province_id in sorted({a.province for a in state.armies.values()}):
        for _ in range(4):  # a few rounds if several armies are involved
            sides = _sides(state, province_id)
            if sides is None:
                break
            battle(state, province_id, sides[0], sides[1], rng, events)


@dataclass
class _Lines:
    """Two sides drawn up for battle: their power (before luck), plans, formations and wings."""

    pa: int
    pd: int
    units_a: dict[str, int]
    units_d: dict[str, int]
    plan_a: Tactic | None
    plan_d: Tactic | None
    form_a: Formation | None
    form_d: Formation | None
    line_a: Line
    line_d: Line
    ground: Ground
    held: bool
    """Defenders dug in on the ground (the river line, if there is a river)."""
    rules: ArmyRules

    def clash(
        self,
        scale: tuple[int, int] = (BP, BP),
        luck: tuple[dict[str, int], dict[str, int]] | None = None,
    ) -> Clash:
        """The wing contests, with what the skirmish left each side and fortune's turn."""
        return contest(self.rules, self.line_a, self.line_d, scale, luck)

    def expected(self) -> tuple[int, int]:
        """Each side's power in the clash without luck (for odds and for cautious generals)."""
        out = self.clash()
        return out.power_a, out.power_d


def _split(state: GameState, side: list[Army]) -> tuple[list[Army], list[Army]]:
    """A side's line, and any army that came to the field from another direction this turn."""

    def way(army: Army) -> str:
        return army.came_from if army.arrived_turn == state.turn else ""

    held = way(commander(side))
    return [a for a in side if way(a) == held], [a for a in side if way(a) != held]


def _line(
    state: GameState,
    province_id: str,
    ground: Ground,
    side: list[Army],
    other: list[Army],
    attacking: bool,
    parts: Parts,
    enemy: Parts,
    fleet: tuple[int, int],
    dug_in: bool,
    flank: list[Army],
    reserve_bp: int,
) -> Line:
    """One side's powers wing by wing, scaled so that together they match its whole power."""
    rules = state.world.rules.armies
    final, raw = fleet
    river = river_held(rules, dug_in) if ground.river and attacking else 0
    first = wing_powers(state, side, parts, enemy, attacking, province_id, ground, river)
    later = first
    if river:
        later = wing_powers(
            state,
            side,
            parts,
            enemy,
            attacking,
            province_id,
            ground,
            river * rules.river_later_bp // BP,
        )
    scale = max(1, raw)
    out = Line(
        first={p: v * final // scale for p, v in first.items()},
        later={p: v * final // scale for p, v in later.items()},
        men={p: men_in(parts, p) for p in parts},
        horse={p: kinds_in(state, parts, (p,)).get("mounted", 0) for p in parts},
        reserve_bp=reserve_bp,
        great=commander(side).skill >= rules.reads_enemy_skill,
    )
    if flank:
        power = side_power(state, flank, other, attacking, province_id)[0]
        out.flank = power * final // scale
        out.flank_men = sum(a.men for a in flank)
    return out


def _lines(
    state: GameState, province_id: str, attackers: list[Army], defenders: list[Army]
) -> _Lines:
    """Weigh both sides: their soldiers, plans (D-108), formations and rules of engagement."""
    rules = state.world.rules.armies
    ground = ground_of(state, province_id)
    terrain = ground.terrain
    pa, units_a = side_power(state, attackers, defenders, True, province_id)
    pd, units_d = side_power(state, defenders, attackers, False, province_id)
    raw_a, raw_d = pa, pd
    # the plans (D-108): each side's own worth on this ground, and the edge of the better one
    plan_a, plan_d = plans(state, attackers, defenders, terrain)
    edge_a = edge_d = 0
    if plan_a is not None and plan_d is not None:
        edge_a = edge(state, plan_a, plan_d, commander(attackers))
        edge_d = edge(state, plan_d, plan_a, commander(defenders))
    if plan_a is not None:
        pa = pa * max(2000, BP + bonus(plan_a, terrain) + edge_a) // BP
    if plan_d is not None:
        pd = pd * max(2000, BP + bonus(plan_d, terrain) + edge_d) // BP
    # the formations (D-267): the first clash's worth, and the edge of the better line
    form_a, form_d = pick_formations(state, attackers, defenders, terrain)
    fedge_a = fedge_d = 0
    if form_a is not None and form_d is not None:
        fedge_a = formation_edge(form_a, form_d, attackers, defenders, terrain)
        fedge_d = formation_edge(form_d, form_a, defenders, attackers, terrain)
    if form_a is not None:
        worth = formation_power(form_a, attackers, defenders, terrain) + fedge_a
        pa = pa * max(2000, BP + worth) // BP
    if form_d is not None:
        worth = formation_power(form_d, defenders, attackers, terrain) + fedge_d
        pd = pd * max(2000, BP + worth) // BP
    if commander(attackers).engage == "last_man":
        pa = pa * (BP + rules.last_man_power_bp) // BP
    if commander(defenders).engage == "last_man":
        pd = pd * (BP + rules.last_man_power_bp) // BP
    # the deployment (D-270): who stands where, and a second army on the flank
    main_a, flank_a = _split(state, attackers)
    main_d, flank_d = _split(state, defenders)
    dug_in = any(a.dug_in for a in defenders)

    def draw(mirror_a: bool, mirror_d: bool) -> tuple[Line, Line]:
        parts_a = place_side(state, main_a, form_a, mirror_a)
        parts_d = place_side(state, main_d, form_d, mirror_d)
        line_a = _line(
            state,
            province_id,
            ground,
            main_a,
            defenders,
            True,
            parts_a,
            parts_d,
            (pa, raw_a),
            dug_in,
            flank_a,
            form_a.reserve_bp if form_a else 0,
        )
        line_d = _line(
            state,
            province_id,
            ground,
            main_d,
            attackers,
            False,
            parts_d,
            parts_a,
            (pd, raw_d),
            dug_in,
            flank_d,
            form_d.reserve_bp if form_d else 0,
        )
        return line_a, line_d

    def share(mirror_a: bool, mirror_d: bool) -> int:
        line_a, line_d = draw(mirror_a, mirror_d)
        won = contest(rules, line_a, line_d)
        return won.power_a * BP // max(1, won.power_a + won.power_d)

    mirror_a = mirror_d = False
    great_a = commander(attackers).skill >= rules.reads_enemy_skill
    great_d = commander(defenders).skill >= rules.reads_enemy_skill
    if great_a or great_d:  # a great general sets his strong wing against the enemy's weak one
        base = share(False, False)
        mirror_a = great_a and share(True, False) > base
        mirror_d = great_d and share(mirror_a, True) < share(mirror_a, False)
    line_a, line_d = draw(mirror_a, mirror_d)
    return _Lines(
        pa,
        pd,
        units_a,
        units_d,
        plan_a,
        plan_d,
        form_a,
        form_d,
        line_a,
        line_d,
        ground,
        dug_in,
        rules,
    )


def win_share(
    state: GameState, side: list[Army], other: list[Army], province_id: str, attacking: bool
) -> int:
    """A side's expected share (bp, 5_000 = even) of the two sides' strength in a battle."""
    return int(preview(state, side, other, province_id, attacking)["win_bp"])


def preview(
    state: GameState, side: list[Army], other: list[Army], province_id: str, attacking: bool
) -> dict[str, Any]:
    """How a battle would go for ``side`` (D-270): its share, each wing's outlook, the ground.

    ``wings`` lists the side's own left, centre and right: the wing it faces, and whether
    it looks ``strong``, ``even`` or ``weak`` against it (``ratio_bp`` 10_000 = even).
    """
    rules = state.world.rules.armies
    lines = (
        _lines(state, province_id, side, other)
        if attacking
        else _lines(state, province_id, other, side)
    )
    clash = lines.clash()
    mine, theirs = (clash.power_a, clash.power_d) if attacking else (clash.power_d, clash.power_a)
    wings = []
    for w in clash.wings:
        own, facing = (w.wing, w.d_wing) if attacking else (w.d_wing, w.wing)
        pm, pt = (w.a_power, w.d_power) if attacking else (w.d_power, w.a_power)
        ratio = pm * BP // max(1, pt) if pt or pm else BP
        outcome = (
            "strong"
            if ratio >= rules.wing_strong_bp
            else "weak"
            if ratio * rules.wing_strong_bp <= BP * BP
            else "even"
        )
        wings.append({"wing": own, "vs": facing, "outcome": outcome, "ratio_bp": ratio})
    wings.sort(key=lambda x: LINE.index(x["wing"]))
    return {
        "win_bp": mine * BP // max(1, mine + theirs),
        "wings": wings,
        "ground": ground_text(state, lines.ground, lines.held),
    }


def _morale(side: list[Army]) -> int:
    """A side's battle morale: its armies' morale, weighted by men."""
    return sum(a.morale_bp * a.men for a in side) // max(1, sum(a.men for a in side))


def _adjective(state: GameState, side: list[Army]) -> str:
    return state.civs[side[0].owner].adjective


def _missile_power(state: GameState, units: dict[str, int], total: int) -> int:
    """The part of a side's power (after plan and formation) that is missile troops."""
    mass = sum(units.values())
    shot = sum(p for u, p in units.items() if state.world.units[u].kind == "missile")
    return total * shot // max(1, mass)


def _skirmish(
    state: GameState,
    lines: _Lines,
) -> tuple[list[int], list[int]]:
    """Phase 1: missile troops trade shots; few die, but morale is shaken.

    Returns each side's losses (bp of its men) and morale drop.
    """
    rules = state.world.rules.armies
    power = (lines.pa, lines.pd)
    units = (lines.units_a, lines.units_d)
    plans_ = (lines.plan_a, lines.plan_d)
    shots = []
    for i in (0, 1):
        shot = _missile_power(state, units[i], power[i])
        plan = plans_[i]
        shot = shot * max(0, BP + (plan.skirmish_bp if plan else 0)) // BP
        if i == 1 and lines.ground.high:  # the defenders' archers on the high ground
            shot = shot * (BP + rules.hill_missile_bp) // BP
        shots.append(shot)
    losses, drops = [0, 0], [0, 0]
    for i in (0, 1):  # side i shoots at side 1 - i
        hit = min(2 * BP, shots[i] * BP // max(1, power[1 - i]))
        losses[1 - i] = rules.skirmish_losses_bp * hit // BP
        drops[1 - i] = rules.skirmish_morale_bp * hit // BP
    return losses, drops


def _broke(state: GameState, side: list[Army], morale: int) -> bool:
    """A side breaks when its morale is gone - unless it fights to the last man."""
    if commander(side).engage == "last_man":
        return False
    return morale < state.world.rules.armies.break_morale_bp


def battle(
    state: GameState,
    province_id: str,
    attackers: list[Army],
    defenders: list[Army],
    rng: GameRng,
    events: EventLog,
    storm: str = "",
) -> str:
    """Fight it out in three phases (skirmish, clash, pursuit). Returns the winning state's id.

    ``storm`` (D-273): the defenders are a city's garrison being stormed, and this sentence
    says how they stand (it replaces the ground's in the report).
    """
    rules = state.world.rules.armies
    terrain = state.world.geography[province_id].terrain
    lines = _lines(state, province_id, attackers, defenders)
    withdrew = _withdrawal(state, province_id, attackers, defenders, lines, events)
    if withdrew is not None:
        return withdrew
    plan_a, plan_d = lines.plan_a, lines.plan_d
    sides = (attackers, defenders)
    adj = (_adjective(state, attackers), _adjective(state, defenders))
    morale = [_morale(attackers), _morale(defenders)]
    phases: list[dict[str, Any]] = []
    totals = [0, 0]  # men each side has lost so far

    def record(name: str, text: str, lost: list[int], **more: Any) -> None:
        phases.append(
            {
                "name": name,
                "text": text,
                "losses": {"a": lost[0], "d": lost[1]},
                "morale": {"a": morale[0], "d": morale[1]},
                **more,
            }
        )

    # --- phase 1: the skirmish
    loss1, drop1 = _skirmish(state, lines)
    dead1 = [sum(_casualties(a, loss1[i]) for a in sides[i]) for i in (0, 1)]
    for i in (0, 1):
        morale[i] = max(0, morale[i] - drop1[i])
        totals[i] += dead1[i]
    shooters = any(state.world.units[u].kind == "missile" for u in (*lines.units_a, *lines.units_d))
    record(
        "Skirmish",
        (
            f"Archers and skirmishers trade fire: {adj[0]} lose {dead1[0]:,}, "
            f"{adj[1]} {dead1[1]:,}; the lines are shaken."
            if shooters
            else "Neither army has many shooters; the lines close at once."
        ),
        dead1,
    )
    broke = [_broke(state, sides[i], morale[i]) for i in (0, 1)]
    early = broke[0] or broke[1]
    margin = 5000
    if early:
        won_a = broke[1] if broke[0] != broke[1] else morale[0] >= morale[1]
        lose_c = [0, 0]
    else:
        # --- phase 2: the clash, wing by wing (the reserve commits after the first exchange)
        luck = rules.battle_luck_bp
        left_after = (
            (BP - loss1[0]) * (BP - drop1[0] // 4) // BP,
            (BP - loss1[1]) * (BP - drop1[1] // 4) // BP,
        )
        fortune = _fortune(rng, luck, rules.wing_luck_bp)
        clash = lines.clash(left_after, fortune)
        won_a = clash.winner == "a"
        pw, pl = (clash.power_a, clash.power_d) if won_a else (clash.power_d, clash.power_a)
        margin = max(0, pw - pl) * BP // max(1, pw + pl)  # 0 (even) .. 10_000 (rout)
        blood = BP + sum(p.losses_bp for p in (plan_a, plan_d) if p is not None)
        blood = clamp(blood, 2000, 20_000)  # a charge is bloody, skirmishing is not
        lose = rules.clash_losses_bp + apply_bp(rules.clash_losses_bp, margin)
        lose = clamp(lose * blood // BP, 0, 9000)
        win = rules.clash_win_losses_bp - apply_bp(rules.clash_win_losses_bp, margin)
        win = clamp(win * blood // BP, 300, 9000)
        lose_c = [win, lose] if won_a else [lose, win]
        beaten = 1 if won_a else 0
        if commander(sides[beaten]).engage == "last_man":  # they fight on to the end
            lose_c[beaten] = lose_c[beaten] * (BP + rules.last_man_losses_bp) // BP
        dead2 = [sum(_casualties(a, lose_c[i]) for a in sides[i]) for i in (0, 1)]
        ref = rules.clash_losses_bp + rules.clash_win_losses_bp
        share = max(1, lose_c[0] + lose_c[1])
        scale = clamp(share * BP // max(1, ref), 5000, 20_000)
        for i in (0, 1):
            relative = 2 * lose_c[i] * BP // share  # 10_000 = an equal share of the dead
            drop = rules.clash_morale_bp * relative // BP * scale // BP
            morale[i] = max(0, morale[i] - drop)
            totals[i] += dead2[i]
        for i, broken in ((0, clash.broken_a), (1, clash.broken_d)):  # a wing that broke
            morale[i] = max(0, morale[i] - rules.wing_morale_bp * broken)
        forms = _forms_told(adj, lines.form_a, lines.form_d)
        record(
            "Clash",
            f"{forms}{_clash_told(adj, clash)}{adj[0]} lose {dead2[0]:,}, "
            f"{adj[1]} {dead2[1]:,}.".lstrip(),
            dead2,
            wings=_wings_record(adj, clash),
            reserve=dict(clash.reserve),
            flank=dict(clash.flank),
        )
        broke = [_broke(state, sides[i], morale[i]) for i in (0, 1)]
        if broke[0] != broke[1]:  # a side whose line gives way loses, whatever the odds
            won_a = broke[1]
    winners, losers = (attackers, defenders) if won_a else (defenders, attackers)
    w, l_ = (0, 1) if won_a else (1, 0)
    plan_w, plan_l = (plan_a, plan_d) if won_a else (plan_d, plan_a)
    # --- phase 3: the pursuit - the winner's horse run down the beaten
    horse = (
        sum(
            n
            for a in winners
            for u, n in a.troops.items()
            if state.world.units[u].kind == "mounted"
        )
        * BP
        // max(1, sum(a.men for a in winners))
    )
    chase = rules.pursuit_base_bp + apply_bp(rules.pursuit_horse_bp, horse)
    chase = chase * (BP + margin) // BP
    if not broke[l_] and commander(losers).engage != "last_man":
        chase = chase * rules.orderly_retreat_bp // BP  # they got away in good order
    if commander(losers).engage == "last_man":
        chase = chase * (BP + rules.last_man_losses_bp) // BP
    rout_bp = plan_w.rout_bp if plan_w else 0
    chase += apply_bp(rules.clash_losses_bp, 2 * rout_bp)  # an envelopment destroys the beaten
    chase = clamp(chase, 0, 9000)
    dead3 = [0, 0]
    dead3[l_] = sum(_casualties(a, chase) for a in losers)
    totals[l_] += dead3[l_]
    crush = margin + rout_bp
    rout = crush >= 4000 or early
    if broke[l_]:
        text3 = (
            f"The {adj[l_]} line breaks and the {adj[w]} "
            f"{'horse ride them down' if horse >= 2500 else 'pursue them'}: "
            f"{dead3[l_]:,} {adj[l_]} fall."
        )
    else:
        text3 = (
            f"The {adj[l_]} withdraw in good order; {dead3[l_]:,} are cut off."
            if dead3[l_]
            else f"The {adj[l_]} withdraw in good order."
        )
    record("Pursuit", text3, dead3)
    dead_w, dead_l = totals[w], totals[l_]
    for army in winners:
        army.morale_bp = clamp(army.morale_bp - rules.morale_loss_bp // 6, 1000, BP)
        army.veterancy_bp = min(rules.max_veterancy_bp, army.veterancy_bp + rules.veterancy_win_bp)
    for army in losers:
        loss = rules.morale_loss_bp * BP // (BP + trait_bp(state, army, "beloved"))
        army.morale_bp = clamp(army.morale_bp - loss, 1000, BP)
        army.veterancy_bp = min(rules.max_veterancy_bp, army.veterancy_bp + rules.veterancy_loss_bp)
        army.dug_in = False
    winner, loser = winners[0].owner, losers[0].owner
    w_civ, l_civ = state.civs[winner], state.civs[loser]
    place = state.world.geography[province_id].name.split(" (")[0]
    units_w = lines.units_a if won_a else lines.units_d
    hero = max(units_w, key=lambda u: units_w[u])
    hero_name = state.world.units[hero].name.lower()
    fallen = ""
    general = next((a.general for a in losers if a.general), "")
    if general and rng.chance(rules.general_death_bp):
        fallen = f" {general} fell on the field."
        for army in losers:
            if army.general == general:
                army.general = ""
                army.skill = 1
    named = "the " + place[4:] if place.startswith("The ") else place  # "of the Punjab"
    kind = state.world.units[hero].kind
    told = tell(state, kind, terrain, rout, rng, winner=winner, plan=plan_w.id if plan_w else "")
    story = told.format(place=named, winner=w_civ.adjective, loser=l_civ.adjective, unit=hero_name)
    story = story[:1].upper() + story[1:]
    schemes = _plans_told(w_civ.adjective, plan_w, l_civ.adjective, plan_l)
    title = "The storming of" if storm else "Battle of"
    text = (
        f"{title} {named}. {story}{fallen}{schemes}"
        f" {w_civ.adjective} losses {dead_w:,}, {l_civ.adjective} {dead_l:,}."
    )
    sides_told = {"a": adj[0], "d": adj[1], "winner": "a" if won_a else "d"}
    where = storm or ground_text(state, lines.ground, lines.held)
    events.add(winner, "battle_won", text, place, phases=phases, sides=sides_told, ground=where)
    events.add(loser, "battle_lost", text, place, phases=phases, sides=sides_told, ground=where)
    on_battle(state, province_id, winner, loser, events)  # a friend's gratitude (D-277)
    glory = rules.victory_legitimacy_bp  # a victory is the talk of the court; a defeat, too
    w_civ.stats.legitimacy_bp = clamp(w_civ.stats.legitimacy_bp + glory, 0, BP)
    l_civ.stats.legitimacy_bp = clamp(l_civ.stats.legitimacy_bp - glory, 0, BP)
    rel = relation(state, winner, loser)
    if rel is not None:
        rel.weariness[loser] = rel.weariness.get(loser, 0) + rules.weariness_per_battle_bp
        rel.losses[loser] = rel.losses.get(loser, 0) + 1
    for army in losers:
        _retreat(state, army, events)
    _prune(state)
    return winner


def _fortune(rng: GameRng, luck: int, wing: int) -> tuple[dict[str, int], dict[str, int]]:
    """Each side's fortune (bp) in each place: one roll for the day, and one for each wing."""
    out: tuple[dict[str, int], dict[str, int]] = ({}, {})
    for side in out:
        day = BP - luck + rng.below(2 * luck + 1)
        for place in LINE:
            side[place] = day * (BP - wing + rng.below(2 * wing + 1)) // BP
    return out


def _forms_told(adj: tuple[str, str], form_a: Formation | None, form_d: Formation | None) -> str:
    """The two formations in a sentence, for the clash (empty if there are none)."""
    if form_a is None or form_d is None:
        return ""
    if form_d.id in form_a.beats or (form_d.id in form_a.duel and form_a.edge_bp):
        verdict = f"The {adj[0]} {form_a.name.lower()} turns the {adj[1]} {form_d.name.lower()}."
    elif form_a.id in form_d.beats:
        verdict = f"The {adj[1]} {form_d.name.lower()} turns the {adj[0]} {form_a.name.lower()}."
    else:
        verdict = f"{adj[0]} {form_a.name.lower()} meets {adj[1]} {form_d.name.lower()}."
    return f"{verdict} "


def _wing_told(adj: tuple[str, str], w: WingResult) -> str:
    """One contest in a sentence: the attackers' wing against the defenders' facing wing."""
    left = f"The {adj[0]} {w.wing} ({w.a_men:,}) meets the {adj[1]} {w.d_wing} ({w.d_men:,})"
    if w.broke == "d":
        return f"{left} and breaks it, then wheels on the centre."
    if w.broke == "a":
        return f"{left} but is broken, and the {adj[1]} wheel on the centre."
    if w.winner == "a":
        return f"{left} and gets the better of it."
    if w.winner == "d":
        return f"{left} and gives ground."
    return f"{left} and neither gives way."


def _wings_record(adj: tuple[str, str], clash: Clash) -> list[dict[str, Any]]:
    """The three contests for the battle report (``wing`` is the attackers' own name)."""
    return [
        {
            "wing": w.wing,
            "d_wing": w.d_wing,
            "a_men": w.a_men,
            "d_men": w.d_men,
            "winner": w.winner,
            "text": _wing_told(adj, w),
        }
        for w in clash.wings
    ]


def _clash_told(adj: tuple[str, str], clash: Clash) -> str:
    """What decided the clash, in a few sentences (flank, broken wings, horse, reserves)."""
    parts: list[str] = []
    if clash.flank:
        i = 0 if clash.flank["side"] == "a" else 1
        parts.append(f"The {adj[i]} second army fell on the {adj[1 - i]} {clash.flank['against']}.")
    for w in clash.wings:
        if w.broke:
            parts.append(_wing_told(adj, w))
    for i, tag in ((0, "a"), (1, "d")):
        if clash.horse_round[tag]:
            parts.append(f"The {adj[i]} horse ride round the flank.")
    for i, tag in ((0, "a"), (1, "d")):
        if clash.reserve[tag]:
            parts.append(f"The {adj[i]} reserve goes in on the {clash.reserve[tag]}.")
    return " ".join(parts) + " " if parts else ""


def _withdrawal(
    state: GameState,
    province_id: str,
    attackers: list[Army],
    defenders: list[Army],
    lines: _Lines,
    events: EventLog,
) -> str | None:
    """A cautious army that expects to be beaten falls back instead of fighting.

    Returns the other side's state id if one withdrew (defenders behind walls never do).
    """
    rules = state.world.rules.armies
    pa, pd = lines.expected()
    walled = state.provinces[province_id].walls > 0
    for side, other, mine, theirs, defending in (
        (attackers, defenders, pa, pd, False),
        (defenders, attackers, pd, pa, True),
    ):
        if commander(side).engage != "cautious" or (defending and walled):
            continue
        if mine * BP // max(1, mine + theirs) >= rules.cautious_win_share_bp:
            continue
        if any(_fall_back_to(state, a) is None for a in side):
            continue
        place = state.world.geography[province_id].name.split(" (")[0]
        for army in side:
            _casualties(army, rules.rearguard_losses_bp)
            _retreat(state, army, events)
        _prune(state)
        text = (
            f"The {state.civs[side[0].owner].adjective} withdraw from {place} rather than "
            f"fight at long odds, leaving a rear-guard behind."
        )
        events.add(side[0].owner, "withdrawal", text, place)
        events.add(other[0].owner, "withdrawal", text, place)
        return other[0].owner
    return None


def _plans_told(won: str, plan_w: Tactic | None, lost: str, plan_l: Tactic | None) -> str:
    """The plans in a sentence, for the battle report (empty if both stood in line)."""
    if plan_w is None or plan_l is None or (plan_w.id == plan_l.id == "line"):
        return ""
    w, ll = plan_w.name.lower(), plan_l.name.lower()
    if plan_l.id in plan_w.beats:
        return f" The {won} {w} beat the {lost} {ll}."
    if plan_w.id in plan_l.beats:
        return f" The {lost} {ll} should have beaten the {won} {w}, but numbers told."
    return f" {won} {w} against {lost} {ll}."


def _casualties(army: Army, loss_bp: int) -> int:
    dead = 0
    for unit_id in sorted(army.troops):
        lost = apply_bp(army.troops[unit_id], loss_bp)
        army.troops[unit_id] -= lost
        dead += lost
    return dead


def _fall_back_to(state: GameState, army: Army) -> str | None:
    """Where a beaten (or withdrawing) army would go: the way it came, or a safe neighbour.

    None if it has nowhere to go.
    """

    def safe(pid: str) -> bool:
        return pid in state.provinces and not any(
            o.province == pid and at_war_with(state, army.owner, o.owner)
            for o in state.armies.values()
        )

    def friendly(pid: str) -> bool:
        owner = state.provinces[pid].owner
        return owner is None or owner == army.owner or not at_war_with(state, army.owner, owner)

    near = sorted(p for p in state.world.geography[army.province].neighbours if safe(p))
    if army.came_from and army.came_from != army.province and safe(army.came_from):
        return army.came_from
    for options in ([p for p in near if friendly(p)], near):
        if options:
            return max(options, key=lambda p: (friendly(p), state.provinces[p].population, p))
    return None


def _retreat(state: GameState, army: Army, events: EventLog) -> None:
    """A beaten army falls back the way it came, or to any safe neighbouring province.

    Only an army with nowhere to go - surrounded in enemy land - lays down its arms.
    """
    if army.id not in state.armies or army.garrison:
        return  # a beaten garrison has nowhere to go: its city falls (D-273)
    army.target = None
    army.siege_bp = 0
    army.dug_in = False
    army.forced = False
    refuge = _fall_back_to(state, army)
    if refuge is not None:
        army.province = refuge
        return
    if state.provinces[army.province].owner == army.owner:
        return  # nowhere to run: it stands and holds its own ground
    state.armies.pop(army.id)
    events.add(
        army.owner, "army_lost", f"The {army.name}, surrounded, lays down its arms.", army.name
    )


def _prune(state: GameState) -> None:
    """Armies too small to fight melt away (their men go home if they can)."""
    floor = state.world.rules.armies.min_army
    for army_id in sorted(state.armies):
        army = state.armies[army_id]
        army.troops = {u: n for u, n in army.troops.items() if n > 0}
        if army.men < floor and not army.garrison:
            disband(state, army_id)


# --- sieges --------------------------------------------------------------------------------


def siege_progress(state: GameState, army: Army) -> int:
    """How far a turn of siege by this army brings down the walls (bp)."""
    rules = state.world.rules.armies
    people = state.provinces[army.province].population
    needed_men = max(1, people // rules.garrison_people_per_man)
    base = rules.siege_base_bp * min(army.men, needed_men) // needed_men
    engines = sum(
        state.world.units[u].siege * men // 1000 * rules.siege_point_bp
        for u, men in army.troops.items()
    )
    return (base + engines) * (BP + trait_bp(state, army, "siege")) // BP


def pillage(state: GameState, army: Army, owner: str, events: EventLog) -> None:
    """Ravage an enemy province: burn, loot and drive off its people instead of besieging."""
    rules = state.world.rules.armies
    province = state.provinces[army.province]
    lost = apply_bp(province.population, rules.pillage_people_bp)
    province.population -= lost
    loot = min(
        state.civs[owner].stockpiles.wealth,
        province.population // 1000 * rules.pillage_loot_per_1000,
    )
    state.civs[owner].stockpiles.wealth -= loot
    state.civs[army.owner].stockpiles.wealth += loot
    province.ravaged = rules.ravaged_turns
    burned = ruin_newest(state, army.province)
    rel = relation(state, army.owner, owner)
    if rel is not None:
        rel.grievance[owner] = rel.grievance.get(owner, 0) + rules.pillage_grievance_bp // 3
        rival_rules = state.world.rules.rivals
        rel.weariness[owner] = rel.weariness.get(owner, 0) + rival_rules.weariness_per_loss_bp // 3
    place = state.world.geography[army.province].name
    adjective = state.civs[army.owner].adjective
    text = f"{adjective} armies ravage {place}: {lost:,} dead or fled, {loot:,} wealth carried off."
    if burned:
        text = text[:-1] + f", its {burned.lower()} burned."
    events.add(owner, "pillaged", text, place)
    events.add(army.owner, "pillage", text, place)


# --- supply and upkeep ---------------------------------------------------------------------


def upkeep(state: GameState, events: EventLog) -> None:
    """Armies eat, are paid, sicken and recover; unpaid armies lose heart and desert.

    Ravaged provinces recover a little each turn.
    """
    rules = state.world.rules.armies
    for province in state.provinces.values():
        province.ravaged = max(0, province.ravaged - 1)
    by_place: dict[tuple[str, str], int] = {}
    for army in state.armies.values():
        key = (army.owner, army.province)
        by_place[key] = by_place.get(key, 0) + army.men
    for army_id in sorted(state.armies):
        army = state.armies[army_id]
        civ = state.civs[army.owner]
        food = sum(state.world.units[u].upkeep_food * n // 1000 for u, n in army.troops.items())
        wealth = sum(state.world.units[u].upkeep_wealth * n // 1000 for u, n in army.troops.items())
        paid = civ.stockpiles.food >= food and civ.stockpiles.wealth >= wealth
        civ.stockpiles.food = max(0, civ.stockpiles.food - food)
        civ.stockpiles.wealth = max(0, civ.stockpiles.wealth - wealth)
        home = state.provinces[army.province].owner == army.owner
        if home or army.stance == "pillage":  # at home, or living off an enemy's land
            loss = rules.attrition_home_bp
        else:
            terrain = state.world.geography[army.province].terrain
            loss = rules.attrition_abroad_bp + rules.attrition_terrain_bp.get(terrain, 0)
            loss = loss * BP // (BP + trait_bp(state, army, "quartermaster"))
        supply = state.provinces[army.province].population // rules.supply_people_per_man
        crowd = by_place[(army.owner, army.province)]
        if crowd > supply:
            loss += rules.starving_attrition_bp * (crowd - supply) // crowd
        if not paid:
            loss += rules.unpaid_desertion_bp
            army.morale_bp = clamp(army.morale_bp - rules.unpaid_morale_bp, 1000, BP)
        elif home:
            recovery = rules.morale_recovery_bp * (BP + trait_bp(state, army, "beloved")) // BP
            army.morale_bp = clamp(army.morale_bp + recovery, 0, BP)
        _casualties(army, clamp(loss, 0, 9000))
        if army.contract:
            army.contract -= 1
            if army.contract == 0:  # paid off: they take their swords elsewhere
                state.armies.pop(army_id)
                events.add(army.owner, "news", "The mercenaries' contract ends; they march away.")
    _prune(state)


# --- generalship: how courts (and the player's defenders) move their armies ----------------


def _threats(state: GameState, civ_id: str) -> list[Army]:
    """Enemy armies standing in this state's land."""
    return sorted(
        (
            a
            for a in state.armies.values()
            if state.provinces[a.province].owner == civ_id and at_war_with(state, civ_id, a.owner)
        ),
        key=lambda a: (-a.men, a.id),
    )


def defend(state: GameState, civ_id: str) -> None:
    """Armies set to defend march on invaders in their own land."""
    threats = _threats(state, civ_id)
    if not threats:
        return
    for army in sorted(state.armies.values(), key=lambda a: a.id):
        if army.owner == civ_id and army.target is None and army.stance == "defend":
            nearest = min(
                threats,
                key=lambda t: (len(route(state, civ_id, army.province, t.province)) or 99, t.id),
            )
            if nearest.province != army.province:
                if army.engage == "cautious" and (
                    win_share(state, [army], [nearest], nearest.province, False)
                    < state.world.rules.armies.cautious_win_share_bp
                ):
                    continue  # it will not march on a host it cannot beat
                army.target = nearest.province


RAIDER_MARTIAL_BP = 30_000
"""Peoples this warlike (steppe horsemen) ravage what they cannot quickly take."""


def merge(state: GameState) -> None:
    """Idle armies of one state standing in the same province join into one host.

    An army told to hold its ground (a garrison) keeps apart from a passing host.
    """
    groups: dict[tuple[str, str, bool], list[Army]] = {}
    for army in sorted(state.armies.values(), key=lambda a: a.id):
        if army.target is None and not army.contract:
            key = (army.owner, army.province, army.stance == "hold")
            groups.setdefault(key, []).append(army)
    for armies in groups.values():
        if len(armies) < 2:
            continue
        armies.sort(key=lambda a: (-a.men, a.id))
        keep = armies[0]
        for other in armies[1:]:
            total = keep.men + other.men
            keep.morale_bp = (keep.morale_bp * keep.men + other.morale_bp * other.men) // max(
                1, total
            )
            keep.veterancy_bp = (
                keep.veterancy_bp * keep.men + other.veterancy_bp * other.men
            ) // max(1, total)
            for unit_id, men in other.troops.items():
                keep.troops[unit_id] = keep.troops.get(unit_id, 0) + men
            if other.general and (not keep.general or other.skill > keep.skill):
                if keep.general:
                    release(state, keep)
                keep.general, keep.skill, keep.trait = other.general, other.skill, other.trait
            else:
                release(state, other)
            keep.siege_bp = max(keep.siege_bp, other.siege_bp)
            state.armies.pop(other.id)


def odds(state: GameState, mine: list[Army], theirs: list[Army], province_id: str) -> int:
    """How strongly ``mine`` would attack ``theirs`` at a province (bp; 10_000 = even).

    Counts the plans, formations, rules of engagement and fortified camps on both sides.
    """
    if not theirs:
        return 10 * BP
    attack, defend_power = _lines(state, province_id, mine, theirs).expected()
    return attack * BP // max(1, defend_power)


def command(state: GameState, strengths: dict[str, int]) -> None:
    """Rival courts raise, mass and direct their armies; every defender meets invaders."""
    rules = state.world.rules.armies
    merge(state)
    grace = state.turn < state.world.rules.rivals.player_grace_turns
    for civ_id in sorted(state.civs):
        if not alive(state, civ_id):
            continue
        if civ_id == state.player_civ:
            defend(state, civ_id)
            continue
        civ = state.civs[civ_id]
        engage: Literal["fight", "cautious"] = (
            "fight" if civ.disposition.value == "aggressive" else "cautious"
        )
        for army in state.armies.values():  # rival generals choose their own rules of engagement
            if army.owner == civ_id and army.engage != "last_man":
                army.engage = engage
        enemies = at_war(state, civ_id)
        want_bp = rules.war_army_bp if enemies else rules.peace_army_bp
        want = apply_bp(apply_bp(state.population(civ_id), want_bp), civ.martial_bp)
        have = under_arms(state, civ_id)
        seat = civ.capital if civ.capital in state.provinces else state.owned_provinces(civ_id)[0]
        if have < want * 8 // 10:
            spare = civ.stockpiles.wealth // 2  # half the treasury kept for other needs
            per_k = max(1, sum(raise_cost(state, composition(state, civ_id, 1000))))
            men = min(want - have, spare * 1000 // per_k)
            if men >= rules.min_army:
                raise_army(state, civ_id, seat, men)
        mine = sorted(
            (a for a in state.armies.values() if a.owner == civ_id), key=lambda a: (-a.men, a.id)
        )
        if not mine:
            continue
        threats = _threats(state, civ_id)
        main = mine[0]
        if threats:
            defend(state, civ_id)
            continue
        if not enemies:
            for army in mine:
                if state.provinces[army.province].owner != civ_id:
                    army.target = seat
            continue
        raiders = civ.martial_bp >= RAIDER_MARTIAL_BP  # the steppe raids rather than besieges
        for army in mine:
            owner = state.provinces[army.province].owner
            if raiders and army.target is None and owner and at_war_with(state, civ_id, owner):
                progress = max(1, siege_progress(state, army))
                if defence_bp(state, owner, army.province) // progress >= 3:
                    army.stance = "pillage"
        if main.target is not None or main.siege_bp > 0 or main.stance == "pillage":
            continue
        # the nearest enemy province it can reach, weakest walls and richest first
        choices: list[tuple[int, int, int, str, str]] = []
        for enemy in enemies:
            if grace and enemy == state.player_civ:
                continue
            for p in frontier(state, civ_id, enemy):
                path = route(state, civ_id, main.province, p)
                if path:
                    choices.append(
                        (
                            len(path),
                            defence_bp(state, enemy, p),
                            -state.provinces[p].population,
                            p,
                            enemy,
                        )
                    )
        if not choices:
            continue
        _, _, _, objective, enemy = min(choices)
        # march when the odds against the enemy armies near the objective are good enough:
        # a warlike court accepts an even fight, a cautious one wants the upper hand
        near = {objective, *state.world.geography[objective].neighbours}
        theirs = [a for a in state.armies.values() if a.owner == enemy and a.province in near]
        nerve = 9_000 if civ.disposition.value == "aggressive" else 11_500
        if odds(state, [main], theirs, objective) >= nerve:
            main.target = objective


# --- the player's orders -------------------------------------------------------------------


def wall_cost(state: GameState, province_id: str) -> tuple[int, int]:
    """Materials and wealth for the next level of walls in a province."""
    rules = state.world.rules.armies
    level = state.provinces[province_id].walls + 1
    materials = rules.wall_materials * level * state.world.cost_scale
    return materials, materials // 2


def wall_tech(state: GameState, province_id: str) -> str | None:
    """The advancement the next level of walls needs (None: no higher walls exist)."""
    techs = state.world.rules.armies.wall_techs
    level = state.provinces[province_id].walls
    return techs[level] if level < len(techs) else None


def fortify(state: GameState, civ_id: str, province_id: str) -> tuple[bool, str]:
    """Build the next level of walls in one of the state's provinces."""
    province = state.provinces.get(province_id)
    if province is None or province.owner != civ_id:
        return False, "walls are built in your own provinces"
    needed = wall_tech(state, province_id)
    if needed is None:
        return False, "these walls are as strong as walls can be"
    civ = state.civs[civ_id]
    if needed in state.tech_nodes and not is_adopted(civ, needed):
        return False, f"higher walls need {state.tech_nodes[needed].name}"
    materials, wealth = wall_cost(state, province_id)
    if civ.stockpiles.materials < materials or civ.stockpiles.wealth < wealth:
        return False, f"the walls need {materials} materials and {wealth} wealth"
    civ.stockpiles.materials -= materials
    civ.stockpiles.wealth -= wealth
    province.walls += 1
    place = state.world.geography[province_id].name
    kind = ("stone walls", "towers and gates", "star-shaped bastions")[min(2, province.walls - 1)]
    return True, f"Masons raise {kind} around {place}."


def _deploy(state: GameState, army: Army, action: ArmyDeploy) -> tuple[bool, str]:
    """Order where one kind of soldier stands in the line (D-270)."""
    kinds = {u.kind for u in state.world.units.values()}
    if action.unit_kind not in kinds:
        return False, f"there are no {action.unit_kind!r} soldiers"
    if action.place not in DEPLOY_CHOICES:
        return False, f"unknown place in the line {action.place!r}"
    if action.unit_kind == SIEGE:
        return False, "siege engines stay in camp; they take no place in the line"
    if action.place == "auto":
        army.deployment.pop(action.unit_kind, None)
        return (
            True,
            f"The {army.name}'s {action.unit_kind} troops stand where the formation puts them.",
        )
    army.deployment[action.unit_kind] = action.place
    where = PLACE_NAMES[action.place].lower()
    return True, f"The {army.name}'s {action.unit_kind} troops will stand: {where}."


def apply_orders(state: GameState, action: Orders) -> tuple[bool, str]:
    """Carry out an order to raise, march, halt or disband an army, or to build walls."""
    if isinstance(action, Fortify):
        return fortify(state, action.civ, action.province)
    if isinstance(action, BuildFleet):
        fleet, message = build_fleet(state, action.civ, action.province, SIZES[action.size])
        return fleet is not None, message
    if isinstance(action, SailFleet | ScuttleFleet):
        fleet = state.fleets.get(action.fleet)
        if fleet is None or fleet.owner != action.civ:
            return False, f"you have no fleet {action.fleet!r}"
        if isinstance(action, ScuttleFleet):
            state.fleets.pop(fleet.id)
            return True, f"The {fleet.name} is laid up and its ships broken up."
        if action.sea == fleet.sea:
            return False, f"the {fleet.name} is already there"
        if action.sea not in state.world.seas or not sea_route(state, fleet.sea, action.sea):
            return False, "the fleet cannot sail there"
        fleet.target = action.sea
        return True, f"The {fleet.name} sails for the {state.world.seas[action.sea].name}."
    if isinstance(action, RaiseArmy):
        if action.province not in state.provinces:
            return False, f"unknown province {action.province!r}"
        men = levy_size(state, action.civ, action.province, action.size)
        army, message = raise_army(state, action.civ, action.province, men, action.style)
        return army is not None, message
    army = state.armies.get(action.army)
    if army is None or army.owner != action.civ:
        return False, f"you have no army {action.army!r}"
    if isinstance(action, DisbandArmy):
        return True, disband(state, army.id)
    if isinstance(action, ArmyPlan):
        chosen = state.world.tactics.get(action.plan)
        if chosen is None and action.plan != AUTO:
            return False, f"unknown battle plan {action.plan!r}"
        army.plan = action.plan
        if chosen is None:
            return True, f"The {army.name}'s general will choose how to fight."
        return True, f"The {army.name} will fight with a {chosen.name.lower()}."
    if isinstance(action, ArmyFormation):
        chosen_f = state.world.formations.get(action.formation)
        if chosen_f is None and action.formation != FORMATION_AUTO:
            return False, f"unknown formation {action.formation!r}"
        army.formation = action.formation
        if chosen_f is None:
            return True, f"The {army.name}'s general will choose how to draw up the line."
        return True, f"The {army.name} will fight in a {chosen_f.name.lower()}."
    if isinstance(action, ArmyDeploy):
        return _deploy(state, army, action)
    if isinstance(action, ArmyAssault):
        army.assault = action.assault
        said = {
            "breach": "will storm the city once its walls are breached",
            "now": "will storm the city at once, whatever the walls",
            "starve": "will not storm, but starve the city into surrender",
        }[action.assault]
        return True, f"The {army.name} {said}."
    if isinstance(action, ArmyEngage):
        army.engage = action.engage
        said = {
            "fight": "will fight whatever comes",
            "cautious": "will withdraw from a battle it expects to lose",
            "last_man": "will fight to the last man",
        }[action.engage]
        return True, f"The {army.name} {said}."
    if isinstance(action, ArmyStance):
        army.target = None
        army.stance = action.stance
        verb = {
            "hold": "holds its ground",
            "defend": "stands ready to defend",
            "pillage": "turns to plunder",
        }[action.stance]
        return True, f"The {army.name} {verb}."
    if action.target not in state.provinces:
        return False, f"unknown province {action.target!r}"
    if action.target == army.province:
        return False, f"the {army.name} is already there"
    if not route(state, army.owner, army.province, action.target):
        owner = state.provinces[action.target].owner
        why = (
            f"you are not at war with {state.civs[owner].name}"
            if owner and owner != army.owner and not at_war_with(state, army.owner, owner)
            else "there is no way there"
        )
        return False, f"the {army.name} cannot march there: {why}"
    army.target = action.target
    army.forced = action.forced
    place = state.world.geography[action.target].name
    pace = " at a forced pace" if action.forced else ""
    return True, f"The {army.name} marches on {place}{pace}."
