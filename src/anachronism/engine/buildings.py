"""Buildings in provinces (D-111): what stands where, what it does, and raising more.

A province holds a few buildings, more as its people grow. Each kind needs its
advancements, sometimes a coast, a river or a map resource; it costs materials and wealth
up front, takes time to build, and wealth to keep. Standing buildings raise what their
province produces, help it grow, calm the realm or teach its people. Rival courts build
too, in their richest provinces, when their stores allow. Pillage burns the newest.
"""

from __future__ import annotations

from dataclasses import dataclass, fields

from anachronism.content.schema import Access, Building
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp
from anachronism.engine.state import Construction, GameState
from anachronism.engine.tech import is_adopted, standing_buildings
from anachronism.engine.timeflow import per_turn, turns_for


@dataclass(frozen=True)
class Bonus:
    """What a province's standing buildings add, in basis points."""

    food_bp: int = 0
    materials_bp: int = 0
    wealth_bp: int = 0
    knowledge_bp: int = 0
    growth_bp: int = 0
    capacity_bp: int = 0
    calm_bp: int = 0
    literacy_bp: int = 0
    veterans_bp: int = 0


_FIELDS = tuple(f.name for f in fields(Bonus))
NONE = Bonus()


def bonus(state: GameState, province_id: str) -> Bonus:
    """The sum of what every building standing in a province adds."""
    standing = state.provinces[province_id].buildings
    if not standing:
        return NONE
    kinds = [state.world.buildings[b] for b in standing if b in state.world.buildings]
    return Bonus(**{name: sum(getattr(k, name) for k in kinds) for name in _FIELDS})


def with_building(built: Bonus, kind: Building, replaced: Building | None = None) -> Bonus:
    """A province's bonus with one more building (taking out the one it replaces)."""
    values = {name: getattr(built, name) + getattr(kind, name) for name in _FIELDS}
    if replaced is not None:
        for name in _FIELDS:
            values[name] -= getattr(replaced, name)
    return Bonus(**values)


def slots(state: GameState, province_id: str) -> int:
    """How many buildings the province can hold: more as its people grow."""
    rules = state.world.rules.buildings
    people = state.provinces[province_id].population
    return min(rules.max_slots, rules.base_slots + people // rules.people_per_slot)


def cost(state: GameState, province_id: str, building_id: str) -> tuple[int, int]:
    """Materials and wealth to build one here; each building already standing adds more."""
    kind = state.world.buildings[building_id]
    rules = state.world.rules.buildings
    standing = len(state.provinces[province_id].buildings)
    scale = state.world.cost_scale * (BP + standing * rules.extra_cost_bp)
    return kind.materials * scale // BP, kind.wealth * scale // BP


QUEUE_LENGTH = 3
"""How many buildings a province can have waiting to start (D-128)."""


def why_not(
    state: GameState, civ_id: str, province_id: str, building_id: str, *, planning: bool = False
) -> str | None:
    """Why the building cannot go up here now (None: it can, if the stores allow).

    ``planning``: could it be queued behind the building going up, counting the plots that
    the works and the queue will take.
    """
    province = state.provinces.get(province_id)
    kind = state.world.buildings.get(building_id)
    if province is None or kind is None:
        return "no such place or building"
    if province.owner != civ_id:
        return "you build only in your own provinces"
    if building_id in province.buildings:
        return "already built here"
    planned = province.queue + ([province.works.building] if province.works else [])
    if planning and building_id in planned:
        return "already planned here"
    if planning and len(province.queue) >= QUEUE_LENGTH:
        return f"the queue holds {QUEUE_LENGTH} at most"
    if province.works is not None and not planning:
        return "builders are already at work here"
    if any(_replaces(state, b) == building_id for b in province.buildings):
        return "a better one already stands here"
    civ = state.civs[civ_id]
    missing = [t for t in kind.needs_techs if t in state.tech_nodes and not is_adopted(civ, t)]
    if missing:
        return "needs " + ", ".join(state.tech_nodes[t].name for t in missing)
    upgrading = kind.replaces in province.buildings or (planning and kind.replaces in planned)
    if kind.replaces is not None and not upgrading:
        return f"needs a {state.world.buildings[kind.replaces].name.lower()} here first"
    geography = state.world.geography[province_id]
    if kind.coastal and not geography.coastal:
        return "needs a coast"
    if kind.river and not geography.river:
        return "needs a river"
    if kind.needs_resource and not any(
        province.resources.get(r, Access.UNEXPLORED) in (Access.ACCESSIBLE, Access.LIMITED)
        for r in kind.needs_resource
    ):
        names = " or ".join(
            state.world.resources[r].name for r in kind.needs_resource if r in state.world.resources
        )
        return f"needs {names}"
    taken = len(province.buildings)
    if planning:  # plots the works and the queue will take (upgrades take none)
        taken += sum(
            1
            for b in planned
            if b in state.world.buildings and not state.world.buildings[b].replaces
        )
    if kind.replaces is None and taken >= slots(state, province_id):
        return "no room: the city must grow first"
    return None


def _replaces(state: GameState, building_id: str) -> str | None:
    kind = state.world.buildings.get(building_id)
    return kind.replaces if kind is not None else None


def queue(state: GameState, civ_id: str, province_id: str, building_id: str) -> tuple[bool, str]:
    """Build now if the builders are free; otherwise queue it to start next (D-128)."""
    province = state.provinces.get(province_id)
    if province is None or province.works is None:
        return start(state, civ_id, province_id, building_id)
    reason = why_not(state, civ_id, province_id, building_id, planning=True)
    if reason is not None:
        return False, reason
    if province.queued_by != civ_id:
        province.queue = []
    province.queue.append(building_id)
    province.queued_by = civ_id
    name = state.world.buildings[building_id].name.lower()
    place = state.world.geography[province_id].name
    return True, f"The {name} will start in {place} when the builders are free."


def unqueue(state: GameState, civ_id: str, province_id: str, building_id: str) -> tuple[bool, str]:
    """Take a building off a province's queue."""
    province = state.provinces.get(province_id)
    if province is None or province.owner != civ_id or building_id not in province.queue:
        return False, "that is not planned there"
    province.queue.remove(building_id)
    return True, f"The {state.world.buildings[building_id].name.lower()} is taken off the plans."


def start(state: GameState, civ_id: str, province_id: str, building_id: str) -> tuple[bool, str]:
    """Pay for a building and set the builders to work."""
    reason = why_not(state, civ_id, province_id, building_id)
    kind = state.world.buildings.get(building_id)
    if reason is not None or kind is None:
        return False, reason or "no such building"
    materials, wealth = cost(state, province_id, building_id)
    stores = state.civs[civ_id].stockpiles
    if stores.materials < materials or stores.wealth < wealth:
        return False, f"the {kind.name.lower()} needs {materials:,} materials and {wealth:,} wealth"
    stores.materials -= materials
    stores.wealth -= wealth
    turns = turns_for(state, kind.decades)
    state.provinces[province_id].works = Construction(building=building_id, turns_left=turns)
    place = state.world.geography[province_id].name
    return True, f"Builders begin the {kind.name.lower()} in {place}."


def advance_works(state: GameState, events: EventLog) -> None:
    """Building sites move on a turn; finished buildings open (replacing older ones).

    Then the next one queued starts, if the stores can pay for it (D-128).
    """
    for province_id in sorted(state.provinces):
        province = state.provinces[province_id]
        if province.queue and province.queued_by != province.owner:
            province.queue = []  # the plans of the old owners
        works = province.works
        if works is None:
            _next_queued(state, province_id, events)
            continue
        if province.owner is None:
            province.works = None
            continue
        works.turns_left -= 1
        if works.turns_left > 0:
            continue
        province.works = None
        kind = state.world.buildings[works.building]
        if kind.replaces in province.buildings:
            province.buildings.remove(kind.replaces)
        province.buildings.append(kind.id)
        place = state.world.geography[province_id].name
        events.add(
            province.owner,
            "building",
            f"Builders finish the {kind.name.lower()} in {place}.",
            subject=kind.name,
        )
        _next_queued(state, province_id, events)


def _next_queued(state: GameState, province_id: str, events: EventLog) -> None:
    """Start the next queued building, if it still can go up and the stores can pay."""
    province = state.provinces[province_id]
    owner = province.owner
    while province.queue and owner is not None and province.works is None:
        building_id = province.queue[0]
        if why_not(state, owner, province_id, building_id) is not None:
            province.queue.pop(0)  # no longer possible here: dropped from the plans
            continue
        materials, wealth = cost(state, province_id, building_id)
        stores = state.civs[owner].stockpiles
        if stores.materials < materials or stores.wealth < wealth:
            return  # it waits until the stores can pay
        province.queue.pop(0)
        ok, message = start(state, owner, province_id, building_id)
        if ok:
            events.add(owner, "building", message, subject=state.world.buildings[building_id].name)


def upkeep(state: GameState, civ_id: str) -> int:
    """Wealth a civilisation pays this turn to keep its buildings."""
    total = sum(
        state.world.buildings[b].upkeep
        for pid in state.owned_provinces(civ_id)
        for b in state.provinces[pid].buildings
        if b in state.world.buildings
    )
    return per_turn(state, total * state.world.cost_scale)


def weighted(state: GameState, civ_id: str, name: str) -> int:
    """A realm-wide bonus (calm, literacy): each province's weighted by its share of people."""
    people = state.population(civ_id)
    if people == 0:
        return 0
    total = 0
    for pid in state.owned_provinces(civ_id):
        value: int = getattr(bonus(state, pid), name)
        total += value * state.provinces[pid].population
    return total // people


def ruin_newest(state: GameState, province_id: str) -> str | None:
    """Pillage burns the newest building (and any building site); returns its name."""
    province = state.provinces[province_id]
    province.works = None
    if not province.buildings:
        return None
    burned = province.buildings.pop()
    kind = state.world.buildings.get(burned)
    return kind.name if kind is not None else burned


def worth(kind: Building, unrest_bp: int = 0) -> int:
    """A rough measure of what a building gives, for courts choosing what to build.

    Calm counts for more the more restless the realm is.
    """
    calm = kind.calm_bp * (4 + unrest_bp // 500)
    return calm + (
        kind.food_bp
        + kind.materials_bp
        + kind.wealth_bp
        + kind.knowledge_bp
        + kind.growth_bp // 2
        + kind.capacity_bp // 2
        + kind.literacy_bp * 4
        + kind.veterans_bp // 4
    )


def best_choice(state: GameState, civ_id: str, reserve: int) -> tuple[str, str] | None:
    """The most worthwhile (province, building) whose cost the stores hold ``reserve`` times.

    Worth is what the building gives, times the province's people: big cities first.
    """
    stores = state.civs[civ_id].stockpiles
    unrest = state.civs[civ_id].stats.unrest_bp
    wanted = wanted_buildings(state, civ_id)
    choices: list[tuple[int, int, str, str]] = []
    for pid in state.owned_provinces(civ_id):
        people = state.provinces[pid].population
        for bid, kind in state.world.buildings.items():
            if why_not(state, civ_id, pid, bid) is not None:
                continue
            materials, wealth = cost(state, pid, bid)
            if stores.materials < materials * reserve or stores.wealth < wealth * reserve:
                continue
            value = apply_bp(people // 1000, worth(kind, unrest))
            if bid in wanted:  # it opens the way to an idea the court is waiting on
                value *= 3
            choices.append((-value, materials + wealth, pid, bid))
    if not choices:
        return None
    _, _, pid, bid = min(choices)
    return pid, bid


def wanted_buildings(state: GameState, civ_id: str) -> set[str]:
    """Buildings that ideas the civilisation knows of but has not adopted are waiting for."""
    civ = state.civs[civ_id]
    have = standing_buildings(state, civ_id)
    wanted: set[str] = set()
    for node_id, tech in civ.tech.items():
        node = state.tech_nodes.get(node_id)
        if node is None or tech.stage.is_adopted:
            continue
        wanted.update(b for b in node.requires.buildings if b not in have)
    return wanted


def rival_builders(state: GameState, events: EventLog) -> None:
    """Each rival court with full stores raises one building a turn, in its largest city."""
    reserve = state.world.rules.buildings.rival_reserve
    for civ_id in sorted(state.civs):
        if civ_id == state.player_civ or not state.owned_provinces(civ_id):
            continue
        choice = best_choice(state, civ_id, reserve)
        if choice is not None:
            start(state, civ_id, *choice)


def options(
    state: GameState, civ_id: str, province_id: str, *, planning: bool = False
) -> list[tuple[Building, str | None]]:
    """Every kind of building with why it cannot go up here (None if it can), in order.

    ``planning``: whether it could be queued behind the building going up (D-128).
    """
    return [
        (kind, why_not(state, civ_id, province_id, kind.id, planning=planning))
        for kind in state.world.buildings.values()
    ]
