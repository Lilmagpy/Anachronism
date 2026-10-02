"""What the player's screen shows, as plain JSON-ready data built from the game state."""

from __future__ import annotations

from dataclasses import asdict
from typing import Any

from anachronism.content.loader import Content
from anachronism.content.schema import Building, Stage
from anachronism.engine.armies import (
    STYLES,
    available_units,
    composition,
    mobilisation_cap,
    raise_cost,
    route,
    under_arms,
    wall_cost,
    wall_tech,
)
from anachronism.engine.buildings import cost as building_cost
from anachronism.engine.buildings import options as building_options
from anachronism.engine.buildings import slots
from anachronism.engine.commands import describe_blockers
from anachronism.engine.decrees import cost, explain_costs, explain_ready_in, news_on_the_road
from anachronism.engine.dilemmas import effects_text, fill
from anachronism.engine.dynasty import remembered_in
from anachronism.engine.economy import project_costs
from anachronism.engine.navies import SIZES, best_ship, sea_links, sea_route, seas_of
from anachronism.engine.navies import power as sea_power
from anachronism.engine.occupation import garrisoned, restless
from anachronism.engine.offers import describe
from anachronism.engine.projects import hasten_cost, project_turns
from anachronism.engine.reports import capacity
from anachronism.engine.rivals import relation, strength
from anachronism.engine.state import Army, Event, GameState
from anachronism.engine.suspicion import adoption_suspicion_bp
from anachronism.engine.tactics import AUTO, final, natural, needs_text, short_of_men
from anachronism.engine.tech import feasibility, is_adopted
from anachronism.engine.timeflow import turns_for
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
    links = sea_links(state)
    return {
        "turn": state.turn + 1,
        "year": state.year,
        "years_per_turn": state.world.years_per_turn,
        "difficulty": state.world.difficulty,
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
            "explain_costs": list(explain_costs(state, civ_id)),
            "explain_ready_in": explain_ready_in(state, civ_id),
            "sealed": civ.sealed,
            "seal_turns": state.world.rules.rivals.seal_turns,
            "news_on_the_road": news_on_the_road(state, civ_id),
            "rumour_cost": cost(state, civ_id, state.world.rules.rivals.rumour_wealth_per_1000),
            "spy_cost": cost(state, civ_id, state.world.rules.rivals.spy_wealth_per_1000),
            "spy_turns": state.world.rules.rivals.spy_turns,
            "population": state.population(civ_id),
            "provinces": len(state.owned_provinces(civ_id)),
            # the time traveller's mark on history (D-126)
            "anachronisms": ahead_of_history(state, civ_id)[0],
            "years_ahead": ahead_of_history(state, civ_id)[1],
            **civ.stats.model_dump(),
            "framing": civ.framing.value,
            "collapsed": civ.collapsed,
            "dynasties": civ.dynasties,
            # fallen, but remembered: where the people may yet rise to restore the state
            "exile": [state.world.geography[p].name for p in remembered_in(state, civ_id)]
            if not state.owned_provinces(civ_id)
            else [],
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
                "adjective": other.adjective,
                "disposition": other.disposition.value,
                "ruler": other.ruler,
                "ruler_age": other.ruler_age,
                "faith": _faith_name(state, other.faith),
                "same_faith": bool(other.faith) and other.faith == civ.faith,
                "awareness": other.awareness.value,
                "strength": strengths[other_id],
                **_relation_to_player(state, other_id),
                **_intel(state, civ_id, other_id),
            }
            for other_id, other in sorted(state.civs.items())
        ],
        "wars": fronts(state),
        "armies": _armies(state),
        "tactics": _tactics(state),
        "fleets": _fleets(state),
        "navy": _navy(state, civ_id),
        "dilemma": _dilemma(state),
        "offer": {
            "from": state.offer.from_civ,
            "kind": state.offer.kind,
            **describe(state, state.offer),
        }
        if state.offer
        else None,
        "levy": _levy(state, civ_id),
        "battles": _battle_sites(state, events or []),
        "sea_battles": _sea_battle_sites(state, events or []),
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
                "walls": state.provinces[pid].walls,
                **_people(state, pid),
                "ravaged": state.provinces[pid].ravaged,
                "port": next(iter(seas_of(state, pid)), None),
                "blockaded": state.provinces[pid].blockaded,
                **_walls_next(state, pid),
                **_buildings(state, pid),
            }
            for pid, geography in sorted(state.world.geography.items())
        ],
        "seas": [
            {
                "id": sid,
                "name": sea.name,
                "position": list(sea.position) if sea.position else None,
                "latlon": list(sea.latlon) if sea.latlon else None,
                "shores": sorted(p for p in sea.neighbours if p in state.provinces),
                "links": sorted(links[sid]),
                "command": _command_of(state, sid),
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
                "hasten": asdict(hasten_cost(state, node_id)),
                "hastened": project.hastened_turn == state.turn,
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


def _intel(state: GameState, me: str, court: str) -> dict[str, Any]:
    """What the player knows of a court's plans, who says so, and the spies there (D-115)."""
    report = state.civs[me].intel.get(court)
    return {
        "intel": {
            "turn": report.turn,
            "source": report.source,
            "lines": list(report.lines),
            "trust_bp": report.trust_bp,
        }
        if report is not None and court != me
        else None,
        "spies": state.civs[me].spies.get(court, 0),
    }


def _defence(state: GameState, province_id: str) -> int:
    """How hard the province is to take from its holder (terrain, walls, last stand)."""
    owner = state.provinces[province_id].owner
    if owner is None:
        terrain = state.world.terrain[state.world.geography[province_id].terrain]
        return terrain.defence_bp
    return defence_bp(state, owner, province_id)


def next_steps(state: GameState, civ_id: str, node_id: str, limit: int = 3) -> list[dict[str, str]]:
    """The first ideas on the road to a blocked one that can be started now.

    Walks back through prerequisites not yet in use, nearest first, and keeps those whose
    own needs are met, so a ruling can offer "Begin" on the next step.
    """
    civ = state.civs[civ_id]
    found: list[dict[str, str]] = []
    seen: set[str] = set()
    queue = list(state.tech_nodes[node_id].prerequisites) if node_id in state.tech_nodes else []
    while queue and len(found) < limit:
        current = queue.pop(0)
        if current in seen or current not in state.tech_nodes:
            continue
        seen.add(current)
        known = civ.tech.get(current)
        if known is not None and known.stage is not Stage.CONCEPT:
            continue  # in use, or already being tried
        if feasibility(state, civ_id, current).blocked:
            queue.extend(sorted(state.tech_nodes[current].prerequisites))
        else:
            found.append({"id": current, "name": state.tech_nodes[current].name})
    return found


def ahead_of_history(state: GameState, civ_id: str) -> tuple[int, int]:
    """Ideas brought in before their time, and by how many years in all (D-126)."""
    count = years = 0
    for node_id, tech in sorted(state.civs[civ_id].tech.items()):
        node = state.tech_nodes.get(node_id)
        if node is None or tech.adopted_year is None or not tech.stage.is_adopted:
            continue
        if node.year > tech.adopted_year:
            count += 1
            years += node.year - tech.adopted_year
    return count, years


def _ideas(state: GameState, civ_id: str) -> list[dict[str, Any]]:
    """Every idea the player could see, with what each needs.

    Known ones, those ready to start, and everything from the future the player remembers
    (the notebook, D-126).
    """
    civ = state.civs[civ_id]
    free = max(1, capacity(state, civ_id).free_labour)
    ideas = []
    for node_id, node in sorted(state.tech_nodes.items(), key=lambda item: item[1].name):
        known = civ.tech.get(node_id)
        result = feasibility(state, civ_id, node_id)
        future = node.year > state.year
        if known is None and result.blocked and not future:
            continue
        cost = project_costs(state, node_id)
        thieves = sorted(
            state.civs[other].name
            for other in state.civs
            if other != civ_id
            and node_id in state.civs[other].tech
            and state.civs[other].tech[node_id].stolen
        )
        ideas.append(
            {
                "id": node_id,
                "name": node.name,
                "category": node.category.value,
                "year": node.year,
                "ahead": node.year - state.year,
                "complexity": node.complexity,
                "flavour": node.flavour,
                "history": node.history,
                "stage": known.stage.value if known else None,
                "adopted_year": known.adopted_year if known else None,
                "goal": bool(known and known.goal),
                "stub": node.stub,
                "provenance": node.provenance.value,
                "spread_bp": known.spread_bp if known else 0,
                "ready": not result.blocked and not (known and known.stage is not Stage.CONCEPT),
                "blockers": describe_blockers(state, result) if result.blocked else "",
                "needs": [
                    {
                        "id": p,
                        "name": state.tech_nodes[p].name if p in state.tech_nodes else p,
                        "have": is_adopted(civ, p),
                    }
                    for p in node.prerequisites
                ],
                "cost": {
                    "labour": cost.labour,
                    "materials": cost.materials,
                    "knowledge": cost.knowledge,
                    "wealth": cost.wealth,
                },
                "labour_share": min(999, cost.labour * 100 // free),
                "suspicion": adoption_suspicion_bp(state, node) // 100,
                "stolen_by": thieves,
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


def _people(state: GameState, province_id: str) -> dict[str, Any]:
    """Whose people live in a conquered province, and what holding it down takes."""
    if not restless(state, province_id):
        return {}
    province = state.provinces[province_id]
    people = state.civs.get(province.people or "")
    years = (state.turn - province.held_since) * state.world.years_per_turn
    rules = state.world.rules.armies
    return {
        "people": people.adjective if people else "",
        "conquered_years": years,
        "assimilate_in": max(0, rules.assimilation_years - years),
        "garrison_need": province.population // rules.garrison_people_per_man,
        "garrisoned": garrisoned(state, province_id),
    }


def _dilemma(state: GameState) -> dict[str, Any] | None:
    """The question waiting for the player's answer, if any."""
    dilemma = state.world.dilemmas.get(state.dilemma or "")
    if dilemma is None:
        return None
    return {
        "id": dilemma.id,
        "title": dilemma.title,
        "text": fill(state, dilemma.text),
        "choices": [{"label": c.label, "hint": effects_text(c)} for c in dilemma.choices],
    }


_BONUS_WORDS = (
    ("food_bp", "food"),
    ("materials_bp", "materials"),
    ("wealth_bp", "wealth"),
    ("knowledge_bp", "knowledge"),
    ("growth_bp", "growth"),
    ("capacity_bp", "room for people"),
)


def building_effects(kind: Building) -> str:
    """What a building does, in a few words (e.g. "+15% wealth, calms the realm")."""
    parts = [
        f"+{getattr(kind, name) // 100}% {word}"
        for name, word in _BONUS_WORDS
        if getattr(kind, name)
    ]
    if kind.calm_bp:
        parts.append("calms the realm")
    if kind.literacy_bp:
        parts.append("teaches reading")
    if kind.veterans_bp:
        parts.append("trains soldiers")
    return ", ".join(parts)


def _buildings(state: GameState, province_id: str) -> dict[str, Any]:
    """What stands in a province, what is going up, and (for yours) what could be built."""
    province = state.provinces[province_id]
    kinds = state.world.buildings
    out: dict[str, Any] = {
        "buildings": [
            {"id": b, "name": kinds[b].name, "look": kinds[b].look}
            for b in province.buildings
            if b in kinds
        ],
        "works": {
            "id": province.works.building,
            "name": kinds[province.works.building].name,
            "look": kinds[province.works.building].look,
            "turns": province.works.turns_left,
        }
        if province.works is not None and province.works.building in kinds
        else None,
        "slots": slots(state, province_id),
    }
    if province.owner == state.player_civ:
        options: list[dict[str, Any]] = []
        for kind, reason in building_options(state, state.player_civ, province_id):
            if reason == "already built here" or reason == "a better one already stands here":
                continue
            materials, wealth = building_cost(state, province_id, kind.id)
            options.append(
                {
                    "id": kind.id,
                    "name": kind.name,
                    "note": kind.note,
                    "does": building_effects(kind),
                    "materials": materials,
                    "wealth": wealth,
                    "turns": turns_for(state, kind.decades),
                    "why_not": reason,
                }
            )
        # what can be built first, then what is nearly in reach
        options.sort(key=lambda o: (o["why_not"] is not None, o["materials"] + o["wealth"]))
        out["can_build"] = options
    return out


def _walls_next(state: GameState, province_id: str) -> dict[str, Any]:
    """What the next level of walls here would cost and need (for the player's provinces)."""
    if state.provinces[province_id].owner != state.player_civ:
        return {}
    needed = wall_tech(state, province_id)
    if needed is None:
        return {"wall_next": None}
    materials, wealth = wall_cost(state, province_id)
    node = state.tech_nodes.get(needed)
    ready = node is None or is_adopted(state.civs[state.player_civ], needed)
    return {
        "wall_next": {
            "materials": materials,
            "wealth": wealth,
            "needs": "" if ready else (node.name if node else needed),
        }
    }


def _armies(state: GameState) -> list[dict[str, Any]]:
    """Every army in the field: where, who, how many, and where it is going."""
    out = []
    for army_id, army in sorted(state.armies.items()):
        owner = state.provinces[army.province].owner
        besieged = owner is not None and army.siege_bp > 0
        out.append(
            {
                "id": army_id,
                "owner": army.owner,
                "name": army.name,
                "province": army.province,
                "men": army.men,
                "troops": [
                    {"unit": u, "name": state.world.units[u].name, "men": n}
                    for u, n in sorted(army.troops.items(), key=lambda item: -item[1])
                ],
                "morale_bp": army.morale_bp,
                "general": army.general,
                "skill": army.skill,
                "trait": army.trait,
                "mercenary": army.contract > 0,
                "target": army.target,
                "route": route(state, army.owner, army.province, army.target)
                if army.target
                else [],
                "stance": army.stance,
                **_plan(state, army),
                "veterancy_bp": army.veterancy_bp,
                "siege_bp": army.siege_bp,
                "siege_needed": defence_bp(state, owner, army.province)
                if besieged and owner
                else 0,
            }
        )
    return out


def _plan(state: GameState, army: Army) -> dict[str, Any]:
    """An army's battle plan: ordered, likely here, and (if yours) which its men cannot do.

    A rival army's likely plan is its answer to the nearest of the player's armies.
    """
    owner = state.provinces[army.province].owner
    attacking = owner is not None and owner != army.owner
    terrain = state.world.geography[army.province].terrain
    out: dict[str, Any] = {
        "plan": army.plan,
        "reads": army.plan == AUTO and army.skill >= state.world.rules.armies.reads_enemy_skill,
    }
    if army.owner == state.player_civ:
        likely = natural(state, [army], attacking, terrain)
        out["lacking"] = {
            tid: why
            for tid, tactic in sorted(state.world.tactics.items())
            if (why := short_of_men(state, tactic, [army]))
        }
    else:
        foe = _nearest(state, army)
        if foe is None:
            likely = natural(state, [army], attacking, terrain)
        else:
            likely = final(state, [army], [foe], attacking, terrain)
    out["likely"] = {"id": likely.id, "name": likely.name} if likely else None
    return out


def _nearest(state: GameState, army: Army) -> Army | None:
    """The player's army a rival army would most likely meet: here, next door, or the largest."""
    near = set(state.world.geography[army.province].neighbours)
    mine = [a for a in state.armies.values() if a.owner == state.player_civ]
    return min(
        mine,
        key=lambda a: (a.province != army.province, a.province not in near, -a.men, a.id),
        default=None,
    )


def _tactics(state: GameState) -> list[dict[str, Any]]:
    """The battle plans, what each beats and what beats it, for the plan picker."""
    tactics = state.world.tactics
    return [
        {
            "id": tid,
            "name": t.name,
            "note": t.note,
            "beats": [tactics[b].name for b in t.beats if b in tactics],
            "beaten_by": [o.name for _, o in sorted(tactics.items()) if tid in o.beats],
            "needs": needs_text(state, t),
        }
        for tid, t in sorted(tactics.items())
    ]


def _fleets(state: GameState) -> list[dict[str, Any]]:
    """Every fleet at sea: whose, where, how many ships, and where it is sailing."""
    out = []
    for fleet_id, fleet in sorted(state.fleets.items()):
        ship = state.world.ships[fleet.ship]
        out.append(
            {
                "id": fleet_id,
                "owner": fleet.owner,
                "name": fleet.name,
                "sea": fleet.sea,
                "ship": fleet.ship,
                "ship_name": ship.name,
                "ships": fleet.ships,
                "power": fleet.ships * ship.attack,
                "upkeep": fleet.ships * ship.upkeep_wealth // 10,
                "target": fleet.target,
                "route": sea_route(state, fleet.sea, fleet.target) if fleet.target else [],
            }
        )
    return out


def _navy(state: GameState, civ_id: str) -> dict[str, Any]:
    """What the player's shipyards can build: the best warship and what squadrons cost."""
    ship = best_ship(state, civ_id)
    if ship is None:
        sailing = state.tech_nodes.get("sailing")
        return {"ship": None, "needs": sailing.name if sailing else "Sailing"}
    return {
        "ship": ship.name,
        "ship_id": ship.id,
        "attack": ship.attack,
        "note": ship.note,
        "sizes": {
            size: {
                "ships": n,
                "materials": ship.materials * n,
                "wealth": ship.wealth * n,
                "upkeep": n * ship.upkeep_wealth // 10,
            }
            for size, n in SIZES.items()
        },
    }


def _command_of(state: GameState, sea: str) -> str | None:
    """Who commands a sea: the owner of the most naval power there, if anyone's ships are."""
    owners = sorted({f.owner for f in state.fleets.values() if f.sea == sea})
    if not owners:
        return None
    return max(owners, key=lambda o: (sea_power(state, o, sea), o))


def _levy(state: GameState, civ_id: str) -> dict[str, Any]:
    """What raising troops would give and cost: shares, styles and costs per 10,000 men."""
    rules = state.world.rules.armies
    styles = {}
    for style in STYLES:
        troops = composition(state, civ_id, 10_000, style)
        food, materials, wealth = raise_cost(state, troops)
        styles[style] = {
            "units": [state.world.units[u].name for u in troops],
            "food": food,
            "materials": materials,
            "wealth": wealth,
        }
    return {
        "martial_bp": state.civs[civ_id].martial_bp,
        "sizes": {
            "small": rules.raise_small_bp,
            "medium": rules.raise_medium_bp,
            "large": rules.raise_large_bp,
        },
        "styles": styles,
        "under_arms": under_arms(state, civ_id),
        "cap": mobilisation_cap(state, civ_id),
        "kinds": [u.name for u in available_units(state, civ_id)],
    }


def _battle_sites(state: GameState, events: list[Event]) -> list[str]:
    """Provinces where battles were fought in the last turn (for the crossed swords)."""
    by_name = {g.name.split(" (")[0]: pid for pid, g in state.world.geography.items()}
    return sorted(
        {by_name[e.subject] for e in events if e.kind == "battle_won" and e.subject in by_name}
    )


def _sea_battle_sites(state: GameState, events: list[Event]) -> list[str]:
    """Seas where fleets fought in the last turn."""
    by_name = {sea.name: sid for sid, sea in state.world.seas.items()}
    return sorted(
        {by_name[e.subject] for e in events if e.kind == "sea_battle_won" and e.subject in by_name}
    )


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
                    "symbol": definition.symbol or "",
                    "portrait": definition.portrait,
                    "leader": start.leader,
                    "pitch": start.pitch,
                    "population": sum(start.provinces.values()),
                    "provinces": len(start.provinces),
                    "capital": content.provinces[start.capital].name,
                    "advances": sum(stage.is_adopted for stage in start.techs.values()),
                    "literacy_bp": start.stats.literacy_bp,
                    # chronicle mode (D-120): how many chapters of history this state has
                    "chronicle": sum(
                        1
                        for c in content.chapters.values()
                        if c.scenario == scenario_id and c.civ == civ_id
                    ),
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
