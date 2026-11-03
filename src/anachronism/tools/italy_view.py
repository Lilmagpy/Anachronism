"""Rome's world as the client sees it (R3, F1): allies, colonies, provinces, citizenship.

``italy_view(state)`` is the ``italy`` key of the server's view (``null`` outside the
Republic): ``allies[]``, ``colonies[]``, ``provinces[]``, ``citizenship`` and ``events[]``
(this turn's events of these systems, for the Senate and World tabs).
"""

from __future__ import annotations

from typing import Any

from anachronism.content.schema.italy import AllyStatus
from anachronism.engine.allies import CITIZENSHIP_LAW, STATUS_NAMES, extra_citizens
from anachronism.engine.provinces_rome import people_of
from anachronism.engine.republic import year_label
from anachronism.engine.rivals import status
from anachronism.engine.state import GameState

KINDS = (
    "levy",
    "citizenship",
    "social_war",
    "colony",
    "colony_lost",
    "colony_refuses",
    "provincia",
    "provincia_lost",
    "extortion",
    "repetundae",
    "province_revolt",
    "triumph_hunger",
)
"""The event kinds these systems emit (``law`` is shared with the Senate)."""
LADDER = [{"status": s.value, "label": STATUS_NAMES[s], "rank": s.rank} for s in AllyStatus]


def _place(state: GameState, province_id: str) -> str:
    geo = state.world.geography.get(province_id)
    return geo.name if geo is not None else province_id


def _allies(state: GameState) -> list[dict[str, Any]]:
    rep = state.republic
    assert rep is not None
    me = state.player_civ
    out = []
    for civ_id in sorted(rep.italy.treaties):
        t = rep.italy.treaties[civ_id]
        civ = state.civs[civ_id]
        now = status(state, me, civ_id)
        out.append(
            {
                "civ": civ_id,
                "name": t.name,
                "adjective": civ.adjective,
                "status": t.status.value,
                "status_label": STATUS_NAMES[t.status],
                "latin": t.status is AllyStatus.LATIN,
                "italian": t.italian,
                "loyalty_bp": t.loyalty_bp,
                "levy_bp": t.levy_bp,
                "serving": t.serving,
                "citizens": t.citizens,
                "booty_share": t.booty_share,
                "land_share": t.land_share,
                "since": t.since,
                "since_label": year_label(t.since),
                "revolted": t.revolted,
                "relation": now.value if now is not None else "",
                "population": state.population(civ_id),
                "alive": bool(state.owned_provinces(civ_id)),
            }
        )
    return out


def _colonies(state: GameState) -> list[dict[str, Any]]:
    rep = state.republic
    assert rep is not None
    out = []
    for cid in sorted(rep.italy.colonies, key=lambda c: (rep.italy.colonies[c].year, c)):
        c = rep.italy.colonies[cid]
        out.append(
            {
                "id": c.id,
                "name": c.name,
                "province": c.province,
                "place": _place(state, c.province),
                "kind": c.kind.value,
                "year": c.year,
                "year_label": year_label(c.year),
                "settlers": c.settlers,
                "garrison": c.garrison,
                "loyalty_bp": c.loyalty_bp,
                "historical": c.historical,
                "refusals": c.refusals,
            }
        )
    return out


def _provinces(state: GameState) -> list[dict[str, Any]]:
    rep = state.republic
    assert rep is not None
    out = []
    for pid in sorted(rep.italy.provinciae):
        p = rep.italy.provinciae[pid]
        definition = state.world.provinciae.get(pid)
        owned = (
            [
                q
                for q in definition.provinces
                if state.provinces.get(q) is not None
                and state.provinces[q].owner == state.player_civ
            ]
            if definition is not None
            else []
        )
        out.append(
            {
                "id": p.id,
                "name": p.name,
                "provinces": owned,
                "places": [_place(state, q) for q in owned],
                "since": p.since,
                "since_label": year_label(p.since),
                "historical_year": definition.historical_year if definition is not None else None,
                "governor": p.governor,
                "governor_name": p.governor_name,
                "office": p.office,
                "governor_since": p.governor_since,
                "loyalty_bp": p.loyalty_bp,
                "tribute": p.tribute,
                "people": people_of(state, pid),
                "extorted": p.extorted,
                "extorted_total": p.extorted_total,
                "revolts": p.revolts,
                "prosecutions": p.prosecutions,
            }
        )
    return out


def _citizenship(state: GameState) -> dict[str, Any]:
    rep = state.republic
    assert rep is not None
    italy = rep.italy
    rules = state.world.italy_rules
    law_open = any(
        law.id == CITIZENSHIP_LAW and law.open_in(state.year)
        for law in state.world.republic_rules.senate.laws
    )
    return {
        "ladder": LADDER,
        "citizens_added": italy.citizens_added,
        "extra_citizens": extra_citizens(state),
        "census": rep.census[-1].citizens if rep.census else None,
        "law_open": law_open,
        "law_year": rep.laws.get(CITIZENSHIP_LAW),
        "social_war_year": italy.social_war_year,
        "social_war_from": rules.social_war_year,
        "citizenship_year": italy.citizenship_year,
        "italian_allies": sum(
            1 for t in italy.treaties.values() if t.italian and t.status is not AllyStatus.CITIZEN
        ),
        "disaffected": sum(
            1
            for t in italy.treaties.values()
            if t.italian
            and t.status is not AllyStatus.CITIZEN
            and not t.revolted
            and t.loyalty_bp < rules.social_war_loyalty_bp
        ),
        "prosecutions": [
            {
                "year": p.year,
                "year_label": year_label(p.year),
                "provincia": p.provincia,
                "governor": p.governor,
                "name": p.name,
                "amount": p.amount,
                "convicted": p.convicted,
            }
            for p in italy.prosecutions[-10:]
        ],
    }


def italy_view(state: GameState) -> dict[str, Any] | None:
    """Rome's allies, colonies and provinces for the client; ``None`` outside the Republic."""
    if state.republic is None:
        return None
    events = [
        {"kind": e.kind, "year": e.year, "turn": e.turn, "message": e.message, "subject": e.subject}
        for e in state.events
        if e.turn == state.turn and e.kind in KINDS
    ]
    return {
        "allies": _allies(state),
        "colonies": _colonies(state),
        "provinces": _provinces(state),
        "citizenship": _citizenship(state),
        "events": events,
    }
