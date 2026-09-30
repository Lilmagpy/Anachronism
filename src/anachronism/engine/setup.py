"""Build the starting ``GameState`` for a scenario."""

from __future__ import annotations

from anachronism import __version__
from anachronism.content.loader import Content
from anachronism.content.schema import (
    CivDefinition,
    ProvinceGeography,
    ScenarioCiv,
    SocialGroup,
    Stage,
)
from anachronism.engine.fixed import BP
from anachronism.engine.rng import GameRng
from anachronism.engine.state import (
    CivState,
    GameState,
    ProvinceState,
    Stats,
    Stockpiles,
    TechState,
    World,
)


def build_state(
    content: Content, scenario_id: str, seed: int, player_civ: str | None = None
) -> GameState:
    """Create the state at the start of a scenario (before any turn is played).

    Raises:
        ValueError: if the scenario does not exist, or ``player_civ`` is not in it.
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
        rules=content.rules,
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
    )
    civs = {
        civ_id: _start_civ(content.civs[civ_id], start, content.rules.spread.baseline_adopted_bp)
        for civ_id, start in sorted(scenario.civs.items())
    }
    return GameState(
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


def _trim_neighbours(geography: ProvinceGeography, in_play: set[str]) -> ProvinceGeography:
    kept = tuple(n for n in geography.neighbours if n in in_play)
    if kept == geography.neighbours:
        return geography
    return geography.model_copy(update={"neighbours": kept})


def _start_civ(identity: CivDefinition, start: ScenarioCiv, adopted_spread_bp: int) -> CivState:
    tech = {}
    for node_id, stage in sorted(start.techs.items()):
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
