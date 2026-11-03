"""The Republic as the client sees it (R2): magistrates, the Senate's mood, notable people.

F1 additions: ``year_disputed`` / ``year_gap`` / ``year_note`` (the Fasti's confidence and
gap kind for the year, in a chronicle), ``disputed`` on each magistrate and record entry
seated from a doubtful year, and on each proposal ``tribune_name`` and ``tribune_note`` (the
chance a tribune acts, or why none will).
"""

from __future__ import annotations

from typing import Any

from anachronism.content.schema import FastiYear, Issue
from anachronism.engine.republic import (
    factions_at,
    family_leaning,
    senate_mood,
    senate_vote,
    year_label,
)
from anachronism.engine.republic_state import Ballot, Person
from anachronism.engine.senate import Interposition, available, interposition, resolve
from anachronism.engine.state import GameState

NOTABLE = 12
"""How many notable persons the view lists."""


def _person(state: GameState, person: Person) -> dict[str, Any]:
    rep = state.republic
    assert rep is not None
    gens = state.world.gentes.get(person.gens)
    return {
        "id": person.id,
        "name": person.name,
        "gens": person.gens,
        "gens_name": gens.name if gens else person.gens,
        "order": person.order.value,
        "age": state.year - person.born,
        "alive": person.alive,
        "glory": person.glory,
        "historical": person.historical,
        "traits": list(person.traits),
        "offices": [
            {"office": h.office, "year": h.year, "suffect": h.suffect} for h in person.offices
        ],
    }


def _proposals(state: GameState) -> list[dict[str, Any]]:
    """What the player may put to the Senate now, with the Senate's forecast (no record)."""
    votes = {}
    out: list[dict[str, Any]] = []
    for item in available(state):
        if item.issue not in votes:
            vote = senate_vote(state, item.issue)
            votes[item.issue] = (vote, interposition(state, vote))
        vote, stand = votes[item.issue]
        out.append(
            {
                "issue": item.issue.value,
                "proposal": item.proposal,
                "label": item.label,
                "cost": item.cost,
                "forecast_yes_bp": vote.yes_bp,
                "forecast_no_bp": vote.no_bp,
                "passes": vote.passes,
                "tribune": stand.kind,
                "tribune_bp": stand.chance_bp,
                "tribune_name": stand.tribune,
                "tribune_note": _tribune_note(stand),
            }
        )
    return out


def _tribune_note(stand: Interposition) -> str:
    """What the forecast says about the tribune, honestly: the chance and its ground."""
    if stand.kind == "veto":
        return f"{stand.tribune} may interpose his veto ({stand.chance_bp // 100}% chance)"
    if stand.kind == "force":
        return (
            f"{stand.tribune} may carry it to the people over the Senate's refusal "
            f"({stand.chance_bp // 100}% chance)"
        )
    return f"no tribune will act: {stand.why}" if stand.why else ""


def _fasti_year(state: GameState, year: int) -> FastiYear | None:
    return state.world.fasti.get(year) if state.chronicle_mode else None


def _last_votes(state: GameState) -> list[dict[str, Any]]:
    """The turn's Senate votes (from the city events), with how the player's own ended."""
    rep = state.republic
    assert rep is not None
    ballots = {(b.turn, b.issue, b.yes_bp, b.no_bp): b for b in rep.ballots}
    out: list[dict[str, Any]] = []
    for e in state.city.events if state.city is not None else []:
        if e.kind != "senate":
            continue
        ballot = ballots.get((e.turn, e.ref, e.value, e.other))
        out.append(
            {
                "issue": e.ref,
                "year": e.year,
                "turn": e.turn,
                "yes_bp": e.value,
                "no_bp": e.other,
                "house": e.monument,
                "proposal": ballot.proposal if ballot else "",
                "outcome": ballot.outcome if ballot else "",
                "label": _vote_label(state, e.turn, e.ref, ballot),
            }
        )
    return out


def _vote_label(state: GameState, turn: int, issue: str, ballot: Ballot | None) -> str:
    """What the vote was about.

    The player's proposal, or the Senate's own business (a war declared on Rome, a war Rome's
    own court or a script began), from the turn's war events.
    """
    if ballot is not None:
        found, _ = resolve(state, ballot.proposal)
        return found.label if found is not None else ballot.proposal
    me = state.player_civ
    if issue == "war":
        for ev in state.events:
            if ev.turn != turn or ev.kind != "war" or ev.civ != me:
                continue
            if ev.message.startswith("War:"):
                return f"war declared on {ev.subject}"
            return f"war declared by {ev.subject}"
        return "a war that reached Rome"
    return f"the Senate's own business: {issue}"


def _persuaded(state: GameState) -> dict[str, list[str]]:
    """Families the player has won over, by issue (from the state, so a load keeps it)."""
    rep = state.republic
    assert rep is not None
    out: dict[str, list[str]] = {}
    for fid in sorted(rep.families):
        issues = [i for i, v in sorted(rep.families[fid].favour.items()) if v > 0]
        if issues:
            out[fid] = issues
    return out


def _event_names(state: GameState) -> dict[str, str]:
    """Names of the persons the turn's city events refer to.

    A dead man honoured by a munus is not in ``notable``.
    """
    rep = state.republic
    assert rep is not None
    names: dict[str, str] = {}
    for e in state.city.events if state.city is not None else []:
        if e.person and e.person in rep.people:
            names[e.person] = rep.people[e.person].name
    return names


def _disputed(state: GameState, year: int) -> bool:
    """True when the Fasti's list for that year is doubtful (low confidence)."""
    entry = _fasti_year(state, year)
    return entry.disputed if entry is not None else False


def republic_view(state: GameState) -> dict[str, Any] | None:
    """Everything the client needs to draw how Rome governs itself, or ``None``."""
    rep = state.republic
    if rep is None:
        return None
    mags = state.world.magistracies
    people = rep.people
    holders = {m.person for m in rep.magistrates}
    this_year = _fasti_year(state, state.year)
    notable = sorted(
        (p for p in people.values() if p.alive),
        key=lambda p: (p.id not in holders, -p.glory, p.id),
    )[:NOTABLE]
    return {
        "year_label": year_label(state.year),
        "year_disputed": this_year.disputed if this_year is not None else False,
        "year_gap": this_year.gap if this_year is not None else "",
        "year_note": this_year.notes if this_year is not None else "",
        "influence": rep.influence,
        "influence_costs": {
            "persuade": state.world.republic_rules.persuade_cost,
            "back": state.world.republic_rules.back_cost,
        },
        "proposals": _proposals(state),
        "last_votes": _last_votes(state),
        "persuaded": _persuaded(state),
        "event_names": _event_names(state),
        "laws": [{"id": lid, "year": year} for lid, year in sorted(rep.laws.items())],
        "colonies": [{"province": pid, "year": year} for pid, year in sorted(rep.colonies.items())],
        "emergency_bp": rep.emergency_bp,
        "history_turned": rep.diverged,
        "magistrates": [
            {
                "office": m.office,
                "office_name": mags[m.office].name,
                "rank": mags[m.office].rank,
                "person": m.person,
                "name": m.name,
                "gens": people[m.person].gens if m.person in people else "",
                "order": people[m.person].order.value if m.person in people else "",
                "age": state.year - people[m.person].born if m.person in people else None,
                "historical": people[m.person].historical if m.person in people else False,
                "months": m.term_months,
                "suffect": m.suffect,
                "appointed": m.appointed,
                "from_fasti": m.by_fasti,
                "disputed": _disputed(state, m.year) if m.by_fasti else False,
                "master_of": m.master,
            }
            for m in sorted(rep.magistrates, key=lambda m: (-mags[m.office].rank, m.office, m.name))
        ],
        "senate": {
            "factions": [
                {
                    "id": f.id,
                    "name": f.name,
                    "weight_bp": f.weight_bp,
                    "mood_bp": f.mood_bp,
                    "issues": f.issues,
                }
                for f in senate_mood(state)
            ],
            "votes": [
                {
                    "issue": issue.value,
                    "yes_bp": vote.yes_bp,
                    "no_bp": vote.no_bp,
                    "passes": vote.passes,
                }
                for issue in Issue
                for vote in [senate_vote(state, issue)]
            ],
            "blocs_now": [f.id for f in factions_at(state, state.year)],
        },
        "families": [
            {
                "id": fid,
                "name": state.world.gentes[fid].name,
                "order": state.world.gentes[fid].order.value,
                "dignitas_bp": f.dignitas_bp,
                "auctoritas_bp": f.auctoritas_bp,
                "wealth": f.wealth,
                "clients": f.clients,
                "living": sum(1 for p in people.values() if p.alive and p.gens == fid),
                "stance": {i.value: family_leaning(state, fid, i) for i in Issue},
            }
            for fid, f in sorted(rep.families.items())
        ],
        "notable": [_person(state, p) for p in notable],
        "census": [{"year": c.year, "citizens": c.citizens} for c in rep.census[-5:]],
        "fasti": [
            {
                "year": m.year,
                "office": m.office,
                "name": m.name,
                "suffect": m.suffect,
                "from_fasti": m.by_fasti,
                "disputed": _disputed(state, m.year) if m.by_fasti else False,
            }
            for m in rep.record[-40:]
        ],
    }
