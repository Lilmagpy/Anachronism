"""What the player does at the places of Rome (F2, D-304): speak, vow, give games, choose a site.

Four logged actions, each played where the Romans did it and each leaving a city event of its
``watch`` kind with the real numbers, so the 3D city plays the spectacle:

- ``contio`` at the Rostra of the year: a magistrate argues a matter (or a candidate) before
  the people. The families that court the people move most on the issue; a consul's or a
  tribune's voice carries furthest (``places.contio.speakers``). Cicero's speeches against
  Rullus' land bill (63) and Tiberius Gracchus' for his own (133) are the models.
- ``vow`` at the Capitol: a magistrate with imperium vows a temple history built later (for a
  battle, needing a war, or for a plague); the temple is begun the next year and dedicated
  ``build_years`` after the vow, in the city timeline (Livy's vows: Juno Moneta 345-344,
  Bellona 296, Jupiter Stator 294).
- ``games`` in a circus (``ludi``, given by an aedile) or a ``munus`` for a dead noble (given
  by his family) in the Forum Boarium (264), the Forum (from 216), a stone amphitheatre (29,
  or the player's own anachronistic one).
- ``site``: where an idea's great work rises (history's site or one of ``places.site.sites``).

Each ``plan_*`` checks an action without changing anything and says what it would cost and do
(the view's forecasts and the action itself share it); each ``apply_*`` carries it out.
Integers only; every loop in sorted order; no randomness is needed.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from anachronism.content.schema import Issue
from anachronism.content.schema.monuments import Monument
from anachronism.content.schema.places import PlaceOfYear, PlacesRules, VowCause
from anachronism.engine.actions import ChooseSite, Contio, GiveGames, VowTemple
from anachronism.engine.city import add_event, first_year, place_of_year, work_form
from anachronism.engine.city_state import GamesGiven, Vow
from anachronism.engine.decrees import cost as wealth_cost
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.republic import eligible, year_label
from anachronism.engine.republic_state import Backing, Magistrate, Person
from anachronism.engine.rivals import at_war
from anachronism.engine.state import GameState

SIDES = ("for", "against")
HISTORY_SITE = "history"
GIVEN_KEPT_YEARS = 50
"""How long the city remembers games given (enough for the once-a-year cap)."""


@dataclass(frozen=True)
class Plan:
    """What an action would cost and do; ``why`` is set (and nothing else matters) if it cannot."""

    why: str = ""
    influence: int = 0
    wealth: int = 0
    place: str = ""
    """The monument where it happens."""
    person: str = ""
    """The man who acts (speaker, vower, giver)."""
    numbers: dict[str, int] = field(default_factory=dict)
    """What it does, for the forecast and the event."""
    shifts: dict[str, int] = field(default_factory=dict)
    """Family id -> favour moved (a contio on an issue)."""

    @property
    def ok(self) -> bool:
        """True when the action can be taken now."""
        return not self.why


def _no(why: str) -> Plan:
    return Plan(why=why)


def _places(state: GameState) -> PlacesRules:
    return state.world.republic_rules.city.places


def _person_name(state: GameState, person_id: str) -> str:
    rep = state.republic
    person = rep.people.get(person_id) if rep is not None else None
    return person.name if person is not None else person_id


def _office_name(state: GameState, office: str) -> str:
    mag = state.world.magistracies.get(office)
    return mag.name if mag is not None else office


def _common(state: GameState, civ: str) -> str:
    """Why no city action can be taken at all, or ``""``."""
    if state.republic is None or state.city is None:
        return "Rome's places are played only in the Republic"
    if civ != state.player_civ:
        return "only the Republic's own court acts in Rome"
    return ""


def magistrates_of(state: GameState, offices: tuple[str, ...] | list[str]) -> list[Magistrate]:
    """Men in office now in any of ``offices``, by the offices' order then by name."""
    rep = state.republic
    if rep is None:
        return []
    order = {office: i for i, office in enumerate(offices)}
    return sorted(
        (m for m in rep.magistrates if m.office in order),
        key=lambda m: (order[m.office], m.person),
    )


# ---------------------------------------------------------------- contio


def speakers(state: GameState) -> list[tuple[Magistrate, int]]:
    """Magistrates who may call a contio now and the weight of their voice, weightiest first."""
    weights = _places(state).contio.speakers
    rep = state.republic
    if rep is None:
        return []
    found = [(m, weights[m.office]) for m in rep.magistrates if m.office in weights]
    return sorted(found, key=lambda pair: (-pair[1], pair[0].office, pair[0].person))


def _speaker(state: GameState, wanted: str) -> tuple[Magistrate, int] | None:
    for magistrate, weight in speakers(state):
        if not wanted or magistrate.person == wanted:
            return magistrate, weight
    return None


def rostra(state: GameState) -> PlaceOfYear | None:
    """The Rostra of the year (before 338 the Comitium's platform; Caesar's from 44)."""
    return place_of_year(state, _places(state).rostra)


def plan_contio(state: GameState, action: Contio) -> Plan:
    """Check a contio and work out what it would move."""
    why = _common(state, action.civ)
    if why:
        return _no(why)
    rules = _places(state).contio
    rep = state.republic
    assert rep is not None
    place = rostra(state)
    if place is None:
        return _no("Rome has no speakers' platform this year")
    chosen = _speaker(state, action.speaker)
    if chosen is None:
        if action.speaker:
            return _no("only a consul, praetor or tribune in office may call the people")
        return _no("no magistrate in office may call the people")
    speaker, weight = chosen
    if rep.influence < rules.cost:
        return _no(f"not enough influence ({rules.cost} needed)")
    if action.issue == "candidate":
        return _plan_candidate(state, action, place.monument, speaker, weight)
    if action.issue not in {i.value for i in Issue}:
        return _no(f"the people are not asked about {action.issue!r}")
    if action.side not in SIDES:
        return _no("a speech is for or against")
    sign = 1 if action.side == "for" else -1
    base = rules.shift_bp * weight // BP
    shifts: dict[str, int] = {}
    for fid in sorted(rep.families):
        gens = state.world.gentes[fid]
        moved = (
            base
            if gens.popular_lean_bp >= rules.popular_from_bp
            else (base * rules.others_share_bp // BP)
        )
        if moved:
            shifts[fid] = sign * moved
    return Plan(
        influence=rules.cost,
        place=place.monument,
        person=speaker.person,
        numbers={"shift_bp": sign * base, "families": len(shifts), "weight_bp": weight},
        shifts=shifts,
    )


def _plan_candidate(
    state: GameState, action: Contio, place: str, speaker: Magistrate, weight: int
) -> Plan:
    rep = state.republic
    assert rep is not None
    rules = _places(state).contio
    target = state.year + 1
    person = rep.people.get(action.side)
    mag = state.world.magistracies.get(action.office)
    if person is None or not person.alive:
        return _no("no such man is alive")
    if mag is None:
        return _no(f"unknown office {action.office!r}")
    era = mag.era_at(target)
    if era is None or not era.held_in(target) or era.appointed:
        return _no(f"the {mag.name.lower()} is not elected in {year_label(target)}")
    if not eligible(state, person, mag, era, target):
        return _no(f"{person.name} cannot stand for the {mag.name.lower()}")
    bp = rules.candidate_bp * weight // BP
    return Plan(
        influence=rules.cost,
        place=place,
        person=speaker.person,
        numbers={"election_bp": bp, "weight_bp": weight, "year": target},
    )


def apply_contio(state: GameState, action: Contio) -> tuple[bool, str]:
    """Hold a contio: spend influence, move the families (or the voters), note the speech."""
    plan = plan_contio(state, action)
    if not plan.ok:
        return False, plan.why
    rep = state.republic
    assert rep is not None
    rep.influence -= plan.influence
    speaker = _person_name(state, plan.person)
    place = rostra(state)
    where = place.name if place is not None else "the Rostra"
    if action.issue == "candidate":
        bp = plan.numbers["election_bp"]
        rep.backing.append(
            Backing(person=action.side, office=action.office, year=state.year + 1, bp=bp)
        )
        add_event(
            state,
            "contio",
            ref=f"candidate:{action.office}",
            monument=plan.place,
            person=plan.person,
            value=bp,
            other=0,
        )
        man = _person_name(state, action.side)
        office = _office_name(state, action.office).lower()
        return (
            True,
            f"{speaker} speaks for {man} from the {where}: the voters for the {office} hear him.",
        )
    issue = action.issue
    for fid in sorted(plan.shifts):
        family = rep.families[fid]
        family.favour[issue] = clamp(family.favour.get(issue, 0) + plan.shifts[fid], -BP, BP)
    add_event(
        state,
        "contio",
        ref=issue,
        monument=plan.place,
        person=plan.person,
        value=plan.numbers["shift_bp"],
        other=plan.numbers["families"],
    )
    pct = abs(plan.numbers["shift_bp"]) // 100
    return True, (
        f"{speaker} speaks {action.side} the matter of {issue} from the {where}; the families "
        f"who court the people move {pct} points, the rest less."
    )


# ---------------------------------------------------------------- vow


def vow_place(state: GameState) -> PlaceOfYear | None:
    """Where the state's vows are pronounced this year (the Capitol)."""
    return place_of_year(state, _places(state).vow_place)


def vowers(state: GameState) -> list[Magistrate]:
    """Magistrates with imperium who may vow for the state, senior first."""
    rules = _places(state).vow
    return magistrates_of(state, rules.vowers) if rules is not None else []


def _vowable(state: GameState, monument: Monument) -> str:
    """Why a temple cannot be vowed now, or ``""``."""
    rules = _places(state).vow
    city = state.city
    assert rules is not None
    assert city is not None
    if monument.type not in _places(state).temple_types:
        return f"{monument.english or monument.id} is not a temple"
    if any(v.monument == monument.id for v in city.vows):
        return "that temple is already vowed"
    status = city.standing.get(monument.id)
    if status is None or status.state != "planned":
        return "that temple already stands or is being built"
    built = first_year(monument)
    if built is None:
        return "history does not date that temple"
    if built <= state.year + rules.build_years:
        return "history will dedicate it sooner than a vow could"
    if built > state.year + rules.window_years:
        return "its god has no claim on Rome yet"
    return ""


def vow_candidates(state: GameState) -> list[Monument]:
    """Temples history built later that may be vowed now, soonest first (all, not only offered)."""
    if state.city is None or _places(state).vow is None:
        return []
    found = [
        state.world.monuments[mid]
        for mid in sorted(state.world.monuments)
        if not _vowable(state, state.world.monuments[mid])
    ]
    return sorted(found, key=lambda m: (first_year(m) or 0, m.id))


def _cause(state: GameState, cause: str) -> VowCause | None:
    rules = _places(state).vow
    if rules is None:
        return None
    return next((c for c in rules.causes if c.id == cause), None)


def vow_wealth(state: GameState) -> int:
    """What building a vowed temple costs the treasury now."""
    rules = _places(state).vow
    return wealth_cost(state, state.player_civ, rules.wealth_per_1000) if rules is not None else 0


def games_wealth(state: GameState, kind: str) -> int:
    """What games of ``kind`` (``ludi`` or ``munus``) cost the treasury now."""
    rules = _places(state).games
    if rules is None:
        return 0
    per = rules.ludi_wealth_per_1000 if kind == "ludi" else rules.munus_wealth_per_1000
    return wealth_cost(state, state.player_civ, per)


def plan_vow(state: GameState, action: VowTemple) -> Plan:
    """Check a vow and work out its cost and its dedication year."""
    why = _common(state, action.civ)
    if why:
        return _no(why)
    rules = _places(state).vow
    if rules is None:
        return _no("vows are not in this game")
    place = vow_place(state)
    if place is None:
        return _no("there is no temple on the Capitol to vow at this year")
    monument = state.world.monuments.get(action.temple)
    if monument is None:
        return _no(f"unknown temple {action.temple!r}")
    why = _vowable(state, monument)
    if why:
        return _no(why)
    cause = _cause(state, action.cause)
    if cause is None:
        return _no(f"no vow is made {action.cause!r}")
    if cause.needs_war and not at_war(state, state.player_civ):
        return _no("a temple is vowed in battle only when Rome is at war")
    men = vowers(state)
    who = next((m for m in men if not action.by or m.person == action.by), None)
    if who is None:
        return _no("only a magistrate with imperium may vow for the state")
    rep = state.republic
    assert rep is not None
    wealth = vow_wealth(state)
    if rep.influence < rules.cost:
        return _no(f"not enough influence ({rules.cost} needed)")
    if state.civs[state.player_civ].stockpiles.wealth < wealth:
        return _no(f"the treasury cannot pay for the building ({wealth} wealth needed)")
    built = first_year(monument) or 0
    completes = state.year + rules.build_years
    return Plan(
        influence=rules.cost,
        wealth=wealth,
        place=place.monument,
        person=who.person,
        numbers={
            "dedicated": completes,
            "history": built,
            "ahead": built - completes,
            "legitimacy_bp": cause.legitimacy_bp,
            "unrest_bp": cause.unrest_bp,
        },
    )


def apply_vow(state: GameState, action: VowTemple) -> tuple[bool, str]:
    """Pronounce a vow: pay, record it in the city (the temple rises early), note the sacrifice."""
    plan = plan_vow(state, action)
    if not plan.ok:
        return False, plan.why
    rep, city = state.republic, state.city
    assert rep is not None
    assert city is not None
    civ = state.civs[state.player_civ]
    cause = _cause(state, action.cause)
    assert cause is not None
    rep.influence -= plan.influence
    civ.stockpiles.wealth -= plan.wealth
    civ.stats.legitimacy_bp = clamp(civ.stats.legitimacy_bp + cause.legitimacy_bp, 0, BP)
    civ.stats.unrest_bp = clamp(civ.stats.unrest_bp + cause.unrest_bp, 0, BP)
    completes = plan.numbers["dedicated"]
    city.vows.append(
        Vow(
            monument=action.temple,
            cause=action.cause,
            year=state.year,
            completes=completes,
            by=plan.person,
        )
    )
    add_event(
        state, "sacrifice", ref="vow", monument=action.temple, person=plan.person, value=completes
    )
    temple = state.world.monuments[action.temple].english or action.temple
    return True, (
        f"{_person_name(state, plan.person)} vows the {temple} {cause.name}; it is to be "
        f"dedicated in {year_label(completes)}, {plan.numbers['ahead']} years before its time."
    )


# ---------------------------------------------------------------- games


def venues(state: GameState, kind: str) -> list[tuple[str, str]]:
    """Where games of ``kind`` (``ludi`` or ``munus``) can be given this year: (id, name)."""
    rules = _places(state).games
    city = state.city
    if rules is None or city is None:
        return []
    entries = rules.circus if kind == "ludi" else rules.munus_venues
    out = [
        (entry.monument, entry.name)
        for entry in entries
        if place_of_year(state, [entry]) is not None
    ]
    if kind == "munus":
        out += [
            (a.id, a.name)
            for a in city.anachronisms
            if a.builds == rules.arena_builds and a.year <= state.year
        ]
    return out


def honourees(state: GameState) -> list[Person]:
    """Dead men who may be honoured with a munus now, the greatest first."""
    rules = _places(state).games
    rep, city = state.republic, state.city
    if rules is None or rep is None or city is None:
        return []
    done = {g.honour for g in city.given if g.kind == "munus"}
    mags = state.world.magistracies
    found = [
        p
        for p in rep.people.values()
        if not p.alive
        and p.died is not None
        and state.year - rules.munus_window_years <= p.died <= state.year
        and p.id not in done
    ]

    def rank(person: Person) -> int:
        return max((mags[h.office].rank for h in person.offices if h.office in mags), default=-1)

    return sorted(found, key=lambda p: (-rank(p), -p.glory, p.id))


def givers(state: GameState) -> list[Magistrate]:
    """The aediles in office, who give the regular games."""
    rules = _places(state).games
    return magistrates_of(state, rules.givers) if rules is not None else []


def _family_giver(state: GameState, dead: Person, wanted: str) -> Person | None:
    rep = state.republic
    assert rep is not None
    kin = sorted(
        (p for p in rep.people.values() if p.alive and p.gens == dead.gens),
        key=lambda p: (-p.glory, p.id),
    )
    return next((p for p in kin if not wanted or p.id == wanted), None)


def plan_games(state: GameState, action: GiveGames) -> Plan:
    """Check games and work out what they cost and do."""
    why = _common(state, action.civ)
    if why:
        return _no(why)
    rules = _places(state).games
    if rules is None:
        return _no("games are not in this game")
    city = state.city
    assert city is not None
    if action.games not in ("ludi", "munus"):
        return _no("games are races (ludi) or a munus")
    names = dict(venues(state, action.games))
    if action.venue not in names:
        return _no("games of that kind are not given there this year")
    held = sum(1 for g in city.given if g.venue == action.venue and g.year == state.year)
    if held >= rules.per_venue_per_year:
        return _no(f"games have been given at {names[action.venue]} this year")
    civ = state.civs[state.player_civ]
    if action.games == "ludi":
        men = givers(state)
        giver = next((m.person for m in men if not action.giver or m.person == action.giver), "")
        if not giver:
            return _no("only an aedile in office gives the games")
        wealth = games_wealth(state, "ludi")
        numbers = {
            "legitimacy_bp": rules.ludi_legitimacy_bp,
            "unrest_bp": rules.ludi_unrest_bp,
            "dignitas_bp": rules.giver_dignitas_bp,
            "glory": rules.giver_glory,
        }
    else:
        rep = state.republic
        assert rep is not None
        dead = rep.people.get(action.honour)
        if dead is None or dead not in honourees(state):
            return _no("a munus honours a man of note who died in these last years")
        kin = _family_giver(state, dead, action.giver)
        if kin is None:
            return _no(f"no man of the {dead.gens} is alive to give the munus")
        giver = kin.id
        wealth = games_wealth(state, "munus")
        numbers = {
            "legitimacy_bp": 0,
            "unrest_bp": rules.munus_unrest_bp,
            "dignitas_bp": rules.munus_dignitas_bp,
            "glory": 0,
        }
    if civ.stockpiles.wealth < wealth:
        return _no(f"the treasury cannot pay for the games ({wealth} wealth needed)")
    return Plan(wealth=wealth, place=action.venue, person=giver, numbers=numbers)


def apply_games(state: GameState, action: GiveGames) -> tuple[bool, str]:
    """Give games: pay, quiet the people, raise the giver's family; note the race or the munus."""
    plan = plan_games(state, action)
    if not plan.ok:
        return False, plan.why
    rep, city = state.republic, state.city
    assert rep is not None
    assert city is not None
    civ = state.civs[state.player_civ]
    civ.stockpiles.wealth -= plan.wealth
    before = civ.stats.unrest_bp
    civ.stats.unrest_bp = clamp(before + plan.numbers["unrest_bp"], 0, BP)
    civ.stats.legitimacy_bp = clamp(civ.stats.legitimacy_bp + plan.numbers["legitimacy_bp"], 0, BP)
    giver = rep.people[plan.person]
    giver.glory += plan.numbers["glory"]
    family = rep.families.get(giver.gens)
    if family is not None:
        family.dignitas_bp += plan.numbers["dignitas_bp"]
    city.given.append(
        GamesGiven(
            kind=action.games,
            venue=action.venue,
            year=state.year,
            giver=plan.person,
            honour=action.honour if action.games == "munus" else "",
        )
    )
    city.given = [g for g in city.given if g.year > state.year - GIVEN_KEPT_YEARS]
    relieved = before - civ.stats.unrest_bp
    venue = dict(venues(state, action.games)).get(action.venue, action.venue)
    if action.games == "ludi":
        add_event(
            state,
            "race",
            ref="ludi",
            monument=action.venue,
            person=plan.person,
            value=plan.wealth,
            other=relieved,
        )
        return True, (
            f"{giver.name} gives races in the {venue} ({plan.wealth} wealth); the people cheer "
            "his name."
        )
    add_event(
        state,
        "munus",
        ref=plan.person,
        monument=action.venue,
        person=action.honour,
        value=plan.wealth,
        other=relieved,
    )
    dead = _person_name(state, action.honour)
    return True, f"{giver.name} gives a munus for {dead} at {venue} ({plan.wealth} wealth)."


# ---------------------------------------------------------------- site


def site_options(state: GameState, tech: str) -> list[tuple[str, str]]:
    """The sites a great work of this idea may take: (id, description), history's first."""
    node = state.tech_nodes.get(tech)
    if node is None or not node.builds:
        return []
    form = work_form(node.builds)
    out = [(HISTORY_SITE, form.site if form is not None else "history's site")]
    out += [
        (site.id, site.name)
        for site in _places(state).site.sites
        if site.builds == node.builds and site.at in state.world.monuments
    ]
    return out


def chosen_site(state: GameState, tech: str) -> str:
    """The site chosen for an idea's work (``history`` unless the player chose another)."""
    city = state.city
    return city.sites.get(tech, HISTORY_SITE) if city is not None else HISTORY_SITE


def plan_site(state: GameState, action: ChooseSite) -> Plan:
    """Check a choice of site."""
    why = _common(state, action.civ)
    if why:
        return _no(why)
    city = state.city
    assert city is not None
    civ = state.civs[state.player_civ]
    node = state.tech_nodes.get(action.tech)
    if node is None or not node.builds:
        return _no("that idea raises no great work in the city")
    if action.tech not in civ.tech and action.tech not in civ.projects:
        return _no(f"{node.name} is not yet known in Rome")
    if any(a.tech == action.tech for a in city.anachronisms):
        return _no(f"the {node.name.lower()} already stands")
    options = dict(site_options(state, action.tech))
    if action.site not in options:
        return _no("that is not a site for it")
    if chosen_site(state, action.tech) == action.site:
        return _no("that site is already chosen")
    rep = state.republic
    assert rep is not None
    cost = _places(state).site.cost
    if rep.influence < cost:
        return _no(f"not enough influence ({cost} needed)")
    project = civ.projects.get(action.tech)
    progress = project.progress_bp if project is not None else 0
    return Plan(
        influence=cost,
        place=f"anachronism_{action.tech}",
        numbers={"progress_bp": progress},
    )


def apply_site(state: GameState, action: ChooseSite) -> tuple[bool, str]:
    """Choose where an idea's great work will rise."""
    plan = plan_site(state, action)
    if not plan.ok:
        return False, plan.why
    rep, city = state.republic, state.city
    assert rep is not None
    assert city is not None
    rep.influence -= plan.influence
    if action.site == HISTORY_SITE:
        city.sites.pop(action.tech, None)
    else:
        city.sites[action.tech] = action.site
    city.sites = dict(sorted(city.sites.items()))
    add_event(
        state,
        "building",
        ref=action.tech,
        monument=plan.place,
        value=plan.numbers["progress_bp"],
        other=1,
    )
    where = dict(site_options(state, action.tech))[action.site]
    return True, f"The {state.tech_nodes[action.tech].name.lower()} will rise at {where}."


# ---------------------------------------------------------------- levy


def levy_place(state: GameState) -> PlaceOfYear | None:
    """Where the levy is held this year (the Villa Publica on the Campus, from 435)."""
    return place_of_year(state, _places(state).levy)


def levy_event(state: GameState, army: str, men: int) -> None:
    """A ``raise`` by the player in a Republic game plays the dilectus (``levy``) on the Campus."""
    if state.city is None or state.republic is None or men <= 0:
        return
    place = levy_place(state)
    society = state.rome_society
    pool = society.legions.assidui if society is not None else 0
    add_event(
        state,
        "levy",
        ref=army,
        monument=place.monument if place is not None else "",
        value=men,
        other=pool,
    )
