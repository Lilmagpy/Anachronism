"""How the Roman Republic governs itself (R2): elections, offices, people, Senate.

Each year two consuls (or consular tribunes, or whatever the year's law says) are chosen from
the living men of the great families. The choice is a weighted draw on ``engine.rng``: the
weights are the candidate's family standing, his glory, his family's wealth, the strength of
his faction and the player's backing. In a chronicle the Fasti decide, unless the player's
changes have removed or replaced a historical holder. The player never commands: he persuades
families and backs candidates with the influence he has won.

All numbers are integers; every loop runs in sorted-id order; randomness is only ``GameRng``.

The rules of the year (F1), in the order they run:

1. Terms end; senior offices go to the record.
2. Life: a death draw for everyone (the age table in ``republic_rules``); in a chronicle a real
   person dies in his real year (``died``) and not before his last known year; the families
   have sons in proportion to their standing (none after ``extinct_after``), named from the
   branches alive in the year and never with the name of a living man or of a modelled person.
3. Standing fades towards its base; influence grows.
4. The magistrates. In a chronicle the Fasti seat the year's holders (a man named only by name
   is the earlier namesake while that man would be under ``namesake_max_age``, else a new man
   of the family), a gap year (the anarchy, a dictator year) seats no curule magistrate, and a
   modelled person's recorded lower offices (praetor, tribune...) are honoured too. The rest is
   elected office by office in rank order, by weighted draw among the eligible: the laws of
   the year (orders, the cursus, the Lex Villia ages, ``max_office_age``), one office per man
   per year. A dictator is named in an emergency, never in a year the Fasti cover.
5. The census when censors take office.

The Senate (``senate_vote``) weighs each family by its standing and by its living senators
(members who have held office) and adds to its stance the lean of the bloc it belongs to in
the year (orders until 287, the nobility, optimates and populares from 133).
"""

from __future__ import annotations

from dataclasses import dataclass

from anachronism.content.schema import (
    Faction,
    FastiYear,
    Gens,
    HistoricalPerson,
    Issue,
    Magistracy,
    MagistracyEra,
    Order,
    RepublicRules,
)
from anachronism.engine import city as city_module
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP
from anachronism.engine.republic_state import (
    Backing,
    CensusRecord,
    Family,
    Held,
    Magistrate,
    Person,
    RepublicState,
)
from anachronism.engine.rivals import at_war
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState

ISSUE_ORDER = tuple(Issue)
POPULIST_LEAN_BP = 5000
FAVOUR_FADE_BP = 3000
EMERGENCY_FADE_BP = 5000
EMERGENCY_PER_WAR_BP = 3500
RECORD_RANK = 4
"""Offices of this rank or above are kept in the game's own Fasti."""


# ---------------------------------------------------------------- helpers


def year_label(year: int) -> str:
    """``-264`` -> ``264 BC``."""
    return f"{-year} BC" if year < 0 else f"AD {year}"


def _rep(state: GameState) -> RepublicState:
    assert state.republic is not None, "this game is not a Republic scenario"
    return state.republic


def _age(person: Person, year: int) -> int:
    return year - person.born


def death_bp(rules: RepublicRules, age: int) -> int:
    """Chance in a year of dying at this age."""
    bp = 0
    for from_age, chance in rules.death_bp_by_age:
        if age >= from_age:
            bp = chance
    return bp


def family_weight(family: Family) -> int:
    """How much a family counts in the Senate: its auctoritas, dignitas and clients."""
    return max(1, family.auctoritas_bp + family.dignitas_bp // 2 + family.clients // 2)


def senators_by_family(rep: RepublicState) -> dict[str, int]:
    """Living members of each family who have held an office (its men in the Senate)."""
    counts: dict[str, int] = {}
    for pid in sorted(rep.people):
        person = rep.people[pid]
        if person.alive and person.offices:
            counts[person.gens] = counts.get(person.gens, 0) + 1
    return counts


def senate_weights(state: GameState) -> dict[str, int]:
    """Each family's weight in a vote: its standing, raised by its living senators."""
    rep = _rep(state)
    bonus = state.world.republic_rules.senator_weight_bp
    senators = senators_by_family(rep)
    return {
        fid: family_weight(rep.families[fid]) * (BP + senators.get(fid, 0) * bonus) // BP
        for fid in sorted(rep.families)
    }


def _lean_popular(gens: Gens) -> bool:
    return gens.popular_lean_bp >= POPULIST_LEAN_BP


def _person_popular(state: GameState, person: Person) -> bool:
    if person.popular is not None:
        return person.popular
    return _lean_popular(state.world.gentes[person.gens])


def _in_faction(faction: Faction, order: Order, popular: bool) -> bool:
    if faction.order is not None and faction.order != order:
        return False
    return faction.populist is None or faction.populist == popular


def factions_at(state: GameState, year: int) -> list[Faction]:
    """The blocs of the Senate in a year (one nameless bloc if the content lists none)."""
    found = [f for f in state.world.republic_rules.factions if f.covers(year)]
    return found or [Faction(id="senate", name="The Senate", from_year=year)]


def faction_of(state: GameState, order: Order, popular: bool, year: int) -> str:
    """The id of the bloc a family of this order and lean belongs to."""
    for faction in factions_at(state, year):
        if _in_faction(faction, order, popular):
            return faction.id
    return ""


def faction_shares(state: GameState, year: int) -> dict[str, int]:
    """Each bloc's share of the Senate's weight, in basis points."""
    rep = _rep(state)
    weights: dict[str, int] = {}
    total = 0
    for gid in sorted(rep.families):
        gens = state.world.gentes[gid]
        weight = family_weight(rep.families[gid])
        fid = faction_of(state, gens.order, _lean_popular(gens), year)
        weights[fid] = weights.get(fid, 0) + weight
        total += weight
    return {fid: w * BP // total for fid, w in sorted(weights.items())} if total else {}


# ---------------------------------------------------------------- people


def _new_id(rep: RepublicState) -> str:
    rep.next_person += 1
    return f"p{rep.next_person - 1:05d}"


def _spawn_historical(
    state: GameState, rep: RepublicState, hp: HistoricalPerson, year: int, force: bool = False
) -> Person:
    """Bring a real person into the game."""
    rules = state.world.republic_rules
    gens = state.world.gentes[hp.gens]
    born = hp.birth_year(rules.age_at_first_listed_office)
    if force:
        first = min((h.year for h in hp.offices), default=year)
        born = min(born, min(first, year) - rules.pre_villia_min_age)
    past = [Held(office=h.office, year=h.year) for h in hp.offices if h.year < year]
    future = [Held(office=h.office, year=h.year) for h in hp.offices if h.year >= year]
    last = hp.last_known_alive if hp.last_known_alive is not None else year
    person = Person(
        id=hp.id,
        name=hp.name,
        gens=hp.gens,
        order=hp.order or gens.order,
        born=born,
        historical=True,
        content_id=hp.id,
        traits=list(hp.traits),
        popular=hp.popular,
        glory=sum(state.world.magistracies[h.office].glory for h in past),
        offices=past,
        future=future,
        protected_until=max(last, year),
        history_died=hp.died,
    )
    rep.people[hp.id] = person
    return person


def _taken_names(state: GameState, rep: RepublicState, born: int) -> set[str]:
    """Names no generated man may carry.

    Every living man's, every modelled person's, and every name the Fasti will give to a man
    of his generation (so the game's Marcus Fabius Licinus is not mistaken for the consul of 246).
    """
    names = {p.name for p in rep.people.values() if p.alive}
    names.update(hp.name for hp in state.world.people.values())
    for year in range(born, born + 80):
        entry = state.world.fasti.get(year)
        if entry is None:
            continue
        for college in entry.colleges:
            names.update(h.name for h in college.holders if h.name)
    return names


def _name_man(state: GameState, rep: RepublicState, rng: GameRng, gens: Gens, born: int) -> str:
    """A name from the family's praenomina and the branches alive in ``born``, not yet in use.

    A generated namesake must never duplicate a living man or a modelled person (a second
    "Lucius Iunius Brutus" would be re-elected as if the first had come back). When every
    combination is in use the man is "Minor", the younger.
    """
    rules = state.world.republic_rules
    firsts = list(gens.praenomina or rules.default_praenomina)
    cognomina = list(gens.cognomina_at(born))
    taken = _taken_names(state, rep, born)
    combos = [(f, c) for f in firsts for c in (cognomina or [""])]
    rng.shuffle(combos)
    for first, cognomen in combos:
        name = " ".join(part for part in (first, gens.nomen, cognomen) if part)
        if name not in taken:
            return name
    first, cognomen = combos[0] if combos else ("", "")
    base = " ".join(part for part in (first, gens.nomen, cognomen) if part)
    for suffix in ("Minor", "Nepos", "Tertius", "Quartus", "Quintus", "Sextus"):
        if f"{base} {suffix}" not in taken:
            return f"{base} {suffix}"
    return f"{base} {rep.next_person}"


def _spawn_man(
    state: GameState,
    rep: RepublicState,
    rng: GameRng,
    gens: Gens,
    born: int,
    name_note: str = "",
) -> Person:
    """A man of a family, born in ``born`` (a child of the game or a new man)."""
    person = Person(
        id=_new_id(rep),
        name=_name_man(state, rep, rng, gens, born),
        gens=gens.id,
        order=gens.order,
        born=born,
        traits=[name_note] if name_note else [],
    )
    rep.people[person.id] = person
    return person


def _holds(person: Person, office: str, before: int) -> bool:
    return any(h.office == office and h.year < before for h in person.offices)


def _last_year(state: GameState, person: Person, office: str | None, before: int) -> int | None:
    """The latest year before ``before`` he held ``office`` (or any cursus office)."""
    years = [
        h.year
        for h in person.offices
        if h.year < before
        and (
            h.office == office if office is not None else state.world.magistracies[h.office].cursus
        )
    ]
    return max(years) if years else None


def eligible(
    state: GameState, person: Person, mag: Magistracy, era: MagistracyEra, year: int
) -> bool:
    """May this man stand for this office in this year (offices already taken aside)?"""
    rules = state.world.republic_rules
    if not person.alive or year - person.born < rules.adult_age:
        return False
    least = era.min_age
    if least is None:
        least = rules.pre_villia_min_age if mag.cursus else rules.adult_age
    if _age(person, year) < least or _age(person, year) > rules.max_office_age:
        return False
    if era.patricians_only and person.order is not Order.PATRICIAN:
        return False
    if era.plebeians_only and person.order is not Order.PLEBEIAN:
        return False
    if era.interval_years and mag.cursus:
        last = _last_year(state, person, None, year)
        if last is not None and year - last <= era.interval_years:
            return False
    if era.reelect_gap_years:
        same = _last_year(state, person, mag.id, year)
        if same is not None and year - same < era.reelect_gap_years:
            return False
    return not (era.prior_office and not _holds(person, era.prior_office, year))


def _eligible_ignoring_prior(
    state: GameState, person: Person, mag: Magistracy, era: MagistracyEra, year: int
) -> bool:
    relaxed = era.model_copy(update={"prior_office": None})
    return eligible(state, person, mag, relaxed, year)


# ---------------------------------------------------------------- starting


def start_republic(state: GameState, rng: GameRng) -> None:
    """Create the Republic's state at the scenario's start year and hold its first election."""
    rules = state.world.republic_rules
    rep = RepublicState(influence=rules.influence_income * 3)
    state.republic = rep
    for gid in sorted(state.world.gentes):
        standing = state.world.gentes[gid].standing_at(state.year)
        rep.families[gid] = Family(
            id=gid,
            dignitas_bp=standing.dignitas_bp,
            auctoritas_bp=standing.auctoritas_bp,
            wealth=standing.wealth,
            clients=standing.clients,
            base_dignitas_bp=standing.dignitas_bp,
        )
    for pid in sorted(state.world.people):
        hp = state.world.people[pid]
        born = hp.birth_year(rules.age_at_first_listed_office)
        if born <= state.year and (hp.died is None or hp.died >= state.year):
            _spawn_historical(state, rep, hp, state.year)
    _seed_population(state, rep, rng, state.year)
    events = EventLog(turn=state.turn, year=state.year)
    _hold_year(state, rep, rng, events, state.year)
    _deaths_in_office(state, rep, events, state.year)  # Brutus falls in 509 itself
    city_module.start_city(state, events.turn)
    state.events.extend(events.items)


SEED_YEARS = 65
"""How far back the families' living men are generated at the start of a game."""
SEED_CAREER_BP = (("quaestor", 30, 5000), ("aedile_curule", 36, 2500), ("praetor", 39, 2500))
"""Offices a seeded man may already have held: (office, age, chance in bp given the one
before), so the cursus has men of the proper career from the first election."""


def _seed_population(state: GameState, rep: RepublicState, rng: GameRng, year: int) -> None:
    """The families' living men at the start: the sons of the last sixty-five years who lived.

    Without them the first elections would find only the modelled persons and fill every
    praetorship with new men. Each year back, each family has a son with its usual chance,
    and he faces the death table year by year to the start; a survivor of thirty or more may
    already have climbed the first steps of the cursus.
    """
    rules = state.world.republic_rules
    mags = state.world.magistracies
    for gid in sorted(state.world.gentes):
        gens = state.world.gentes[gid]
        family = rep.families.get(gid)
        for born in range(year - SEED_YEARS, year):
            if not gens.alive_in(born) or not rng.chance(_birth_bp(rules, family)):
                continue
            if any(rng.chance(death_bp(rules, age)) for age in range(year - born)):
                continue
            man = _spawn_man(state, rep, rng, gens, born)
            for office, age, chance in SEED_CAREER_BP:
                held_year = born + age
                mag = mags.get(office)
                era = mag.era_at(held_year) if mag is not None else None
                if held_year >= year or era is None or not rng.chance(chance):
                    break
                if (era.patricians_only and man.order is not Order.PATRICIAN) or (
                    era.plebeians_only and man.order is not Order.PLEBEIAN
                ):
                    break
                man.offices.append(Held(office=office, year=held_year))
                man.glory += mag.glory if mag is not None else 0


def run_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """Move the Republic into ``year``: the old college's term ends, a new one is chosen."""
    rep = _rep(state)
    _close_year(state, rep, events, year)
    _life(state, rep, rng, events, year)
    _fade(state, rep, year)
    _hold_year(state, rep, rng, events, year)
    _deaths_in_office(state, rep, events, year)
    city_module.run_year(state, events, year)


# ---------------------------------------------------------------- the year


def _close_year(state: GameState, rep: RepublicState, events: EventLog, year: int) -> None:
    """Terms that have ended leave office; senior offices go into the record."""
    keep: list[Magistrate] = []
    for m in rep.magistrates:
        mag = state.world.magistracies[m.office]
        if m.ends_year >= year:
            keep.append(m)
            continue
        if mag.rank >= RECORD_RANK:
            rep.record.append(m)
        if m.appointed and m.term_months < 12:
            events.add(
                state.player_civ,
                "term_ended",
                f"{m.name} lays down the {mag.name.lower()} after {m.term_months} months.",
                m.name,
            )
    rep.magistrates = keep


def _life(state: GameState, rep: RepublicState, rng: GameRng, events: EventLog, year: int) -> None:
    """Deaths, births and real persons coming of age, for the year just begun."""
    rules = state.world.republic_rules
    for pid in sorted(rep.people):
        person = rep.people[pid]
        if not person.alive:
            continue
        roll = rng.chance(death_bp(rules, _age(person, year)))
        dies = roll
        if state.chronicle_mode and person.protected_until is not None:
            if person.history_died is not None:
                dies = person.history_died == year  # a chronicle keeps to the real death
                if dies and any(h.year == year for h in person.future):
                    dies = False  # he held office that year (Caesar in 44): he dies in it
            else:
                dies = roll and year > person.protected_until
        if dies:
            _die(state, rep, person, year, events)
    for gid in sorted(state.world.gentes):
        gens = state.world.gentes[gid]
        if gens.alive_in(year) and rng.chance(_birth_bp(rules, rep.families.get(gid))):
            _spawn_man(state, rep, rng, gens, year)
    for hid in sorted(state.world.people):
        hp = state.world.people[hid]
        if hid in rep.people:
            continue
        if hp.birth_year(rules.age_at_first_listed_office) == year:
            _spawn_historical(state, rep, hp, year)
    # the dead who held no great office are forgotten; the rest stay in the books
    for pid in sorted(rep.people):
        person = rep.people[pid]
        gone = not person.alive and person.died is not None and year - person.died > 40
        if gone and not person.offices and not person.historical:
            del rep.people[pid]


def _birth_bp(rules: RepublicRules, family: Family | None) -> int:
    """A family's chance of a son this year: the base rate scaled by its dignitas.

    Within a quarter and two and a half times the base, so the great houses have the men.
    """
    if family is None:
        return rules.births_per_gens_per_year_bp
    scaled = (
        rules.births_per_gens_per_year_bp
        * family.dignitas_bp
        // max(1, rules.birth_reference_dignitas_bp)
    )
    low = rules.births_per_gens_per_year_bp // 4
    high = rules.births_per_gens_per_year_bp * 5 // 2
    return min(BP, max(low, min(high, scaled)))


DEATH_TEXT = {
    "battle": "{name} falls in battle.",
    "murdered": "{name} is murdered.",
    "killed": "{name} is killed.",
    "executed": "{name} is put to death.",
    "proscribed": "{name} is proscribed and killed.",
    "suicide": "{name} dies by his own hand.",
    "illness": "{name} dies of illness.",
    "natural": "{name} dies, full of years.",
}


def _deaths_in_office(state: GameState, rep: RepublicState, events: EventLog, year: int) -> None:
    """A real person who died in a year he held office dies after taking it.

    Caesar in 44, Hirtius and Pansa in 43: the seat falls to the suffect the Fasti name, or
    stays empty.
    """
    if not state.chronicle_mode:
        return
    for pid in sorted(rep.people):
        person = rep.people[pid]
        if person.alive and person.history_died == year:
            _die(state, rep, person, year, events, keep_office=True)


def _die(
    state: GameState,
    rep: RepublicState,
    person: Person,
    year: int,
    events: EventLog | None,
    *,
    keep_office: bool = False,
) -> None:
    """He dies; his seats fall vacant.

    Unless ``keep_office``: he died in office at the end of his year, and the year's list and
    the record keep him.
    """
    person.alive = False
    person.died = year
    if not keep_office:
        rep.magistrates = [m for m in rep.magistrates if m.person != person.id]
    if person.offices and events is not None:
        cause = ""
        if state.chronicle_mode and person.history_died == year:
            hp = state.world.people.get(person.content_id)
            cause = hp.died_of if hp is not None else ""
        text = DEATH_TEXT.get(cause, "{name} dies.").format(name=person.name)
        events.add(state.player_civ, "death", text, person.name)


def kill_person(state: GameState, person_id: str, events: EventLog | None = None) -> bool:
    """A man dies by the game's doing (a battle, a plot). Returns False if he was not alive."""
    rep = _rep(state)
    person = rep.people.get(person_id)
    if person is None or not person.alive:
        return False
    _die(state, rep, person, state.year, events)
    if person.historical:
        rep.diverged = True
    return True


def award_glory(state: GameState, person_id: str, amount: int) -> None:
    """Military or civic glory (a triumph, a victory) for a man; his family's dignitas follows."""
    rep = _rep(state)
    person = rep.people.get(person_id)
    if person is None or not person.alive:
        return
    person.glory += amount
    family = rep.families.get(person.gens)
    if family is not None:
        family.dignitas_bp += amount // 10


def declare_emergency(state: GameState, bp: int) -> None:
    """A threat (a defeat, an invasion) raises the call for a dictator."""
    rep = _rep(state)
    rep.extra_emergency_bp = min(BP, rep.extra_emergency_bp + bp)


def _fade(state: GameState, rep: RepublicState, year: int) -> None:
    rules = state.world.republic_rules
    for fid in sorted(rep.families):
        family = rep.families[fid]
        over = family.dignitas_bp - family.base_dignitas_bp
        family.dignitas_bp -= over * rules.dignitas_decay_bp // BP
        for issue in sorted(family.favour):
            family.favour[issue] -= family.favour[issue] * FAVOUR_FADE_BP // BP
    rep.extra_emergency_bp -= rep.extra_emergency_bp * EMERGENCY_FADE_BP // BP
    rep.influence += rules.influence_income
    rep.backing = [b for b in rep.backing if b.year >= year]


def _emergency(state: GameState, rep: RepublicState) -> int:
    wars = len(at_war(state, state.player_civ))
    rep.emergency_bp = min(BP, wars * EMERGENCY_PER_WAR_BP + rep.extra_emergency_bp)
    return rep.emergency_bp


# ---------------------------------------------------------------- elections


def _weight(
    state: GameState,
    rep: RepublicState,
    person: Person,
    office: str,
    year: int,
    shares: dict[str, int],
) -> int:
    rules = state.world.republic_rules
    family = rep.families.get(person.gens)
    standing = (family.dignitas_bp + family.auctoritas_bp) // 2 if family else 0
    wealth = family.wealth * rules.wealth_weight_bp // 1000 if family else 0
    glory = person.glory * rules.glory_weight_bp // 1000
    fid = faction_of(state, person.order, _person_popular(state, person), year)
    bloc = shares.get(fid, 0) * rules.faction_weight_bp // BP
    backed = sum(
        rules.backing_bp
        for b in rep.backing
        if b.person == person.id and b.office == office and b.year == year
    )
    return max(1, rules.election_noise + standing + wealth + glory + bloc + backed)


def _take(
    state: GameState,
    rep: RepublicState,
    person: Person,
    mag: Magistracy,
    era: MagistracyEra,
    year: int,
    *,
    suffect: bool = False,
    by_fasti: bool = False,
    master: str = "",
) -> Magistrate:
    """Put a man in office: record it, add glory and the family's dignitas."""
    m = Magistrate(
        office=mag.id,
        person=person.id,
        name=person.name,
        year=year,
        ends_year=year + (era.term_months - 1) // 12,
        term_months=era.term_months,
        suffect=suffect,
        appointed=era.appointed,
        by_fasti=by_fasti,
        master=master,
    )
    rep.magistrates.append(m)
    person.offices.append(Held(office=mag.id, year=year, suffect=suffect))
    person.future = [h for h in person.future if not (h.office == mag.id and h.year == year)]
    person.glory += mag.glory
    family = rep.families.get(person.gens)
    if family is not None:
        family.dignitas_bp += mag.glory * state.world.republic_rules.office_dignitas_share_bp // BP
    return m


def _choose(
    state: GameState,
    rep: RepublicState,
    rng: GameRng,
    events: EventLog,
    mag: Magistracy,
    era: MagistracyEra,
    year: int,
    seats: int,
    taken: set[str],
    shares: dict[str, int],
    already: list[Person] | None = None,
) -> list[Person]:
    """Elect ``seats`` men to an office by weighted draw, within the year's laws."""
    chosen: list[Person] = list(already or [])
    adults = [
        rep.people[pid] for pid in sorted(rep.people) if rep.people[pid].alive and pid not in taken
    ]
    target = len(chosen) + seats
    while len(chosen) < target:
        plebs = sum(p.order is Order.PLEBEIAN for p in chosen)
        remaining = target - len(chosen)
        want: Order | None = None
        if era.plebeian_min - plebs >= remaining:
            want = Order.PLEBEIAN
        elif era.plebeian_max is not None and plebs >= era.plebeian_max:
            want = Order.PATRICIAN
        chosen_ids = {p.id for p in chosen}
        pool = [
            p
            for p in adults
            if p.id not in chosen_ids
            and (want is None or p.order is want)
            and eligible(state, p, mag, era, year)
        ]
        if not pool:  # nobody has the career the law asks: take the best of the rest
            pool = [
                p
                for p in adults
                if p.id not in chosen_ids
                and (want is None or p.order is want)
                and _eligible_ignoring_prior(state, p, mag, era, year)
            ]
        if pool:
            weights = [_weight(state, rep, p, mag.id, year, shares) for p in pool]
            chosen.append(pool[rng.weighted_index(weights)])
        else:
            novus = _new_man(state, rep, rng, events, mag, era, year, want)
            if novus is None:
                break
            adults.append(novus)
            chosen.append(novus)
    return chosen


def _new_man(
    state: GameState,
    rep: RepublicState,
    rng: GameRng,
    events: EventLog,
    mag: Magistracy,
    era: MagistracyEra,
    year: int,
    want: Order | None,
) -> Person | None:
    """When no eligible man stands, a family puts forward a new one (a novus homo)."""
    rules = state.world.republic_rules
    if not rules.spawn_new_men:
        return None
    orders = {want} if want else None
    if era.patricians_only:
        orders = {Order.PATRICIAN}
    if era.plebeians_only:
        orders = {Order.PLEBEIAN}
    ids = [
        gid
        for gid in sorted(state.world.gentes)
        if orders is None or state.world.gentes[gid].order in orders
    ]
    if not ids:
        return None
    weights = [family_weight(rep.families[gid]) for gid in ids]
    gens = state.world.gentes[ids[rng.weighted_index(weights)]]
    least = era.min_age
    if least is None:
        least = rules.pre_villia_min_age if mag.cursus else rules.adult_age
    person = _spawn_man(state, rep, rng, gens, year - least - rng.below(8), "novus")
    events.add(
        state.player_civ,
        "new_man",
        f"No man of the proper career stands for the {mag.name.lower()}; "
        f"{person.name} puts himself forward.",
        person.name,
    )
    return person


def _hold_year(
    state: GameState, rep: RepublicState, rng: GameRng, events: EventLog, year: int
) -> None:
    """Choose the year's magistrates: the Fasti first (in a chronicle), then elections."""
    mags = state.world.magistracies
    if not mags:
        return
    shares = faction_shares(state, year)
    taken: set[str] = {m.person for m in rep.magistrates if m.office in mags}
    handled: set[str] = set()
    fasti = state.world.fasti.get(year) if state.chronicle_mode else None
    if fasti is not None:
        handled = _apply_fasti(state, rep, rng, events, fasti, taken, shares)
        if fasti.gap:
            handled |= _gap_year(state, events, year, fasti.gap)
    if state.chronicle_mode:
        _seat_recorded(state, rep, year, taken, handled)
    elected = _elect_all(state, rep, rng, events, year, taken, shares, handled)
    _maybe_dictator(state, rep, rng, events, year, taken, fasti is not None, shares)
    _emergency(state, rep)
    _take_census(state, rep, year)
    _announce(state, rep, events, year, elected)
    _name_ruler(state, rep)


def _gap_year(state: GameState, events: EventLog, year: int, kind: str) -> set[str]:
    """A year without curule magistrates: only the plebeian offices are chosen.

    The anarchy of 375-371 (Livy 6.35.10: the tribunes Licinius and Sextius blocked the
    curule elections, and were themselves re-elected) and the "dictator years" the Varronian
    list pads with (333, 324, 309, 301).
    """
    mags = state.world.magistracies
    blocked = {
        mid
        for mid in sorted(mags)
        if (era := mags[mid].era_at(year)) is None or not era.plebeians_only
    }
    if kind == "anarchy":
        text = (
            f"No consuls or consular tribunes are chosen for {year_label(year)}: the tribunes "
            "block the elections and the city goes without curule magistrates."
        )
    else:
        text = f"The lists give {year_label(year)} to a dictator alone: no consuls are chosen."
    events.add(state.player_civ, "anarchy", text, kind)
    return blocked


def _seat_recorded(
    state: GameState, rep: RepublicState, year: int, taken: set[str], handled: set[str]
) -> None:
    """Honour a modelled person's recorded offices the Fasti do not list.

    A praetorship, a tribunate: he takes the seat before the election fills the rest.
    """
    mags = state.world.magistracies
    for pid in sorted(rep.people):
        person = rep.people[pid]
        if not person.alive or pid in taken:
            continue
        for held in person.future:
            if held.year != year or held.office in handled or held.office not in mags:
                continue
            mag = mags[held.office]
            era = mag.era_at(year)
            if era is None or era.appointed or not era.held_in(year):
                continue
            if sum(1 for m in rep.magistrates if m.office == mag.id) >= era.seats:
                continue
            _take(state, rep, person, mag, era, year, by_fasti=True)
            taken.add(pid)
            break


def _elect_all(
    state: GameState,
    rep: RepublicState,
    rng: GameRng,
    events: EventLog,
    year: int,
    taken: set[str],
    shares: dict[str, int],
    handled: set[str],
) -> list[str]:
    mags = state.world.magistracies
    order = sorted(mags, key=lambda i: (-mags[i].rank, i))
    # offices that stand in for another (consular tribunes) are chosen only when it gives way
    stands_in = {
        e.replaced_by
        for mid in order
        if (e := mags[mid].era_at(year)) is not None and e.replaced_by
    }
    # the two sides of a replacement count as one: a Fasti college settles both
    for mid in order:
        era = mags[mid].era_at(year)
        if era is not None and era.replaced_by:
            if mid in handled:
                handled.add(era.replaced_by)
            if era.replaced_by in handled:
                handled.add(mid)
    forced: set[str] = set()
    for mid in order:
        era = mags[mid].era_at(year)
        if era is None or not era.held_in(year) or mid in handled or not era.replaced_by:
            continue
        if rng.chance(era.replaced_bp):
            forced.add(era.replaced_by)
    covered = state.chronicle_mode and year in state.world.fasti
    elected: list[str] = []
    for mid in order:
        mag, era = mags[mid], mags[mid].era_at(year)
        if era is None or not era.held_in(year) or mid in handled or era.appointed:
            continue
        if covered and era.every > 1:
            continue  # the censors of a year the Fasti cover are the Fasti's, or none
        if mid in stands_in and mid not in forced:
            continue
        if era.replaced_by and era.replaced_by in forced:
            continue
        carried = sum(1 for m in rep.magistrates if m.office == mid)
        seats = era.seats - carried
        if seats <= 0:
            continue
        men = _choose(state, rep, rng, events, mag, era, year, seats, taken, shares)
        for man in men:
            _take(state, rep, man, mag, era, year)
            taken.add(man.id)
        if men:
            elected.append(mid)
    return elected


def _apply_fasti(
    state: GameState,
    rep: RepublicState,
    rng: GameRng,
    events: EventLog,
    fasti: FastiYear,
    taken: set[str],
    shares: dict[str, int],
) -> set[str]:
    """Seat the historical holders; fill seats history cannot (dead, displaced) by election."""
    mags = state.world.magistracies
    year = fasti.year
    handled: set[str] = set()
    for college in fasti.colleges:
        mag = mags[college.office]
        era = mag.era_at(year)
        if era is None:  # history has the office when our law-table does not: take it as 12 months
            era = MagistracyEra(from_year=year, to_year=year, seats=len(college.holders))
        handled.add(mag.id)
        seated: list[tuple[Person, bool]] = []
        missing = 0
        for holder in college.holders:
            person = _resolve_holder(
                state, rep, holder.person, holder.name, holder.gens, holder.plebeian, year
            )
            if person is None or not person.alive:
                if not holder.suffect:
                    missing += 1
                    who = holder.name or state.world.people[holder.person or ""].name
                    events.add(
                        state.player_civ,
                        "history_turned",
                        f"{who}, whom history made {mag.name.lower()} of {year_label(year)}, "
                        "is not alive to take it.",
                        who,
                    )
                continue
            seated.append((person, holder.suffect))
        # the player's candidates displace the historical men who share the office
        for back in sorted(
            (b for b in rep.backing if b.year == year and b.office == mag.id),
            key=lambda b: b.person,
        ):
            man = rep.people.get(back.person)
            if man is None or not man.alive or any(p.id == man.id for p, _ in seated):
                continue
            backed_ids = {b.person for b in rep.backing if b.year == year and b.office == mag.id}
            for index in range(len(seated) - 1, -1, -1):
                person, suffect = seated[index]
                if not suffect and person.id not in backed_ids:
                    events.add(
                        state.player_civ,
                        "history_turned",
                        f"{man.name}, backed by Rome's guiding hand, is chosen "
                        f"in place of {person.name}.",
                        man.name,
                    )
                    seated[index] = (man, False)
                    rep.diverged = True
                    break
        for person, suffect in seated:
            _take(state, rep, person, mag, era, year, suffect=suffect, by_fasti=True)
            taken.add(person.id)
        if missing:
            rep.diverged = True
            men = _choose(state, rep, rng, events, mag, era, year, missing, taken, shares)
            for man in men:
                _take(state, rep, man, mag, era, year)
                taken.add(man.id)
    # a dictator's master of the horse serves him
    for m in rep.magistrates:
        mag = mags[m.office]
        era2 = mag.era_at(year)
        if era2 is not None and era2.companion:
            for other in rep.magistrates:
                if other.office == era2.companion and not other.master:
                    other.master = m.person
    return handled


def _resolve_holder(
    state: GameState,
    rep: RepublicState,
    person_id: str | None,
    name: str,
    gens_id: str | None,
    plebeian: bool | None,
    year: int,
) -> Person | None:
    """Find (or bring into the game) the man the Fasti names."""
    if person_id is not None:
        person = rep.people.get(person_id)
        if person is not None:
            return person
        hp = state.world.people[person_id]
        if hp.died is not None and hp.died < year:
            return None
        return _spawn_historical(state, rep, hp, year, force=True)
    rules = state.world.republic_rules
    for pid in sorted(rep.people):
        existing = rep.people[pid]
        if (
            existing.name == name
            and existing.alive
            and existing.gens == gens_id
            and rules.pre_villia_min_age <= year - existing.born <= rules.namesake_max_age
        ):
            return existing
    assert gens_id is not None
    gens = state.world.gentes[gens_id]
    order = gens.order if plebeian is None else (Order.PLEBEIAN if plebeian else Order.PATRICIAN)
    person = Person(
        id=_new_id(rep),
        name=name,
        gens=gens_id,
        order=order,
        born=year - rules.age_at_first_listed_office,
        historical=True,
        protected_until=year,
    )
    rep.people[person.id] = person
    return person


# ---------------------------------------------------------------- dictator, census, naming


def _maybe_dictator(
    state: GameState,
    rep: RepublicState,
    rng: GameRng,
    events: EventLog,
    year: int,
    taken: set[str],
    history_year: bool,
    shares: dict[str, int],
) -> None:
    """In an emergency the consuls may name a dictator (for six months) and his master of horse."""
    mags = state.world.magistracies
    for mid in sorted(mags):
        mag = mags[mid]
        era = mag.era_at(year)
        if era is None or not era.appointed or not era.companion or not era.covers(year):
            continue
        level = _emergency(state, rep)
        called = rng.chance(level // 2)
        if history_year or level < state.world.republic_rules.dictator_emergency_bp:
            return
        if not called or any(m.office == mid for m in rep.magistrates):
            return
        companion = mags[era.companion]
        c_era = companion.era_at(year) or era
        pool = [
            p
            for p in (rep.people[i] for i in sorted(rep.people))
            if p.alive and p.id not in taken and eligible_for_appointment(state, p, year)
        ]
        if not pool:
            return
        weights = [1 + max(0, p.glory) + (2000 if _consular(state, p) else 0) for p in pool]
        dictator = pool[rng.weighted_index(weights)]
        _take(state, rep, dictator, mag, era, year)
        taken.add(dictator.id)
        master = ""
        horse = _choose(state, rep, rng, events, companion, c_era, year, 1, taken, shares)
        for man in horse:
            _take(state, rep, man, companion, c_era, year, master=dictator.id)
            taken.add(man.id)
            master = man.name
        events.add(
            state.player_civ,
            "dictator",
            f"In the crisis the Senate bids the consuls name a dictator: {dictator.name}"
            + (f", with {master} as master of the horse." if master else "."),
            dictator.name,
        )
        return


def eligible_for_appointment(state: GameState, person: Person, year: int) -> bool:
    """May this man be named to an emergency office (of age for a career, not too old)?"""
    rules = state.world.republic_rules
    return person.alive and rules.pre_villia_min_age <= _age(person, year) <= rules.max_office_age


def _consular(state: GameState, person: Person) -> bool:
    mags = state.world.magistracies
    top = max((m.rank for m in mags.values() if m.cursus), default=0)
    return any(mags[h.office].rank >= top for h in person.offices)


def _take_census(state: GameState, rep: RepublicState, year: int) -> None:
    mags = state.world.magistracies
    for m in rep.magistrates:
        if mags[m.office].census and m.year == year:
            share = state.world.republic_rules.census_citizen_share_bp
            rep.census.append(
                CensusRecord(year=year, citizens=state.population(state.player_civ) * share // BP)
            )
            return


def _announce(
    state: GameState, rep: RepublicState, events: EventLog, year: int, elected: list[str]
) -> None:
    mags = state.world.magistracies
    here = [m for m in rep.magistrates if m.year == year and not m.suffect]
    if not here:
        return
    top = (
        max(mags[m.office].rank for m in here if not m.appointed)
        if any(not m.appointed for m in here)
        else 0
    )
    names = [m.name for m in here if mags[m.office].rank == top and not m.appointed]
    if names:
        office = mags[next(m.office for m in here if mags[m.office].rank == top)].name.lower()
        who = " and ".join([", ".join(names[:-1]), names[-1]] if len(names) > 1 else names)
        plural = "s" if len(names) > 1 else ""
        events.add(
            state.player_civ,
            "election",
            f"The {office}{plural} for {year_label(year)}: {who}.",
            who,
        )
    for m in rep.magistrates:
        if mags[m.office].census and m.year == year:
            events.add(
                state.player_civ,
                "census",
                f"The censors take the census: {rep.census[-1].citizens:,} citizens.",
            )
            break


def _name_ruler(state: GameState, rep: RepublicState) -> None:
    """The old single-ruler fields read as the senior magistrates, so the rest of the game works."""
    mags = state.world.magistracies
    civ = state.civs[state.player_civ]
    senior = [m for m in rep.magistrates if not m.appointed and not m.suffect]
    if not senior:
        civ.ruler = ""
        return
    top = max(mags[m.office].rank for m in senior)
    names = [m.name for m in senior if mags[m.office].rank == top and mags[m.office].cursus]
    civ.ruler = " and ".join(names) if names else senior[0].name


# ---------------------------------------------------------------- the Senate and the player


@dataclass(frozen=True)
class Vote:
    """The Senate's vote on an issue."""

    issue: Issue
    yes_bp: int
    no_bp: int
    passes: bool
    by_family: dict[str, int]
    """Family id -> its leaning (positive for, negative against), stance plus the player's work."""


def family_leaning(state: GameState, family_id: str, issue: Issue) -> int:
    """How a family leans on an issue.

    Its stance, its bloc's lean in this era, and how far the player has won it over.
    """
    rep = _rep(state)
    gens = state.world.gentes[family_id]
    stance = gens.stances.get(issue, 0)
    bloc = 0
    for faction in factions_at(state, state.year):
        if _in_faction(faction, gens.order, _lean_popular(gens)):
            bloc = faction.stances.get(issue, 0)
            break
    return stance + bloc + rep.families[family_id].favour.get(issue.value, 0)


def senate_vote(
    state: GameState,
    issue: Issue,
    *,
    record: bool = False,
    turn: int | None = None,
    year: int | None = None,
) -> Vote:
    """The Senate's will: a vote weighted by the families' standing and their senators.

    Each family's men divide by the strength of its lean on the issue (its stance, its
    bloc's lean in the era, the player's persuasion): a lean of +3000 sends 65% of them to
    the yes side. So the forecast differs by issue and by era, and a house of one mind is rare.
    With ``record`` the vote is a real one: it becomes a ``senate`` event in the city (U7).
    Looking at the Senate's mood (a view, a forecast) leaves ``record`` off. A vote recorded
    while a turn resolves passes that turn's ``turn`` and ``year``.
    """
    rep = _rep(state)
    yes = no = total = 0
    leanings: dict[str, int] = {}
    weights = senate_weights(state)
    for fid in sorted(rep.families):
        weight = weights[fid]
        lean = family_leaning(state, fid, issue)
        leanings[fid] = lean
        total += weight
        # a family's senators split by the strength of its lean: +10000 is every man for,
        # 0 an even house, -10000 every man against
        share = max(-BP, min(BP, lean))
        for_it = weight * (BP + share) // (2 * BP)
        yes += for_it
        no += weight - for_it
    yes_bp = yes * BP // total if total else 0
    no_bp = no * BP // total if total else 0
    if record:
        city_module.record_vote(state, issue.value, yes_bp, no_bp, turn=turn, year=year)
    return Vote(issue, yes_bp, no_bp, yes > no, leanings)


@dataclass(frozen=True)
class FactionMood:
    """One bloc of the Senate: its weight and how it leans."""

    id: str
    name: str
    weight_bp: int
    mood_bp: int
    """Average leaning over all issues, -10000..10000."""
    issues: dict[str, int]
    """Issue -> the bloc's weighted leaning."""


def senate_mood(state: GameState) -> list[FactionMood]:
    """The Senate's mood by bloc for the current year."""
    rep = _rep(state)
    year = state.year
    out: list[FactionMood] = []
    blocs = factions_at(state, year)
    weights = senate_weights(state)
    total = sum(weights.values())
    for faction in blocs:
        members = [
            fid
            for fid in sorted(rep.families)
            if _in_faction(
                faction, state.world.gentes[fid].order, _lean_popular(state.world.gentes[fid])
            )
        ]
        weight = sum(weights[f] for f in members)
        issues: dict[str, int] = {}
        for issue in ISSUE_ORDER:
            if weight:
                issues[issue.value] = (
                    sum(weights[f] * family_leaning(state, f, issue) for f in members) // weight
                )
            else:
                issues[issue.value] = 0
        mood = sum(issues.values()) // len(issues)
        out.append(
            FactionMood(
                faction.id, faction.name, weight * BP // total if total else 0, mood, issues
            )
        )
    return out


def persuade(state: GameState, family_id: str, issue: Issue) -> tuple[bool, str]:
    """Spend influence to win a family over on an issue. Changes ``state``."""
    rep = _rep(state)
    rules = state.world.republic_rules
    family = rep.families.get(family_id)
    if family is None:
        return False, f"unknown family {family_id!r}"
    if rep.influence < rules.persuade_cost:
        return False, "not enough influence with the Senate"
    rep.influence -= rules.persuade_cost
    now = family.favour.get(issue.value, 0)
    family.favour[issue.value] = max(-BP, min(BP, now + rules.persuade_shift))
    name = state.world.gentes[family_id].name
    return True, f"The {name} are won over on {issue.value}."


def back_candidate(
    state: GameState, person_id: str, office: str, year: int | None = None
) -> tuple[bool, str]:
    """Spend influence to back a man for an office at a coming election. Changes ``state``."""
    rep = _rep(state)
    rules = state.world.republic_rules
    target = state.year + 1 if year is None else year
    person = rep.people.get(person_id)
    mag = state.world.magistracies.get(office)
    if person is None or not person.alive:
        return False, "no such man is alive"
    if mag is None:
        return False, f"unknown office {office!r}"
    era = mag.era_at(target)
    if era is None or not era.held_in(target) or era.appointed:
        return False, f"the {mag.name.lower()} is not chosen in {year_label(target)}"
    if not eligible(state, person, mag, era, target):
        return (
            False,
            f"{person.name} cannot stand for the {mag.name.lower()} in {year_label(target)}",
        )
    if any(b.person == person_id and b.office == office and b.year == target for b in rep.backing):
        return False, "already backed"
    if rep.influence < rules.back_cost:
        return False, "not enough influence with the Senate"
    rep.influence -= rules.back_cost
    rep.backing.append(Backing(person=person_id, office=office, year=target))
    return True, f"{person.name} is backed for the {mag.name.lower()} of {year_label(target)}."
