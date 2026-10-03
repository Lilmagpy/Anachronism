"""Turning a model's reply into engine rulings, with every value bounded (D-020).

The model speaks in percentages and 0-3 levels; the engine wants basis points, known ids
and numbers inside the era's caps. Anything the model gets wrong in a harmless way is
repaired (unknown prerequisites dropped, too many effects cut); the engine bounds the result
once more when it applies it (``engine/judge.py``).
"""

from __future__ import annotations

import re

from anachronism.content.schema import Effect, Requirements, Resistance, TechNode
from anachronism.engine.rulings import AdviserReaction, Ruling, Source, StubSpec, Verdict
from anachronism.engine.state import GameState
from anachronism.engine.summary import match_score
from anachronism.llm.schemas import ModelIdea, ModelReply


def slug(name: str) -> str:
    """A node id from a name: ``"Steam engine!"`` -> ``"steam_engine"``."""
    words = re.findall(r"[a-z0-9]+", name.lower())
    text = "_".join(words)[:48].strip("_") or "idea"
    return text if text[0].isalpha() else f"idea_{text}"


def _resource_id(state: GameState, name: str) -> str | None:
    wanted = name.strip().lower()
    for resource_id, resource in sorted(state.world.resources.items()):
        if wanted in (resource_id, resource.name.lower()):
            return resource_id
    return None


def _existing_match(state: GameState, idea: ModelIdea) -> str | None:
    """The node an idea refers to: the one the model named, or one with the same name."""
    if idea.matches in state.tech_nodes and not state.tech_nodes[idea.matches].stub:
        return idea.matches
    if idea.name:
        wanted = slug(idea.name)
        for node_id, node in sorted(state.tech_nodes.items()):
            if node.stub:
                continue
            if node_id == wanted or node.name.lower() == idea.name.lower():
                return node_id
    return None


def _stubs(state: GameState, idea: ModelIdea) -> tuple[StubSpec, ...]:
    limit = state.world.rules.rulings.max_stubs
    specs: dict[str, StubSpec] = {}
    for missing in idea.missing:
        # a "missing" step that already exists in the graph is a prerequisite, not a stub
        existing = next(
            (
                n
                for n in sorted(state.tech_nodes)
                if match_score(state.tech_nodes[n], missing.name) >= 12
            ),
            None,
        )
        stub_id = existing or slug(missing.name)
        specs.setdefault(
            stub_id, StubSpec(id=stub_id, name=missing.name[:80], category=missing.category)
        )
    return tuple(specs.values())[:limit]


def _new_node(state: GameState, idea: ModelIdea, stubs: tuple[StubSpec, ...]) -> TechNode:
    node_id = slug(idea.name or idea.text)
    effects: list[Effect] = []
    for effect in idea.effects:
        bp = round(effect.percent * 100)
        if bp == 0 or effect.type.is_unlock:
            continue
        if bp < 0 and not effect.type.may_be_negative:
            continue
        if any(e.type is effect.type for e in effects):
            continue
        effects.append(Effect(type=effect.type, bp=bp))
    materials = tuple(
        dict.fromkeys(r for m in idea.materials if (r := _resource_id(state, m)) is not None)
    )
    resistance: dict[str, Resistance] = {}
    for opposed in idea.resistance:
        resistance.setdefault(
            opposed.group.value, Resistance(group=opposed.group, level=opposed.level)
        )
    prerequisites = [p for p in idea.prerequisites if p in state.tech_nodes]
    prerequisites += [s.id for s in stubs]
    node = TechNode(
        id=node_id,
        name=(idea.name or idea.text or "An idea")[:80],
        category=idea.category,
        year=idea.year or state.year,
        complexity=idea.complexity,
        visibility=2,
        prerequisites=tuple(dict.fromkeys(p for p in prerequisites if p != node_id)),
        requires=Requirements(materials=materials, literacy_bp=round(idea.literacy_percent * 100)),
        resistance=tuple(resistance.values()),
        effects=tuple(effects),
        flavour=idea.flavour[:200],
    )
    return node


def to_rulings(
    state: GameState,
    reply: ModelReply,
    source: Source,
    model: str = "",
    prompt_version: str = "",
) -> list[Ruling]:
    """Engine rulings for each idea in a reply, bounded; at most the rules' idea limit."""
    limits = state.world.rules.rulings
    rulings: list[Ruling] = []
    for idea in reply.ideas[: limits.max_ideas_per_message]:
        stubs: tuple[StubSpec, ...] = ()
        node_id = _existing_match(state, idea)
        new_node = None
        verdict = idea.verdict
        if verdict is not Verdict.IMPLAUSIBLE and node_id is None:
            if not (idea.name or idea.text):
                continue
            stubs = _stubs(state, idea) if verdict is Verdict.BLOCKED else ()
            stubs = tuple(
                s for s in stubs if s.id not in state.tech_nodes or state.tech_nodes[s.id].stub
            )
            new_node = _new_node(state, idea, stubs)
            if new_node.id in state.tech_nodes and not state.tech_nodes[new_node.id].stub:
                node_id, new_node = new_node.id, None
            else:
                node_id = new_node.id
        advisers = tuple(
            AdviserReaction(role=a.role, text=a.text, mood=a.mood) for a in idea.advisers[:2]
        )
        rulings.append(
            Ruling(
                idea=(idea.text or idea.name)[:300],
                verdict=verdict,
                node_id=node_id if verdict is not Verdict.IMPLAUSIBLE else None,
                new_node=new_node if verdict is not Verdict.IMPLAUSIBLE else None,
                stubs=stubs,
                reason=idea.reason[:400],
                hint=idea.hint[:300],
                advisers=advisers,
                unrest_bp=idea.stirs_unrest * limits.adviser_unrest_bp // 3,
                suspicion_bp=idea.stirs_suspicion * limits.adviser_suspicion_bp // 3,
                source=source,
                model=model[:80],
                prompt_version=prompt_version,
            )
        )
    return rulings
