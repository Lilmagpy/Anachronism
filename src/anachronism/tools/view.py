"""What the player's screen shows, as plain JSON-ready data built from the game state."""

from __future__ import annotations

from typing import Any

from anachronism.content.schema import Stage
from anachronism.engine.commands import describe_blockers
from anachronism.engine.economy import project_costs
from anachronism.engine.projects import project_turns
from anachronism.engine.reports import capacity
from anachronism.engine.state import Event, GameState
from anachronism.engine.tech import feasibility
from anachronism.tools.console import describe_effect

TRENDED = ("population", "food", "literacy_bp", "unrest_bp", "legitimacy_bp", "suspicion_bp")


def trend(state: GameState, civ_id: str, field: str) -> int:
    """1 if a value rose since last turn, -1 if it fell, 0 otherwise."""
    history = state.civs[civ_id].history
    if len(history) < 2:
        return 0
    now: int = getattr(history[-1], field)
    before: int = getattr(history[-2], field)
    return (now > before) - (now < before)


def build_view(state: GameState, events: list[Event] | None = None) -> dict[str, Any]:
    """Everything the client needs to draw the current turn for the player."""
    civ_id = state.player_civ
    civ = state.civs[civ_id]
    room = capacity(state, civ_id)
    return {
        "turn": state.turn + 1,
        "year": state.year,
        "years_per_turn": state.world.years_per_turn,
        "scenario": state.world.scenario_name,
        "map": state.world.map,
        "seed": state.seed,
        "player": civ_id,
        "status": {
            "name": civ.name,
            "population": state.population(civ_id),
            "provinces": len(state.owned_provinces(civ_id)),
            **civ.stats.model_dump(),
            "framing": civ.framing.value,
            "collapsed": civ.collapsed,
            "stores": civ.stockpiles.model_dump(),
            "workforce": room.workforce,
            "free_labour": room.free_labour,
            "trends": {field: trend(state, civ_id, field) for field in TRENDED},
        },
        "civs": [
            {
                "id": other_id,
                "name": other.name,
                "colour": other.colour,
                "population": state.population(other_id),
                "provinces": len(state.owned_provinces(other_id)),
                "unrest_bp": other.stats.unrest_bp,
                "advances": sum(t.stage.is_adopted for t in other.tech.values()),
            }
            for other_id, other in sorted(state.civs.items())
        ],
        "provinces": [
            {
                "id": pid,
                "name": geography.name,
                "terrain": geography.terrain,
                "river": geography.river,
                "coastal": geography.coastal,
                "position": list(geography.position) if geography.position else None,
                "latlon": list(geography.latlon) if geography.latlon else None,
                "neighbours": list(geography.neighbours),
                "owner": state.provinces[pid].owner,
                "population": state.provinces[pid].population,
                "resources": {
                    res: access.value for res, access in state.provinces[pid].resources.items()
                },
                "capital": any(c.capital == pid for c in state.civs.values()),
            }
            for pid, geography in sorted(state.world.geography.items())
        ],
        "seas": [
            {
                "id": sid,
                "name": sea.name,
                "position": list(sea.position) if sea.position else None,
                "latlon": list(sea.latlon) if sea.latlon else None,
            }
            for sid, sea in sorted(state.world.seas.items())
        ],
        "projects": [
            {
                "id": node_id,
                "name": state.tech_nodes[node_id].name,
                "progress_bp": project.progress_bp,
                "funding_bp": project.last_funding_bp,
                "priority": project.priority.value,
                "paused": project.paused,
                "turns": project_turns(state, node_id),
            }
            for node_id, project in sorted(civ.projects.items())
        ],
        "ideas": _ideas(state, civ_id),
        "events": [
            {"civ": e.civ, "kind": e.kind, "message": e.message}
            for e in (events or [])
            if e.civ == civ_id or e.kind in ("revolt", "collapse")
        ],
    }


def _ideas(state: GameState, civ_id: str) -> list[dict[str, Any]]:
    """Every idea the player could see: known ones and those ready to start."""
    civ = state.civs[civ_id]
    ideas = []
    for node_id, node in sorted(state.tech_nodes.items(), key=lambda item: item[1].name):
        known = civ.tech.get(node_id)
        result = feasibility(state, civ_id, node_id)
        if known is None and result.blocked:
            continue
        cost = project_costs(state, node_id)
        ideas.append(
            {
                "id": node_id,
                "name": node.name,
                "category": node.category.value,
                "year": node.year,
                "complexity": node.complexity,
                "flavour": node.flavour,
                "stage": known.stage.value if known else None,
                "goal": bool(known and known.goal),
                "spread_bp": known.spread_bp if known else 0,
                "ready": not result.blocked and not (known and known.stage is not Stage.CONCEPT),
                "blockers": describe_blockers(state, result) if result.blocked else "",
                "cost": {
                    "labour": cost.labour,
                    "materials": cost.materials,
                    "knowledge": cost.knowledge,
                    "wealth": cost.wealth,
                },
                "turns": project_turns(state, node_id),
                "effects": [
                    {
                        "type": e.type.value,
                        "bp": e.bp,
                        "target": e.target,
                        "text": describe_effect(e.type, e.bp, e.target),
                    }
                    for e in node.effects
                ],
            }
        )
    return ideas
