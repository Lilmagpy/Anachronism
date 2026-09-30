"""Headless simulations for balance work: ``uv run anachronism-sim --turns 60``."""

from __future__ import annotations

import argparse
from collections import Counter
from collections.abc import Callable, Sequence

from anachronism.content.loader import load_content
from anachronism.engine.bots import BOTS, make_bot, play_turn
from anachronism.engine.game import new_game
from anachronism.engine.state import GameState
from anachronism.tools.console import pct, year_text

Writer = Callable[[str], None]


def table(state: GameState) -> list[str]:
    """One line per civilisation with its key numbers."""
    lines = []
    for civ_id, civ in sorted(state.civs.items()):
        stats = civ.stats
        adopted = sum(t.stage.is_adopted for t in civ.tech.values())
        owned = len(state.owned_provinces(civ_id))
        framing = civ.framing if civ.framing != "none" else ""
        lines.append(
            f"  {civ_id:<9} pop {state.population(civ_id):>9,}  prov {owned:>2}"
            f"  adv {adopted:>2}  proj {len(civ.projects):>2}  unrest {pct(stats.unrest_bp):>6}"
            f"  legit {pct(stats.legitimacy_bp):>6}  lit {pct(stats.literacy_bp):>6}"
            f"  susp {pct(stats.suspicion_bp):>6} {framing}"
        )
    return lines


def main(argv: Sequence[str] | None = None, write: Writer = print) -> int:
    """Run a bot-played game and print how every civilisation fares."""
    parser = argparse.ArgumentParser(prog="anachronism-sim", description="Simulate with bots.")
    parser.add_argument("--scenario", default="bronze_dawn")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--turns", type=int, default=60)
    parser.add_argument("--every", type=int, default=10, help="print a table every N turns")
    parser.add_argument("--player", default="growth", choices=sorted(BOTS))
    parser.add_argument("--rivals", default="growth", choices=sorted(BOTS))
    args = parser.parse_args(argv)
    state = new_game(load_content(), args.scenario, args.seed)
    bots = {
        civ_id: make_bot(args.player if civ_id == state.player_civ else args.rivals)
        for civ_id in state.civs
    }
    counts: Counter[tuple[str | None, str]] = Counter()
    write(f"{state.world.scenario_name}: seed {args.seed}")
    write(f"Bots: player {args.player}, rivals {args.rivals}")
    for _ in range(args.turns):
        state, events = play_turn(state, bots)
        counts.update((event.civ, event.kind) for event in events)
        if state.turn % args.every == 0 or state.turn == args.turns:
            write(f"{year_text(state.year)} (turn {state.turn})")
            for line in table(state):
                write(line)
    write("Events:")
    for civ_id in sorted(state.civs):
        mine = {kind: n for (civ, kind), n in counts.items() if civ == civ_id}
        summary = ", ".join(f"{kind} {n}" for kind, n in sorted(mine.items()))
        write(f"  {civ_id:<9} {summary or 'none'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
