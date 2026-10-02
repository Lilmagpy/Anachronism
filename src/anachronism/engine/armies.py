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

from anachronism.content.schema import General, RelationStatus, Tactic, Unit
from anachronism.engine.actions import (
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
from anachronism.engine.buildings import bonus as building_bonus
from anachronism.engine.buildings import ruin_newest
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.navies import SIZES, build_fleet, can_cross, sea_route
from anachronism.engine.rivals import alive, at_war, frontier, province_links, relation, status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import Army, GameState
from anachronism.engine.tactics import AUTO, bonus, commander, edge, plans
from anachronism.engine.tales import tell
from anachronism.engine.tech import is_adopted, usable_resources
from anachronism.engine.war import capture, defence_bp

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


def trait_bp(state: GameState, army: Army, trait: str) -> int:
    """The strength of a general's gift for this army (0 if its general lacks it)."""
    return state.world.rules.armies.trait_bp.get(trait, 0) if army.trait == trait else 0


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
    return found in (RelationStatus.WAR, RelationStatus.ALLIED)


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
            army.province = nxt
            army.siege_bp = 0
            if nxt == army.target:
                army.target = None
        fight_battles(state, rng, events)


# --- battles -------------------------------------------------------------------------------


def _kinds(state: GameState, armies: list[Army]) -> dict[str, int]:
    """Share of each kind of soldier among these armies (bp)."""
    total = sum(a.men for a in armies) or 1
    kinds: dict[str, int] = {}
    for army in armies:
        for unit_id, men in army.troops.items():
            kind = state.world.units[unit_id].kind
            kinds[kind] = kinds.get(kind, 0) + men * BP // total
    return kinds


def unit_power(
    unit: Unit, men: int, attacking: bool, enemy_kinds: dict[str, int], terrain: str
) -> int:
    """The fighting power of ``men`` soldiers of one kind in a battle (before morale)."""
    base = (unit.attack if attacking else unit.defence) * men
    bonus = sum(apply_bp(swing, enemy_kinds.get(kind, 0)) for kind, swing in unit.bonus_vs.items())
    bonus += unit.terrain.get(terrain, 0)
    return max(0, base * (BP + bonus) // BP)


def side_power(
    state: GameState, armies: list[Army], enemies: list[Army], attacking: bool, province_id: str
) -> tuple[int, dict[str, int]]:
    """A side's total power in a battle, and each unit type's share of it."""
    rules = state.world.rules.armies
    terrain = state.world.geography[province_id].terrain
    enemy_kinds = _kinds(state, enemies)
    total = 0
    by_unit: dict[str, int] = {}
    for army in armies:
        power = 0
        horse = trait_bp(state, army, "horse")
        for unit_id, men in sorted(army.troops.items()):
            unit = state.world.units[unit_id]
            p = unit_power(unit, men, attacking, enemy_kinds, terrain)
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
            power = power * (BP + gift) // BP
        total += power
    if not attacking:  # defenders hold the high ground (walls matter in sieges, not here)
        owner = state.provinces[province_id].owner
        if owner is not None and armies and armies[0].owner == owner:
            ground = state.world.terrain[state.world.geography[province_id].terrain]
            extra = ground.defence_bp - BP
            total = total * (BP + apply_bp(max(0, extra), rules.field_defence_share_bp)) // BP
    return total, by_unit


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
                    owner and status(state, owner, first) is RelationStatus.ALLIED
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
        and status(state, civ, friend) is RelationStatus.ALLIED
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


def battle(
    state: GameState,
    province_id: str,
    attackers: list[Army],
    defenders: list[Army],
    rng: GameRng,
    events: EventLog,
) -> str:
    """Fight it out. Returns the winning state's id."""
    rules = state.world.rules.armies
    terrain = state.world.geography[province_id].terrain
    pa, units_a = side_power(state, attackers, defenders, True, province_id)
    pd, units_d = side_power(state, defenders, attackers, False, province_id)
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
    luck = rules.battle_luck_bp
    pa = pa * (BP - luck + rng.below(2 * luck + 1)) // BP
    pd = pd * (BP - luck + rng.below(2 * luck + 1)) // BP
    won_a = pa > pd
    winners, losers = (attackers, defenders) if won_a else (defenders, attackers)
    pw, pl = (pa, pd) if won_a else (pd, pa)
    plan_w, plan_l = (plan_a, plan_d) if won_a else (plan_d, plan_a)
    margin = (pw - pl) * BP // max(1, pw + pl)  # 0 (even) .. 10_000 (rout)
    crush = margin + (plan_w.rout_bp if plan_w else 0)  # an envelopment destroys the beaten
    blood = BP + sum(p.losses_bp for p in (plan_a, plan_d) if p is not None)
    blood = clamp(blood, 2000, 20_000)  # a charge is bloody, skirmishing is not
    lose_bp = rules.loser_losses_bp + apply_bp(rules.loser_losses_bp, crush * 2)
    lose_bp = clamp(lose_bp * blood // BP, 0, 9000)
    win_bp = rules.winner_losses_bp - apply_bp(rules.winner_losses_bp, margin)
    win_bp = clamp(win_bp * blood // BP, 300, 9000)
    dead_w = sum(_casualties(army, win_bp) for army in winners)
    dead_l = sum(_casualties(army, lose_bp) for army in losers)
    for army in winners:
        army.morale_bp = clamp(army.morale_bp - rules.morale_loss_bp // 6, 1000, BP)
        army.veterancy_bp = min(rules.max_veterancy_bp, army.veterancy_bp + rules.veterancy_win_bp)
    for army in losers:
        loss = rules.morale_loss_bp * BP // (BP + trait_bp(state, army, "beloved"))
        army.morale_bp = clamp(army.morale_bp - loss, 1000, BP)
        army.veterancy_bp = min(rules.max_veterancy_bp, army.veterancy_bp + rules.veterancy_loss_bp)
    winner, loser = winners[0].owner, losers[0].owner
    w_civ, l_civ = state.civs[winner], state.civs[loser]
    place = state.world.geography[province_id].name.split(" (")[0]
    hero = max(units_a if won_a else units_d, key=lambda u: (units_a if won_a else units_d)[u])
    hero_name = state.world.units[hero].name.lower()
    fallen = ""
    general = next((a.general for a in losers if a.general), "")
    if general and rng.chance(rules.general_death_bp):
        fallen = f" {general} fell on the field."
        for army in losers:
            if army.general == general:
                army.general = ""
                army.skill = 1
    rout = crush >= 4000
    named = "the " + place[4:] if place.startswith("The ") else place  # "of the Punjab"
    kind = state.world.units[hero].kind
    told = tell(state, kind, terrain, rout, rng, winner=winner, plan=plan_w.id if plan_w else "")
    story = told.format(place=named, winner=w_civ.adjective, loser=l_civ.adjective, unit=hero_name)
    story = story[:1].upper() + story[1:]
    schemes = _plans_told(w_civ.adjective, plan_w, l_civ.adjective, plan_l)
    text = (
        f"Battle of {named}. {story}{fallen}{schemes}"
        f" {w_civ.adjective} losses {dead_w:,}, {l_civ.adjective} {dead_l:,}."
    )
    events.add(winner, "battle_won", text, place)
    events.add(loser, "battle_lost", text, place)
    rel = relation(state, winner, loser)
    if rel is not None:
        rel.weariness[loser] = rel.weariness.get(loser, 0) + rules.weariness_per_battle_bp
        rel.losses[loser] = rel.losses.get(loser, 0) + 1
    for army in losers:
        _retreat(state, army, events)
    _prune(state)
    return winner


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


def _retreat(state: GameState, army: Army, events: EventLog) -> None:
    """A beaten army falls back the way it came, or to any safe neighbouring province.

    Only an army with nowhere to go - surrounded in enemy land - lays down its arms.
    """
    if army.id not in state.armies:
        return
    army.target = None
    army.siege_bp = 0

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
        army.province = army.came_from
        return
    for options in ([p for p in near if friendly(p)], near):
        if options:
            army.province = max(
                options, key=lambda p: (friendly(p), state.provinces[p].population, p)
            )
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
        if army.men < floor:
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


def sieges(state: GameState, events: EventLog) -> None:
    """Armies alone in enemy provinces besiege them; walls that fall change the map."""
    for army_id in sorted(state.armies):
        army = state.armies.get(army_id)
        if army is None:
            continue
        owner = state.provinces[army.province].owner
        if owner is None or owner == army.owner or not at_war_with(state, army.owner, owner):
            army.siege_bp = 0
            continue
        if _enemies_here(state, army):
            continue
        place = state.world.geography[army.province].name
        if army.stance == "pillage":
            pillage(state, army, owner, events)
            continue
        if army.siege_bp == 0:
            events.add(
                owner, "siege", f"{state.civs[army.owner].adjective} armies besiege {place}.", place
            )
        army.siege_bp += siege_progress(state, army)
        if army.siege_bp >= defence_bp(state, owner, army.province):
            army.siege_bp = 0
            capture(state, army.owner, army.province, events)
            rel = relation(state, army.owner, owner)
            if rel is not None:
                rules = state.world.rules.rivals
                rel.losses[owner] = rel.losses.get(owner, 0) + 1
                rel.weariness[owner] = rel.weariness.get(owner, 0) + rules.weariness_per_loss_bp


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
                army.target = nearest.province


RAIDER_MARTIAL_BP = 30_000
"""Peoples this warlike (steppe horsemen) ravage what they cannot quickly take."""


def merge(state: GameState) -> None:
    """Idle armies of one state standing in the same province join into one host."""
    groups: dict[tuple[str, str], list[Army]] = {}
    for army in sorted(state.armies.values(), key=lambda a: a.id):
        if army.target is None and not army.contract:
            groups.setdefault((army.owner, army.province), []).append(army)
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
    """How strongly ``mine`` would attack ``theirs`` at a province (bp; 10_000 = even)."""
    if not theirs:
        return 10 * BP
    attack, _ = side_power(state, mine, theirs, True, province_id)
    defend_power, _ = side_power(state, theirs, mine, False, province_id)
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
    place = state.world.geography[action.target].name
    return True, f"The {army.name} marches on {place}."
