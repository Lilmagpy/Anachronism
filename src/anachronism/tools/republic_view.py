"""The Republic as the client sees it (R2): magistrates, the Senate's mood, notable people."""

from __future__ import annotations

from typing import Any

from anachronism.content.schema import Issue
from anachronism.engine.republic import (
    factions_at,
    family_leaning,
    senate_mood,
    senate_vote,
    year_label,
)
from anachronism.engine.republic_state import Person
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


def republic_view(state: GameState) -> dict[str, Any] | None:
    """Everything the client needs to draw how Rome governs itself, or ``None``."""
    rep = state.republic
    if rep is None:
        return None
    mags = state.world.magistracies
    people = rep.people
    holders = {m.person for m in rep.magistrates}
    notable = sorted(
        (p for p in people.values() if p.alive),
        key=lambda p: (p.id not in holders, -p.glory, p.id),
    )[:NOTABLE]
    return {
        "year_label": year_label(state.year),
        "influence": rep.influence,
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
            {"year": m.year, "office": m.office, "name": m.name, "suffect": m.suffect}
            for m in rep.record[-40:]
        ],
    }
