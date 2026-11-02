"""Religion and the state (R4, F1): priesthoods, auspices, prodigies, the Books, new cults.

The Romans acted on their gods' signs, so the engine does too. The colleges (pontifices,
augurs, the keepers of the Sibylline Books, the flamines, the Vestals) are filled from the
Republic's people and kept for life (``fill_priesthoods``). Before a battle of the player's
army the signs are taken (``auspices``): one ``GameRng`` draw whose odds the commander's piety
and the augurs shape, and the men's morale follows (Livy 22.3.11-14 on Flaminius before
Trasimene; Livy 22.42.8-9 on the chickens before Cannae; Suetonius, Tiberius 2.2 and Cicero,
De natura deorum 2.7 on Pulcher's chickens in 249 BC). Each year the prodigies the sources
date are reported and expiated at a cost in wealth, raising a ``sacrifice`` in the city; a
prodigy the treasury cannot expiate breeds unrest until it is. Disasters send the decemviri to
the Books (Livy 22.9.7-10, 29.10.4-6, 10.47.6-7), and new cults come on their dates, early if
the Books were opened within their window (Aesculapius 291, Venus Erycina 215, Magna Mater
204) or are put down (the Bacchanalia, 186: Livy 39.8-19).

Integers only; every loop in sorted order; randomness only through ``GameRng``.
"""

from __future__ import annotations

from anachronism.content.schema import Order
from anachronism.content.schema.rome_society import Priesthood, PriesthoodEra, Prodigy
from anachronism.engine.city_state import CityEvent
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.republic_state import Person, RepublicState
from anachronism.engine.rng import GameRng
from anachronism.engine.rome_society_state import (
    Auspice,
    Priest,
    ProdigyRecord,
    ReligionState,
    RomeSocietyState,
)
from anachronism.engine.state import Army, GameState
from anachronism.engine.tactics import commander

CO_OPT_NOISE = 1000
"""Weight every candidate for a priesthood has, so an unknown man can be chosen."""
CURULE_RANK = 2
"""Offices of this rank or above count as curule when the pontifex maximus is chosen."""


def year_label(year: int) -> str:
    """``-264`` -> ``264 BC``."""
    return f"{-year} BC" if year < 0 else f"AD {year}"


def _society(state: GameState) -> RomeSocietyState:
    assert state.rome_society is not None, "this game has no Roman society"
    return state.rome_society


def _rep(state: GameState) -> RepublicState:
    assert state.republic is not None, "this game is not a Republic scenario"
    return state.republic


def _family_weight(rep: RepublicState, gens: str, glory: int = 0) -> int:
    family = rep.families.get(gens)
    if family is None:
        return CO_OPT_NOISE
    standing = family.auctoritas_bp + family.dignitas_bp // 2 + family.clients // 2
    return CO_OPT_NOISE + standing + max(0, glory)


def _monument(state: GameState, mid: str | None, fallback: str | None) -> str:
    """A monument id the city knows, else the fallback, else nothing."""
    for candidate in (mid, fallback):
        if candidate and candidate in state.world.monuments:
            return candidate
    return ""


def _city_sacrifice(state: GameState, events: EventLog, year: int, ref: str, monument: str) -> None:
    if state.city is None:
        return
    state.city.events.append(
        CityEvent(kind="sacrifice", year=year, turn=events.turn, ref=ref, monument=monument)
    )


# ---------------------------------------------------------------- priesthoods


def holders(rel: ReligionState, priesthood: str) -> list[Priest]:
    """Who sits in a college now, in order of seniority."""
    return [p for p in rel.priests if p.priesthood == priesthood]


def priesthoods_of(state: GameState, person_id: str) -> list[str]:
    """The colleges a man belongs to."""
    society = state.rome_society
    if society is None:
        return []
    return sorted(p.priesthood for p in society.religion.priests if p.person == person_id)


def is_augur(state: GameState, person_id: str) -> bool:
    """True when the man sits in a college that takes the auspices."""
    colleges = state.world.rome_society.priesthoods
    return any(colleges[p].augural for p in priesthoods_of(state, person_id) if p in colleges)


def may_command(state: GameState, person_id: str) -> bool:
    """False for a priest who may not look on an army (the flamen Dialis)."""
    colleges = state.world.rome_society.priesthoods
    return not any(
        colleges[p].blocks_command for p in priesthoods_of(state, person_id) if p in colleges
    )


def fill_priesthoods(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """Dead priests leave their colleges; empty seats are filled by co-optation.

    Called each year from ``rome_society.run_year`` (the lead may call it from
    ``republic.run_year`` instead). The year's laws decide who may be chosen: patricians only
    before the Lex Ogulnia (Livy 10.6-9), then a fixed number of plebeian seats.
    """
    society = _society(state)
    rep = _rep(state)
    rel = society.religion
    colleges = state.world.rome_society.priesthoods
    kept: list[Priest] = []
    for priest in rel.priests:
        college = colleges.get(priest.priesthood)
        if college is None:
            continue
        if priest.person:
            person = rep.people.get(priest.person)
            if person is None or not person.alive:
                continue  # died: the seat is empty
        elif college.term_years is not None and year - priest.since >= college.term_years:
            continue  # a Vestal's thirty years are served
        kept.append(priest)
    rel.priests = kept
    taken = {p.person for p in rel.priests if p.person}
    for cid in sorted(colleges):
        college = colleges[cid]
        era = college.era_at(year)
        if era is None:
            continue
        seated = holders(rel, cid)
        while len(seated) < era.seats:
            new = _co_opt(state, rep, rng, college, era, seated, taken, year)
            if new is None:
                break
            rel.priests.append(new)
            seated.append(new)
            if new.person:
                taken.add(new.person)
                person = rep.people[new.person]
                person.glory += college.glory
                events.add(
                    state.player_civ,
                    "priesthood",
                    f"{person.name} is co-opted into the {college.name.lower()}.",
                    person.name,
                )
        if college.chief:
            _choose_chief(state, rep, rng, events, rel, cid, seated)
    rel.priests.sort(key=lambda p: (p.priesthood, p.since, p.person, p.name))


def _co_opt(
    state: GameState,
    rep: RepublicState,
    rng: GameRng,
    college: Priesthood,
    era: PriesthoodEra,
    seated: list[Priest],
    taken: set[str],
    year: int,
) -> Priest | None:
    gentes = state.world.gentes
    if college.women:  # a daughter of a family, named by her gens
        ids = [
            g
            for g in sorted(gentes)
            if not era.patricians_only or gentes[g].order is Order.PATRICIAN
        ]
        if not ids:
            return None
        weights = [_family_weight(rep, g) for g in ids]
        gens = gentes[ids[rng.weighted_index(weights)]]
        return Priest(
            priesthood=college.id, name=f"a daughter of the {gens.name}", gens=gens.id, since=year
        )
    plebs = sum(
        1 for p in seated if p.person in rep.people and rep.people[p.person].order is Order.PLEBEIAN
    )
    want: Order | None = None
    if era.patricians_only:
        want = Order.PATRICIAN
    elif era.plebeian_min - plebs >= era.seats - len(seated):
        want = Order.PLEBEIAN
    adult = state.world.republic_rules.adult_age

    def candidates(excluded: set[str]) -> list[Person]:
        return [
            rep.people[pid]
            for pid in sorted(rep.people)
            if rep.people[pid].alive
            and pid not in excluded
            and year - rep.people[pid].born >= adult
            and (want is None or rep.people[pid].order is want)
        ]

    pool = candidates(taken)
    if not pool:  # too few men free of a priesthood: one may sit in a second college
        pool = candidates({p.person for p in seated})
    if not pool:
        return None
    weights = [_family_weight(rep, p.gens, p.glory) for p in pool]
    chosen = pool[rng.weighted_index(weights)]
    return Priest(
        priesthood=college.id, person=chosen.id, name=chosen.name, gens=chosen.gens, since=year
    )


def _choose_chief(
    state: GameState,
    rep: RepublicState,
    rng: GameRng,
    events: EventLog,
    rel: ReligionState,
    college_id: str,
    seated: list[Priest],
) -> None:
    """The pontifex maximus: chosen by the people from the college when the seat is empty.

    Livy 25.5.2-4: the election of 212, won by a man who had held no curule office, the
    first such in 120 years; so the weights favour men who have held curule office.
    """
    chief = rep.people.get(rel.pontifex_maximus)
    if chief is not None and chief.alive and any(p.person == chief.id for p in seated):
        return
    men = [rep.people[p.person] for p in seated if p.person in rep.people]
    if not men:
        rel.pontifex_maximus = ""
        return
    mags = state.world.magistracies
    weights = [
        CO_OPT_NOISE
        + max(0, m.glory)
        + (
            2000
            if any(mags[h.office].rank >= CURULE_RANK for h in m.offices if h.office in mags)
            else 0
        )
        for m in men
    ]
    chosen = men[rng.weighted_index(weights)]
    rel.pontifex_maximus = chosen.id
    events.add(
        state.player_civ,
        "pontifex_maximus",
        f"{chosen.name} is chosen pontifex maximus.",
        chosen.name,
    )


# ---------------------------------------------------------------- auspices


def _person_named(rep: RepublicState, name: str) -> Person | None:
    for pid in sorted(rep.people):
        person = rep.people[pid]
        if person.alive and person.name == name:
            return person
    return None


def auspice_chance_bp(state: GameState, army: Army) -> int:
    """The odds the signs are favourable for this army's commander (bp, 500..9500)."""
    rules = state.world.rome_society.rites.auspices
    rep = state.republic
    chance = rules.base_bp
    if rep is not None and army.general:
        person = _person_named(rep, army.general)
        if person is not None:
            if rules.pious_trait in person.traits:
                chance += rules.pious_bp
            if rules.impious_trait in person.traits:
                chance += rules.impious_bp
            if is_augur(state, person.id):
                chance += rules.augur_bp
    colleges = state.world.rome_society.priesthoods
    society = state.rome_society
    if society is not None:
        for cid in sorted(colleges):
            college = colleges[cid]
            era = college.era_at(state.year)
            if college.augural and era is not None:
                filled = len(holders(society.religion, cid))
                chance += rules.college_bp * min(filled, era.seats) // era.seats
    return clamp(chance, 500, 9500)


def auspices(
    state: GameState,
    province_id: str,
    attackers: list[Army],
    defenders: list[Army],
    morale: list[int],
    rng: GameRng,
    events: EventLog,
) -> list[int]:
    """Take the auspices for the player's side(s) before a battle; returns the morale to use.

    The hook ``armies.battle`` calls (F1). Nothing happens outside the Republic, and the RNG
    is drawn only for a side the player commands, so other battles are unchanged.
    """
    society = state.rome_society
    if society is None or not state.world.rome_society.present:
        return morale
    rules = state.world.rome_society.rites.auspices
    out = list(morale)
    place = state.world.geography[province_id].name.split(" (")[0]
    for i, side in ((0, attackers), (1, defenders)):
        lead = commander(side)
        if lead.owner != state.player_civ or lead.garrison:
            continue
        chance = auspice_chance_bp(state, lead)
        favourable = rng.chance(chance)
        delta = rules.favourable_morale_bp if favourable else rules.unfavourable_morale_bp
        out[i] = clamp(out[i] + delta, 0, BP)
        who = lead.general or "the consul"
        signs = (
            "feed greedily and the men take heart"
            if favourable
            else "will not eat, and the men go into the line uneasy"
        )
        text = (
            f"Before the battle at {place} the auspices are taken for {who}: "
            f"the sacred chickens {signs}."
        )
        events.add(state.player_civ, "auspices", text, place)
        rel = society.religion
        rel.auspices.append(
            Auspice(
                turn=events.turn,
                year=state.year,
                army=lead.id,
                commander=lead.general,
                province=province_id,
                favourable=favourable,
                morale_bp=delta,
                chance_bp=chance,
            )
        )
        kept = state.world.rome_society.rites.kept_auspices
        del rel.auspices[:-kept]
    return out


# ---------------------------------------------------------------- prodigies and the Books


def books_open(state: GameState, year: int) -> bool:
    """True while the Sibylline Books exist to be consulted."""
    rules = state.world.rome_society.rites.sibylline
    if rules.lost_from_year is None:
        return True
    if year < rules.lost_from_year:
        return True
    return rules.restored_year is not None and year >= rules.restored_year


def prodigies_of_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """Report the year's prodigies and have the Senate order their expiation."""
    society = _society(state)
    rel = society.religion
    rules = state.world.rome_society.rites.prodigies
    listed = state.world.rome_society.prodigies
    if not listed:
        return
    dated = [listed[pid] for pid in sorted(listed) if listed[pid].year == year]
    drawn: list[tuple[Prodigy, bool]] = [(p, True) for p in dated]
    if not dated:
        undated = [listed[pid] for pid in sorted(listed) if listed[pid].year is None]
        if undated and rng.chance(rules.yearly_chance_bp):
            drawn.append((rng.pick(undated), False))
    civ = state.civs[state.player_civ]
    for prodigy, is_dated in drawn:
        cost = prodigy.cost or rules.default_cost
        paid = civ.stockpiles.wealth >= cost
        if paid:
            civ.stockpiles.wealth -= cost
            civ.stats.unrest_bp = clamp(
                civ.stats.unrest_bp - rules.expiation_unrest_relief_bp, 0, BP
            )
            _city_sacrifice(
                state,
                events,
                year,
                "expiation",
                _monument(state, prodigy.monument, rules.default_monument),
            )
        else:
            rel.unexpiated += 1
        rel.prodigies.append(
            ProdigyRecord(
                turn=events.turn,
                year=year,
                prodigy=prodigy.id,
                dated=is_dated,
                expiated=paid,
                cost=cost,
            )
        )
        del rel.prodigies[: -rules.kept]
        where = f" at {prodigy.place}" if prodigy.place else ""
        done = (
            prodigy.expiation
            if paid
            else "The treasury cannot pay for the rites, and the people are afraid."
        )
        events.add(
            state.player_civ,
            "prodigy",
            f"A prodigy{where}: {prodigy.sign} {done}",
            prodigy.place or "Rome",
        )
        if prodigy.sibylline and paid:
            rel.consultations.append(year)
        if prodigy.cult is not None and paid:
            introduce_cult(state, events, prodigy.cult, year)
    # the backlog: neglected rites are paid for as soon as the treasury can
    while rel.unexpiated and civ.stockpiles.wealth >= rules.default_cost:
        civ.stockpiles.wealth -= rules.default_cost
        rel.unexpiated -= 1
        _city_sacrifice(
            state, events, year, "expiation", _monument(state, None, rules.default_monument)
        )
    if rel.unexpiated:
        civ.stats.unrest_bp = clamp(
            civ.stats.unrest_bp + rel.unexpiated * rules.unexpiated_unrest_bp, 0, BP
        )


def consult_books(state: GameState, events: EventLog, year: int, cause: str) -> bool:
    """The decemviri open the Sibylline Books over a disaster. Returns True if they could.

    A lectisternium and supplicatio are held (Livy 5.13.5-6 for the first, 399 BC); unrest
    eases; and a cult the Books were to order within its window comes to Rome early.
    """
    society = _society(state)
    rel = society.religion
    rules = state.world.rome_society.rites.sibylline
    civ = state.civs[state.player_civ]
    if not books_open(state, year):
        if not rel.books_lost:
            rel.books_lost = True
            events.add(
                state.player_civ,
                "sibylline",
                "The Sibylline Books burned with the Capitol; there is nothing to consult.",
            )
        return False
    rel.books_lost = False
    if civ.stockpiles.wealth < rules.cost:
        return False
    civ.stockpiles.wealth -= rules.cost
    civ.stats.unrest_bp = clamp(civ.stats.unrest_bp - rules.unrest_relief_bp, 0, BP)
    civ.stats.legitimacy_bp = clamp(civ.stats.legitimacy_bp + rules.legitimacy_bp, 0, BP)
    rel.consultations.append(year)
    del rel.consultations[:-20]
    _city_sacrifice(state, events, year, "lectisternium", _monument(state, rules.monument, None))
    events.add(
        state.player_civ,
        "sibylline",
        f"After the {cause} the Senate bids the decemviri consult the Sibylline Books: "
        "a lectisternium is held and the people pray at every couch of the gods.",
    )
    for cid in sorted(state.world.rome_society.cults):
        cult = state.world.rome_society.cults[cid]
        ordered = cult.trigger == "sibylline" and cult.kind == "introduced"
        if ordered and cid not in rel.cults and cult.year - cult.window_years <= year < cult.year:
            introduce_cult(state, events, cid, year)
    return True


def disasters(state: GameState, events: EventLog) -> list[str]:
    """What struck the player's state this turn that would send the Senate to the Books."""
    rules = state.world.rome_society.rites.sibylline
    found: list[str] = []
    for item in events.items:
        if item.civ != state.player_civ or item.kind not in rules.consult_on:
            continue
        if item.kind == "battle_lost" and item.sides.get("decisive") != "1":
            continue
        found.append(
            item.subject.lower()
            if item.kind == "disaster" and item.subject
            else item.kind.replace("_", " ")
        )
    return found


# ---------------------------------------------------------------- cults


def introduce_cult(state: GameState, events: EventLog, cult_id: str, year: int) -> None:
    """A new god comes to Rome (or a rite is put down): recorded, told, and played in the city.

    The temple itself stands when the dataset says it does (``city.py``); here the sacrifice
    of the god's reception is played at it, and the people's mood moves.
    """
    society = _society(state)
    rel = society.religion
    cult = state.world.rome_society.cults.get(cult_id)
    if cult is None or cult_id in rel.cults:
        return
    rel.cults[cult_id] = year
    civ = state.civs[state.player_civ]
    civ.stats.unrest_bp = clamp(civ.stats.unrest_bp + cult.unrest_bp, 0, BP)
    civ.stats.legitimacy_bp = clamp(civ.stats.legitimacy_bp + cult.legitimacy_bp, 0, BP)
    if cult.kind == "introduced":
        _city_sacrifice(state, events, year, "cult", _monument(state, cult.monument, None))
        early = f", {cult.year - year} years before its time" if year < cult.year else ""
        text = f"The cult of {cult.name} is received at Rome{early}."
    else:
        text = f"The Senate puts down the {cult.name}."
    events.add(state.player_civ, "cult", text, cult.name)


def cults_of_year(state: GameState, events: EventLog, year: int) -> None:
    """Cults come (or are put down) on history's dates unless they already came early."""
    for cid in sorted(state.world.rome_society.cults):
        cult = state.world.rome_society.cults[cid]
        if cult.year == year:
            introduce_cult(state, events, cid, year)


# ---------------------------------------------------------------- the year


def start(state: GameState, rng: GameRng, events: EventLog) -> None:
    """Fill the colleges at the scenario's start; the cults already come are recorded."""
    society = _society(state)
    rel = society.religion
    for cid in sorted(state.world.rome_society.cults):
        cult = state.world.rome_society.cults[cid]
        if cult.year < state.year:
            rel.cults[cid] = cult.year
    fill_priesthoods(state, rng, events, state.year)
    rel.books_lost = not books_open(state, state.year)


def run_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """Religion's year: the colleges, the prodigies, the Books after disasters, the cults."""
    fill_priesthoods(state, rng, events, year)
    prodigies_of_year(state, rng, events, year)
    cults_of_year(state, events, year)
    if year == state.year:  # the turn's events are complete: disasters send the Senate to the Books
        struck = disasters(state, events)
        if struck:
            consult_books(state, events, year, struck[0])
