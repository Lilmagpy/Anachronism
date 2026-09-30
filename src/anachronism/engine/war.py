"""Abstract war between civilisations (DESIGN §10).

Armies are not moved piece by piece: each turn of a war, the stronger side may take one of
the weaker side's frontier provinces, with a chance that grows with its advantage. Both
sides lose people along the front, grow restless and grow weary; the side that tires first
sues for peace and remembers the defeat. Losing a capital moves the court and shakes the
ruler's legitimacy.
"""

from __future__ import annotations

from anachronism.content.schema import RelationStatus
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.rivals import add_grievance, alive, frontier, set_status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import Awareness, GameState
from anachronism.engine.timeflow import per_turn


def fronts(state: GameState) -> list[dict[str, object]]:
    """Every active war and where it is fought (for the map's army markers)."""
    found: list[dict[str, object]] = []
    for pair, rel in sorted(state.relations.items()):
        if rel.status is not RelationStatus.WAR:
            continue
        a, b = pair.split("|")
        found.append(
            {"a": a, "b": b, "front": sorted({*frontier(state, a, b), *frontier(state, b, a)})}
        )
    return found


def capture(state: GameState, taker: str, province_id: str, events: EventLog) -> None:
    """``taker`` takes a province; a lost capital moves to the largest province left."""
    province = state.provinces[province_id]
    loser_id = province.owner
    province.owner = taker
    name = state.world.geography[province_id].name
    taker_civ = state.civs[taker]
    events.add(taker, "conquest", f"{taker_civ.name} takes {name}.", name)
    if loser_id is None:
        return
    loser = state.civs[loser_id]
    events.add(loser_id, "province_lost", f"{loser.name} loses {name} to {taker_civ.name}.", name)
    if loser.capital == province_id:
        left = state.owned_provinces(loser_id)
        if left:
            loser.capital = max(left, key=lambda p: (state.provinces[p].population, p))
            loser.stats.legitimacy_bp = clamp(
                loser.stats.legitimacy_bp - state.world.rules.rivals.capital_loss_legitimacy_bp,
                0,
                BP,
            )
            new_seat = state.world.geography[loser.capital].name
            events.add(loser_id, "capital_lost", f"{loser.name}'s court flees to {new_seat}.", name)
    if not state.owned_provinces(loser_id):
        loser.collapsed = True
        events.add(
            loser_id,
            "destroyed",
            f"{loser.name} is no more: {taker_civ.name} holds all its lands.",
            loser.name,
        )
    if taker == state.player_civ and loser_id != state.player_civ:
        loser.awareness = Awareness.FREE_AGENT  # a conquered people does not forget


def defence_bp(state: GameState, defender: str, province_id: str) -> int:
    """How hard a province is to take: its terrain, and walls if it is the capital."""
    terrain = state.world.terrain[state.world.geography[province_id].terrain]
    defence = terrain.defence_bp
    if state.civs[defender].capital == province_id:
        defence = defence * state.world.rules.rivals.capital_defence_bp // BP
    return max(1, defence)


def side_strength(state: GameState, civ: str, enemy: str, strengths: dict[str, int]) -> int:
    """A civilisation's strength in its war with ``enemy``.

    Its own, plus half of each ally also at war with that enemy (allies send help, not
    their whole army).
    """
    total = strengths.get(civ, 0)
    for pair, rel in sorted(state.relations.items()):
        if rel.status is RelationStatus.ALLIED and civ in pair.split("|"):
            ally = next(c for c in pair.split("|") if c != civ)
            other = state.relations.get(f"{ally}|{enemy}" if ally < enemy else f"{enemy}|{ally}")
            if other is not None and other.status is RelationStatus.WAR:
                total += strengths.get(ally, 0) // 2
    return total


def resolve_wars(
    state: GameState, strengths: dict[str, int], rng: GameRng, events: EventLog
) -> None:
    """One turn of every war, pairs in id order."""
    rules = state.world.rules.rivals
    for pair, rel in sorted(state.relations.items()):
        if rel.status is not RelationStatus.WAR:
            continue
        a, b = pair.split("|")
        if not alive(state, a) or not alive(state, b):
            set_status(state, a, b, RelationStatus.HOSTILE)
            continue
        sa, sb = side_strength(state, a, b, strengths), side_strength(state, b, a, strengths)
        strong, weak = (a, b) if (sa, b) >= (sb, a) else (b, a)
        s_strong, s_weak = max(sa, sb), min(sa, sb)
        targets = frontier(state, strong, weak)
        if targets and s_strong > s_weak:
            advantage_bp = (s_strong - s_weak) * BP // max(1, s_weak)
            chance = min(rules.max_capture_bp, apply_bp(advantage_bp, rules.capture_per_excess_bp))
            prize = min(targets, key=lambda p: (state.provinces[p].population, p))
            chance = chance * BP // defence_bp(state, weak, prize)
            if rng.chance(chance):
                capture(state, strong, prize, events)
                rel.losses[weak] = rel.losses.get(weak, 0) + 1
                rel.weariness[weak] = rel.weariness.get(weak, 0) + rules.weariness_per_loss_bp
        for side, other in ((a, b), (b, a)):
            for pid in frontier(state, other, side):
                province = state.provinces[pid]
                province.population = max(
                    0, province.population - apply_bp(province.population, rules.war_losses_bp)
                )
            civ = state.civs[side]
            civ.stats.unrest_bp = clamp(
                civ.stats.unrest_bp + per_turn(state, rules.war_unrest_bp), 0, BP
            )
            rel.weariness[side] = rel.weariness.get(side, 0) + per_turn(
                state, rules.weariness_per_turn_bp
            )
        tired = [c for c in (a, b) if rel.weariness.get(c, 0) >= rules.peace_weariness_bp]
        if tired:
            make_peace(state, a, b, events)


def make_peace(state: GameState, a: str, b: str, events: EventLog) -> None:
    """End a war. The side that lost more ground carries a grievance away."""
    rel = state.relations.get(f"{a}|{b}" if a < b else f"{b}|{a}")
    if rel is None or rel.status is not RelationStatus.WAR:
        return
    losses = dict(rel.losses)
    set_status(state, a, b, RelationStatus.HOSTILE)
    loser = (
        a
        if losses.get(a, 0) > losses.get(b, 0)
        else b
        if losses.get(b, 0) > losses.get(a, 0)
        else None
    )
    if loser is not None:
        winner = b if loser == a else a
        add_grievance(state, loser, winner, state.world.rules.rivals.war_grievance_bp)
    names = f"{state.civs[a].name} and {state.civs[b].name}"
    events.add(a, "peace", f"Peace between {names}.", state.civs[b].name)
    events.add(b, "peace", f"Peace between {names}.", state.civs[a].name)
