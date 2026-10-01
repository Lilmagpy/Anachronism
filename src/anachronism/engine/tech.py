"""The tech graph from a civilisation's point of view: feasibility, goals, adoption, spread."""

from __future__ import annotations

from dataclasses import dataclass

from anachronism.content.schema import Access, Category, EffectType, Provenance, Stage, TechNode
from anachronism.engine.effects import Effects
from anachronism.engine.events import EventLog, list_names
from anachronism.engine.fixed import BP, apply_bp, clamp, with_bonus
from anachronism.engine.state import CivState, GameState, TechState
from anachronism.engine.suspicion import on_adoption
from anachronism.engine.timeflow import rate_per_turn


@dataclass(frozen=True)
class Feasibility:
    """What stands between a civilisation and experimenting with an advancement."""

    node_id: str
    stage: Stage | None
    """The civilisation's current stage for this node, if it knows it."""
    missing_prerequisites: tuple[str, ...]
    missing_materials: tuple[str, ...]
    missing_widespread: tuple[str, ...]
    literacy_shortfall_bp: int
    """Soft requirement: how far literacy is below what the node wants (raises setbacks)."""
    stub: bool

    @property
    def blocked(self) -> bool:
        """True if a hard requirement is missing, so no project can start."""
        return bool(
            self.missing_prerequisites
            or self.missing_materials
            or self.missing_widespread
            or self.stub
        )


def usable_resources(state: GameState, civ_id: str) -> set[str]:
    """Map resources the civilisation can use (accessible or limited in an owned province)."""
    return {
        resource
        for province in state.provinces.values()
        if province.owner == civ_id
        for resource, access in province.resources.items()
        if access.usable
    }


def is_adopted(civ: CivState, node_id: str) -> bool:
    """True if the civilisation uses the advancement (adopted or widespread)."""
    tech = civ.tech.get(node_id)
    return tech is not None and tech.stage.is_adopted


def feasibility(state: GameState, civ_id: str, node_id: str) -> Feasibility:
    """Check every requirement of an advancement for a civilisation (DESIGN §6)."""
    civ = state.civs[civ_id]
    node = state.tech_nodes[node_id]
    tech = civ.tech.get(node_id)
    resources = usable_resources(state, civ_id)
    return Feasibility(
        node_id=node_id,
        stage=tech.stage if tech else None,
        missing_prerequisites=tuple(p for p in node.prerequisites if not is_adopted(civ, p)),
        missing_materials=tuple(m for m in node.requires.materials if m not in resources),
        missing_widespread=tuple(
            w
            for w in node.requires.widespread
            if (known := civ.tech.get(w)) is None or known.stage is not Stage.WIDESPREAD
        ),
        literacy_shortfall_bp=max(0, node.requires.literacy_bp - civ.stats.literacy_bp),
        stub=node.stub,
    )


def propose(state: GameState, civ_id: str, node_id: str) -> Feasibility:
    """Make an idea a known concept; unknown missing prerequisites become visible goals.

    Goals cost nothing: no resources are committed until the player starts a project.
    """
    civ = state.civs[civ_id]
    if node_id not in civ.tech:
        civ.tech[node_id] = TechState(stage=Stage.CONCEPT)
    result = feasibility(state, civ_id, node_id)
    for missing in (*result.missing_prerequisites, *result.missing_widespread):
        if missing not in civ.tech:
            civ.tech[missing] = TechState(stage=Stage.CONCEPT, goal=True)
    return result


def add_stub(state: GameState, node_id: str, name: str, category: Category) -> TechNode:
    """Add a placeholder node named by a ruling; it must be ruled on before it can start."""
    existing = state.tech_nodes.get(node_id)
    if existing is not None:
        return existing
    stub = TechNode(
        id=node_id,
        name=name,
        category=category,
        year=state.year,
        complexity=1,
        provenance=Provenance.LLM,
        stub=True,
    )
    state.tech_nodes[node_id] = stub
    return stub


def resistance_bp(state: GameState, civ: CivState, node: TechNode) -> int:
    """Unrest per decade caused by social groups opposing an advancement."""
    per_level = state.world.rules.society.resistance_unrest_bp
    return sum(
        apply_bp(resistance.level * per_level, civ.influence.get(resistance.group, 0))
        for resistance in node.resistance
    )


def adopt(state: GameState, civ: CivState, node_id: str, events: EventLog) -> None:
    """A completed project: the advancement is adopted and starts spreading."""
    node = state.tech_nodes[node_id]
    tech = civ.tech.setdefault(node_id, TechState(stage=Stage.CONCEPT))
    tech.stage = Stage.ADOPTED
    tech.goal = False
    tech.spread_bp = max(tech.spread_bp, state.world.rules.projects.initial_spread_bp)
    events.add(
        civ.id, "adopted", f"{node.name} is adopted in the {civ.adjective} lands.", node.name
    )
    for effect in node.effects:
        if effect.type is EffectType.UNLOCKS_RESOURCE and effect.target is not None:
            _discover(state, civ, effect.target, events)
        elif (
            effect.type in (EffectType.UNLOCKS_BUILDING, EffectType.UNLOCKS_UNIT)
            and effect.target is not None
            and effect.target not in civ.unlocked
        ):
            civ.unlocked = sorted([*civ.unlocked, effect.target])
    opposition = resistance_bp(state, civ, node)
    if opposition:
        civ.stats.unrest_bp = clamp(civ.stats.unrest_bp + opposition, 0, BP)
        events.add(
            civ.id, "resistance", f"Some in {civ.name} resent the new {node.name}.", node.name
        )
    on_adoption(state, civ, node, events)


def _discover(state: GameState, civ: CivState, resource: str, events: EventLog) -> None:
    name = state.world.resources[resource].name
    for province_id in state.owned_provinces(civ.id):
        province = state.provinces[province_id]
        if province.resources.get(resource) is Access.UNEXPLORED:
            province.resources[resource] = Access.ACCESSIBLE
            place = state.world.geography[province_id].name
            events.add(civ.id, "discovery", f"{name} found in {place}.", name)


def spread_step(state: GameState, civ: CivState, effects: Effects, events: EventLog) -> None:
    """Adopted advancements spread; past the threshold they become widespread."""
    rules = state.world.rules.spread
    per_decade = rules.base_bp + apply_bp(rules.literacy_bonus_bp, civ.stats.literacy_bp)
    gain = rate_per_turn(state, with_bonus(per_decade, effects[EffectType.MOBILITY]))
    now_common: list[str] = []
    for node_id, tech in sorted(civ.tech.items()):
        if not tech.stage.is_adopted or tech.spread_bp >= BP:
            continue
        tech.spread_bp = min(BP, tech.spread_bp + gain)
        if tech.stage is Stage.ADOPTED and tech.spread_bp >= rules.widespread_at_bp:
            tech.stage = Stage.WIDESPREAD
            now_common.append(state.tech_nodes[node_id].name)
    if now_common:
        verb = "is" if len(now_common) == 1 else "are"
        events.add(
            civ.id,
            "widespread",
            f"{list_names(now_common)} {verb} now common across {civ.name}.",
            list_names(now_common),
        )
