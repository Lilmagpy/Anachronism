"""Provinces and governors (R3, F1): tribute, extortion, prosecution, revolt, triumph-hunger.

From 227 BC, when the praetors were raised to four for Sicily and Sardinia (Livy, Periochae
20.7; Pomponius, Digest 1.2.2.32), a conquered overseas region Rome holds becomes a
*provincia* (``provinciae.yaml`` says which map provinces make one). Each year a governor is
drawn from the year's praetors (``state.republic.magistrates``); a province no praetor is left
for keeps last year's man prorogued (a propraetor), or takes a former magistrate from the
record. The province pays tribute to Rome, a share of its wealth (Sicily paid a tithe:
Cicero, Verrines 2.3, unverified). A governor may enrich himself from it: the draw moves the
sum from the tribute to his family's wealth and lowers the province's loyalty. From 149 BC
the lex Calpurnia set up the first standing court for extortion (L. Piso, tribune of the
plebs, under Censorinus and Manilius: Cicero, Brutus 106), so a governor who extorted may be
prosecuted when he lays down his province: an event the Senate view shows. A province whose
loyalty sinks may revolt and throw off Rome's rule. And a governor hungry for a triumph may
provoke a neighbour of his province: the neighbour's grievance against Rome grows (the hook
for the rivals' own decisions). Governors change yearly with the magistrates.
"""

from __future__ import annotations

from anachronism.content.schema import RelationStatus
from anachronism.content.schema.italy import ProvinciaDefinition
from anachronism.engine.allies import italy_of, rules_of
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.italy_state import Prosecution, Provincia
from anachronism.engine.republic_state import Magistrate, RepublicState
from anachronism.engine.rivals import add_grievance, alive, status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState

GOVERNOR_RANK = 4
"""Former magistrates of this rank or above may hold a province as pro-magistrates."""
REVOLT_LOSS_BP = 300


def _rep(state: GameState) -> RepublicState:
    assert state.republic is not None
    return state.republic


def held(state: GameState, definition: ProvinciaDefinition) -> list[str]:
    """The map provinces of a provincia that Rome holds, sorted."""
    me = state.player_civ
    return [
        p
        for p in sorted(definition.provinces)
        if p in state.provinces and state.provinces[p].owner == me
    ]


def people_of(state: GameState, provincia_id: str) -> int:
    """How many people live in the parts of a provincia Rome holds."""
    definition = state.world.provinciae.get(provincia_id)
    if definition is None:
        return 0
    return sum(state.provinces[p].population for p in held(state, definition))


def _create_and_remove(state: GameState, events: EventLog | None, year: int) -> None:
    italy = italy_of(state)
    rules = rules_of(state)
    me = state.player_civ
    for did in sorted(state.world.provinciae):
        definition = state.world.provinciae[did]
        owned = held(state, definition)
        ready = year >= max(rules.provinces_from_year, definition.from_year)
        if owned and did not in italy.provinciae and ready:
            italy.provinciae[did] = Provincia(
                id=did,
                name=definition.name,
                since=year,
                loyalty_bp=rules.province_baseline_loyalty_bp,
            )
            if events is not None:
                events.add(
                    me,
                    "provincia",
                    f"{definition.name} becomes a province of the Roman people, to be governed"
                    f" by a {definition.office}.",
                    definition.name,
                )
        elif not owned and did in italy.provinciae:
            del italy.provinciae[did]
            if events is not None:
                events.add(me, "provincia_lost", f"Rome holds no more of {definition.name}.")


def _alive(state: GameState, person_id: str) -> bool:
    person = _rep(state).people.get(person_id)
    return person is not None and person.alive


def assign_governors(
    state: GameState, rng: GameRng | None, events: EventLog | None, year: int
) -> None:
    """This year's praetors take the provinces; the rest keep their governors prorogued."""
    italy = italy_of(state)
    rep = _rep(state)
    taken: set[str] = set()
    for pid in sorted(italy.provinciae):
        provincia = italy.provinciae[pid]
        definition = state.world.provinciae[pid]
        fresh = sorted(
            (
                m
                for m in rep.magistrates
                if m.office == definition.office and m.year == year and m.person not in taken
            ),
            key=lambda m: m.person,
        )
        old = provincia.governor
        if fresh:
            chosen = fresh[0]
            _seat(provincia, chosen.person, chosen.name, definition.office, year, taken)
        elif old and _alive(state, old) and old not in taken:
            provincia.office = f"pro{definition.office}"
            taken.add(old)
        else:
            former = _former(state, taken, year)
            if former is not None:
                _seat(provincia, former.person, former.name, f"pro{former.office}", year, taken)
            else:
                provincia.governor = provincia.governor_name = provincia.office = ""
        if old and old != provincia.governor:
            _lay_down(state, provincia, old, rng, events, year)


def _seat(
    provincia: Provincia, person: str, name: str, office: str, year: int, taken: set[str]
) -> None:
    provincia.governor = person
    provincia.governor_name = name
    provincia.office = office
    provincia.governor_since = year
    taken.add(person)


def _former(state: GameState, taken: set[str], year: int) -> Magistrate | None:
    """The most recent former senior magistrate still alive and free for a province."""
    rep = _rep(state)
    mags = state.world.magistracies
    for m in sorted(rep.record, key=lambda m: (-m.year, m.person)):
        if m.person in taken or mags[m.office].rank < GOVERNOR_RANK or m.year >= year:
            continue
        if _alive(state, m.person):
            return m
    return None


def _lay_down(
    state: GameState,
    provincia: Provincia,
    old: str,
    rng: GameRng | None,
    events: EventLog | None,
    year: int,
) -> None:
    """A governor leaves his province: if he extorted, from 149 he may be prosecuted."""
    italy = italy_of(state)
    rules = rules_of(state)
    rep = _rep(state)
    amount = provincia.extorted
    provincia.extorted = 0
    if amount <= 0 or year < rules.lex_calpurnia_year or rng is None:
        return
    if not rng.chance(rules.prosecution_chance_bp):
        return
    convicted = rng.chance(rules.conviction_bp)
    person = rep.people.get(old)
    name = person.name if person is not None else old
    italy.prosecutions.append(
        Prosecution(
            year=year,
            provincia=provincia.id,
            governor=old,
            name=name,
            amount=amount,
            convicted=convicted,
        )
    )
    provincia.prosecutions += 1
    if convicted:
        if person is not None:
            person.glory = max(0, person.glory - rules.prosecution_glory)
            family = rep.families.get(person.gens)
            if family is not None:
                family.wealth = max(0, family.wealth - amount // rules.wealth_per_talent)
        provincia.loyalty_bp = clamp(provincia.loyalty_bp + rules.extortion_loyalty_bp, 0, BP)
        verdict = "is condemned and makes restitution"
    else:
        verdict = "is acquitted"
    if events is not None:
        events.add(
            state.player_civ,
            "repetundae",
            f"{name}, lately governor of {provincia.name}, is tried for extortion under the lex"
            f" Calpurnia and {verdict}.",
            name,
        )


def _tribute(state: GameState, rng: GameRng, events: EventLog) -> None:
    """Each province pays; a governor may take his cut; loyalty wears and drifts."""
    italy = italy_of(state)
    rules = rules_of(state)
    rep = _rep(state)
    me = state.player_civ
    civ = state.civs[me]
    for pid in sorted(italy.provinciae):
        provincia = italy.provinciae[pid]
        tribute = people_of(state, pid) // 1000 * rules.tribute_per_1000
        delta = -rules.tribute_loyalty_bp if tribute else 0
        if provincia.governor and tribute and rng.chance(rules.extortion_chance_bp):
            taken = tribute * rules.extortion_share_bp // BP
            tribute -= taken
            provincia.extorted += taken
            provincia.extorted_total += taken
            delta -= rules.extortion_loyalty_bp
            person = rep.people.get(provincia.governor)
            family = rep.families.get(person.gens) if person is not None else None
            if family is not None:
                family.wealth += taken // rules.wealth_per_talent
            events.add(
                me,
                "extortion",
                f"{provincia.governor_name} squeezes {provincia.name}: {taken:,} wealth goes to"
                " his own house instead of the treasury.",
                provincia.governor_name,
            )
        civ.stockpiles.wealth += tribute
        provincia.tribute = tribute
        delta += (
            (rules.province_baseline_loyalty_bp - provincia.loyalty_bp)
            * rules.province_drift_bp
            // BP
        )
        provincia.loyalty_bp = clamp(provincia.loyalty_bp + delta, 0, BP)


def _revolts(state: GameState, rng: GameRng, events: EventLog) -> None:
    """A disaffected province may throw off Rome's rule (its largest part goes unowned)."""
    italy = italy_of(state)
    rules = rules_of(state)
    me = state.player_civ
    for pid in sorted(italy.provinciae):
        provincia = italy.provinciae[pid]
        if provincia.loyalty_bp >= rules.revolt_loyalty_bp:
            continue
        if not rng.chance(rules.revolt_chance_bp):
            continue
        owned = held(state, state.world.provinciae[pid])
        if not owned:
            continue
        lost = max(owned, key=lambda p: (state.provinces[p].population, p))
        province = state.provinces[lost]
        province.owner = None
        province.population -= province.population * REVOLT_LOSS_BP // BP
        province.held_since = state.turn
        provincia.revolts += 1
        provincia.loyalty_bp = rules.province_baseline_loyalty_bp
        place = state.world.geography[lost].name
        events.add(
            me,
            "province_revolt",
            f"{place} rises against its governor and throws off Rome's rule.",
            place,
        )


def _neighbours(state: GameState, provincia_id: str) -> list[str]:
    """Civs whose land touches a provincia and are neither Rome's enemies nor its friends."""
    me = state.player_civ
    definition = state.world.provinciae[provincia_id]
    found: set[str] = set()
    for pid in held(state, definition):
        for other in state.world.geography[pid].neighbours:
            owner = state.provinces[other].owner if other in state.provinces else None
            if owner is None or owner == me or not alive(state, owner):
                continue
            now = status(state, me, owner)
            if now in (None, RelationStatus.WAR, RelationStatus.ALLIED, RelationStatus.TRIBUTARY):
                continue
            found.add(owner)
    return sorted(found)


def _triumph_hunger(state: GameState, rng: GameRng, events: EventLog) -> None:
    """A governor provokes a neighbour for the sake of a triumph: a grievance the rivals act on."""
    italy = italy_of(state)
    rules = rules_of(state)
    me = state.player_civ
    for pid in sorted(italy.provinciae):
        provincia = italy.provinciae[pid]
        if not provincia.governor:
            continue
        others = _neighbours(state, pid)
        if not others or not rng.chance(rules.triumph_hunger_bp):
            continue
        target = others[0]
        add_grievance(state, target, me, rules.triumph_hunger_grievance_bp)
        events.add(
            me,
            "triumph_hunger",
            f"{provincia.governor_name}, governor of {provincia.name}, raids the"
            f" {state.civs[target].adjective} border for the sake of a triumph;"
            f" the {state.civs[target].adjective} court takes it ill.",
            target,
        )


def start(state: GameState) -> None:
    """Provinces Rome already holds at the start, with this year's governors."""
    _create_and_remove(state, None, state.year)
    assign_governors(state, None, None, state.year)


def run_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """One year of the provinces: new ones, governors, tribute, revolts, hunger for triumphs."""
    _create_and_remove(state, events, year)
    assign_governors(state, rng, events, year)
    _tribute(state, rng, events)
    _revolts(state, rng, events)
    _triumph_hunger(state, rng, events)
