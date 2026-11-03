"""The clash, wing by wing (D-270).

Each side's line is a left wing, a centre and a right wing, with perhaps a reserve. A side's
left meets the enemy's right. The first exchange shows how each wing fares; a wing that
clearly beats its opposite *breaks* it and wheels on the enemy's centre; reserves go in where
the line is weakest (or, under a great general, where it is winning); horse that face no horse
ride round; a second army that came from another direction falls on a flank. The side that
wins two of the three contests wins the clash.

This module is pure arithmetic on powers worked out elsewhere (``power.wing_powers``).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from anachronism.content.schema.rules import ArmyRules
from anachronism.engine.deployment import CENTRE, FACING, LEFT, LINE, RESERVE, RIGHT
from anachronism.engine.fixed import BP

_CAP = 20 * BP
_WINGS = (LEFT, RIGHT)


@dataclass
class Line:
    """One side as the clash sees it (powers already include plan, formation and so on)."""

    first: dict[str, int]
    """Power by place in the first exchange (the river still tells)."""
    later: dict[str, int]
    """Power by place after it (and the reserve's, fresh)."""
    men: dict[str, int]
    horse: dict[str, int]
    """Share (bp) of each place's men that are mounted."""
    reserve_bp: int = 0
    """Extra power of the fresh men when the reserve commits."""
    great: bool = False
    """A great general commits the reserve to exploit success."""
    flank: int = 0
    """Power of a second army arriving from another direction (0: none)."""
    flank_men: int = 0


@dataclass
class WingResult:
    """One of the three contests, from the attackers' side (a's left meets d's right)."""

    wing: str
    d_wing: str
    a_men: int
    d_men: int
    a_power: int
    d_power: int
    winner: str
    """``a``, ``d`` or empty for a drawn contest."""
    broke: str = ""
    """``a`` or ``d``: the side whose wing was broken in the first exchange."""
    refused: str = ""
    """``a`` or ``d``: the side that held this wing back, out of the fight."""


@dataclass
class Clash:
    """The outcome of the three contests."""

    wings: list[WingResult]
    reserve: dict[str, str]
    """Where each side's reserve went (``a``/``d`` -> a place, or empty if it had none)."""
    flank: dict[str, str | int] = field(default_factory=dict)
    """A second army's blow: ``side``, ``against`` (the enemy wing, by its own name), ``men``."""
    horse_round: dict[str, bool] = field(default_factory=dict)
    broken_a: int = 0
    broken_d: int = 0
    power_a: int = 0
    power_d: int = 0
    winner: str = "d"


def _ratio(mine: int, theirs: int) -> int:
    if mine <= 0 and theirs <= 0:
        return BP
    return min(_CAP, mine * BP // max(1, theirs))


def _refused(rules: ArmyRules, line: Line) -> set[str]:
    """The wings a side deliberately holds back: well under its fair third of the line."""
    total = sum(line.men.get(k, 0) for k in LINE)
    return {k for k in _WINGS if line.men.get(k, 0) * 3 * BP < rules.refused_bp * total}


def _commit(ratios: dict[str, int], great: bool) -> str:
    """Where a reserve goes: the wing most in danger, or the best one for a great general."""
    worst = min(LINE, key=lambda k: (ratios[k], k))
    if great and ratios[worst] >= BP:
        return max(LINE, key=lambda k: (ratios[k], k))
    return worst


def contest(
    rules: ArmyRules,
    a: Line,
    d: Line,
    scale: tuple[int, int] = (BP, BP),
    luck: tuple[dict[str, int], dict[str, int]] | None = None,
) -> Clash:
    """Fight the clash.

    ``scale`` is what the skirmish left each side (bp); ``luck`` is each side's fortune by
    place (bp, 10_000 = none), felt in both exchanges.
    """
    high = rules.wing_break_bp
    low = BP * BP // max(1, high)
    fate_a, fate_d = luck or ({}, {})
    first_a = {k: a.first[k] * fate_a.get(k, BP) // BP for k in LINE}
    first_d = {k: d.first[k] * fate_d.get(k, BP) // BP for k in LINE}
    seen_a = {k: _ratio(first_a[k], first_d[FACING[k]]) for k in LINE}
    seen_d = {j: _ratio(first_d[j], first_a[FACING[j]]) for j in LINE}
    # the reserves go in after that first exchange, where the line is weakest: they plug a
    # breach before it becomes one (or, under a great general, press a success)
    pow_a, pow_d = dict(a.later), dict(d.later)
    reserve = {"a": "", "d": ""}
    for tag, line, power, first, seen in (
        ("a", a, pow_a, first_a, seen_a),
        ("d", d, pow_d, first_d, seen_d),
    ):
        if power.get(RESERVE, 0) > 0:
            where = _commit(seen, line.great)
            fresh = BP + max(line.reserve_bp, rules.reserve_fresh_bp)
            power[where] += power[RESERVE] * fresh // BP
            first[where] += line.first[RESERVE] * fresh // BP
            reserve[tag] = where
        power[RESERVE] = 0
    seen_a = {k: _ratio(first_a[k], first_d[FACING[k]]) for k in LINE}
    # a wing held far back (a refused flank) is out of the fight: it is neither broken nor won
    refused_a = _refused(rules, a)
    refused_d = _refused(rules, d)
    broke_a = [k for k in LINE if seen_a[k] <= low and k not in refused_a]  # d broke them
    broke_d = [
        FACING[k] for k in LINE if seen_a[k] >= high and FACING[k] not in refused_d
    ]  # a broke them
    for k in broke_a:
        pow_a[k] = pow_a[k] * rules.broken_wing_bp // BP
    for j in broke_d:
        pow_d[j] = pow_d[j] * rules.broken_wing_bp // BP
    # a wing that broke its opposite wheels on the enemy's centre; horse ride round
    wheel_a = sum(1 for j in _WINGS if j in broke_d)  # d wings broken -> a wheels on d's centre
    wheel_d = sum(1 for k in _WINGS if k in broke_a)
    ride = {"a": False, "d": False}
    cost_d = wheel_a * rules.flank_penalty_bp + len(refused_d) * rules.free_wing_bp
    cost_a = wheel_d * rules.flank_penalty_bp + len(refused_a) * rules.free_wing_bp
    for k in _WINGS:
        free_a = a.horse[k] >= rules.horse_round_min_bp
        if free_a and d.horse[FACING[k]] < rules.horse_round_free_bp:
            cost_d += rules.horse_round_bp
            ride["a"] = True
        free_d = d.horse[k] >= rules.horse_round_min_bp
        if free_d and a.horse[FACING[k]] < rules.horse_round_free_bp:
            cost_a += rules.horse_round_bp
            ride["d"] = True
    pow_d[CENTRE] = pow_d[CENTRE] * max(3000, BP - cost_d) // BP
    pow_a[CENTRE] = pow_a[CENTRE] * max(3000, BP - cost_a) // BP
    for k in _WINGS:  # the winning (or unopposed) wing turns inward with part of its strength
        if FACING[k] in broke_d or FACING[k] in refused_d:
            pow_a[CENTRE] += pow_a[k] * rules.wheel_bp // BP
        if k in broke_a or k in refused_a:
            pow_d[CENTRE] += pow_d[FACING[k]] * rules.wheel_bp // BP
    # a second army falls on the enemy's weaker wing
    flank: dict[str, str | int] = {}
    for tag, line, mine, theirs, other in (("a", a, pow_a, pow_d, d), ("d", d, pow_d, pow_a, a)):
        if line.flank <= 0:
            continue
        target = min(_WINGS, key=lambda j: (other.first[j], j))  # the enemy wing, by its name
        own = FACING[target]
        mine[own] += line.flank * (BP + rules.flank_arrival_bp) // BP
        theirs[target] = theirs[target] * (BP - rules.flank_hit_bp) // BP
        flank = {"side": tag, "against": target, "men": line.flank_men}
    for power, factor, fate in ((pow_a, scale[0], fate_a), (pow_d, scale[1], fate_d)):
        for place in LINE:
            power[place] = power[place] * factor // BP * fate.get(place, BP) // BP
    wings: list[WingResult] = []
    for k in LINE:
        pa, pd = pow_a[k], pow_d[FACING[k]]
        winner = "a" if pa > pd else "d" if pd > pa else ""
        held = "a" if k in refused_a else "d" if FACING[k] in refused_d else ""
        if held:
            winner = ""
        wings.append(
            WingResult(
                wing=k,
                d_wing=FACING[k],
                a_men=a.men.get(k, 0),
                d_men=d.men.get(FACING[k], 0),
                a_power=pa,
                d_power=pd,
                winner=winner,
                broke="d" if FACING[k] in broke_d else "a" if k in broke_a else "",
                refused=held,
            )
        )
    total_a = sum(w.a_power for w in wings)
    total_d = sum(w.d_power for w in wings)
    won_a = sum(1 for w in wings if w.winner == "a")
    won_d = sum(1 for w in wings if w.winner == "d")
    winner = "a" if won_a > won_d or (won_a == won_d and total_a > total_d) else "d"
    return Clash(
        wings=wings,
        reserve=reserve,
        flank=flank,
        horse_round=ride,
        broken_a=len(broke_a),
        broken_d=len(broke_d),
        power_a=total_a,
        power_d=total_d,
        winner=winner,
    )
