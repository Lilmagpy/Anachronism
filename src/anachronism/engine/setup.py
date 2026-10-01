"""Build the starting ``GameState`` for a scenario."""

from __future__ import annotations

from anachronism import __version__
from anachronism.content.loader import Content
from anachronism.content.schema import (
    CivDefinition,
    ProvinceGeography,
    RelationStatus,
    Rules,
    ScenarioCiv,
    SocialGroup,
    Stage,
)
from anachronism.engine.fixed import BP
from anachronism.engine.rivals import contact_pairs
from anachronism.engine.rng import GameRng
from anachronism.engine.state import (
    CivState,
    GameState,
    ProvinceState,
    Relation,
    Stats,
    Stockpiles,
    TechState,
    World,
)


def build_state(
    content: Content,
    scenario_id: str,
    seed: int,
    player_civ: str | None = None,
    difficulty: str = "normal",
) -> GameState:
    """Create the state at the start of a scenario (before any turn is played).

    ``difficulty`` names a level in the rules (``easy``, ``hard``); ``normal`` is the rules
    as written. The chosen rules are stored in the state, so saves and replays keep them.

    Raises:
        ValueError: if the scenario does not exist, ``player_civ`` is not in it, or the
            difficulty is unknown.
    """
    scenario = content.scenarios.get(scenario_id)
    if scenario is None:
        known = ", ".join(sorted(content.scenarios)) or "none"
        raise ValueError(f"unknown scenario {scenario_id!r} (available: {known})")
    player = scenario.player_civ if player_civ is None else player_civ
    if player not in scenario.civs:
        known = ", ".join(sorted(scenario.civs))
        raise ValueError(f"{player!r} is not a civilisation in {scenario_id} (choose: {known})")
    in_play = sorted(
        {pid for start in scenario.civs.values() for pid in start.provinces} | set(scenario.unowned)
    )
    geography = {pid: _trim_neighbours(content.provinces[pid], set(in_play)) for pid in in_play}
    owners = {pid: civ_id for civ_id, start in scenario.civs.items() for pid in start.provinces}
    populations = {
        pid: pop for start in scenario.civs.values() for pid, pop in start.provinces.items()
    }
    populations.update(scenario.unowned)
    provinces = {
        pid: ProvinceState(
            owner=owners.get(pid),
            people=owners.get(pid),
            population=populations[pid],
            resources=dict(sorted(geography[pid].resources.items())),
        )
        for pid in in_play
    }
    world = World(
        scenario_id=scenario.id,
        scenario_name=scenario.name,
        content_digest=content.digest,
        years_per_turn=scenario.years_per_turn,
        rules=_rules_for(content, difficulty),
        difficulty=difficulty,
        eras=content.eras,
        effect_caps={effect: dict(caps) for effect, caps in content.effect_caps.items()},
        terrain=dict(content.terrain),
        resources=dict(content.resources),
        geography=geography,
        seas={
            sid: sea
            for sid, sea in sorted(content.seas.items())
            if any(p in geography for p in sea.neighbours)
        },
        map=scenario.map,
        cost_scale=scenario.cost_scale,
        happenings=dict(sorted(content.happenings.items())),
        units=dict(content.units),
        tales=dict(sorted(content.tales.items())),
        dilemmas=dict(sorted(content.dilemmas.items())),
        faiths={f.id: f for f in scenario.faiths},
        successors={
            c: start.successors for c, start in sorted(scenario.civs.items()) if start.successors
        },
        scripts={c: start.scripts for c, start in sorted(scenario.civs.items()) if start.scripts},
    )
    needs = {node_id: set(node.prerequisites) for node_id, node in content.techs.items()}
    civs = {
        civ_id: _start_civ(
            content.civs[civ_id],
            start,
            scenario.starting_techs(civ_id, needs),
            content.rules.spread.baseline_adopted_bp,
        )
        for civ_id, start in sorted(scenario.civs.items())
    }
    for civ_id, start in scenario.civs.items():
        civs[civ_id].disposition = start.disposition
        civs[civ_id].ruler = start.leader
        civs[civ_id].ruler_age = start.leader_age
        civs[civ_id].martial_bp = start.martial_bp
        civs[civ_id].generals = list(start.generals)
    for faith in scenario.faiths:
        for follower in faith.followers:
            civs[follower].faith = faith.id
    relations = {
        f"{a}|{b}": Relation(status=RelationStatus.NEUTRAL)
        for a, b in sorted(contact_pairs(world, owners))
    }
    for listed in scenario.relations:
        a, b = sorted((listed.a, listed.b))
        rel = relations.setdefault(f"{a}|{b}", Relation(status=listed.status))
        rel.status = listed.status
        if listed.grievance_bp:
            rel.grievance = {a: listed.grievance_bp, b: listed.grievance_bp}
    return GameState(
        relations=relations,
        engine_version=__version__,
        seed=seed,
        rng=GameRng.from_seed(seed).state,
        year=scenario.start_year,
        player_civ=player,
        world=world,
        tech_nodes=dict(sorted(content.techs.items())),
        provinces=provinces,
        civs=civs,
    )


def _rules_for(content: Content, difficulty: str) -> Rules:
    """The rules with a difficulty level's overrides to the rival rules applied."""
    rules = content.rules
    if difficulty == "normal":
        return rules
    if difficulty not in rules.difficulty:
        known = ", ".join(["normal", *sorted(rules.difficulty)])
        raise ValueError(f"unknown difficulty {difficulty!r} (choose: {known})")
    rivals = rules.rivals.model_copy(update=rules.difficulty[difficulty])
    return rules.model_copy(update={"rivals": rivals})


def _trim_neighbours(geography: ProvinceGeography, in_play: set[str]) -> ProvinceGeography:
    kept = tuple(n for n in geography.neighbours if n in in_play)
    if kept == geography.neighbours:
        return geography
    return geography.model_copy(update={"neighbours": kept})


def _start_civ(
    identity: CivDefinition, start: ScenarioCiv, techs: dict[str, Stage], adopted_spread_bp: int
) -> CivState:
    tech = {}
    for node_id, stage in sorted(techs.items()):
        if stage is Stage.WIDESPREAD:
            spread = BP
        elif stage is Stage.ADOPTED:
            spread = adopted_spread_bp
        else:
            spread = 0
        tech[node_id] = TechState(stage=stage, spread_bp=spread)
    return CivState(
        id=identity.id,
        name=identity.name,
        adjective=identity.adjective,
        lineage=identity.lineage,
        colour=identity.colour,
        capital=start.capital,
        starting_provinces=len(start.provinces),
        influence={group: start.influence.get(group, 0) for group in SocialGroup},
        stockpiles=Stockpiles(**start.stockpiles.model_dump()),
        stats=Stats(**start.stats.model_dump()),
        tech=tech,
    )
