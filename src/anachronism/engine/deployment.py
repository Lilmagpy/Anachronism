"""Deployment (D-270): where each kind of soldier stands in the line.

An army deploys its troops by *kind* (infantry, spear, missile, mounted, elephant) to the left
wing, the centre, the right wing or the reserve. Siege engines never fight in the line: they
stay in camp. A kind left to the general (``auto``) stands where the army's formation puts it;
``split`` spreads it across the line by the formation's weights. Formations are therefore
presets of a deployment (their layouts are content, ``core/formations.yaml``).
"""

from __future__ import annotations

from anachronism.content.schema import Formation
from anachronism.engine.fixed import BP
from anachronism.engine.state import Army, GameState

AUTO = "auto"
SPLIT = "split"
LEFT, CENTRE, RIGHT, RESERVE = "left", "centre", "right", "reserve"
LINE = (LEFT, CENTRE, RIGHT)
PLACES = (LEFT, CENTRE, RIGHT, RESERVE)
CHOICES = (AUTO, SPLIT, *PLACES)
FACING = {LEFT: RIGHT, CENTRE: CENTRE, RIGHT: LEFT}
"""The wing opposite: my left meets their right."""
SIEGE = "siege"
"""The kind of soldier that never stands in the line."""

PLACE_NOTES = {
    LEFT: "The left wing, facing the enemy's right.",
    CENTRE: "The centre of the line.",
    RIGHT: "The right wing, facing the enemy's left.",
    RESERVE: "Held back, then thrown in after the first exchange where the line is weakest.",
    SPLIT: "Spread across the whole line.",
    AUTO: "Left to the general: the formation decides.",
}
PLACE_NAMES = {
    LEFT: "Left wing",
    CENTRE: "Centre",
    RIGHT: "Right wing",
    RESERVE: "Reserve",
    SPLIT: "Spread along the line",
    AUTO: "Auto",
}

Shares = dict[str, int]
"""A kind's men by place, in bp of the kind (sums to 10_000)."""


def _fit(weights: dict[str, int]) -> Shares:
    """Weights as shares of 10_000 (the rounding goes to the heaviest place)."""
    total = sum(weights.values())
    if total <= 0:
        return {}
    out = {p: weights[p] * BP // total for p in PLACES if weights.get(p, 0) > 0}
    heaviest = max(out, key=lambda p: (out[p], -PLACES.index(p)))
    out[heaviest] += BP - sum(out.values())
    return out


def _even() -> Shares:
    return _fit(dict.fromkeys(LINE, 1))


def layout(form: Formation | None, kind: str) -> Shares:
    """Where a formation puts a kind of soldier when its deployment is left to the general."""
    if form is None:
        return _even()
    weights = form.layout.get(kind) or form.layout.get("default")
    return _fit(dict(weights)) if weights else _even()


def mirrored(shares: Shares) -> Shares:
    """The same shares with left and right swapped."""
    swap = {LEFT: RIGHT, RIGHT: LEFT}
    return {swap.get(p, p): n for p, n in shares.items()}


def shares(form: Formation | None, kind: str, order: str, mirror: bool = False) -> Shares:
    """Where a kind stands: the ordered place, or (auto/split) the formation's layout.

    ``mirror`` turns the auto layout round (a great general putting his strong wing against
    the enemy's weak one); an order is never mirrored.
    """
    if kind == SIEGE:
        return {}
    if order in PLACES:
        return {order: BP}
    plan = layout(form, kind)
    if order == SPLIT:
        line = _fit({p: n for p, n in plan.items() if p in LINE}) or _even()
        return line
    return mirrored(plan) if mirror else plan


def ordered(army: Army, kind: str) -> str:
    """What the army's ruler ordered for a kind (``auto`` if nothing)."""
    order = army.deployment.get(kind, AUTO)
    return order if order in CHOICES else AUTO


def place_army(
    state: GameState, army: Army, form: Formation | None, mirror: bool = False
) -> dict[str, dict[str, int]]:
    """An army's men by place: place -> unit id -> men (siege engines left in camp)."""
    out: dict[str, dict[str, int]] = {p: {} for p in PLACES}
    for unit_id, men in sorted(army.troops.items()):
        if men <= 0:
            continue
        kind = state.world.units[unit_id].kind
        want = shares(form, kind, ordered(army, kind), mirror)
        if not want:
            continue
        given = {p: men * n // BP for p, n in want.items()}
        heaviest = max(want, key=lambda p: (want[p], -PLACES.index(p)))
        given[heaviest] += men - sum(given.values())
        for place, n in given.items():
            if n > 0:
                out[place][unit_id] = out[place].get(unit_id, 0) + n
    return out


def resolved(want: Shares) -> str:
    """One word for where a kind stands: its place, or ``split`` if no place holds most of it."""
    if not want:
        return "camp"
    place = max(want, key=lambda p: (want[p], -PLACES.index(p)))
    return place if want[place] >= 6000 else SPLIT


def place_side(
    state: GameState, armies: list[Army], form: Formation | None, mirror: bool = False
) -> dict[str, list[tuple[Army, dict[str, int]]]]:
    """A side's armies drawn up: place -> (army, its men there by unit id)."""
    out: dict[str, list[tuple[Army, dict[str, int]]]] = {p: [] for p in PLACES}
    for army in armies:
        for place, troops in place_army(state, army, form, mirror).items():
            if troops:
                out[place].append((army, troops))
    return out
