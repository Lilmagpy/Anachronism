"""The compact state summary a ruling is made from (brief §6.4), and related-node search.

Built fresh for every idea, because a model remembers nothing between calls. It holds only
what is needed to judge feasibility, and stays small late in a game because only the nodes
related to the idea are shown in full. Pure: no model, no network.
"""

from __future__ import annotations

import re

from anachronism.content.schema import TechNode
from anachronism.engine.economy import project_costs
from anachronism.engine.projects import project_turns
from anachronism.engine.reports import capacity
from anachronism.engine.state import GameState
from anachronism.engine.tech import is_adopted, usable_resources
from anachronism.engine.timeflow import current_era

_WORD = re.compile(r"[a-z]+")
_STOP = frozenset(
    {
        "a", "an", "and", "the", "of", "to", "for", "in", "on", "with", "our", "we", "us", "my",
        "me", "make", "let", "build", "use", "using", "get", "have", "more", "better", "new",
        "way", "ways", "people", "them", "it", "its", "that", "this", "some", "into", "from", "by",
        "at", "be", "can", "should", "could", "would", "like", "want", "idea", "ideas", "start",
        "try", "work", "works", "everyone", "everywhere", "all", "every", "whole", "really",
        "much", "lot",
    }
)  # fmt: skip


_GENERIC = frozenset({"machine", "thing", "system", "tool", "method", "device", "great", "good"})
"""Words too general to point at one advancement on their own ("flying machines" is not
"spinning machines"); they still count inside a whole matching phrase."""


def words(text: str) -> list[str]:
    """Lower-case words of a text without the filler, singular where that is obvious."""
    found = []
    for word in _WORD.findall(text.lower()):
        if word in _STOP or len(word) < 3:
            continue
        if len(word) > 4 and word.endswith("s") and not word.endswith("ss"):
            word = word[:-1]
        found.append(word)
    return found


def match_score(node: TechNode, text: str) -> int:
    """How strongly a text points at a node: whole keyword phrases count most."""
    lowered = " " + " ".join(_WORD.findall(text.lower())) + " "
    idea = set(words(text))
    whole = " ".join(words(text))
    score = 0
    loose: set[str] = set()  # single words shared with the idea, each counted once
    for phrase in (node.name, *node.keywords, node.id.replace("_", " ")):
        phrase_words = words(phrase)
        if not phrase_words:
            continue
        if f" {phrase.lower()} " in lowered and len(phrase_words) > 1:
            score += 6 * len(phrase_words)
        elif whole and whole == " ".join(phrase_words):
            score += 6  # the idea is exactly this keyword ("democracy")
        else:
            loose.update(w for w in phrase_words if w in idea and w not in _GENERIC)
    # (a word repeated across many keywords - "iron" - must not outweigh the idea's others);
    # long words are distinctive, and naming every word of a short idea counts extra
    score += sum(4 if len(w) > 5 else 3 if len(w) > 3 else 2 for w in loose)
    if idea and loose >= idea - _GENERIC:
        score += 2
    return score


def related_nodes(state: GameState, text: str, limit: int = 6) -> list[TechNode]:
    """Existing advancements an idea is about, best first, then their prerequisites."""
    scored = sorted(
        ((match_score(node, text), node_id) for node_id, node in sorted(state.tech_nodes.items())),
        key=lambda pair: (-pair[0], pair[1]),
    )
    chosen: list[str] = [node_id for score, node_id in scored if score > 0][:limit]
    for node_id in list(chosen):
        for prerequisite in state.tech_nodes[node_id].prerequisites:
            if prerequisite not in chosen and len(chosen) < limit + 3:
                chosen.append(prerequisite)
    return [state.tech_nodes[n] for n in chosen]


def _trend(state: GameState, civ_id: str, field: str) -> str:
    history = state.civs[civ_id].history
    if len(history) < 2:
        return "steady"
    now, before = getattr(history[-1], field), getattr(history[-2], field)
    return "rising" if now > before else "falling" if now < before else "steady"


def _node_line(state: GameState, node: TechNode) -> str:
    effects = ", ".join(f"{e.type.value} {e.bp / 100:+g}%" for e in node.effects if e.bp)
    needs = [state.tech_nodes[p].name for p in node.prerequisites if p in state.tech_nodes]
    needs += [state.world.resources[m].name for m in node.requires.materials]
    year = f"{-node.year} BC" if node.year < 0 else f"AD {node.year}"
    parts = [f"{node.id} '{node.name}' {node.category.value} c{node.complexity} {year}"]
    if effects:
        parts.append(effects)
    if needs:
        parts.append("needs " + ", ".join(needs))
    return "[" + "; ".join(parts) + "]"


def build(state: GameState, civ_id: str, idea: str) -> str:
    """The summary for ruling on ``idea`` (brief §6.4).

    Identity, numbers, capacity, knowledge, map, projects, related nodes, recent history.
    """
    civ = state.civs[civ_id]
    stats = civ.stats
    room = capacity(state, civ_id)
    year = f"{-state.year} BC" if state.year < 0 else f"AD {state.year}"
    lines = [
        f"CIV: {civ.name}, {year}, {current_era(state).name} era, "
        f"{len(state.owned_provinces(civ_id))} provinces.",
        f"STATS: pop {state.population(civ_id):,} ({_trend(state, civ_id, 'population')}), "
        f"food {room.food} ({_trend(state, civ_id, 'food')}), materials {room.materials}, "
        f"wealth {room.wealth}, knowledge {room.knowledge}, "
        f"literacy {stats.literacy_bp / 100:.1f}%, unrest {stats.unrest_bp / 100:.0f}, "
        f"legitimacy {stats.legitimacy_bp / 100:.0f}, suspicion {stats.suspicion_bp / 100:.0f}",
        f"FREE CAPACITY: labour {room.free_labour} of {room.workforce}",
    ]
    known: dict[str, list[str]] = {}
    for node_id in sorted(civ.tech):
        if is_adopted(civ, node_id):
            node = state.tech_nodes[node_id]
            known.setdefault(node.category.value, []).append(node.name.lower())
    lines.append(
        "KNOWN: " + " ".join(f"{cat}[{', '.join(names)}]" for cat, names in sorted(known.items()))
    )
    usable = usable_resources(state, civ_id)
    coastal = any(state.world.geography[pid].coastal for pid in state.owned_provinces(civ_id))
    resources = ", ".join(state.world.resources[r].name.lower() for r in sorted(usable))
    lines.append(f"MAP: {'coastal' if coastal else 'landlocked'}; resources: {resources or 'none'}")
    built: dict[str, int] = {}
    for pid in state.owned_provinces(civ_id):
        for b in state.provinces[pid].buildings:
            name = state.world.buildings[b].name if b in state.world.buildings else b
            built[name] = built.get(name, 0) + 1
    listed = ", ".join(f"{n} x{k}" if k > 1 else n for n, k in sorted(built.items()))
    lines.append(f"BUILDINGS: {listed or 'none'}")  # infrastructure (D-114)
    projects = []
    for node_id, project in sorted(civ.projects.items()):
        cost = project_costs(state, node_id)
        left = max(1, project_turns(state, node_id) * (10_000 - project.progress_bp) // 10_000)
        projects.append(
            f"{state.tech_nodes[node_id].name} ({left} turns left, -{cost.labour} labour/turn)"
        )
    lines.append("ACTIVE PROJECTS: " + ("; ".join(projects) if projects else "none"))
    related = related_nodes(state, idea)
    lines.append("RELATED NODES: " + (" ".join(_node_line(state, n) for n in related) or "none"))
    recent = [e.message for e in state.events if e.civ in (civ_id, None)][-3:]
    rulings = [
        f"ruled '{entry.action.ruling.idea[:40]}' {entry.action.ruling.verdict.value}"
        for entry in state.action_log
        if entry.action.kind == "ruling" and entry.action.civ == civ_id
    ][-2:]
    lines.append("RECENT: " + (" ".join([*rulings, *recent]) or "nothing of note"))
    return "\n".join(lines)
