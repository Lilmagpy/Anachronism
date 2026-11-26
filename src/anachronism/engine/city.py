"""The city of Rome, year by year (U7): what stands, and what happens there.

The 3D city is driven by this module and saved with the game. Each monument has a life read
from the dataset (``built.year`` is its dedication, ``ended`` its end) and from the content's
``city_timeline`` (vows, building work, fires, rebuilding, demolition, floods). A monument's
status in any year is a pure function of those, so a new game starts at the right place and the
yearly step only has to notice what changed. On top of that: the games of the year by the
calendar in ``republic_rules.city``, funeral games for dead notables, the Senate's votes, and
a triumph after a decisive victory or the taking of an enemy capital.

Integers and ids only; every loop runs in sorted order; no randomness is needed.
"""

from __future__ import annotations

import math
from collections.abc import Iterable
from dataclasses import dataclass, replace

from anachronism.content.schema import CityTimeline, Monument
from anachronism.content.schema.places import Assembly, PlaceOfYear
from anachronism.engine.city_state import (
    Anachronism,
    CityEvent,
    CityState,
    EventKind,
    MonumentStatus,
    Vow,
)
from anachronism.engine.events import EventLog
from anachronism.engine.state import GameState, World

# Within one year: destruction first, then new work, then completion (so "burned and rebuilt"
# in one year ends standing).
_ORDER = {"fire": 0, "demolished": 0, "begun": 1, "completed": 2, "vowed": 3, "flood": 3}

Mark = tuple[int, int, str]
"""(year, order within the year, kind)."""


# --- F2 city accuracy: timeline fixes (marks_for) -----------------------------------------
# Three rules (F2, see docs/reports/city_audit.md section 4):
# - a timeline ``completed`` never erases an earlier, separate ``built.year``: it replaces it
#   only when the dataset year is the start of that same work (a ``begun`` on or before it) or
#   is not earlier than the completion (the Forum, finished c. 600 BC, rebuilt after the fire
#   of 210, stays standing before 210);
# - ``ended`` is the last thing in its year, so a building put up and removed in one year (a
#   temporary theatre) ends;
# - the dataset's ``phases`` (the client's form changes) count: ``gone`` is a demolition,
#   ``burnt`` a fire, ``building`` new work, and ``standing`` after one of those a completion.
_ORDER_END = 4
"""``ended`` sorts after everything else in its year."""

_PHASE_KIND = {"gone": "demolished", "burnt": "fire", "building": "begun"}


def phase_marks(monument: Monument) -> list[Mark]:
    """The marks the dataset's ``phases`` imply (a standing phase only after a break)."""
    phases = (monument.model_extra or {}).get("phases") or []
    out: list[Mark] = []
    broken = False
    for ph in sorted(phases, key=lambda p: int(p["from"])):
        year, state = int(ph["from"]), str(ph.get("state", ""))
        kind = _PHASE_KIND.get(state)
        if kind is not None:
            out.append((year, _ORDER[kind], kind))
            broken = True
        elif state.startswith("standing") and broken:
            out.append((year, _ORDER["completed"], "completed"))
            broken = False
    return out


def marks_for(monument: Monument, timeline: Iterable[CityTimeline]) -> list[Mark]:
    """Every turning point of a monument, sorted: its dataset dates and its timeline entries.

    The dataset's ``built.year`` is a completion. A timeline completion replaces it only when
    the dataset year is the start of that same work (a building begun by Caesar and dedicated
    by Augustus) or is not earlier than it, and never across a fire or demolition. ``ended`` is
    a demolition, the last event of its year. The dataset's ``phases`` add their own marks
    where the timeline does not already have them.
    """
    explicit = [t for t in timeline if t.monument == monument.id]
    marks: list[Mark] = [(t.year, _ORDER[t.kind], t.kind) for t in explicit]
    have = {(y, k) for y, _, k in marks}
    marks += [m for m in phase_marks(monument) if (m[0], m[2]) not in have]
    destroyed = [y for y, _, k in marks if k in ("fire", "demolished")]
    if monument.ended is not None and monument.ended.year is not None:
        destroyed.append(monument.ended.year)
        marks.append((monument.ended.year, _ORDER_END, "demolished"))
    built = first_year(monument)
    if built is not None:
        first_done = min((t.year for t in explicit if t.kind == "completed"), default=None)
        # F2 places: a fire and a rebuilding in one year is a rebuilding (the Forum's shops, 210);
        # F2 city accuracy: a later completion replaces the built year only for the same work
        replaced = False
        if first_done is not None and not any(y <= first_done for y in destroyed):
            same_work = any(t.kind == "begun" and t.year <= built for t in explicit)
            replaced = built >= first_done or same_work
        if not replaced:
            marks.append((built, _ORDER["completed"], "completed"))
    return sorted(marks)


# --- end F2 timeline fixes -------------------------------------------------------------------


def first_year(monument: Monument) -> int | None:
    """The year the monument was finished, if known.

    With no building date but a floor from the sources ("after 27 BC"), it stands from
    the floor. A monument with no dates at all has always stood.
    """
    if monument.built is None:
        return None
    if monument.built.year is not None:
        return monument.built.year
    return monument.built.not_before


def status_at(marks: list[Mark], year: int, built_known: bool) -> MonumentStatus:
    """A monument's status in ``year``. With no known building date it has always stood."""
    state = "standing" if not built_known else "planned"
    since = 0
    for y, _, kind in marks:
        if y > year:
            break
        if kind == "fire":
            state, since = "burnt", y
        elif kind == "demolished":
            state, since = "ruined", y
        elif kind == "begun":
            if state == "planned":
                state, since = "building", y
            # after a fire or demolition the work goes on but the monument stays burnt/ruined
            # until it is completed (years_left says how long)
        elif kind == "completed":
            state, since = "standing", y
    left = 0
    if state in ("building", "burnt", "ruined"):
        begun = any(k == "begun" and y <= year for y, _, k in marks)
        finish = min((y for y, _, k in marks if k == "completed" and y > year), default=None)
        if begun and finish is not None:
            left = finish - year
    return MonumentStatus(state=state, years_left=left, since=since)


def status_map(world: World, year: int, vows: Iterable[Vow] = ()) -> dict[str, MonumentStatus]:
    """The status of every monument in ``year`` (sorted by id), from the dataset and timeline.

    F2: ``vows`` are the player's vowed temples (``CityState.vows``), which rise early.
    """
    by_monument = timelines(world, vows)  # F2 places: the content's timeline + the player's vows
    return {
        mid: status_at(
            marks_for(world.monuments[mid], by_monument.get(mid, [])),
            year,
            first_year(world.monuments[mid]) is not None,
        )
        for mid in sorted(world.monuments)
    }


def start_city(state: GameState, turn: int) -> None:
    """Create the city at the scenario's start year, with that year's games."""
    city = CityState(year=state.year, standing=status_map(state.world, state.year))
    state.city = city
    if state.republic is not None:  # the already dead had their funerals before the game began
        city.funerals = sorted(p for p, man in state.republic.people.items() if not man.alive)
    _games(state, city, state.year, turn)


def run_year(state: GameState, events: EventLog, year: int) -> None:
    """Bring the city to ``year``: monuments change, games and fires and floods are held.

    Called from ``republic.run_year`` after the people have been through the year, so deaths
    already show. Events of earlier turns are dropped when a new turn's first year begins.
    """
    city = state.city
    if city is None or year <= city.year:
        return
    city.events = [e for e in city.events if e.turn >= events.turn]
    new = status_map(state.world, year, city.vows)  # F2 places: + vows
    city.changed = [mid for mid in sorted(new) if new[mid].state != city.standing[mid].state]
    city.standing = new
    first = city.year + 1
    by_monument = timelines(state.world, city.vows)  # F2 places: + vows
    for mid in sorted(state.world.monuments):
        monument = state.world.monuments[mid]
        for y, _, kind in marks_for(monument, by_monument.get(mid, [])):
            if not first <= y <= year:
                continue
            if kind == "completed":
                _add(city, "sacrifice", y, events, ref="dedication", monument=mid)
            elif kind == "vowed" and not _vowed_by_player(city, mid, y):  # F2 places
                _add(city, "sacrifice", y, events, ref="vow", monument=mid)
            elif kind == "fire":
                _add(city, "fire", y, events, monument=mid)
            elif kind == "flood":
                _add(city, "flood", y, events, monument=mid)
    for y in range(first, year + 1):
        _games(state, city, y, events.turn)
    _funerals(state, city, year, events.turn)
    if year == state.year:
        _anachronisms(state, city, events)
        _triumphs(state, city, events)
    city.year = year


def _add(
    city: CityState, kind: EventKind, year: int, events: EventLog, *, ref: str = "", monument: str
) -> None:
    city.events.append(
        CityEvent(kind=kind, year=year, turn=events.turn, ref=ref, monument=monument)
    )


def _games(state: GameState, city: CityState, year: int, turn: int) -> None:
    """The festivals of the calendar held this year, in month order."""
    ludi = sorted(state.world.republic_rules.city.ludi, key=lambda lu: (lu.month, lu.id))
    for ludus in ludi:
        if year >= ludus.from_year:
            city.events.append(
                CityEvent(
                    kind="games",
                    year=year,
                    turn=turn,
                    ref=ludus.id,
                    monument=ludus.venue,
                    value=ludus.month,
                )
            )


def _funerals(state: GameState, city: CityState, year: int, turn: int) -> None:
    """Funeral games (munus) for notables who have died: Livy Per. 16 for the first, 264 BC."""
    rules = state.world.republic_rules.city
    rep = state.republic
    if rep is None or rules.munus_venue is None:
        return
    for pid in sorted(rep.people):
        person = rep.people[pid]
        if person.alive or person.died is None or pid in city.funerals:
            continue
        if person.died < city.year or person.died > year or person.died < rules.munus_from_year:
            continue
        rank = max((state.world.magistracies[h.office].rank for h in person.offices), default=-1)
        if rank >= rules.munus_min_rank:
            city.funerals.append(pid)
            city.funerals.sort()
            city.events.append(
                CityEvent(
                    kind="games",
                    year=person.died,
                    turn=turn,
                    ref="munus",
                    monument=rules.munus_venue,
                    person=pid,
                )
            )


# --- F1 ideas: the works an idea raises in the city, and where they stand -------------------


@dataclass(frozen=True)
class WorkForm:
    """How the 3D city draws the work a ``builds`` kind raises, and where (F1 ideas).

    The work stands on the site of the real building that history raised later, with that
    building's dimensions (``twin``: the dataset monument whose site it takes and which
    replaces it when history catches up; drawn only while the twin is absent). ``lat``/``lon``
    and ``offset`` are the site, ``bearing`` the compass bearing of the front, ``model`` the
    Urbs kit form (monument_forms.gd / anachronisms.gd), ``route_of`` a dataset monument whose
    route a linear work follows. ``site`` and ``source`` say which real building the place and
    size come from; the client's card shows them.
    """

    model: str
    latin: str
    english: str
    lat: float
    lon: float
    bearing: int = 0
    offset: tuple[int, int] = (0, 0)
    length: float = 0.0
    width: float = 0.0
    radius: float = 0.0
    height: float = 0.0
    twin: str = ""
    route_of: str = ""
    arcade_m: int = 0
    site: str = ""
    source: str = ""


BUILD_FORMS: dict[str, WorkForm] = {
    "aqueduct": WorkForm(
        "aqueduct",
        "Aqua nova",
        "An aqueduct",
        41.889,
        12.48,
        height=8.0,
        twin="aqua_appia",
        route_of="aqua_appia",
        arcade_m=300,
        site="the course of the Aqua Appia (312 BC), on arches for its last 300 m",
        source="Frontinus, De aquaeductu 5; Livy 9.29.6",
    ),
    "road": WorkForm(
        "road_paved",
        "Via lapide strata",
        "A paved road",
        41.8855,
        12.4885,
        bearing=135,
        length=600.0,
        width=4.1,
        route_of="via_appia",
        site="the first 600 m of the Via Appia outside the Porta Capena, paved 296 BC",
        source="Livy 9.29.6; Livy 10.23.12",
    ),
    "concrete_hall": WorkForm(
        "long_hall",
        "Porticus caementicia",
        "A vaulted concrete hall",
        41.88,
        12.4736,
        bearing=45,
        length=60.0,
        width=200.0,
        height=9.0,
        twin="porticus_aemilia",
        site="the Emporium, where the Porticus Aemilia (193 BC) stood, at a third of its length",
        source="Livy 35.10.12; Platner-Ashby s.v. Porticus Aemilia",
    ),
    "basilica": WorkForm(
        "basilica",
        "Basilica",
        "A basilica",
        41.893004,
        12.484902,
        bearing=196,
        length=16.0,
        width=26.0,
        twin="basilica_porcia",
        site="the site of the Basilica Porcia (184 BC) beside the Curia",
        source="Livy 39.44.7; Platner-Ashby s.v. Basilica Porcia",
    ),
    "bridge_stone": WorkForm(
        "bridge_stone",
        "Pons lapideus",
        "A stone bridge",
        41.8884,
        12.4789,
        bearing=255,
        length=100.0,
        width=8.0,
        height=11.0,
        twin="pons_aemilius",
        site="the crossing of the Pons Aemilius (piers 179 BC, arches 142 BC)",
        source="Livy 40.51.4; Platner-Ashby s.v. Pons Aemilius",
    ),
    "theatre_stone": WorkForm(
        "theatre_stone",
        "Theatrum lapideum",
        "A stone theatre",
        41.8958,
        12.4743,
        bearing=134,
        offset=(-58, -56),
        radius=77.5,
        twin="theatrum_pompei",
        site="the site and size of the Theatre of Pompey (55 BC), 150 m across",
        source="Plutarch, Pompey 42.4; Platner-Ashby s.v. Theatrum Pompei",
    ),
    "amphitheatre": WorkForm(
        "amphitheatre_flavian",
        "Amphitheatrum",
        "A stone amphitheatre",
        41.8902,
        12.4922,
        bearing=120,
        length=188.0,
        width=156.0,
        height=48.5,
        twin="amphitheatrum_flavium",
        site="the valley where the Flavian Amphitheatre (AD 80) rose, at its size, 188 by 156 m",
        source="Dio 51.23.1; Platner-Ashby s.v. Amphitheatrum Flavium",
    ),
    "baths": WorkForm(
        "baths",
        "Thermae",
        "Public baths with a hypocaust",
        41.898,
        12.478,
        bearing=180,
        offset=(-83, -121),
        length=100.0,
        width=80.0,
        height=20.0,
        twin="thermae_agrippae",
        site="the site of the Baths of Agrippa (25 BC) in the Campus Martius",
        source="Dio 53.27.1; Platner-Ashby s.v. Thermae Agrippae",
    ),
    "dome": WorkForm(
        "rotunda_dome",
        "Tholus caementicius",
        "A concrete dome",
        41.8986,
        12.4768,
        bearing=0,
        radius=21.6,
        height=43.2,
        twin="pantheon_agrippae",
        site="the site of the Pantheon, at the rotunda's size: 43.2 m across and as high",
        source="Platner-Ashby s.v. Pantheon; Dio 53.27.2",
    ),
    "harbour": WorkForm(
        "quay",
        "Portus",
        "A stone harbour quay",
        41.8823,
        12.475185,
        bearing=270,
        length=500.0,
        width=40.0,
        twin="emporium",
        site="the Tiber bank below the Aventine where the Emporium's quays (193 BC) stood",
        source="Livy 35.10.12; Livy 41.27.8",
    ),
    "granary": WorkForm(
        "horrea",
        "Horrea publica",
        "Public granaries",
        41.883,
        12.478,
        bearing=45,
        length=100.0,
        width=120.0,
        height=12.0,
        twin="horrea_sempronia",
        site="the site of the Horrea Sempronia (123 BC) by the Aventine, at half the Galbae's size",
        source="Plutarch, C. Gracchus 6.3; Platner-Ashby s.v. Horrea Galbae",
    ),
    "library": WorkForm(
        "archive_hall",
        "Bibliotheca publica",
        "A public library",
        41.8947,
        12.4852,
        bearing=178,
        offset=(60, -40),
        length=30.0,
        width=40.0,
        height=10.0,
        site="beside the Atrium Libertatis, where Pollio opened the first public library (39 BC)",
        source="Pliny NH 7.115; Platner-Ashby s.v. Atrium Libertatis",
    ),
    "sundial": WorkForm(
        "sundial",
        "Solarium",
        "A sundial",
        41.8926,
        12.4846,
        bearing=196,
        offset=(46, 10),
        length=3.0,
        width=3.0,
        height=2.5,
        site="by the Rostra, where Valerius Messalla's sundial from Catania stood (263 BC)",
        source="Pliny NH 7.214; Censorinus 23.6",
    ),
    "water_clock": WorkForm(
        "water_clock",
        "Horologium ex aqua",
        "A water clock",
        41.8926,
        12.4846,
        bearing=196,
        offset=(46, -14),
        length=4.0,
        width=4.0,
        height=6.0,
        site="by the Rostra, near Scipio Nasica's roofed water clock (159 BC)",
        source="Pliny NH 7.215; Censorinus 23.7",
    ),
    "fire_station": WorkForm(
        "statio_vigilum",
        "Statio vigilum",
        "A fire station",
        41.8925,
        12.4853,
        bearing=270,
        offset=(260, -150),
        length=30.0,
        width=36.0,
        height=9.0,
        site="at the edge of the Subura, where the vigiles' stations (AD 6) kept their pumps",
        source="Dio 55.26.4-5; Suetonius, Augustus 30.1",
    ),
    "sewer_outfall": WorkForm(
        "sewer",
        "Cloaca Aventina",
        "A vaulted sewer's outfall",
        41.888,
        12.479662,
        bearing=250,
        offset=(-70, 10),
        width=3.2,
        height=4.2,
        site="the Tiber bank by the Porta Trigemina, for the Aventine's sewers (184 BC)",
        source="Livy 39.44.5; Platner-Ashby s.v. Cloaca Maxima",
    ),
    "mill": WorkForm(
        "mill",
        "Mola aquaria",
        "A water mill",
        41.8884,
        12.4789,
        bearing=165,
        offset=(70, 30),
        length=10.0,
        width=8.0,
        height=7.0,
        site="the Tiber bank below the Pons Aemilius; Rome's own mills stood on the Janiculum",
        source="Vitruvius 10.5.2",
    ),
    "arch": WorkForm(
        "arch",
        "Fornix",
        "A commemorative arch",
        41.8921,
        12.487,
        bearing=106,
        length=6.0,
        width=12.0,
        height=12.0,
        twin="fornix_fabianus",
        site="the Sacra Via where the Fornix Fabianus (121 BC) spanned it",
        source="Cicero, In Verrem 1.19; Platner-Ashby s.v. Fornix Fabianus",
    ),
    "temple_marble": WorkForm(
        "temple_hexastyle_corinthian_marble",
        "Aedes marmorea",
        "A marble temple",
        41.8923,
        12.4793,
        bearing=225,
        length=35.0,
        width=20.0,
        twin="aedes_iovis_statoris_metelli",
        site="the site of Metellus' marble temple of Jupiter Stator (146 BC)",
        source="Velleius 1.11.3-5; Vitruvius 3.2.5",
    ),
    "portico": WorkForm(
        "portico_enclosure",
        "Porticus",
        "A colonnaded portico",
        41.8925,
        12.4786,
        bearing=225,
        length=130.0,
        width=118.0,
        height=10.0,
        twin="porticus_octaviae",
        site="the site of the Porticus Metelli (146 BC) by the Circus Flaminius",
        source="Velleius 1.11.3; Platner-Ashby s.v. Porticus Octaviae",
    ),
}
"""Every ``builds`` kind in the content maps here (tests enforce it)."""


def work_form(builds: str) -> WorkForm | None:
    """The form and site for a ``builds`` kind, if the city can draw it."""
    return BUILD_FORMS.get(builds)


def _anachronisms(state: GameState, city: CityState, events: EventLog) -> None:
    """A project with ``builds`` that has been adopted raises its work in the city."""
    civ = state.civs.get(state.player_civ)
    if civ is None:
        return
    have = {a.tech for a in city.anachronisms}
    for tid in sorted(civ.tech):
        tech = civ.tech[tid]
        node = state.tech_nodes.get(tid)
        if node is None or not node.builds or tid in have:
            continue
        if not tech.stage.is_adopted or tech.adopted_year is None:
            continue
        mid = f"anachronism_{tid}"
        city.anachronisms.append(
            Anachronism(
                id=mid,
                tech=tid,
                name=node.name,
                builds=node.builds,
                year=tech.adopted_year,
                ahead=max(0, node.year - tech.adopted_year),
            )
        )
        _add(city, "sacrifice", state.year, events, ref="dedication", monument=mid)


def senate_house(state: GameState) -> str:
    """The building where the Senate sits, else ``""``.

    F2: the house of the year from ``places.senate_houses`` (Curia Hostilia, Sulla's Curia
    Cornelia from 80, the Curia Pompeia from 52, the Curia Iulia from 44); without that table,
    the first of ``senate_houses`` that stands.
    """
    city = state.city
    if city is None:
        return ""
    found = place_of_year(state, state.world.republic_rules.city.places.senate_houses)  # F2
    if found is not None:  # F2 places: the house of the year
        return found.monument
    for mid in state.world.republic_rules.city.senate_houses:
        status = city.standing.get(mid)
        if status is not None and status.state == "standing":
            return mid
    return ""


def record_vote(
    state: GameState,
    issue: str,
    yes_bp: int,
    no_bp: int,
    *,
    turn: int | None = None,
    year: int | None = None,
) -> None:
    """Note a Senate vote as a ``senate`` event for the 3D city to play.

    A vote taken while a turn resolves belongs to the turn being resolved: the caller passes
    its ``turn`` and ``year`` (the yearly step drops the events of older turns).
    """
    if state.city is None:
        return
    state.city.events.append(
        CityEvent(
            kind="senate",
            year=state.year if year is None else year,
            turn=state.turn if turn is None else turn,
            ref=issue,
            monument=senate_house(state),
            value=yes_bp,
            other=no_bp,
        )
    )


def _triumphator(state: GameState) -> str:
    """The senior magistrate in office: the general who is granted the triumph."""
    rep = state.republic
    if rep is None:
        return ""
    best: tuple[int, str] | None = None
    for m in rep.magistrates:
        rank = state.world.magistracies[m.office].rank
        key = (rank, m.person)
        if rank >= 5 and (best is None or key > best):
            best = key
    return best[1] if best else ""


def _triumphs(state: GameState, city: CityState, events: EventLog) -> None:
    """A decisive victory or an enemy capital taken earns the player's general a triumph."""
    for item in events.items:
        if item.civ != state.player_civ:
            continue
        capital = item.kind == "spoils" and bool(item.spoils.get("capital"))
        decisive = item.kind == "battle_won" and item.sides.get("decisive") == "1"
        if capital or decisive:
            city.events.append(
                CityEvent(
                    kind="triumph",
                    year=state.year,
                    turn=events.turn,
                    ref="capital" if capital else "battle",
                    person=_triumphator(state),
                    value=int(item.spoils.get("wealth", 0)) if capital else 0,
                )
            )


# --- F2 places (D-304): one block, apart from the timeline and the rest of the city ----------
# (in-body hooks elsewhere are single lines marked "F2 places")


def timelines(world: World, vows: Iterable[Vow] = ()) -> dict[str, list[CityTimeline]]:
    """Each monument's timeline: the content's, with the player's vows (F2) in place.

    A temple the player vowed is begun the year after the vow and dedicated in the vow's
    ``completes`` year; history's own vow, building and dedication of it after the player's
    vow are dropped (the player's vow has taken their place). Fires and floods stay.
    """
    by_monument: dict[str, list[CityTimeline]] = {}
    for turn in world.city_timeline:
        by_monument.setdefault(turn.monument, []).append(turn)
    for vow in vows:
        kept = [
            t
            for t in by_monument.get(vow.monument, [])
            if t.kind not in ("vowed", "begun", "completed") or t.year < vow.year
        ]
        source = "the player's vow (F2)"
        kept += [
            CityTimeline(
                id=f"vow_{vow.monument}_{kind}",
                monument=vow.monument,
                year=year,
                kind=kind,
                source=source,
            )
            for year, kind in (
                (vow.year, "vowed"),
                (min(vow.year + 1, vow.completes), "begun"),
                (vow.completes, "completed"),
            )
        ]
        by_monument[vow.monument] = kept
    return by_monument


def place_of_year(
    state: GameState, entries: Iterable[PlaceOfYear], year: int | None = None
) -> PlaceOfYear | None:
    """The first building of ``entries`` serving in the year (F2 places, D-304).

    It must be in the year's span and standing (or, for one that serves ``while_building``,
    being built or rebuilt).
    """
    city = state.city
    if city is None:
        return None
    when = state.year if year is None else year
    for entry in entries:
        status = city.standing.get(entry.monument)
        if status is None or not entry.holds(when):
            continue
        if status.state == "standing" or (
            entry.while_building and status.state in ("building", "burnt")
        ):
            return entry
    return None


METRES_PER_DEGREE_LAT = 111_320.0
"""For placing a site's offset (display only: the engine's state holds ids, not positions)."""


def site_form(state: GameState, tech: str, builds: str) -> WorkForm | None:
    """The form of an idea's work at the site the player chose (F2 ``site``), else history's.

    A chosen site takes the ground of a dataset monument (plus its offset in metres); the work
    no longer stands in for history's building there, so it has no ``twin`` or route.
    """
    form = work_form(builds)
    city = state.city
    if form is None or city is None or tech not in city.sites:
        return form
    site = next(
        (s for s in state.world.republic_rules.city.places.site.sites if s.id == city.sites[tech]),
        None,
    )
    ground = state.world.monuments.get(site.at) if site is not None else None
    if site is None or ground is None:
        return form
    east, north = site.offset_m
    lat = ground.lat + north / METRES_PER_DEGREE_LAT
    lon = ground.lon + east / (METRES_PER_DEGREE_LAT * math.cos(math.radians(ground.lat)))
    return replace(
        form,
        lat=round(lat, 6),
        lon=round(lon, 6),
        bearing=site.bearing if site.bearing is not None else form.bearing,
        offset=(0, 0),
        twin="",
        route_of="",
        site=site.name,
        source=site.source,
    )


def assembly_place(state: GameState, office: str, year: int | None = None) -> str:
    """Where the assembly that elects ``office`` meets in the year (a monument id, or ``""``)."""
    for assembly in state.world.republic_rules.city.places.assemblies:
        if office in assembly.offices:
            found = place_of_year(state, assembly.places, year)
            return found.monument if found is not None else ""
    return ""


def add_event(state: GameState, kind: EventKind, **fields: str | int) -> None:
    """Note a spectacle of the player's action this turn (F2), if the city exists."""
    if state.city is None:
        return
    state.city.events.append(
        CityEvent(kind=kind, year=state.year, turn=state.turn, **fields)  # type: ignore[arg-type]
    )


def assembly_of(state: GameState, office: str) -> Assembly | None:
    """The assembly that elects ``office``."""
    for assembly in state.world.republic_rules.city.places.assemblies:
        if office in assembly.offices:
            return assembly
    return None


def votes(state: GameState, office: str, year: int, share_bp: int, won: bool) -> tuple[int, int]:
    """The voting units for and against a man.

    His expected share of them, and a majority if he was elected (the centuries voted until a
    majority was reached: Livy 1.43.11), short of one if he was not. Without an assembly for
    the office: his share in bp.
    """
    assembly = assembly_of(state, office)
    units = assembly.units_in(year) if assembly is not None else 10_000
    majority = units // 2 + 1
    count = units * share_bp // 10_000
    count = max(count, majority) if won else min(count, majority - 1)
    return count, units - count


def election_events(
    state: GameState, events: EventLog, year: int, shares: dict[tuple[str, str], int]
) -> None:
    """After a year's elections, an ``election`` for each man the player backed (F2).

    Called from ``republic.run_year`` once the year's magistrates are chosen, with each man's
    expected share of the vote (``republic.backed_shares``): ``value``/``other`` are the voting
    units (centuries, tribes) for and against him; he was elected when ``value > other``.
    """
    rep = state.republic
    city = state.city
    if rep is None or city is None:
        return
    seen: set[tuple[str, str]] = set()
    for backing in sorted(rep.backing, key=lambda b: (b.office, b.person)):
        key = (backing.office, backing.person)
        if backing.year != year or key in seen:
            continue
        seen.add(key)
        holders = [m for m in rep.magistrates if m.office == backing.office and m.year == year]
        won = any(m.person == backing.person for m in holders)
        yes, no = votes(state, backing.office, year, shares.get(key, 0), won)
        city.events.append(
            CityEvent(
                kind="election",
                year=year,
                turn=events.turn,
                ref=backing.office,
                monument=assembly_place(state, backing.office, year),
                person=backing.person,
                value=yes,
                other=no,
            )
        )


def _vowed_by_player(city: CityState, monument: str, year: int) -> bool:
    """A player's vow played its sacrifice when it was pronounced, not again at year's end."""
    return any(v.monument == monument and v.year == year for v in city.vows)
