"""Coming to the aid of a state under attack (D-277): the way to win friends by the sword.

When a state is attacked, any court in reach of it may come to its aid: it goes to war with
the attacker, its armies may march through the friend's land and fight beside it (they
defend its provinces as if they were the friend's allies), and everything it does in that
war earns the friend's gratitude:

- joining the war at all;
- each battle won against the attacker (twice as much on the friend's own soil);
- each of the friend's cities taken back from the attacker - handed back to the friend,
  not kept (a liberation, not a conquest);
- each turn an army stands on the friend's soil while the war goes on.

Gratitude eases the friend's grudges, warms its relation (to neutral, then trading) and at
last brings its envoys with an offer of alliance. Making a separate peace with the attacker
while the friend still fights is remembered as betrayal. The pledge ends with the friend's
war; the warmer relation and the eased grudges remain.
"""

from __future__ import annotations

from anachronism.content.schema import RelationStatus
from anachronism.engine.events import EventLog
from anachronism.engine.rivals import (
    add_grievance,
    alive,
    declare_war,
    relation,
    set_status,
    status,
)
from anachronism.engine.state import GameState, Offer, Pledge

_WARMTH = {RelationStatus.HOSTILE: 0, RelationStatus.NEUTRAL: 1, RelationStatus.TRADING: 2}


def key(by: str, friend: str, against: str) -> str:
    """The pledge's key in ``GameState.pledges``."""
    return f"{by}|{friend}|{against}"


def aiding(state: GameState, by: str, friend: str) -> bool:
    """True when ``by`` fights in ``friend``'s war (its armies may enter its land)."""
    return any(p.by == by and p.friend == friend for p in state.pledges.values())


def pledges_of(state: GameState, by: str, friend: str) -> list[Pledge]:
    """Every pledge ``by`` has made to ``friend`` (one per attacker), in key order."""
    return [
        state.pledges[k]
        for k in sorted(state.pledges)
        if state.pledges[k].by == by and state.pledges[k].friend == friend
    ]


def gratitude(state: GameState, by: str, friend: str) -> int:
    """All the gratitude ``friend`` owes ``by`` for its present wars."""
    return sum(p.gratitude_bp for p in pledges_of(state, by, friend))


def come_to_aid(
    state: GameState, me: str, friend: str, against: str, events: EventLog
) -> tuple[bool, str]:
    """Join ``friend``'s war against ``against``. Returns whether it happened and a message."""
    rules = state.world.rules.rivals
    if friend == me or against in (me, friend):
        return False, "you cannot come to your own aid"
    for civ_id in (friend, against):
        if civ_id not in state.civs or not alive(state, civ_id):
            return False, f"unknown civilisation {civ_id!r}"
    name, foe = state.civs[friend].name, state.civs[against].name
    if relation(state, me, friend) is None:
        return False, f"{name} is out of reach"
    if status(state, me, friend) is RelationStatus.WAR:
        return False, f"you are at war with {name} yourself"
    if status(state, friend, against) is not RelationStatus.WAR:
        return False, f"{name} is not at war with {foe}"
    if key(me, friend, against) in state.pledges:
        return False, f"you already fight for {name} against {foe}"
    if status(state, me, against) is RelationStatus.ALLIED:
        set_status(state, me, against, RelationStatus.NEUTRAL)  # betrayal is remembered
        add_grievance(state, against, me, 3000)
    if status(state, me, against) is not RelationStatus.WAR:
        declare_war(state, me, against, events, f" in defence of {name}")
    pledge = Pledge(by=me, friend=friend, against=against, since_turn=state.turn)
    state.pledges[key(me, friend, against)] = pledge
    adjective = state.civs[me].adjective
    events.add(
        friend,
        "aid",
        f"The {adjective} court comes to the aid of {name} against {foe}.",
        state.civs[me].name,
    )
    grateful(state, pledge, rules.aid_join_bp, events)
    return True, (
        f"You march to the aid of {name} against {foe}. Your armies may cross its land;"
        " every victory for it will be remembered."
    )


def grateful(state: GameState, pledge: Pledge, amount: int, events: EventLog) -> None:
    """The friend's gratitude grows: grudges ease and the relation warms."""
    if amount <= 0 or not alive(state, pledge.friend):
        return
    rules = state.world.rules.rivals
    pledge.gratitude_bp += amount
    rel = relation(state, pledge.by, pledge.friend)
    if rel is None:
        return
    rel.grievance[pledge.friend] = max(0, rel.grievance.get(pledge.friend, 0) - amount)
    total = gratitude(state, pledge.by, pledge.friend)
    want = 2 if total >= rules.aid_warm_bp else (1 if total * 2 >= rules.aid_warm_bp else 0)
    now = _WARMTH.get(rel.status)
    if now is None or want <= now:
        return
    warmer = RelationStatus.TRADING if want == 2 else RelationStatus.NEUTRAL
    set_status(state, pledge.by, pledge.friend, warmer)
    pledge.warmed = want
    name = state.civs[pledge.friend].name
    said = "opens its markets to you" if want == 2 else "thinks better of you"
    events.add(pledge.by, "aid_thanks", f"In gratitude for your help, {name} {said}.", name)


def on_battle(
    state: GameState, province_id: str, winner: str, loser: str, events: EventLog
) -> None:
    """A battle won against a friend's attacker earns its gratitude."""
    rules = state.world.rules.rivals
    owner = state.provinces[province_id].owner
    for k in sorted(state.pledges):
        pledge = state.pledges[k]
        if pledge.by == winner and pledge.against == loser:
            home = 2 if owner == pledge.friend else 1
            grateful(state, pledge, rules.aid_battle_bp * home, events)


def liberator(state: GameState, taker: str, province_id: str) -> Pledge | None:
    """The pledge under which ``taker`` takes back a friend's city from its attacker, if any."""
    province = state.provinces[province_id]
    for k in sorted(state.pledges):
        pledge = state.pledges[k]
        if (
            pledge.by == taker
            and pledge.against == province.owner
            and province.people == pledge.friend
            and alive(state, pledge.friend)
        ):
            return pledge
    return None


def aid_turn(state: GameState, events: EventLog) -> None:
    """Each turn's reckoning of every pledge.

    Armies on a friend's soil earn its thanks; pledges end with the war, or in betrayal; a
    friend grateful enough offers its alliance (to the player, by envoys).
    """
    rules = state.world.rules.rivals
    for k in sorted(state.pledges):
        pledge = state.pledges[k]
        by, friend, against = pledge.by, pledge.friend, pledge.against
        name = state.civs[friend].name
        fighting = alive(state, friend) and alive(state, against)
        if not fighting or status(state, friend, against) is not RelationStatus.WAR:
            del state.pledges[k]
            if alive(state, friend) and pledge.gratitude_bp > 0:
                events.add(by, "aid_ends", f"{name}'s war is over; it will remember your help.")
            continue
        if status(state, by, against) is not RelationStatus.WAR:
            del state.pledges[k]
            add_grievance(state, friend, by, rules.aid_abandon_bp)
            events.add(
                by,
                "aid_abandoned",
                f"You made peace with {state.civs[against].name} while {name} still fights:"
                " it will not forget the betrayal.",
                name,
            )
            continue
        if any(
            a.owner == by and state.provinces[a.province].owner == friend
            for a in state.armies.values()
        ):
            grateful(state, pledge, rules.aid_presence_bp, events)
        if (
            by == state.player_civ
            and not pledge.offered
            and state.offer is None
            and gratitude(state, by, friend) >= rules.aid_alliance_bp
            and status(state, by, friend) is not RelationStatus.ALLIED
        ):
            pledge.offered = True
            state.offer = Offer(kind="alliance", from_civ=friend, against=against, turn=state.turn)
            events.add(by, "envoy", f"Grateful envoys arrive from {name}.", name)
