"""What the player's screen shows, as plain JSON-ready data built from the game state."""

from __future__ import annotations

from typing import Any

from anachronism.content.loader import Content
from anachronism.content.schema import Stage
from anachronism.engine.commands import describe_blockers
from anachronism.engine.decrees import cost
from anachronism.engine.economy import project_costs
from anachronism.engine.projects import project_turns
from anachronism.engine.reports import capacity
from anachronism.engine.rivals import relation, strength
from anachronism.engine.state import Event, GameState
from anachronism.engine.tech import feasibility
from anachronism.engine.victory import progress
from anachronism.engine.war import defence_bp, fronts
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
    strengths = {c: strength(state, c) for c in sorted(state.civs)}
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
            "ruler": civ.ruler,
            "ruler_age": civ.ruler_age,
            "faith": _faith_name(state, civ.faith),
            "faith_spreads": bool(civ.faith) and state.world.faiths[civ.faith].spreads,
            "mercenaries": civ.mercenaries,
            "festival_cost": cost(state, civ_id, state.world.rules.rivals.festival_wealth_per_1000),
            "mercenary_cost": cost(
                state, civ_id, state.world.rules.rivals.mercenary_wealth_per_1000
            ),
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
                "alive": bool(state.owned_provinces(other_id)),
                "disposition": other.disposition.value,
                "ruler": other.ruler,
                "ruler_age": other.ruler_age,
                "faith": _faith_name(state, other.faith),
                "same_faith": bool(other.faith) and other.faith == civ.faith,
                "awareness": other.awareness.value,
                "strength": strengths[other_id],
                **_relation_to_player(state, other_id),
            }
            for other_id, other in sorted(state.civs.items())
        ],
        "wars": fronts(state),
        "victory": {
            "paths": progress(state),
            "outcome": state.outcome.model_dump() if state.outcome else None,
        },
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
                "defence_bp": _defence(state, pid),
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
            if e.civ == civ_id or e.kind in ("revolt", "collapse", "destroyed")
        ],
    }


def _defence(state: GameState, province_id: str) -> int:
    """How hard the province is to take from its holder (terrain, walls, last stand)."""
    owner = state.provinces[province_id].owner
    if owner is None:
        terrain = state.world.terrain[state.world.geography[province_id].terrain]
        return terrain.defence_bp
    return defence_bp(state, owner, province_id)


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
                "stub": node.stub,
                "provenance": node.provenance.value,
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


def _faith_name(state: GameState, faith_id: str) -> str:
    faith = state.world.faiths.get(faith_id)
    return faith.name if faith else ""


def _relation_to_player(state: GameState, other_id: str) -> dict[str, Any]:
    """How a civilisation stands with the player, for the World tab."""
    if other_id == state.player_civ:
        return {"relation": None, "grievance_bp": 0, "heard_of_you": []}
    rel = relation(state, state.player_civ, other_id)
    heard = [
        state.tech_nodes[h.node_id].name if not h.garbled else "strange rumours"
        for h in state.civs[other_id].heard
        if h.about == state.player_civ
    ]
    return {
        "relation": rel.status.value if rel else None,
        "grievance_bp": rel.grievance.get(other_id, 0) if rel else 0,
        "heard_of_you": sorted(set(heard)),
    }


def build_catalog(content: Content) -> list[dict[str, Any]]:
    """Every playable starting moment, for the civilisation picker (real-map scenarios)."""
    catalog: list[dict[str, Any]] = []
    for scenario_id, scenario in sorted(content.scenarios.items(), key=lambda s: s[1].start_year):
        civs: list[dict[str, Any]] = []
        for civ_id, start in scenario.civs.items():
            definition = content.civs[civ_id]
            civs.append(
                {
                    "id": civ_id,
                    "name": definition.name,
                    "adjective": definition.adjective,
                    "colour": definition.colour,
                    "description": definition.description,
                    "emblem": definition.emblem or definition.adjective[:1],
                    "portrait": definition.portrait,
                    "leader": start.leader,
                    "pitch": start.pitch,
                    "population": sum(start.provinces.values()),
                    "provinces": len(start.provinces),
                    "capital": content.provinces[start.capital].name,
                    "advances": sum(stage.is_adopted for stage in start.techs.values()),
                    "literacy_bp": start.stats.literacy_bp,
                }
            )
        civs.sort(key=lambda c: -sum(scenario.civs[c["id"]].provinces.values()))
        catalog.append(
            {
                "id": scenario_id,
                "name": scenario.name,
                "description": scenario.description,
                "start_year": scenario.start_year,
                "map": scenario.map,
                "default_civ": scenario.player_civ,
                "civs": civs,
            }
        )
    return catalog
