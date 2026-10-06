"""Envoys: rival courts come to the player with proposals (D-105).

At most one proposal waits at a time. Each turn a rival court may send one, if its
situation calls for it:

- **peace**: a weary enemy that is losing sues for peace;
- **ultimatum**: a far stronger, aggrieved neighbour demands tribute or war;
- **alliance**: a friendly court at war with the player's enemy proposes an alliance;
- **trade**: a merchant court proposes a trade pact.

The player answers with an ``AnswerEnvoy`` action. Unanswered at the end of the turn, the
court declines for the player (which, for an ultimatum, means war). Answers are recorded
actions, so replays stay exact.
"""

from __future__ import annotations

from anachronism.content.schema import Disposition, RelationStatus
from anachronism.engine.aid import key
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import apply_bp
from anachronism.engine.rivals import (
    add_grievance,
    alive,
    at_war,
    declare_war,
    grievance,
    relation,
    set_status,
    status,
    strength,
)
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState, Offer
from anachronism.engine.timeflow import per_turn
from anachronism.engine.war import make_peace

TRIBUTE_BP = 2500
"""Share of the treasury an ultimatum demands."""


def _candidates(state: GameState) -> list[Offer]:
    """Every proposal some rival court would make now, in a fixed order."""
    me = state.player_civ
    rules = state.world.rules.rivals
    mine = strength(state, me)
    found: list[Offer] = []
    for civ_id in sorted(state.civs):
        if civ_id == me or not alive(state, civ_id):
            continue
        rel = relation(state, civ_id, me)
        if rel is None:
            continue
        civ = state.civs[civ_id]
        theirs = strength(state, civ_id)
        if rel.status is RelationStatus.WAR:
            losing = rel.losses.get(civ_id, 0) > rel.losses.get(me, 0)
            weary = rel.weariness.get(civ_id, 0) * 2 >= rules.peace_weariness_bp
            if losing and weary:
                found.append(Offer(kind="peace", from_civ=civ_id, turn=state.turn))
            continue
        grudge = grievance(state, civ_id, me)
        if (
            civ.disposition is Disposition.AGGRESSIVE
            and rel.status in (RelationStatus.HOSTILE, RelationStatus.NEUTRAL)
            and theirs >= mine * 2
            and grudge >= 2000
            and state.turn >= rules.player_grace_turns
            and not at_war(state, civ_id)
        ):
            found.append(Offer(kind="ultimatum", from_civ=civ_id, turn=state.turn))
            continue
        if rel.status is RelationStatus.TRADING and grudge < 1000:
            for enemy in at_war(state, civ_id):
                if enemy != me and status(state, me, enemy) in (
                    RelationStatus.HOSTILE,
                    RelationStatus.WAR,
                ):
                    found.append(
                        Offer(kind="alliance", from_civ=civ_id, against=enemy, turn=state.turn)
                    )
                    break
            continue
        if (
            civ.disposition is Disposition.MERCANTILE
            and rel.status is RelationStatus.NEUTRAL
            and grudge < 1500
        ):
            found.append(Offer(kind="trade", from_civ=civ_id, turn=state.turn))
    return found


def envoys(state: GameState, rng: GameRng, events: EventLog) -> None:
    """Settle an unanswered proposal (declined), then perhaps receive a new one."""
    if state.offer is not None:
        message = respond(state, accept=False, events=events)
        events.add(state.player_civ, "envoy_declined", f"No answer was given: {message}")
    chance = per_turn(state, state.world.rules.rivals.envoy_offer_bp)
    for offer in _candidates(state):
        if rng.chance(chance):
            state.offer = offer
            name = state.civs[offer.from_civ].name
            events.add(state.player_civ, "envoy", f"Envoys arrive from {name}.", name)
            return


def describe(state: GameState, offer: Offer) -> dict[str, str]:
    """The proposal told to the player: who, what, and the two answers."""
    them = state.civs[offer.from_civ]
    who = f"{them.ruler} of {them.name}" if them.ruler else f"the court of {them.name}"
    if offer.kind == "peace":
        return {
            "title": f"{them.name} sues for peace",
            "text": f"Envoys from {who} come under a flag of truce. Their armies are beaten and "
            "their people weary; they offer peace, each side keeping what it holds.",
            "accept": "Grant peace",
            "decline": "Fight on",
            "hint": "Peace ends the war. Fighting on may win more - or cost more.",
        }
    if offer.kind == "ultimatum":
        tribute = apply_bp(state.civs[state.player_civ].stockpiles.wealth, TRIBUTE_BP)
        return {
            "title": f"An ultimatum from {them.name}",
            "text": f"The envoys of {who} do not bow. Their master is far stronger than you, they "
            f"say, and remembers old wrongs. Pay {tribute:,} wealth and acknowledge him, or "
            "his armies will come.",
            "accept": "Pay the tribute",
            "decline": "Defy them",
            "hint": "Paying keeps the peace and makes you their tributary; defiance means war.",
        }
    if offer.kind == "alliance":
        enemy = state.civs[offer.against].name
        if key(state.player_civ, offer.from_civ, offer.against) in state.pledges:
            return {
                "title": f"{them.name} offers its alliance",
                "text": f"Envoys from {who} come bearing gifts. You came to their aid when "
                f"{enemy} attacked them, and your soldiers bled for them. They offer an "
                "alliance: their armies and yours, in every war to come.",
                "accept": "Ally with them",
                "decline": "Not now",
                "hint": "Allies defend each other when attacked and trade freely.",
            }
        return {
            "title": f"{them.name} proposes an alliance",
            "text": f"Envoys from {who} propose an alliance against {enemy}, your common enemy: "
            "their armies and yours, one war.",
            "accept": "Ally with them",
            "decline": "Refuse",
            "hint": f"Allies fight each other's wars: you will be at war with {enemy}.",
        }
    return {
        "title": f"{them.name} proposes a trade pact",
        "text": f"Merchants sent by {who} propose open markets between your peoples: goods "
        "and wealth both ways, and news travels with them.",
        "accept": "Open the markets",
        "decline": "Refuse",
        "hint": "Trading partners earn wealth each turn - and hear of your inventions sooner.",
    }


def respond(state: GameState, *, accept: bool, events: EventLog) -> str:
    """Answer the waiting proposal; returns what happened."""
    offer = state.offer
    assert offer is not None
    state.offer = None
    me = state.player_civ
    them = offer.from_civ
    name = state.civs[them].name
    if not alive(state, them):
        return f"{name} is no more."
    if offer.kind == "peace":
        if accept and status(state, me, them) is RelationStatus.WAR:
            make_peace(state, me, them, events)
            return f"Peace with {name}."
        return f"The war with {name} goes on."
    if offer.kind == "ultimatum":
        if accept:
            stores = state.civs[me].stockpiles
            tribute = apply_bp(stores.wealth, TRIBUTE_BP)
            stores.wealth -= tribute
            state.civs[them].stockpiles.wealth += tribute
            set_status(state, me, them, RelationStatus.TRIBUTARY)
            state.civs[me].stats.legitimacy_bp = max(0, state.civs[me].stats.legitimacy_bp - 500)
            return f"{tribute:,} wealth goes to {name}. Peace, at a price."
        if status(state, me, them) is not RelationStatus.WAR:
            declare_war(state, them, me, events, " - you defied their ultimatum")
        return f"{name} answers defiance with war."
    if offer.kind == "alliance":
        if accept:
            set_status(state, me, them, RelationStatus.ALLIED)
            enemy = offer.against
            if alive(state, enemy) and status(state, me, enemy) is not RelationStatus.WAR:
                declare_war(state, me, enemy, events, f" alongside {name}")
            return f"An alliance with {name}."
        add_grievance(state, them, me, 500)
        return f"{name}'s envoys leave, disappointed."
    if accept:
        set_status(state, me, them, RelationStatus.TRADING)
        return f"Markets open between you and {name}."
    return f"{name}'s merchants sail home."
