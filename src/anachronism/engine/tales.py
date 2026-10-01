"""How battles on land and at sea are told (D-103, D-107): content tales fitted to them."""

from __future__ import annotations

from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState


def tell(
    state: GameState,
    kind: str,
    terrain: str,
    rout: bool,
    rng: GameRng,
    *,
    ship: str | None = None,
    winner: str = "",
) -> str:
    """The most fitting way to tell a battle (content ``tales``), one of its lines.

    A sea battle passes the winners' ``ship`` kind; only sea tales tell those.
    """
    best: tuple[int, str] | None = None
    for tale_id, tale in sorted(state.world.tales.items()):
        if tale.sea != (ship is not None) or (tale.civs and winner not in tale.civs):
            continue
        if ship is not None and tale.ships and ship not in tale.ships:
            continue
        if ship is None and (
            (tale.kind and tale.kind != kind) or (tale.terrain and terrain not in tale.terrain)
        ):
            continue
        if tale.rout is not None and tale.rout != rout:
            continue
        score = 2 * bool(tale.kind) + 2 * bool(tale.terrain) + (tale.rout is not None)
        score += 2 * bool(tale.ships) + 3 * bool(tale.civs)
        if best is None or score > best[0]:
            best = (score, tale_id)
    if best is None:
        if ship is not None:
            return "On the {place} the {winner} {unit} broke the {loser} line."
        return "At {place} the {winner} {unit} carried the day against the {loser} host."
    lines = state.world.tales[best[1]].lines
    return lines[rng.below(len(lines))]
