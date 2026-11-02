"""Roman society as the client sees it (R4, F1): priests, prodigies, land, grain, coin, army."""

from __future__ import annotations

from typing import Any

from anachronism.engine.legions import era_at, would_march_on_rome
from anachronism.engine.religion import books_open, year_label
from anachronism.engine.roman_economy import estates_bp
from anachronism.engine.state import GameState


def rome_society_view(state: GameState) -> dict[str, Any] | None:
    """Everything the client needs to show Roman society, or ``None`` outside the Republic.

    Keys: ``priests[]``, ``pontifex_maximus``, ``auspices[]``, ``prodigies[]``, ``unexpiated``,
    ``cults[]``, ``books`` (open, consulted), ``land``, ``grain``, ``coinage``, ``debt``,
    ``army_era``, ``recruitment``.
    """
    society = state.rome_society
    if society is None:
        return None
    world = state.world.rome_society
    rep = state.republic
    people = rep.people if rep is not None else {}
    rel, land, grain, coin, legions = (
        society.religion,
        society.land,
        society.grain,
        society.coin,
        society.legions,
    )
    era = era_at(state, state.year)
    threshold = legions.threshold_asses
    return {
        "year_label": year_label(state.year),
        "priests": [
            {
                "priesthood": p.priesthood,
                "priesthood_name": world.priesthoods[p.priesthood].name
                if p.priesthood in world.priesthoods
                else p.priesthood,
                "person": p.person,
                "name": p.name,
                "gens": p.gens,
                "since": p.since,
                "alive": people[p.person].alive if p.person in people else True,
                "chief": bool(p.person) and p.person == rel.pontifex_maximus,
            }
            for p in rel.priests
        ],
        "pontifex_maximus": rel.pontifex_maximus,
        "auspices": [a.model_dump() for a in rel.auspices],
        "prodigies": [
            {
                **r.model_dump(),
                "year_label": year_label(r.year),
                "place": world.prodigies[r.prodigy].place if r.prodigy in world.prodigies else "",
                "sign": world.prodigies[r.prodigy].sign if r.prodigy in world.prodigies else "",
                "expiation": world.prodigies[r.prodigy].expiation
                if r.prodigy in world.prodigies
                else "",
            }
            for r in rel.prodigies
        ],
        "unexpiated": rel.unexpiated,
        "cults": [
            {
                "id": cid,
                "name": world.cults[cid].name if cid in world.cults else cid,
                "kind": world.cults[cid].kind if cid in world.cults else "introduced",
                "year": year,
                "monument": world.cults[cid].monument if cid in world.cults else None,
            }
            for cid, year in sorted(rel.cults.items())
        ],
        "books": {
            "open": books_open(state, state.year),
            "lost": rel.books_lost,
            "consulted": list(rel.consultations),
        },
        "land": {
            "ager_publicus": land.ager_publicus,
            "latifundia": land.latifundia,
            "estates_bp": estates_bp(state),
            "assidui_bp": land.assidui_bp,
            "slaves": land.slaves,
            "slave_revolts": list(land.revolts),
            "reform_applied": land.reform_applied,
        },
        "grain": {
            "city_people": grain.city_people,
            "supply_bp": grain.supply_bp,
            "shortfall_bp": grain.shortfall_bp,
            "shortages": grain.shortages,
            "held": list(grain.held),
            "dole": grain.dole_since is not None,
            "dole_since": grain.dole_since,
            "dole_cost": grain.dole_cost,
        },
        "coinage": {
            "reforms": list(coin.reforms),
            "trade_bonus_bp": coin.trade_bonus_bp,
            "trade_bonus": coin.trade_bonus,
            "tribute": coin.tribute,
        },
        "debt": {
            "debt_bp": land.debt_bp,
            "relief_applied": land.relief_applied,
            "secessions": list(land.secessions),
        },
        "army_era": {
            "id": legions.era,
            "name": era.name if era is not None else "",
            "since": legions.era_since,
            "professional": legions.proletarii,
        },
        "recruitment": {
            "threshold_asses": threshold,
            "assidui": legions.assidui,
            "levied": legions.levied,
            "levy_share_bp": world.recruitment.levy_share_bp,
            "proletarii": legions.proletarii,
            "loyalty": [
                {"general": g, "loyalty_bp": bp} for g, bp in sorted(legions.loyalty.items())
            ],
            "would_march": would_march_on_rome(state),
        },
    }
