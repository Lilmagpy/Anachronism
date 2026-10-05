"""Battle formations (D-267): how each side draws up its line, and what that is worth.

Like battle plans (``tactics.py``), a ruler may order a formation; left to himself (``auto``)
a general draws up against what he expects of the enemy, and a great general reads the
enemy's real formation and answers it. A formation that beats the enemy's gives its side an
edge in the clash. A wide line needs the numbers; without them it is thin.
"""

from __future__ import annotations

from anachronism.content.schema import Formation
from anachronism.engine.fixed import BP
from anachronism.engine.state import Army, GameState
from anachronism.engine.tactics import AUTO, commander

__all__ = ["AUTO", "answer", "edge", "final", "formations", "lacks", "natural", "thin"]


def _men(armies: list[Army]) -> int:
    return sum(a.men for a in armies)


def lacks(form: Formation, side: list[Army], other: list[Army], terrain: str = "") -> str:
    """Why a side cannot properly draw up in this formation against this enemy, or ""."""
    if terrain and terrain in form.blocked_terrain:
        return "too rough a place to form a line like that"
    if form.needs_ratio_bp and _men(side) * BP < form.needs_ratio_bp * _men(other):
        ratio = form.needs_ratio_bp
        return f"needs {ratio // BP}.{ratio % BP // 1000} times the enemy's men"
    return ""


def thin(form: Formation, side: list[Army], other: list[Army], terrain: str = "") -> bool:
    """True when the formation is stretched beyond the side's numbers (or the ground)."""
    return bool(lacks(form, side, other, terrain))


def power(form: Formation, side: list[Army], other: list[Army], terrain: str = "") -> int:
    """The formation's own worth in the first clash (bp, before any edge)."""
    return form.power_bp - (form.thin_bp if thin(form, side, other, terrain) else 0)


def edge(
    mine: Formation,
    theirs: Formation,
    side: list[Army],
    other: list[Army],
    terrain: str = "",
) -> int:
    """The edge one formation has over another (0 if it does not beat it, or is thin)."""
    if thin(mine, side, other, terrain):
        return 0
    if theirs.id in mine.beats:
        return mine.edge_bp
    if theirs.id in mine.duel and commander(side).skill > commander(other).skill:
        return mine.edge_bp  # the better general wins the meeting of equals (Leuctra)
    return 0


def _merit(form: Formation) -> int:
    return form.power_bp + form.reserve_bp // 2 + form.natural_bp


def _options(
    state: GameState, side: list[Army], other: list[Army], terrain: str
) -> list[Formation]:
    return [
        f for _, f in sorted(state.world.formations.items()) if not lacks(f, side, other, terrain)
    ]


def natural(
    state: GameState, side: list[Army], other: list[Army], terrain: str = ""
) -> Formation | None:
    """The formation a general draws up in knowing nothing of what the enemy will do."""
    options = _options(state, side, other, terrain)
    return max(options, key=lambda f: (_merit(f), f.id), default=None)


def ordered(state: GameState, side: list[Army]) -> Formation | None:
    """The formation its ruler ordered, if there is such a formation."""
    return state.world.formations.get(commander(side).formation)


def answer(
    state: GameState,
    side: list[Army],
    other: list[Army],
    theirs: Formation | None,
    terrain: str = "",
) -> Formation | None:
    """The best formation for this side against an enemy formation."""
    if theirs is None:
        return natural(state, side, other, terrain)

    def value(f: Formation) -> int:
        worth = _merit(f) // 2 + edge(f, theirs, side, other, terrain)
        return worth - edge(theirs, f, other, side, terrain)

    options = _options(state, side, other, terrain)
    return max(options, key=lambda f: (value(f), f.id), default=None)


def first_thought(
    state: GameState, side: list[Army], other: list[Army], terrain: str = ""
) -> Formation | None:
    """A side's formation before reading the enemy.

    Its ruler's order, or the general's answer to what such an enemy would naturally do.
    """
    chosen = ordered(state, side)
    if chosen is not None:
        return chosen
    return answer(state, side, other, natural(state, other, side, terrain), terrain)


def final(
    state: GameState, side: list[Army], other: list[Army], terrain: str = ""
) -> Formation | None:
    """The formation a side fights in (a great general left to choose reads the enemy)."""
    mine = first_thought(state, side, other, terrain)
    lead = commander(side)
    if lead.formation != AUTO or lead.skill < state.world.rules.armies.reads_enemy_skill:
        return mine
    return answer(state, side, other, first_thought(state, other, side, terrain), terrain) or mine


def formations(
    state: GameState, attackers: list[Army], defenders: list[Army], terrain: str = ""
) -> tuple[Formation | None, Formation | None]:
    """The formations the attackers and the defenders draw up in."""
    return final(state, attackers, defenders, terrain), final(state, defenders, attackers, terrain)
