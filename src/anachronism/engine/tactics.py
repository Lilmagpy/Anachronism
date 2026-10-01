"""Battle plans (D-108): the plan each side fights with, and what it is worth.

Every army goes into battle with a plan. A ruler may order one; left to himself (``auto``),
a general plans against what he expects: the plan that suits the enemy's soldiers and the
ground (its *natural* plan), answered with the best plan his own soldiers can carry out.
A great general (skill at least ``reads_enemy_skill``) reads the enemy's real intentions
instead - its ruler's order, or its general's own answer - and answers those. The side
whose plan beats the other's has the edge; a general gifted for his plan doubles it.
"""

from __future__ import annotations

from anachronism.content.schema import Tactic
from anachronism.engine.fixed import BP
from anachronism.engine.state import Army, GameState

AUTO = "auto"
"""An army's plan when its general decides."""


def commander(armies: list[Army]) -> Army:
    """Who leads a side: the general of its largest army."""
    return max(armies, key=lambda a: (a.men, a.id))


def _men(armies: list[Army]) -> dict[str, int]:
    out: dict[str, int] = {}
    for army in armies:
        for unit, men in army.troops.items():
            out[unit] = out.get(unit, 0) + men
    return out


def lacks(
    state: GameState, tactic: Tactic, armies: list[Army], attacking: bool, terrain: str
) -> str:
    """Why a side cannot fight with a plan here, or "" if it can."""
    if tactic.when == "attacking" and not attacking:
        return "only for an attack"
    if tactic.when == "defending" and attacking:
        return "only in defence"
    if tactic.needs_terrain and terrain not in tactic.needs_terrain:
        return "needs " + _or([state.world.terrain[t].name.lower() for t in tactic.needs_terrain])
    return short_of_men(state, tactic, armies)


def short_of_men(state: GameState, tactic: Tactic, armies: list[Army]) -> str:
    """Why these soldiers cannot carry out a plan, or "" if they can."""
    if not tactic.needs_units:
        return ""
    men = _men(armies)
    total = sum(men.values())
    have = sum(n for u, n in men.items() if u in tactic.needs_units)
    if total <= 0 or have * BP < tactic.needs_share_bp * total:
        kinds = [state.world.units[u].name.lower() for u in tactic.needs_units]
        return f"needs {tactic.needs_share_bp // 100}% {_or(kinds)}"
    return ""


def needs_text(state: GameState, tactic: Tactic) -> str:
    """A plan's requirements in words ("" if it has none)."""
    parts = []
    if tactic.needs_units:
        kinds = [state.world.units[u].name.lower() for u in tactic.needs_units]
        parts.append(f"{tactic.needs_share_bp // 100}% of the men {_or(kinds)}")
    if tactic.needs_terrain:
        parts.append(_or([state.world.terrain[t].name.lower() for t in tactic.needs_terrain]))
    if tactic.when != "any":
        parts.append("only in defence" if tactic.when == "defending" else "only in attack")
    return "; ".join(parts)


def _or(items: list[str]) -> str:
    return items[0] if len(items) == 1 else ", ".join(items[:-1]) + " or " + items[-1]


def gifted(army: Army, tactic: Tactic) -> bool:
    """True when the army's general has the gift the plan rewards."""
    return bool(tactic.trait) and bool(army.general) and army.trait == tactic.trait


def bonus(tactic: Tactic, terrain: str) -> int:
    """The plan's own worth on this ground, before any edge over the enemy's plan."""
    return tactic.power_bp + tactic.terrain_bp.get(terrain, 0)


def edge(state: GameState, mine: Tactic, theirs: Tactic, lead: Army) -> int:
    """The edge one plan has over another (0 if it does not beat it)."""
    if theirs.id not in mine.beats:
        return 0
    gift = state.world.rules.armies.tactic_edge_bp
    return gift * 2 if gifted(lead, mine) else gift


def _merit(state: GameState, tactic: Tactic, lead: Army, terrain: str) -> int:
    value = bonus(tactic, terrain) + tactic.needs_share_bp // 4 + tactic.rout_bp // 4
    if gifted(lead, tactic):
        value += state.world.rules.armies.tactic_edge_bp // 2
    return value


def _options(state: GameState, armies: list[Army], attacking: bool, terrain: str) -> list[Tactic]:
    return [
        t
        for _, t in sorted(state.world.tactics.items())
        if not lacks(state, t, armies, attacking, terrain)
    ]


def natural(state: GameState, armies: list[Army], attacking: bool, terrain: str) -> Tactic | None:
    """The plan a general picks for his soldiers and this ground, knowing nothing of the enemy."""
    lead = commander(armies)
    options = _options(state, armies, attacking, terrain)
    return max(options, key=lambda t: (_merit(state, t, lead, terrain), t.id), default=None)


def ordered(state: GameState, armies: list[Army], attacking: bool, terrain: str) -> Tactic | None:
    """The plan its ruler ordered, if the side can carry it out here."""
    chosen = state.world.tactics.get(commander(armies).plan)
    if chosen is not None and not lacks(state, chosen, armies, attacking, terrain):
        return chosen
    return None


def answer(
    state: GameState, armies: list[Army], attacking: bool, terrain: str, theirs: Tactic | None
) -> Tactic | None:
    """The best plan for this side against an enemy plan (its natural plan if none known)."""
    lead = commander(armies)
    if theirs is None:
        return natural(state, armies, attacking, terrain)
    gift = state.world.rules.armies.tactic_edge_bp

    def value(t: Tactic) -> int:
        worth = _merit(state, t, lead, terrain) + edge(state, t, theirs, lead)
        return worth - (gift if t.id in theirs.beats else 0)

    options = _options(state, armies, attacking, terrain)
    return max(options, key=lambda t: (value(t), t.id), default=None)


def first_thought(
    state: GameState, side: list[Army], other: list[Army], attacking: bool, terrain: str
) -> Tactic | None:
    """A side's plan before reading the enemy.

    Its ruler's order, or its general's answer to what such an enemy would naturally do on
    this ground.
    """
    chosen = ordered(state, side, attacking, terrain)
    if chosen is not None:
        return chosen
    expected = natural(state, other, not attacking, terrain)
    return answer(state, side, attacking, terrain, expected)


def final(
    state: GameState, side: list[Army], other: list[Army], attacking: bool, terrain: str
) -> Tactic | None:
    """The plan a side fights with.

    Its first thought, unless a great general left to choose reads the enemy's own first
    thought and answers it.
    """
    mine = first_thought(state, side, other, attacking, terrain)
    lead = commander(side)
    if lead.plan != AUTO or lead.skill < state.world.rules.armies.reads_enemy_skill:
        return mine
    theirs = first_thought(state, other, side, not attacking, terrain)
    return answer(state, side, attacking, terrain, theirs) or mine


def plans(
    state: GameState, attackers: list[Army], defenders: list[Army], terrain: str
) -> tuple[Tactic | None, Tactic | None]:
    """The plans the attackers and the defenders fight with."""
    return (
        final(state, attackers, defenders, True, terrain),
        final(state, defenders, attackers, False, terrain),
    )
