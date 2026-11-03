"""Fleets, sea battles and command of the sea (D-107).

A fleet is a number of warships of one kind in a sea zone. Fleets are built in a coastal
province and launched into a sea on its shore; they sail to neighbouring seas (seas that
share a shore), fight enemy fleets they meet, and cost wealth to keep. An army may cross a
sea only where no enemy fleet there is stronger than its own side's: whoever commands the
sea decides who crosses it.
"""

from __future__ import annotations

from collections import deque

from anachronism.content.schema import RelationStatus, Ship
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.rivals import alive, at_war, relation, status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import Fleet, GameState
from anachronism.engine.tales import tell
from anachronism.engine.tech import is_adopted

SIZES = {"small": 10, "medium": 25, "large": 60}
"""Ships in a small, medium or large squadron."""


def best_ship(state: GameState, civ_id: str) -> Ship | None:
    """The strongest kind of warship the state can build, if any."""
    civ = state.civs[civ_id]
    ships = [
        s
        for _, s in sorted(state.world.ships.items())
        if all(is_adopted(civ, t) for t in s.needs_techs)
    ]
    return max(ships, key=lambda s: (s.attack, s.id)) if ships else None


def seas_of(state: GameState, province_id: str) -> list[str]:
    """The seas on a province's shore, in id order."""
    return sorted(sid for sid, sea in state.world.seas.items() if province_id in sea.neighbours)


def sea_links(state: GameState) -> dict[str, set[str]]:
    """Each sea's neighbouring seas: those sharing a shore province."""
    links: dict[str, set[str]] = {sid: set() for sid in state.world.seas}
    shores: dict[str, list[str]] = {}
    for sid, sea in sorted(state.world.seas.items()):
        for pid in sea.neighbours:
            shores.setdefault(pid, []).append(sid)
    for seas in shores.values():
        for a in seas:
            links[a].update(b for b in seas if b != a)
    return links


def sea_route(state: GameState, start: str, goal: str) -> list[str]:
    """The shortest way by sea from ``start`` to ``goal`` (excluding ``start``)."""
    if start == goal:
        return []
    links = sea_links(state)
    came = {start: start}
    queue = deque([start])
    while queue:
        here = queue.popleft()
        for nxt in sorted(links.get(here, ())):
            if nxt in came:
                continue
            came[nxt] = here
            if nxt == goal:
                path = [goal]
                while came[path[-1]] != start:
                    path.append(came[path[-1]])
                return path[::-1]
            queue.append(nxt)
    return []


def power(state: GameState, civ_id: str, sea: str) -> int:
    """A state's naval power in a sea: its ships there and its allies'."""
    total = 0
    for fleet in state.fleets.values():
        if fleet.sea != sea:
            continue
        if fleet.owner == civ_id or status(state, civ_id, fleet.owner) is RelationStatus.ALLIED:
            total += fleet.ships * state.world.ships[fleet.ship].attack
    return total


def enemy_power(state: GameState, civ_id: str, sea: str) -> int:
    """The naval power in a sea of the states at war with ``civ_id``."""
    enemies = set(at_war(state, civ_id))
    return sum(
        f.ships * state.world.ships[f.ship].attack
        for f in state.fleets.values()
        if f.sea == sea and f.owner in enemies
    )


def can_cross(state: GameState, civ_id: str, a: str, b: str) -> bool:
    """May an army of ``civ_id`` cross the sea between provinces ``a`` and ``b``?

    Yes if some sea joining them is not held by a stronger enemy fleet.
    """
    joining = [s for s in seas_of(state, a) if b in state.world.seas[s].neighbours]
    if not joining:
        return True
    return any(enemy_power(state, civ_id, s) <= power(state, civ_id, s) for s in joining)


def build_fleet(
    state: GameState, civ_id: str, province_id: str, ships: int, *, free: bool = False
) -> tuple[Fleet | None, str]:
    """Build warships in a coastal province and launch them into the sea on its shore."""
    province = state.provinces.get(province_id)
    if province is None or province.owner != civ_id:
        return None, "fleets are built in your own provinces"
    seas = seas_of(state, province_id)
    if not seas:
        return None, "there is no sea to launch them into"
    kind = best_ship(state, civ_id)
    if kind is None:
        return None, "building warships needs Sailing"
    civ = state.civs[civ_id]
    materials, wealth = kind.materials * ships, kind.wealth * ships
    if not free:
        if civ.stockpiles.materials < materials or civ.stockpiles.wealth < wealth:
            return (
                None,
                f"{ships} {kind.name.lower()} need {materials} materials and {wealth} wealth",
            )
        civ.stockpiles.materials -= materials
        civ.stockpiles.wealth -= wealth
    sea = seas[0]
    for fleet in sorted(state.fleets.values(), key=lambda f: f.id):
        if fleet.owner == civ_id and fleet.sea == sea and fleet.ship == kind.id:
            fleet.ships += ships
            return fleet, f"{ships} {kind.name.lower()} join the {fleet.name}."
    civ.armies_raised += 1
    name = f"Fleet of the {state.world.seas[sea].name}"
    fleet = Fleet(
        id=f"{civ_id}-f{civ.armies_raised}",
        owner=civ_id,
        name=name,
        sea=sea,
        ship=kind.id,
        ships=ships,
    )
    state.fleets[fleet.id] = fleet
    return fleet, f"{ships} {kind.name.lower()} put to sea: the {name}."


def standing_fleets(state: GameState) -> None:
    """Seafaring states start with a fleet in proportion to their coastal people."""
    per = state.world.rules.armies.standing_ships_per_100k
    for civ_id in sorted(state.civs):
        if best_ship(state, civ_id) is None or not state.owned_provinces(civ_id):
            continue
        coast = [p for p in state.owned_provinces(civ_id) if seas_of(state, p)]
        people = sum(state.provinces[p].population for p in coast)
        ships = people * per // 100_000 * state.civs[civ_id].navy_bp // BP
        if ships >= state.world.rules.armies.standing_fleet_min and coast:
            home = max(coast, key=lambda p: (state.provinces[p].population, p))
            build_fleet(state, civ_id, home, ships, free=True)


def sail(state: GameState, rng: GameRng, events: EventLog) -> None:
    """Fleets sail toward their targets (two seas a turn); enemy fleets that meet fight once."""
    for _ in range(2):
        for fleet_id in sorted(state.fleets):
            fleet = state.fleets[fleet_id]
            if fleet.target is None:
                continue
            path = sea_route(state, fleet.sea, fleet.target)
            if not path:
                fleet.target = None
                continue
            fleet.sea = path[0]
            if fleet.sea == fleet.target:
                fleet.target = None
    for sea in sorted({f.sea for f in state.fleets.values()}):
        _sea_battle(state, sea, rng, events)


def _sea_battle(state: GameState, sea: str, rng: GameRng, events: EventLog) -> bool:
    here = sorted((f for f in state.fleets.values() if f.sea == sea), key=lambda f: f.id)
    pair = next(
        (
            (a, b)
            for a in here
            for b in here
            if a.owner < b.owner and status(state, a.owner, b.owner) is RelationStatus.WAR
        ),
        None,
    )
    if pair is None:
        return False
    a_side, b_side = pair[0].owner, pair[1].owner
    rules = state.world.rules.armies
    luck = rules.battle_luck_bp
    pa = power(state, a_side, sea) * (BP - luck + rng.below(2 * luck + 1)) // BP
    pb = power(state, b_side, sea) * (BP - luck + rng.below(2 * luck + 1)) // BP
    winner, loser = (a_side, b_side) if pa >= pb else (b_side, a_side)
    pw, pl = max(pa, pb), min(pa, pb)
    margin = (pw - pl) * BP // max(1, pw + pl)
    sunk_l = sunk_w = 0
    for fleet in here:
        if fleet.owner == loser:
            lost = apply_bp(fleet.ships, clamp(3000 + margin, 0, 9000))
            fleet.ships -= lost
            sunk_l += lost
        elif fleet.owner == winner:
            lost = apply_bp(fleet.ships, clamp(1200 - margin // 2, 200, 9000))
            fleet.ships -= lost
            sunk_w += lost
    for fleet_id in sorted(state.fleets):
        if state.fleets[fleet_id].ships <= 0:
            state.fleets.pop(fleet_id)
    name = state.world.seas[sea].name
    won, lost_by = state.civs[winner].adjective, state.civs[loser].adjective
    flagship = max(
        (f for f in here if f.owner == winner), key=lambda f: (f.ships, f.id), default=None
    )
    ship = flagship.ship if flagship else ""
    story = tell(state, "", "", margin >= 4000, rng, ship=ship, winner=winner).format(
        place=name,
        winner=won,
        loser=lost_by,
        unit=state.world.ships[ship].name.lower() if ship else "ships",
    )
    text = (
        f"Sea battle in the {name}. {story[:1].upper()}{story[1:]}"
        f" {lost_by} ships lost {sunk_l}, {won} {sunk_w}."
    )
    events.add(winner, "sea_battle_won", text, name)
    events.add(loser, "sea_battle_lost", text, name)
    rel = relation(state, winner, loser)
    if rel is not None:
        rel.weariness[loser] = rel.weariness.get(loser, 0) + rules.weariness_per_battle_bp // 2
        rel.losses[loser] = rel.losses.get(loser, 0) + 1
    # the beaten fleet falls back toward home waters, or any sea free of its enemies
    for fleet in sorted(state.fleets.values(), key=lambda f: f.id):
        if fleet.owner == loser and fleet.sea == sea:
            fleet.target = _refuge(state, loser, sea)
    return True


def _refuge(state: GameState, civ_id: str, sea: str) -> str | None:
    """Where a beaten fleet falls back to: home waters, else a neighbouring sea it holds."""
    home = _home_sea(state, civ_id)
    if home and home != sea:
        return home
    safe = [
        s
        for s in sorted(sea_links(state).get(sea, ()))
        if enemy_power(state, civ_id, s) <= power(state, civ_id, s)
    ]
    return safe[0] if safe else None


def _home_sea(state: GameState, civ_id: str) -> str | None:
    capital = state.civs[civ_id].capital
    seas = seas_of(state, capital) if capital in state.provinces else []
    if seas:
        return seas[0]
    for pid in state.owned_provinces(civ_id):
        seas = seas_of(state, pid)
        if seas:
            return seas[0]
    return None


def fleet_upkeep(state: GameState) -> None:
    """Fleets cost wealth each turn; unpaid crews desert (a tenth of the ships)."""
    for fleet_id in sorted(state.fleets):
        fleet = state.fleets[fleet_id]
        civ = state.civs[fleet.owner]
        cost = fleet.ships * state.world.ships[fleet.ship].upkeep_wealth // 10
        if civ.stockpiles.wealth >= cost:
            civ.stockpiles.wealth -= cost
        else:
            civ.stockpiles.wealth = 0
            fleet.ships -= max(1, fleet.ships // 10)
        if fleet.ships <= 0 or not alive(state, fleet.owner):
            state.fleets.pop(fleet_id)


def blockades(state: GameState, events: EventLog) -> None:
    """Enemy fleets commanding every sea on a province's shore close its harbours.

    A blockaded province loses most of its trade (see the economy) and its people tire of
    the war that starves them.
    """
    rules = state.world.rules.armies
    tired: dict[tuple[str, str], int] = {}
    for pid in sorted(state.provinces):
        province = state.provinces[pid]
        owner = province.owner
        seas = seas_of(state, pid) if owner else []
        shut = (
            bool(seas)
            and owner is not None
            and all(enemy_power(state, owner, s) > power(state, owner, s) for s in seas)
        )
        if shut and owner is not None:
            if not province.blockaded:
                name = state.world.geography[pid].name
                events.add(owner, "blockade", f"Enemy warships blockade {name}.", name)
            enemy = max(
                at_war(state, owner),
                key=lambda e: (sum(_fleet_power(state, e, s) for s in seas), e),
            )
            tired[owner, enemy] = tired.get((owner, enemy), 0) + rules.blockade_weariness_bp
        province.blockaded = shut
    for (owner, enemy), weariness in sorted(tired.items()):
        rel = relation(state, owner, enemy)
        if rel is not None:
            rel.weariness[owner] = rel.weariness.get(owner, 0) + min(
                weariness, 4 * rules.blockade_weariness_bp
            )


def _fleet_power(state: GameState, civ_id: str, sea: str) -> int:
    return sum(
        f.ships * state.world.ships[f.ship].attack
        for f in state.fleets.values()
        if f.owner == civ_id and f.sea == sea
    )


def admiralty(state: GameState) -> None:
    """Rival courts at war build fleets to contest the seas they share with their enemies."""
    for civ_id in sorted(state.civs):
        if civ_id == state.player_civ or not alive(state, civ_id):
            continue
        enemies = at_war(state, civ_id)
        if not enemies or best_ship(state, civ_id) is None:
            continue
        mine = [f for f in state.fleets.values() if f.owner == civ_id]
        coast = [p for p in state.owned_provinces(civ_id) if seas_of(state, p)]
        if not coast:
            continue
        shared = sorted(
            {s for p in coast for s in seas_of(state, p)}
            & {s for e in enemies for p in state.owned_provinces(e) for s in seas_of(state, p)}
        )
        if not shared:
            continue
        enemy_shores = {p for e in enemies for p in state.owned_provinces(e)}
        # meet the enemy's fleet where it is strongest; failing that, blockade its coasts
        front = max(
            shared,
            key=lambda s: (
                enemy_power(state, civ_id, s),
                len(enemy_shores & set(state.world.seas[s].neighbours)),
                s,
            ),
        )
        threat = enemy_power(state, civ_id, front)
        ours = sum(f.ships * state.world.ships[f.ship].attack for f in mine)
        civ = state.civs[civ_id]
        if ours <= threat and civ.stockpiles.wealth > 0:
            kind = best_ship(state, civ_id)
            assert kind is not None
            ships = min(SIZES["medium"], civ.stockpiles.wealth // 2 // max(1, kind.wealth))
            port = max(
                coast, key=lambda p: (front in seas_of(state, p), state.provinces[p].population, p)
            )
            if ships >= 5:
                build_fleet(state, civ_id, port, ships)
                mine = [f for f in state.fleets.values() if f.owner == civ_id]
        total = sum(f.ships * state.world.ships[f.ship].attack for f in mine)
        if total * 10 >= threat * 12:
            for fleet in mine:
                if fleet.sea != front and fleet.target is None:
                    fleet.target = front
