"""Spies and intelligence (D-115, brief §7.3, D-013): what you know of other courts.

Each turn the player hears about the courts they are in touch with: what each intends (its
scripts), and, where spies are planted, what its scholars work on and how many men it has
under arms. How good the reports are depends on who brings them - allied envoys hear more
than merchants, merchants more than strangers - on distance, and above all on spies. Bad
reports are not marked as bad: a court said to be planning war on one neighbour may in
truth have its eye on another. Spies also steal: now and then they bring back the methods
of an advancement the court has and you lack, which gives its project a head start. And
spies are sometimes caught, and courts remember it.
"""

from __future__ import annotations

from anachronism.content.schema import RelationStatus, Script, ScriptGoal, Stage
from anachronism.engine.decrees import cost
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.rivals import add_grievance, alive, hops, relation
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState, Intel, TechState
from anachronism.engine.tech import is_adopted
from anachronism.engine.timeflow import rate_per_turn

_SOURCE_BP = {
    RelationStatus.ALLIED: 6_000,
    RelationStatus.TRIBUTARY: 5_000,
    RelationStatus.TRADING: 4_000,
    RelationStatus.WAR: 3_000,
}
_SOURCE_NAME = {
    RelationStatus.ALLIED: "allied envoys",
    RelationStatus.TRIBUTARY: "the tribute bearers",
    RelationStatus.TRADING: "merchants",
    RelationStatus.WAR: "captured soldiers",
}
REPORT_FROM_BP = 3_000
"""Below this, a court is too distant and strange for any word of its plans."""


def quality(state: GameState, watcher: str, court: str) -> int:
    """How likely a report about ``court`` is to be true, 0-95% (in basis points)."""
    rel = relation(state, watcher, court)
    if rel is None:
        return 0
    value = _SOURCE_BP.get(rel.status, 1_500)
    distance = hops(state, watcher, court)
    if distance is not None and distance > 1:
        value -= 1_000 * (distance - 1)
    if court in state.civs[watcher].spies:
        value += 4_000
    return clamp(value, 0, 9_500)


def send_spies(state: GameState, civ_id: str, target: str) -> tuple[bool, str]:
    """Plant (or renew) a spy network in another court, if the treasury allows."""
    rules = state.world.rules.rivals
    civ = state.civs[civ_id]
    if target == civ_id or target not in state.civs or not alive(state, target):
        return False, "there is no such court to spy on"
    if relation(state, civ_id, target) is None:
        return False, f"{state.civs[target].name} is beyond our reach"
    price = cost(state, civ_id, rules.spy_wealth_per_1000)
    if civ.stockpiles.wealth < price:
        return False, f"a spy network needs {price} wealth"
    civ.stockpiles.wealth -= price
    civ.spies[target] = rules.spy_turns
    return True, (
        f"Agents slip into {state.civs[target].name} for {rules.spy_turns} turns:"
        " its plans, its workshops, its secrets."
    )


def pending(state: GameState, court: str) -> list[Script]:
    """A court's intentions that have neither come to pass nor lapsed."""
    return [
        s
        for s in state.world.scripts.get(court, ())
        if s.id not in state.scripts_fired and s.id not in state.scripts_lapsed
    ]


def _intent(state: GameState, watcher: str, goal: ScriptGoal, target: str) -> str:
    if goal is ScriptGoal.ADOPT:
        node = state.tech_nodes.get(target)
        return f"hopes to master {node.name if node else target}"
    whom = "us" if target == watcher else state.civs[target].name
    return {
        ScriptGoal.CONQUER: f"means to make war on {whom}",
        ScriptGoal.ALLY: f"seeks an alliance with {whom}",
        ScriptGoal.TRADE: f"wants trade with {whom}",
    }.get(goal, f"has designs on {whom}")


def _report(state: GameState, watcher: str, court: str, rng: GameRng) -> Intel | None:
    """This turn's report about one court (randomness from the game's RNG)."""
    trust = quality(state, watcher, court)
    spied = court in state.civs[watcher].spies
    if trust < REPORT_FROM_BP and not spied:
        return None
    rel = relation(state, watcher, court)
    source = "our spies" if spied else _SOURCE_NAME.get(rel.status, "travellers") if rel else ""
    name = state.civs[court].name
    lines: list[str] = []
    others = sorted(c for c in state.civs if c not in (court, watcher) and alive(state, c))
    for script in pending(state, court)[:2]:
        goal, target = script.goal, script.target
        if not rng.chance(trust):  # a garbled or planted story: the wrong target
            if goal is ScriptGoal.ADOPT:
                target = rng.pick(sorted(state.tech_nodes))
            elif others:
                target = rng.pick([*others, watcher])
        lines.append(f"{name} {_intent(state, watcher, goal, target)}.")
    if spied:
        projects = [state.tech_nodes[p].name for p in sorted(state.civs[court].projects)]
        if projects:
            lines.append(f"Its scholars labour at {', '.join(projects[:3])}.")
        men = sum(a.men for a in state.armies.values() if a.owner == court)
        lines.append(f"It has {men:,} men under arms.")
    if not lines:
        lines.append(f"{name} has no designs we can discover.")
    return Intel(turn=state.turn, source=source, lines=lines, trust_bp=trust)


def gather(state: GameState, rng: GameRng, events: EventLog) -> None:
    """The player's reports for this turn; spies steal, are caught, or come home."""
    me = state.player_civ
    civ = state.civs[me]
    rules = state.world.rules.rivals
    for court in sorted(state.civs):
        if court == me or not alive(state, court):
            civ.intel.pop(court, None)
            continue
        report = _report(state, me, court, rng)
        if report is not None:
            civ.intel[court] = report
    for court in sorted(civ.spies):
        name = state.civs[court].name
        if not alive(state, court):
            del civ.spies[court]
            continue
        if rng.chance(rate_per_turn(state, rules.spy_caught_bp)):
            del civ.spies[court]
            add_grievance(state, court, me, rules.spy_grievance_bp)
            events.add(
                me, "spies_caught", f"Our spies in {name} are caught and put to death.", name
            )
            continue
        if rng.chance(rate_per_turn(state, rules.spy_steal_bp)):
            _steal(state, me, court, events)
        civ.spies[court] -= 1
        if civ.spies[court] <= 0:
            del civ.spies[court]


def _steal(state: GameState, me: str, court: str, events: EventLog) -> None:
    """Spies bring home the methods of an advancement the court has and we lack."""
    mine = state.civs[me]
    theirs = state.civs[court]
    secrets = sorted(
        n
        for n, t in theirs.tech.items()
        if t.stage.is_adopted and n in state.tech_nodes and not is_adopted(mine, n)
    )
    if not secrets:
        return
    node_id = min(secrets, key=lambda n: (state.tech_nodes[n].year, n))  # the oldest first
    head = state.world.rules.rivals.spy_head_start_bp
    project = mine.projects.get(node_id)
    if project is not None:
        project.progress_bp = min(BP - 1, project.progress_bp + head)
    else:
        known = mine.tech.setdefault(node_id, TechState(stage=Stage.CONCEPT))
        known.head_start_bp = max(known.head_start_bp, head)
    name = state.tech_nodes[node_id].name
    events.add(
        me,
        "secrets_stolen",
        f"Our spies bring home the secrets of {theirs.adjective} {name}.",
        name,
    )
