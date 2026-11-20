"""Colonies (R3, F1): Latin and citizen colonies founded by history or by the Senate's vote.

A colony is real: settlers drawn from Rome's population, a garrison, loyalty, growth, and the
province's owner flag (unowned land a colony is planted on becomes Roman). Default history
founds the colonies of ``colonies.yaml`` in their years (Livy's foundation notices and the
list in Velleius 1.14-15), unless the player's history diverged there: an enemy holds the
land, or a colony of the Senate's own already stands there. The Senate's ``colony:<province>``
proposal (``engine/senate.py`` sets ``republic.colonies[province]``) founds one the year it
passes: Latin until 180 BC (Luca, the last Latin colony: Velleius 1.15.2), a citizen colony
after. Colonies owed Rome men too: in 209 twelve of the thirty Latin colonies refused their
levy (Livy 27.9.7), so a colony whose loyalty is low refuses its levy.
"""

from __future__ import annotations

from anachronism.content.schema import RelationStatus
from anachronism.content.schema.italy import ColonyFoundation, ColonyKind
from anachronism.engine.allies import first_year_of_turn, italy_of, rules_of
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.italy_state import Colony
from anachronism.engine.rivals import at_war, status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState

SENATE_PREFIX = "senate_"


def _place(state: GameState, province_id: str) -> str:
    geo = state.world.geography.get(province_id)
    return geo.name.split(" (")[0] if geo is not None else province_id


def may_found(state: GameState, province_id: str) -> str | None:
    """Who holds the land: ``rome``, ``ally``, ``unowned``, or ``None`` for other hands."""
    province = state.provinces.get(province_id)
    if province is None:
        return None
    me = state.player_civ
    if province.owner == me:
        return "rome"
    if province.owner is None:
        return "unowned"
    if status(state, me, province.owner) is RelationStatus.ALLIED:
        return "ally"
    return None


def _draw_settlers(state: GameState, target: str, people: int) -> int:
    """Move ``people`` from Rome's provinces (pro rata, never a quarter of one) to the site."""
    me = state.player_civ
    pool = [p for p in state.owned_provinces(me) if p != target]
    total = sum(state.provinces[p].population for p in pool)
    if total <= 0 or people <= 0:
        return 0
    people = min(people, total // 4)
    moved = 0
    for pid in sorted(pool, key=lambda p: (-state.provinces[p].population, p)):
        province = state.provinces[pid]
        share = min(people * province.population // total, province.population // 4)
        province.population -= share
        moved += share
    biggest = max(pool, key=lambda p: (state.provinces[p].population, p))
    rest = min(people - moved, state.provinces[biggest].population // 4)
    state.provinces[biggest].population -= rest
    moved += rest
    state.provinces[target].population += moved
    return moved


def found(
    state: GameState,
    colony_id: str,
    name: str,
    province_id: str,
    kind: ColonyKind,
    year: int,
    settlers: int | None,
    events: EventLog | None,
    *,
    historical: bool,
) -> Colony | None:
    """Plant a colony; ``None`` if the land is in other hands or a colony of that id stands."""
    italy = italy_of(state)
    rules = rules_of(state)
    if colony_id in italy.colonies:
        return None
    holder = may_found(state, province_id)
    if holder is None:
        return None
    province = state.provinces[province_id]
    me = state.player_civ
    men = settlers or (rules.latin_settlers if kind is ColonyKind.LATIN else rules.citizen_settlers)
    if holder == "unowned":
        province.owner = me
        province.held_since = state.turn
        if province.people is None:
            province.people = me
    elif holder == "ally":
        owner = province.owner
        assert owner is not None
        treaty = italy.treaties.get(owner)
        if treaty is not None and not treaty.land_share:
            treaty.loyalty_bp = clamp(treaty.loyalty_bp - rules.colony_in_ally_land_bp, 0, BP)
    moved = _draw_settlers(state, province_id, men * rules.settler_families_bp // BP)
    province.garrison_bp = BP
    colony = Colony(
        id=colony_id,
        name=name,
        province=province_id,
        kind=kind,
        year=year,
        settlers=men,
        garrison=men * rules.colony_garrison_bp // BP,
        loyalty_bp=rules.colony_loyalty_bp,
        historical=historical,
    )
    italy.colonies[colony_id] = colony
    if events is not None:
        what = "Latin colony" if kind is ColonyKind.LATIN else "colony of Roman citizens"
        events.add(
            me,
            "colony",
            f"A {what} of {men:,} men is founded at {name}, in {_place(state, province_id)}"
            f" ({moved:,} people leave Roman land for it).",
            name,
        )
    return colony


def _foundations(state: GameState) -> list[ColonyFoundation]:
    return sorted(state.world.colonies.values(), key=lambda f: (f.year, f.id))


def start(state: GameState) -> None:
    """Colonies history had founded by the start stand where Rome or its allies hold the land."""
    italy = italy_of(state)
    rules = rules_of(state)
    for f in _foundations(state):
        if f.year > state.year or f.id in italy.colonies:
            continue
        if may_found(state, f.province) is None:
            continue
        men = f.settlers or (
            rules.latin_settlers if f.kind is ColonyKind.LATIN else rules.citizen_settlers
        )
        italy.colonies[f.id] = Colony(
            id=f.id,
            name=f.name,
            province=f.province,
            kind=f.kind,
            year=f.year,
            settlers=men,
            garrison=men * rules.colony_garrison_bp // BP,
            loyalty_bp=rules.colony_loyalty_bp,
            historical=True,
        )


def _history(state: GameState, events: EventLog, year: int) -> None:
    """The foundations of this year, unless history has turned there."""
    italy = italy_of(state)
    for f in _foundations(state):
        if f.year != year or f.id in italy.colonies or f.id in italy.lapsed:
            continue
        senates_own = SENATE_PREFIX + f.province in italy.colonies
        if (
            senates_own
            or found(
                state, f.id, f.name, f.province, f.kind, year, f.settlers, events, historical=True
            )
            is None
        ):
            italy.lapsed[f.id] = year


def _senates(state: GameState, events: EventLog, year: int) -> None:
    """Colonies the Senate resolved on (``republic.colonies``) and has not yet founded."""
    rep = state.republic
    assert rep is not None
    italy = italy_of(state)
    rules = rules_of(state)
    for pid in sorted(rep.colonies):
        cid = SENATE_PREFIX + pid
        if cid in italy.colonies:
            continue
        kind = ColonyKind.LATIN if year <= rules.latin_until_year else ColonyKind.CITIZEN
        found(state, cid, _place(state, pid), pid, kind, year, None, events, historical=False)


def _life(state: GameState, events: EventLog, year: int) -> None:
    """Colonies grow, follow Rome's fortunes, refuse their levy when disaffected, or fall."""
    italy = italy_of(state)
    rules = rules_of(state)
    me = state.player_civ
    wins = losses = 0
    if first_year_of_turn(state, year):
        wins = sum(1 for e in events.items if e.civ == me and e.kind == "battle_won")
        losses = sum(1 for e in events.items if e.civ == me and e.kind == "battle_lost")
    war = bool(at_war(state, me))
    refusing: list[str] = []
    for cid in sorted(italy.colonies):
        colony = italy.colonies[cid]
        if may_found(state, colony.province) is None:
            events.add(
                me,
                "colony_lost",
                f"The colony of {colony.name} is in enemy hands.",
                colony.name,
            )
            del italy.colonies[cid]
            continue
        colony.settlers += colony.settlers * rules.colony_growth_bp // BP
        colony.garrison = colony.settlers * rules.colony_garrison_bp // BP
        delta = wins * rules.victory_bp - losses * rules.defeat_bp
        delta += (rules.colony_loyalty_bp - colony.loyalty_bp) * rules.loyalty_drift_bp // BP
        colony.loyalty_bp = clamp(colony.loyalty_bp + delta, 0, BP)
        if war and colony.loyalty_bp < rules.colony_refusal_bp and first_year_of_turn(state, year):
            colony.refusals += 1
            refusing.append(colony.name)
    if refusing:
        events.add(
            me,
            "colony_refuses",
            f"Drained by the levies, {len(refusing)} colonies say they have neither men nor"
            f" money to give: {', '.join(refusing[:4])}{'...' if len(refusing) > 4 else ''}.",
        )


def run_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """One year of the colonies (``rng`` is unused: colonies draw no lots)."""
    del rng
    _history(state, events, year)
    _senates(state, events, year)
    _life(state, events, year)
