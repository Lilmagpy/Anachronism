"""Holding conquered land (D-106): conquered peoples remember their old lords.

Every province has a people. A province taken in war keeps its people, who may rise when
it has no garrison (an army of its rulers at least one man per hundred people), more often
when the realm is restless: they go back to their old state if it still stands, restore it
if it has fallen (twice as eagerly, D-113), or break free if it never existed. After some
generations (``assimilation_years``) a conquered people thinks of itself as its rulers' own.
"""

from __future__ import annotations

from anachronism.engine.dynasty import restore
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp
from anachronism.engine.rivals import add_grievance, alive
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState
from anachronism.engine.timeflow import per_turn


def garrisoned(state: GameState, province_id: str) -> bool:
    """True when the province's rulers keep enough soldiers there to hold it down."""
    province = state.provinces[province_id]
    need = province.population // state.world.rules.armies.garrison_people_per_man
    here = sum(
        a.men
        for a in state.armies.values()
        if a.province == province_id and a.owner == province.owner
    )
    return here >= max(1, need)


def restless(state: GameState, province_id: str) -> bool:
    """True for a conquered province whose people are not its rulers' own."""
    province = state.provinces[province_id]
    return province.owner is not None and province.people not in (None, province.owner)


def occupation(state: GameState, rng: GameRng, events: EventLog) -> None:
    """Conquered peoples assimilate in time - or rise while they can."""
    rules = state.world.rules.armies
    assimilate_turns = max(1, rules.assimilation_years // state.world.years_per_turn)
    for province_id in sorted(state.provinces):
        if not restless(state, province_id):
            continue
        province = state.provinces[province_id]
        owner = province.owner
        assert owner is not None
        old = province.people
        assert old is not None
        place = state.world.geography[province_id].name
        if state.turn - province.held_since >= assimilate_turns:
            province.people = owner
            events.add(
                owner,
                "assimilated",
                f"The people of {place} now think of themselves as {state.civs[owner].adjective}.",
                place,
            )
            continue
        if garrisoned(state, province_id) or state.civs[owner].capital == province_id:
            continue  # held down by soldiers, or by the court and its guards
        unrest = state.civs[owner].stats.unrest_bp
        chance = per_turn(state, rules.uprising_bp) * (BP + unrest) // BP
        fallen = old in state.civs and not alive(state, old)
        if fallen:  # a people rising to restore its own state (D-113)
            chance *= state.world.rules.society.restoration_uprising_x
        if not rng.chance(chance):
            continue
        rebel_name = state.civs[old].adjective if old in state.civs else "its own"
        province.population -= apply_bp(province.population, 300)  # the fighting
        if fallen:
            restore(state, old, province_id)
            add_grievance(state, old, owner, 1000)
            text = (
                f"{place} rises against {state.civs[owner].name}:"
                f" the {rebel_name} state is restored, its court seated there."
            )
            events.add(old, "restoration", text, place)
        elif old in state.civs and alive(state, old):
            province.owner = old
            province.held_since = state.turn
            add_grievance(state, old, owner, 1000)
            ruler = state.civs[owner].name
            text = f"{place} rises against {ruler} and returns to its {rebel_name} lords."
            events.add(old, "uprising_won", text, place)
        else:
            province.owner = None
            province.people = None
            text = f"{place} rises against {state.civs[owner].name} and throws off its rule."
        events.add(owner, "uprising", text, place)
