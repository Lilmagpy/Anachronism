"""What happened on the map during a turn, for the client to play back (D-124).

The client shows a turn as it happened rather than jumping to its end: armies march along
their roads and fleets sail their courses, battles on land and sea flare where they were
fought, sieges smoke, armies raised appear and armies and fleets destroyed vanish, and land
changing hands is flagged. Everything here is read from the states before and after the
turn and its events; nothing is decided.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from anachronism.engine.armies import route
from anachronism.engine.navies import sea_route
from anachronism.engine.state import Event, GameState
from anachronism.engine.war import defence_bp

BATTLES_SHOWN = 6
"""At most this many battles are played one by one; the rest flare all at once."""


@dataclass(frozen=True)
class Before:
    """What the map looked like when the turn began."""

    armies: dict[str, dict[str, Any]]
    fleets: dict[str, dict[str, Any]]
    owners: dict[str, str | None]
    known: frozenset[str] = frozenset()
    """The player's advancements already in use."""


def snapshot(state: GameState) -> Before:
    """Remember armies and fleets (with their planned ways) and who held what, before a turn."""
    armies = {
        army_id: {
            "owner": army.owner,
            "at": army.province,
            "men": army.men,
            "way": route(state, army.owner, army.province, army.target) if army.target else [],
        }
        for army_id, army in sorted(state.armies.items())
    }
    fleets = {
        fleet_id: {
            "owner": fleet.owner,
            "at": fleet.sea,
            "way": sea_route(state, fleet.sea, fleet.target) if fleet.target else [],
        }
        for fleet_id, fleet in sorted(state.fleets.items())
    }
    owners = {pid: p.owner for pid, p in sorted(state.provinces.items())}
    player = state.civs[state.player_civ]
    known = frozenset(n for n, t in player.tech.items() if t.stage.is_adopted)
    return Before(armies=armies, fleets=fleets, owners=owners, known=known)


def _way(before: dict[str, Any], to: str) -> list[str]:
    """The places passed through to reach ``to`` (ending there)."""
    planned: list[str] = before["way"]
    if to in planned:
        return planned[: planned.index(to) + 1]
    return [to]


def _moves(
    before: dict[str, dict[str, Any]], now: dict[str, tuple[str, str]], me: str
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    """Moves, newcomers and losses, given each force's (owner, place) after the turn."""
    moved, new = [], []
    for force_id, (owner, at) in sorted(now.items()):
        old = before.get(force_id)
        if old is None:
            new.append({"id": force_id, "owner": owner, "at": at})
        elif old["at"] != at:
            moved.append(
                {
                    "id": force_id,
                    "owner": owner,
                    "from": old["at"],
                    "road": _way(old, at),
                    "mine": owner == me,
                }
            )
    gone = [
        {"id": force_id, "owner": old["owner"], "at": old["at"]}
        for force_id, old in sorted(before.items())
        if force_id not in now
    ]
    return moved, new, gone


def _battles(
    events: list[Event], places: dict[str, str], won: str, lost: str, me: str, sea: bool
) -> list[dict[str, Any]]:
    losers = {e.subject: e.civ for e in events if e.kind == lost}
    battles = []
    for e in events:
        if e.kind != won or e.subject not in places:
            continue
        loser = losers.get(e.subject, "")
        battles.append(
            {
                "at": places[e.subject],
                "name": e.message.split(". ")[0].rstrip("."),
                "winner": e.civ,
                "loser": loser,
                "mine": me in (e.civ, loser),
                "won": e.civ == me,
                "sea": sea,
            }
        )
    return battles


def build(before: Before, after: GameState, events: list[Event]) -> dict[str, Any]:
    """The turn's marches and voyages, battles, sieges, new and lost forces, and land taken."""
    me = after.player_civ
    marches, raised, lost = _moves(
        before.armies, {i: (a.owner, a.province) for i, a in after.armies.items()}, me
    )
    sails, _, sunk = _moves(
        before.fleets, {i: (f.owner, f.sea) for i, f in after.fleets.items()}, me
    )
    provinces = {g.name.split(" (")[0]: pid for pid, g in after.world.geography.items()}
    seas = {sea.name: sid for sid, sea in after.world.seas.items()}
    battles = _battles(events, provinces, "battle_won", "battle_lost", me, sea=False)
    battles += _battles(events, seas, "sea_battle_won", "sea_battle_lost", me, sea=True)
    battles.sort(key=lambda b: (not b["mine"], b["at"]))  # the player's own first
    sieges = []
    for _, army in sorted(after.armies.items()):
        held_by = after.provinces[army.province].owner
        if army.siege_bp <= 0 or held_by is None or held_by == army.owner:
            continue
        needed = max(1, defence_bp(after, held_by, army.province))
        sieges.append(
            {
                "at": army.province,
                "by": army.owner,
                "held_by": held_by,
                "progress": min(99, army.siege_bp * 100 // needed),
                "mine": me in (army.owner, held_by),
            }
        )
    taken = [
        {
            "at": pid,
            "from": before.owners.get(pid),
            "to": province.owner,
            "mine": me in (before.owners.get(pid), province.owner),
        }
        for pid, province in sorted(after.provinces.items())
        if before.owners.get(pid) != province.owner
    ]
    # the player's ideas from the future that came to life this turn (D-126)
    player = after.civs[me]
    breakthroughs: list[dict[str, Any]] = []
    for node_id, tech in sorted(player.tech.items()):
        node = after.tech_nodes.get(node_id)
        if node is None or node_id in before.known or not tech.stage.is_adopted:
            continue
        ahead = node.year - (tech.adopted_year if tech.adopted_year is not None else after.year)
        if ahead > 0:
            breakthroughs.append(
                {"id": node_id, "name": node.name, "ahead": ahead, "history": node.history}
            )
    breakthroughs.sort(key=lambda b: -int(b["ahead"]))
    return {
        "breakthroughs": breakthroughs,
        "marches": marches,
        "sails": sails,
        "sieges": sieges,
        "raised": raised,
        "lost": lost + [{**fleet, "fleet": True} for fleet in sunk],
        "battles": battles[:BATTLES_SHOWN],
        "skirmishes": [b["at"] for b in battles[BATTLES_SHOWN:]],
        "taken": taken,
    }
