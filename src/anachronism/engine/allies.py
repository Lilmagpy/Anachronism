"""The *socii* and the Latins (R3, F1): treaties, loyalty, levies, rights, the Social War.

Rome's Italian allies are their own civs bound to Rome by treaty (D-287). Each treaty has a
levy obligation: Polybius 2.24 (the census of 225 BC) lists the allies' men able to bear arms
apart from the Romans' (Latins 80,000 foot and 5,000 horse, Samnites 70,000 and 7,000,
Iapygians and Messapians 50,000 and 16,000, Lucanians 30,000 and 3,000, Marsi, Marrucini,
Frentani and Vestini 20,000 and 4,000, Etruscans and Sabines above 50,000 and 4,000, Umbrians
and Sarsinates 20,000, Veneti and Cenomani 20,000; Romans and Campanians 250,000 and 23,000;
2.24.5-14), and each consular army had 30,000 allied foot and 2,000 horse beside its 20,800
Roman foot and 1,200 horse (2.24.3-4): the allies were about half the force and more. So when
Rome is at war the allies' contingents join its armies up to ``allied_ratio_bp`` of the
citizen soldiers, each people pro rata to its obligation and only while it is loyal enough.

Loyalty falls with Roman defeats (the allies went over to Hannibal after Cannae: Polybius
3.118.5), with citizenship refused once it could be given (Fulvius Flaccus, 125: Appian, Civil
Wars 1.34; Velleius 2.15.2 on the allies' claim) and with land confiscated (Appian 1.18-21),
and rises with victories (a booty share: the allies shared the spoils) and with grants of
rights. Low loyalty across Italy sets up the Social War (91-88): the allies rise as a bloc
(Appian 1.38-39; Velleius 2.15.1, the praetor Servilius killed at Asculum) unless citizenship
has been granted. The ``grant_citizenship`` law gives it: the Lex Iulia of 90 for the loyal
(Appian 1.49; Velleius 2.16.4) and the Lex Plautia Papiria of 89 for those who laid down their
arms (Velleius 2.16.4, 2.17.1; Cicero, Pro Archia 7, unverified).

The ladder of rights per people: ally, Latin right, citizenship without the vote (Caere, 353:
Livy 7.20.7-9 for the pardon, Gellius 16.13.7 for the status, unverified; the Campanians,
Fundi and Formiae, 338: Livy 8.14.10; Anagnia and the Hernici, 306: Livy 9.43.24; Arpinum,
Fundi and Formiae given the vote in 188: Livy 38.36.7-9), full citizenship. Each step changes
the levy, the loyalty and Rome's citizen count (:func:`citizens_added`, read by the census).
"""

from __future__ import annotations

from anachronism.content.schema import RelationStatus
from anachronism.content.schema.italy import AllyStatus, AllyTreaty, ItalyRules
from anachronism.engine.events import EventLog, list_names
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.italy_state import ItalyState, Treaty
from anachronism.engine.republic_state import RepublicState
from anachronism.engine.rivals import add_grievance, alive, at_war, declare_war, status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import Army, GameState
from anachronism.engine.war import make_peace

CITIZENSHIP_LAW = "grant_citizenship"
LAND_LAW = "land_reform"
SOCIAL_WAR_EMERGENCY_BP = 4000
DEFECTION_LOYALTY_BP = 1000
"""An ally this disaffected goes over to Rome's enemies by itself (Polybius 3.118.5)."""
LATIN_LEVY_BP = 1000
"""The Latins furnished the largest contingent of all (Polybius 2.24.10)."""
STATUS_NAMES = {
    AllyStatus.ALLY: "ally",
    AllyStatus.LATIN: "the Latin right",
    AllyStatus.SINE_SUFFRAGIO: "citizenship without the vote",
    AllyStatus.CITIZEN: "full citizenship",
}


# ---------------------------------------------------------------- helpers


def _rep(state: GameState) -> RepublicState:
    assert state.republic is not None
    return state.republic


def italy_of(state: GameState) -> ItalyState:
    """The Republic's alliance, colony and province state."""
    return _rep(state).italy


def rules_of(state: GameState) -> ItalyRules:
    """The tunable numbers."""
    return state.world.italy_rules


def is_italian(state: GameState, civ_id: str) -> bool:
    """A people whose home is in Italy (its provinces are ``it_*``)."""
    owned = state.owned_provinces(civ_id)
    seat = state.civs[civ_id].capital
    return seat.startswith("it_") or any(p.startswith("it_") for p in owned)


def content_treaty(state: GameState, civ_id: str) -> AllyTreaty | None:
    """The treaty content for a civ, if the pack has one."""
    for tid in sorted(state.world.treaties):
        if state.world.treaties[tid].civ == civ_id:
            return state.world.treaties[tid]
    return None


def first_year_of_turn(state: GameState, year: int) -> bool:
    """True for the first year a turn covers (the turn's battles are counted once)."""
    return year == state.year - state.world.years_per_turn + 1 or state.turn == 0


def _new_treaty(state: GameState, civ_id: str, year: int) -> Treaty:
    found = content_treaty(state, civ_id)
    civ = state.civs[civ_id]
    if found is None:
        return Treaty(
            civ=civ_id,
            name=civ.name,
            since=year,
            loyalty_bp=rules_of(state).baseline_loyalty_bp,
            italian=is_italian(state, civ_id),
        )
    return Treaty(
        civ=civ_id,
        name=found.name or civ.name,
        status=found.status,
        loyalty_bp=found.loyalty_bp,
        levy_bp=found.levy_bp,
        booty_share=found.booty_share,
        land_share=found.land_share,
        since=year,
        italian=is_italian(state, civ_id),
    )


def sync_treaties(state: GameState, year: int) -> None:
    """Treaties follow the alliances: a new ally gets one, a lost ally loses it or revolts."""
    italy = italy_of(state)
    me = state.player_civ
    for civ_id in sorted(state.civs):
        if civ_id == me or not alive(state, civ_id):
            continue
        if status(state, me, civ_id) is RelationStatus.ALLIED and civ_id not in italy.treaties:
            italy.treaties[civ_id] = _new_treaty(state, civ_id, year)
    for civ_id in sorted(italy.treaties):
        treaty = italy.treaties[civ_id]
        if treaty.status is AllyStatus.CITIZEN:
            continue  # absorbed into Rome: kept for the record
        now = status(state, me, civ_id)
        if now is RelationStatus.WAR and not treaty.revolted:
            treaty.revolted = True
            treaty.loyalty_bp = 0
            _desert(state, civ_id)
        elif now is RelationStatus.ALLIED and treaty.revolted:
            treaty.revolted = False  # reconciled: the old treaty is renewed
            treaty.loyalty_bp = rules_of(state).baseline_loyalty_bp // 2
            treaty.since = year
        elif (now is not RelationStatus.ALLIED and not treaty.revolted) or (
            not alive(state, civ_id) and treaty.revolted
        ):
            _desert(state, civ_id)
            del italy.treaties[civ_id]


# ---------------------------------------------------------------- the ladder of rights


def citizens_added(state: GameState, n: int) -> None:
    """``n`` adult men join the citizen body (a grant of rights); the census reads the total."""
    italy_of(state).citizens_added += n


def extra_citizens(state: GameState) -> int:
    """Adult men of allied peoples counted in Rome's census (citizenship without the vote)."""
    italy = italy_of(state)
    return sum(italy.treaties[c].citizens for c in sorted(italy.treaties))


def _adult_men(state: GameState, civ_id: str) -> int:
    share = state.world.republic_rules.census_citizen_share_bp
    return state.population(civ_id) * share // BP


def grant_status(
    state: GameState, civ_id: str, new: AllyStatus, year: int, events: EventLog | None = None
) -> bool:
    """Move a people up the ladder. Returns False if it has no treaty or is already there."""
    italy = italy_of(state)
    treaty = italy.treaties.get(civ_id)
    if treaty is None or new.rank <= treaty.status.rank:
        return False
    rules = rules_of(state)
    civ = state.civs[civ_id]
    treaty.status = new
    treaty.since = year
    treaty.revolted = False
    treaty.loyalty_bp = clamp(treaty.loyalty_bp + rules.grant_bp, 0, BP)
    if new is AllyStatus.LATIN:
        treaty.levy_bp = max(treaty.levy_bp, LATIN_LEVY_BP)
    elif new is AllyStatus.SINE_SUFFRAGIO:
        men = _adult_men(state, civ_id)
        citizens_added(state, men - treaty.citizens)
        treaty.citizens = men
    elif new is AllyStatus.CITIZEN:
        men = _adult_men(state, civ_id)
        citizens_added(state, men - treaty.citizens)
        treaty.citizens = 0  # from now on they are Rome's own population
        _absorb(state, civ_id)
    if events is not None:
        events.add(
            state.player_civ,
            "citizenship",
            f"The {civ.adjective} people receive {STATUS_NAMES[new]}.",
            civ.name,
        )
    return True


def _absorb(state: GameState, civ_id: str) -> None:
    """Full citizenship: the people and its land become Roman; its armies go home."""
    italy = italy_of(state)
    me = state.player_civ
    for army_id in sorted(state.armies):
        army = state.armies[army_id]
        if army.owner == civ_id:
            province = state.provinces.get(army.province)
            if province is not None:
                province.population += army.men
            del state.armies[army_id]
    for fleet_id in sorted(state.fleets):
        if state.fleets[fleet_id].owner == civ_id:
            del state.fleets[fleet_id]
    for pid in state.owned_provinces(civ_id):
        province = state.provinces[pid]
        province.owner = me
        province.people = me
        province.held_since = state.turn
    for army_id in sorted(italy.levies):
        italy.levies[army_id].pop(civ_id, None)  # their men in Rome's armies are Romans now
        if not italy.levies[army_id]:
            del italy.levies[army_id]
    treaty = italy.treaties[civ_id]
    treaty.serving = 0
    state.civs[civ_id].collapsed = True


def grant_citizenship_all(state: GameState, year: int, events: EventLog) -> list[str]:
    """Citizenship for every Italian ally at peace with Rome (the Lex Iulia)."""
    italy = italy_of(state)
    me = state.player_civ
    given = []
    for civ_id in sorted(italy.treaties):
        treaty = italy.treaties[civ_id]
        if not treaty.italian or treaty.status is AllyStatus.CITIZEN or not alive(state, civ_id):
            continue
        if status(state, me, civ_id) is RelationStatus.WAR:
            continue  # those still in arms wait for the Lex Plautia Papiria
        if grant_status(state, civ_id, AllyStatus.CITIZEN, year, events):
            given.append(civ_id)
    return given


# ---------------------------------------------------------------- loyalty


def loyalty_year(state: GameState, events: EventLog, year: int) -> None:
    """Victories, defeats, refusals and confiscations move every ally's loyalty."""
    italy = italy_of(state)
    rules = rules_of(state)
    rep = _rep(state)
    me = state.player_civ
    wins = losses = 0
    if first_year_of_turn(state, year):
        for item in events.items:
            if item.civ != me:
                continue
            if item.kind == "battle_won":
                wins += 1
            elif item.kind == "battle_lost":
                losses += 1
    law_open = any(
        law.id == CITIZENSHIP_LAW and law.open_in(year)
        for law in state.world.republic_rules.senate.laws
    )
    refused = law_open and CITIZENSHIP_LAW not in rep.laws
    land_year = rep.laws.get(LAND_LAW)
    confiscating = land_year is not None and 0 <= year - land_year < rules.confiscation_years
    for civ_id in sorted(italy.treaties):
        treaty = italy.treaties[civ_id]
        if treaty.revolted or treaty.status is AllyStatus.CITIZEN:
            continue
        delta = wins * rules.victory_bp * (2 if treaty.booty_share else 1)
        delta -= losses * rules.defeat_bp
        if refused and treaty.italian and treaty.status.rank < AllyStatus.CITIZEN.rank:
            delta -= rules.refused_citizenship_bp
        if confiscating and not treaty.land_share:
            delta -= rules.confiscation_bp
        delta += (rules.baseline_loyalty_bp - treaty.loyalty_bp) * rules.loyalty_drift_bp // BP
        treaty.loyalty_bp = clamp(treaty.loyalty_bp + delta, 0, BP)


# ---------------------------------------------------------------- the levies


def _roman_armies(state: GameState) -> list[Army]:
    me = state.player_civ
    return sorted(
        (a for a in state.armies.values() if a.owner == me and not a.contract and not a.garrison),
        key=lambda a: a.id,
    )


def _add_men(army: Army, n: int) -> None:
    """Add ``n`` men to an army in the proportions of its present kinds of soldier."""
    if n <= 0:
        return
    total = army.men
    if total == 0 or not army.troops:
        army.troops["levy"] = army.troops.get("levy", 0) + n
        return
    units = sorted(army.troops)
    given = 0
    for unit_id in units:
        share = n * army.troops[unit_id] // total
        army.troops[unit_id] += share
        given += share
    biggest = max(units, key=lambda u: (army.troops[u], u))
    army.troops[biggest] += n - given


def _remove_men(army: Army, n: int) -> int:
    """Take ``n`` men out of an army pro rata; returns how many were actually taken."""
    total = army.men
    n = min(n, total)
    if n <= 0:
        return 0
    taken = 0
    for unit_id in sorted(army.troops):
        share = n * army.troops[unit_id] // total
        army.troops[unit_id] -= share
        taken += share
    for unit_id in sorted(army.troops, key=lambda u: (-army.troops[u], u)):
        if taken >= n:
            break
        step = min(n - taken, army.troops[unit_id])
        army.troops[unit_id] -= step
        taken += step
    for unit_id in [u for u in army.troops if army.troops[u] <= 0]:
        del army.troops[unit_id]
    return taken


def _home(state: GameState, civ_id: str, men: int) -> None:
    """Men go home to their people's largest province (lost if the people has no land)."""
    owned = state.owned_provinces(civ_id)
    if not owned or men <= 0:
        return
    seat = max(owned, key=lambda p: (state.provinces[p].population, p))
    state.provinces[seat].population += men


def _desert(state: GameState, civ_id: str) -> None:
    """An ally's men leave Rome's standards (a revolt, a broken alliance)."""
    italy = italy_of(state)
    for army_id in sorted(italy.levies):
        men = italy.levies[army_id].pop(civ_id, None)
        if men:
            army = state.armies.get(army_id)
            if army is not None:
                _remove_men(army, men)
            _home(state, civ_id, men)
        if not italy.levies[army_id]:
            del italy.levies[army_id]
    treaty = italy.treaties.get(civ_id)
    if treaty is not None:
        treaty.serving = 0


def _release_all(state: GameState, events: EventLog) -> None:
    italy = italy_of(state)
    sent = 0
    for army_id in sorted(italy.levies):
        army = state.armies.get(army_id)
        for civ_id in sorted(italy.levies[army_id]):
            men = italy.levies[army_id][civ_id]
            if army is not None:
                men = _remove_men(army, men)
            _home(state, civ_id, men)
            treaty = italy.treaties.get(civ_id)
            if treaty is not None:
                treaty.serving = max(0, treaty.serving - men)
            sent += men
    italy.levies.clear()
    if sent:
        events.add(state.player_civ, "levy", f"The allies' contingents, {sent:,} men, go home.")


def _prune_levies(state: GameState) -> None:
    """Records of armies that no longer exist: their men are lost."""
    italy = italy_of(state)
    for army_id in sorted(italy.levies):
        army = state.armies.get(army_id)
        if army is None:
            for civ_id, men in sorted(italy.levies[army_id].items()):
                treaty = italy.treaties.get(civ_id)
                if treaty is not None:
                    treaty.serving = max(0, treaty.serving - men)
            del italy.levies[army_id]
            continue
        for civ_id in sorted(italy.levies[army_id]):
            italy.levies[army_id][civ_id] = min(italy.levies[army_id][civ_id], army.men)


def allied_men(state: GameState, army_id: str) -> int:
    """How many of an army's men are allied contingents."""
    return sum(italy_of(state).levies.get(army_id, {}).values())


def levies_year(state: GameState, events: EventLog) -> None:
    """At war the allies fill Rome's armies to the treaty ratio; at peace they go home."""
    italy = italy_of(state)
    rules = rules_of(state)
    me = state.player_civ
    _prune_levies(state)
    if not at_war(state, me):
        _release_all(state, events)
        return
    capacity: dict[str, int] = {}
    for civ_id in sorted(italy.treaties):
        treaty = italy.treaties[civ_id]
        if (
            treaty.revolted
            or treaty.status is AllyStatus.CITIZEN
            or treaty.loyalty_bp < rules.levy_loyalty_floor_bp
            or not alive(state, civ_id)
        ):
            continue
        room = apply_bp(state.population(civ_id), treaty.levy_bp) - treaty.serving
        if room > 0:
            capacity[civ_id] = room
    sent_by: dict[str, int] = {}
    for army in _roman_armies(state):
        if state.provinces[army.province].owner != me:
            continue  # contingents join the standards at home, not in the field
        serving = allied_men(state, army.id)
        citizens = army.men - serving
        need = citizens * rules.allied_ratio_bp // BP - serving
        total_room = sum(capacity.values())
        if need <= 0 or total_room <= 0:
            continue
        record = italy.levies.setdefault(army.id, {})
        given = 0
        for civ_id in sorted(capacity):
            share = min(capacity[civ_id], need * capacity[civ_id] // total_room)
            if share <= 0:
                continue
            taken = _draw(state, civ_id, share)
            if taken <= 0:
                continue
            capacity[civ_id] -= taken
            record[civ_id] = record.get(civ_id, 0) + taken
            italy.treaties[civ_id].serving += taken
            sent_by[civ_id] = sent_by.get(civ_id, 0) + taken
            given += taken
        for civ_id in [c for c in capacity if capacity[c] <= 0]:
            del capacity[civ_id]
        _add_men(army, given)
        if not record:
            del italy.levies[army.id]
    total = sum(sent_by.values())
    if total:
        names = [state.civs[c].adjective for c in sorted(sent_by, key=lambda c: (-sent_by[c], c))]
        events.add(
            me,
            "levy",
            f"The allies send {total:,} men to the standards: {list_names(names)} contingents.",
        )


def _draw(state: GameState, civ_id: str, men: int) -> int:
    """Call ``men`` up from an ally's provinces, largest first, never over half of one."""
    taken = 0
    owned = sorted(state.owned_provinces(civ_id), key=lambda p: (-state.provinces[p].population, p))
    for pid in owned:
        province = state.provinces[pid]
        step = min(men - taken, province.population // 2)
        if step <= 0:
            continue
        province.population -= step
        taken += step
        if taken >= men:
            break
    return taken


# ---------------------------------------------------------------- the Social War and history


def _italian_allies(state: GameState) -> list[Treaty]:
    italy = italy_of(state)
    return [
        italy.treaties[c]
        for c in sorted(italy.treaties)
        if italy.treaties[c].italian
        and not italy.treaties[c].revolted
        and italy.treaties[c].status is not AllyStatus.CITIZEN
        and alive(state, c)
    ]


def _revolt(state: GameState, civ_id: str, events: EventLog, why: str) -> None:
    rep = _rep(state)
    treaty = italy_of(state).treaties[civ_id]
    treaty.revolted = True
    treaty.loyalty_bp = 0
    _desert(state, civ_id)
    add_grievance(state, civ_id, state.player_civ, 3000)
    declare_war(state, civ_id, state.player_civ, events, why)
    rep.extra_emergency_bp = min(BP, rep.extra_emergency_bp + SOCIAL_WAR_EMERGENCY_BP)


def social_war(state: GameState, events: EventLog, year: int) -> None:
    """The Italian allies rise as a bloc if their loyalty is low and citizenship is refused.

    Appian, Civil Wars 1.38-39: after Drusus' murder the Italians, seeing no other way to the
    citizenship, conspired and rose at Asculum, and the Marsi, Paeligni, Vestini, Marrucini,
    Picentes, Frentani, Hirpini, Pompeiani, Venusini, Apulians, Lucanians and Samnites followed.
    """
    italy = italy_of(state)
    rules = rules_of(state)
    rep = _rep(state)
    if italy.social_war_year is not None or CITIZENSHIP_LAW in rep.laws:
        return
    if not rules.social_war_year <= year <= rules.social_war_until:
        return
    allies_now = _italian_allies(state)
    if not allies_now:
        return
    rising = [t for t in allies_now if t.loyalty_bp < rules.social_war_loyalty_bp]
    if len(rising) * 2 < len(allies_now):
        return  # no bloc: the ordinary defection rule handles single grievances
    italy.social_war_year = year
    names = [state.civs[t.civ].adjective for t in rising]
    events.add(
        state.player_civ,
        "social_war",
        f"The Italian allies rise against Rome for the citizenship they were refused:"
        f" the {list_names(names, 4)} are in arms.",
    )
    for treaty in rising:
        _revolt(state, treaty.civ, events, " The allies demand the citizenship.")


def defections(state: GameState, events: EventLog) -> None:
    """A single ally this disaffected goes over to Rome's enemies (Capua after Cannae)."""
    for treaty in _italian_allies(state):
        if treaty.loyalty_bp < DEFECTION_LOYALTY_BP and at_war(state, state.player_civ):
            _revolt(state, treaty.civ, events, " The alliance is broken.")


def default_history(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """The steps history gave each people, and the Lex Iulia after a Social War."""
    italy = italy_of(state)
    rules = rules_of(state)
    rep = _rep(state)
    me = state.player_civ
    for civ_id in sorted(italy.treaties):
        treaty = italy.treaties[civ_id]
        found = content_treaty(state, civ_id)
        if found is None or treaty.revolted or not alive(state, civ_id):
            continue
        for step in found.steps:
            if step.year == year and step.status.rank > treaty.status.rank:
                grant_status(state, civ_id, step.status, year, events)
    if (
        year == rules.lex_iulia_year
        and italy.social_war_year is not None
        and CITIZENSHIP_LAW not in rep.laws
    ):
        rep.laws[CITIZENSHIP_LAW] = year
        events.add(
            me,
            "law",
            "The Lex Iulia: the Roman people give the citizenship to the Italians who kept faith,"
            " and to those who lay down their arms.",
        )
    if CITIZENSHIP_LAW in rep.laws:
        if italy.citizenship_year is None:
            italy.citizenship_year = year
        grant_citizenship_all(state, year, events)
        for civ_id in sorted(italy.treaties):  # those who lay down their arms
            treaty = italy.treaties[civ_id]
            if not (treaty.revolted and treaty.italian and alive(state, civ_id)):
                continue
            if year < min(rules.plautia_papiria_year, rep.laws[CITIZENSHIP_LAW]):
                continue
            if status(state, me, civ_id) is RelationStatus.WAR:
                if not rng.chance(rules.lay_down_arms_bp):
                    continue
                make_peace(state, civ_id, me, events)
            treaty.revolted = False
            grant_status(state, civ_id, AllyStatus.CITIZEN, year, events)


# ---------------------------------------------------------------- the year


def start(state: GameState) -> None:
    """Treaties for the alliances the scenario begins with."""
    sync_treaties(state, state.year)


def run_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """One year of the alliance system (one draw: a risen ally laying down its arms)."""
    sync_treaties(state, year)
    loyalty_year(state, events, year)
    default_history(state, rng, events, year)
    social_war(state, events, year)
    defections(state, events)
    levies_year(state, events)
