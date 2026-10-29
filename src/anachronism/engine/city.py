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

from collections.abc import Iterable

from anachronism.content.schema import CityTimeline, Monument
from anachronism.engine.city_state import (
    Anachronism,
    CityEvent,
    CityState,
    EventKind,
    MonumentStatus,
)
from anachronism.engine.events import EventLog
from anachronism.engine.state import GameState, World

# Within one year: destruction first, then new work, then completion (so "burned and rebuilt"
# in one year ends standing).
_ORDER = {"fire": 0, "demolished": 0, "begun": 1, "completed": 2, "vowed": 3, "flood": 3}

Mark = tuple[int, int, str]
"""(year, order within the year, kind)."""


def marks_for(monument: Monument, timeline: Iterable[CityTimeline]) -> list[Mark]:
    """Every turning point of a monument, sorted: its dataset dates and its timeline entries.

    The dataset's ``built.year`` is a completion unless the timeline gives an explicit one
    that is not a rebuilding (no fire or demolition before it): then the explicit year
    replaces it (a building begun by Caesar and dedicated by Augustus). ``ended`` is a
    demolition.
    """
    explicit = [t for t in timeline if t.monument == monument.id]
    marks: list[Mark] = [(t.year, _ORDER[t.kind], t.kind) for t in explicit]
    destroyed = [t.year for t in explicit if t.kind in ("fire", "demolished")]
    if monument.ended is not None and monument.ended.year is not None:
        destroyed.append(monument.ended.year)
        marks.append((monument.ended.year, _ORDER["demolished"], "demolished"))
    built = first_year(monument)
    if built is not None:
        first_done = min((t.year for t in explicit if t.kind == "completed"), default=None)
        replaced = first_done is not None and not any(y < first_done for y in destroyed)
        if not replaced:
            marks.append((built, _ORDER["completed"], "completed"))
    return sorted(marks)


def first_year(monument: Monument) -> int | None:
    """The year the monument was finished, if known.

    With no building date but dated notes (a fire, a restoration), it stood by the first of
    them. Only a monument with no dates at all has always stood.
    """
    if monument.built_year is not None:
        return monument.built_year
    noted = [e.year for e in monument.events if e.year is not None]
    return min(noted) if noted else None


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


def status_map(world: World, year: int) -> dict[str, MonumentStatus]:
    """The status of every monument in ``year`` (sorted by id), from the dataset and timeline."""
    by_monument: dict[str, list[CityTimeline]] = {}
    for turn in world.city_timeline:
        by_monument.setdefault(turn.monument, []).append(turn)
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
    new = status_map(state.world, year)
    city.changed = [mid for mid in sorted(new) if new[mid].state != city.standing[mid].state]
    city.standing = new
    first = city.year + 1
    by_monument: dict[str, list[CityTimeline]] = {}
    for turn in state.world.city_timeline:
        by_monument.setdefault(turn.monument, []).append(turn)
    for mid in sorted(state.world.monuments):
        monument = state.world.monuments[mid]
        for y, _, kind in marks_for(monument, by_monument.get(mid, [])):
            if not first <= y <= year:
                continue
            if kind == "completed":
                _add(city, "sacrifice", y, events, ref="dedication", monument=mid)
            elif kind == "vowed":
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
    """The building where the Senate sits: the first listed that stands, else ``""``."""
    city = state.city
    if city is None:
        return ""
    for mid in state.world.republic_rules.city.senate_houses:
        status = city.standing.get(mid)
        if status is not None and status.state == "standing":
            return mid
    return ""


def record_vote(state: GameState, issue: str, yes_bp: int, no_bp: int) -> None:
    """Note a Senate vote as a ``senate`` event for the 3D city to play."""
    if state.city is None:
        return
    state.city.events.append(
        CityEvent(
            kind="senate",
            year=state.year,
            turn=state.turn,
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
