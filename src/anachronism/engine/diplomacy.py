"""The player's (and any civilisation's) diplomatic actions (brief §7.5).

Whether a rival accepts depends on the numbers: how weary it is, how strong each side is,
how friendly they already are and how much it resents the one asking.
"""

from __future__ import annotations

from anachronism.content.schema import RelationStatus
from anachronism.engine.actions import (
    DeclareWar,
    Diplomacy,
    MakePeace,
    ProposeAlliance,
    SendEnvoy,
    SendMissionaries,
)
from anachronism.engine.culture import convert
from anachronism.engine.events import EventLog
from anachronism.engine.rivals import (
    add_grievance,
    alive,
    declare_war,
    grievance,
    relation,
    set_status,
    status,
    strength,
)
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState
from anachronism.engine.war import make_peace

_WARMER = {
    RelationStatus.HOSTILE: RelationStatus.NEUTRAL,
    RelationStatus.NEUTRAL: RelationStatus.TRADING,
}


def apply_diplomacy(state: GameState, action: Diplomacy) -> tuple[bool, str]:
    """Carry out a diplomatic action. Returns whether it happened and a message."""
    me, target = action.civ, action.target
    if target not in state.civs or target == me:
        return False, f"unknown civilisation {target!r}"
    if not alive(state, target):
        return False, f"{state.civs[target].name} is no more"
    them = state.civs[target].name
    current = status(state, me, target)
    events = EventLog(turn=state.turn, year=state.year)
    ok, message = _apply(state, action, me, target, them, current, events)
    state.events.extend(events.items)
    return ok, message


def _apply(
    state: GameState,
    action: Diplomacy,
    me: str,
    target: str,
    them: str,
    current: RelationStatus | None,
    events: EventLog,
) -> tuple[bool, str]:
    rules = state.world.rules.rivals
    if isinstance(action, DeclareWar):
        if current is None:
            return False, f"{them} is out of reach"
        if current is RelationStatus.WAR:
            return False, f"already at war with {them}"
        if current is RelationStatus.ALLIED:
            set_status(state, me, target, RelationStatus.NEUTRAL)  # betrayal is remembered
            add_grievance(state, target, me, 3000)
        declare_war(state, me, target, events)
        return True, f"War with {them}."
    if isinstance(action, MakePeace):
        rel = relation(state, me, target)
        if rel is None or rel.status is not RelationStatus.WAR:
            return False, f"not at war with {them}"
        theirs, ours = strength(state, target), strength(state, me)
        tired = rel.weariness.get(target, 0) * 2 >= rules.peace_weariness_bp
        if tired or ours * 10 >= theirs * 12 or rel.losses.get(target, 0) > 0:
            make_peace(state, me, target, events)
            return True, f"{them} accepts peace."
        return False, f"{them} scorns your offer: they think they are winning."
    if isinstance(action, SendEnvoy):
        if current is None:
            return False, f"{them} is out of reach"
        if current is RelationStatus.WAR:
            return False, "envoys cannot travel in wartime; offer peace instead"
        civ = state.civs[me]
        cost = rules.envoy_wealth * state.world.cost_scale
        if civ.stockpiles.wealth < cost:
            return False, f"an embassy needs {cost} wealth"
        civ.stockpiles.wealth -= cost
        rel = relation(state, me, target)
        assert rel is not None
        rel.grievance[target] = max(0, rel.grievance.get(target, 0) - 1500)
        if grievance(state, target, me) < 2500 and current in _WARMER:
            set_status(state, me, target, _WARMER[current])
            return True, f"Your envoy returns: {them} is now {_WARMER[current].value}."
        return True, f"Your envoy is received coolly by {them}, but old wounds soften."
    if isinstance(action, ProposeAlliance):
        if current not in (RelationStatus.TRADING, RelationStatus.NEUTRAL):
            return False, f"{them} will not ally with you now"
        if grievance(state, target, me) >= 1000:
            return False, f"{them} does not trust you enough"
        # a common enemy, or friendship already, makes an alliance appealing
        enemies = {
            other
            for pair, rel in state.relations.items()
            if rel.status is RelationStatus.WAR and target in pair.split("|")
            for other in pair.split("|")
            if other != target
        }
        if current is RelationStatus.TRADING or enemies:
            set_status(state, me, target, RelationStatus.ALLIED)
            events.add(me, "alliance", f"An alliance with {them}.", them)
            return True, f"{them} agrees to an alliance."
        return False, f"{them} sees no reason to ally with you yet: trade first"
    if isinstance(action, SendMissionaries):
        civ = state.civs[me]
        if not civ.faith:
            return False, "your court has no faith to preach"
        if state.civs[target].faith == civ.faith:
            return False, f"{them} already shares your faith"
        if current is None or current is RelationStatus.WAR:
            return False, f"missionaries cannot reach {them}"
        cost = rules.missionary_wealth * state.world.cost_scale
        if civ.stockpiles.wealth < cost:
            return False, f"missionaries need {cost} wealth"
        civ.stockpiles.wealth -= cost
        rng = GameRng(state.rng)
        if rng.chance(rules.missionary_chance_bp):
            convert(state, target, civ.faith, events, "won over by your missionaries")
            return True, f"Your missionaries win over the court of {them}!"
        add_grievance(state, target, me, 500)
        return True, f"The court of {them} sends your missionaries home."
    raise AssertionError(f"unhandled action {action!r}")
