"""Play in a terminal: ``uv run anachronism-console`` (the text version of the game)."""

from __future__ import annotations

import argparse
import time
from collections.abc import Callable, Mapping, Sequence
from pathlib import Path

from anachronism import __version__
from anachronism.content.loader import Content, load_content
from anachronism.content.schema import EffectType, Stage
from anachronism.engine.actions import (
    Action,
    CancelProject,
    PauseProject,
    Priority,
    ProposeIdea,
    ResumeProject,
    SetPriority,
    StartProject,
)
from anachronism.engine.bots import BOTS, Bot, make_bot
from anachronism.engine.commands import describe_blockers
from anachronism.engine.economy import project_costs
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.projects import project_turns
from anachronism.engine.reports import capacity
from anachronism.engine.save import SaveError, dumps, loads
from anachronism.engine.state import Event, GameState, Snapshot
from anachronism.engine.tech import feasibility

Reader = Callable[[str], str]
Writer = Callable[[str], None]

HELP = """\
Commands (ideas can be named by id or by the start of their name):
  status              your civilisation at a glance
  ideas [all|field]   ideas your scholars could try (all: include blocked ones)
  about <idea>        everything about one idea
  start <idea> [high|low]   begin experimenting (costs resources every turn)
  pause <idea> / resume <idea> / cancel <idea>
  priority <idea> high|normal|low   who gets funded first when resources run short
  end                 end the turn (also: e, next)
  events              what happened last turn
  world               the other civilisations
  save [name] / load [name]   save or load a game (in the saves folder)
  quit                leave (also: q)
"""

EFFECT_NAMES = {
    EffectType.FOOD_OUTPUT: "food",
    EffectType.LABOUR_OUTPUT: "labour",
    EffectType.MATERIALS_OUTPUT: "materials",
    EffectType.WEALTH_OUTPUT: "taxes",
    EffectType.KNOWLEDGE_GAIN: "knowledge",
    EffectType.TRADE_INCOME: "trade",
    EffectType.POPULATION_CAP: "room for people",
    EffectType.HEALTH: "health",
    EffectType.MILITARY_STRENGTH: "military strength",
    EffectType.NAVAL_STRENGTH: "naval strength",
    EffectType.MOBILITY: "movement and spread",
    EffectType.STORAGE: "food storage",
    EffectType.INFORMATION_SPEED: "speed of news",
    EffectType.SECRECY: "secrecy",
    EffectType.CULTURAL_INFLUENCE: "cultural influence",
}
POINT_EFFECTS = {
    EffectType.LITERACY_GROWTH: "literacy",
    EffectType.UNREST: "unrest",
    EffectType.LEGITIMACY: "legitimacy",
    EffectType.SUSPICION: "suspicion",
}


def year_text(year: int) -> str:
    """Format a year as ``1200 BC`` or ``AD 300``."""
    return f"{-year} BC" if year < 0 else f"AD {year}"


def pct(bp: int) -> str:
    """Format basis points as a percentage with one decimal."""
    return f"{bp / 100:.1f}%"


def trend(history: Sequence[Snapshot], field: str) -> str:
    """An arrow comparing the last two snapshots of a value."""
    if len(history) < 2:
        return "→"
    now, before = getattr(history[-1], field), getattr(history[-2], field)
    return "↑" if now > before else "↓" if now < before else "→"


def plural(count: int, word: str) -> str:
    """``1 turn``, ``2 turns``."""
    return f"{count} {word}" if count == 1 else f"{count} {word}s"


def mark(ok: bool) -> str:
    """A tick or a cross."""
    return "✓" if ok else "✗"


def describe_effect(effect_type: EffectType, bp: int, target: str | None) -> str:
    """Describe one effect in plain words."""
    if effect_type.is_unlock:
        return f"unlocks {target}"
    if effect_type in POINT_EFFECTS:
        per = "" if effect_type is EffectType.SUSPICION else " per decade"
        return f"{POINT_EFFECTS[effect_type]} {bp / 100:+.1f} points{per}"
    return f"{EFFECT_NAMES[effect_type]} {bp / 100:+.0f}%"


class Console:
    """An interactive text game. Input and output are injectable so it can be tested."""

    def __init__(
        self,
        content: Content,
        state: GameState,
        rivals: Mapping[str, Bot],
        read: Reader = input,
        write: Writer = print,
        saves_dir: Path = Path("saves"),
    ) -> None:
        self.content = content
        self.state = state
        self.rivals = rivals
        self.read = read
        self.write = write
        self.saves_dir = saves_dir
        self.last_events: list[Event] = []

    @property
    def civ_id(self) -> str:
        """The player's civilisation."""
        return self.state.player_civ

    def run(self) -> int:
        """Play until the player quits or input ends."""
        world = self.state.world
        self.write(f"ANACHRONISM (working title) — {world.scenario_name}, seed {self.state.seed}")
        self.write("A good-faith simulation, not a re-enactment. Type 'help' for commands.\n")
        self.show_status()
        while True:
            try:
                line = self.read("\n> ").strip()
            except EOFError:
                return 0
            if not line:
                continue
            command, _, rest = line.partition(" ")
            if command.lower() in ("quit", "q", "exit"):
                self.write("Farewell.")
                return 0
            self.dispatch(command.lower(), rest.strip())

    def dispatch(self, command: str, rest: str) -> None:
        """Run one command."""
        handlers: dict[str, Callable[[str], None]] = {
            "help": lambda _: self.write(HELP),
            "?": lambda _: self.write(HELP),
            "status": lambda _: self.show_status(),
            "ideas": self.show_ideas,
            "about": self.show_about,
            "start": self.start,
            "pause": lambda text: self.act(text, PauseProject),
            "resume": lambda text: self.act(text, ResumeProject),
            "cancel": lambda text: self.act(text, CancelProject),
            "priority": self.priority,
            "end": lambda _: self.end_turn(),
            "e": lambda _: self.end_turn(),
            "next": lambda _: self.end_turn(),
            "events": lambda _: self.show_events(self.last_events),
            "world": lambda _: self.show_world(),
            "save": self.save,
            "load": self.load,
        }
        handler = handlers.get(command)
        if handler is None:
            self.write(f"Unknown command '{command}'. Type 'help' to see what you can do.")
        else:
            handler(rest)

    # --- looking ------------------------------------------------------------------------------

    def show_status(self) -> None:
        """Print the player's civilisation at a glance."""
        state = self.state
        civ = state.civs[self.civ_id]
        history = civ.history
        room = capacity(state, self.civ_id)
        stats = civ.stats
        self.write(f"─── {civ.name} ── {year_text(state.year)} ── turn {state.turn + 1} ───")
        self.write(
            f"People {state.population(self.civ_id):,} {trend(history, 'population')}   "
            f"literacy {pct(stats.literacy_bp)} {trend(history, 'literacy_bp')}   "
            f"unrest {pct(stats.unrest_bp)} {trend(history, 'unrest_bp')}   "
            f"legitimacy {pct(stats.legitimacy_bp)} {trend(history, 'legitimacy_bp')}"
        )
        framing = f" (people call it {civ.framing})" if civ.framing != "none" else ""
        self.write(
            f"Suspicion {pct(stats.suspicion_bp)}{framing}   strain {pct(stats.strain_bp)}   "
            f"provinces {len(state.owned_provinces(self.civ_id))}"
        )
        self.write(
            f"Stores: food {room.food} {trend(history, 'food')} · materials {room.materials} · "
            f"wealth {room.wealth} · knowledge {room.knowledge}"
        )
        free = room.free_labour
        warning = "  (over-committed: fields are losing workers!)" if free < 0 else ""
        self.write(f"Labour: workforce {room.workforce} · free for projects {free}{warning}")
        if civ.collapsed:
            self.write("Your realm has collapsed into revolt. Stabilise what remains.")
        if not civ.projects:
            self.write("Projects: none. Type 'ideas' to see what your scholars could try.")
            return
        self.write("Projects:")
        for node_id, project in sorted(civ.projects.items()):
            node = state.tech_nodes[node_id]
            filled = project.progress_bp // 1_000
            bar = "▓" * filled + "░" * (10 - filled)
            paused = " [paused]" if project.paused else ""
            self.write(
                f"  {node.name:<32} {bar} {project.progress_bp // 100:>3}%  "
                f"funded {project.last_funding_bp // 100}% ({project.priority}){paused}"
            )

    def show_ideas(self, text: str) -> None:
        """List ideas: startable ones with costs, then goals and blocked ones with reasons."""
        state = self.state
        civ = state.civs[self.civ_id]
        show_all = text.lower() == "all"
        field = text.lower() if text and not show_all else None
        ready: list[str] = []
        blocked: list[str] = []
        for node_id, node in sorted(state.tech_nodes.items(), key=lambda item: item[1].name):
            known = civ.tech.get(node_id)
            if (known and known.stage is not Stage.CONCEPT) or node_id in civ.projects:
                continue
            if field and node.category != field:
                continue
            result = feasibility(state, self.civ_id, node_id)
            goal = "★ " if known and known.goal else "  "
            if not result.blocked:
                cost = project_costs(state, node_id)
                early = node.year - state.year
                note = f"  {early:,} years early" if early > 0 else ""
                ready.append(
                    f"{goal}{node.name:<32} labour {cost.labour} · knowledge {cost.knowledge} · "
                    f"{plural(project_turns(state, node_id), 'turn')}{note}"
                )
            elif show_all or known is not None:
                blocked.append(f"{goal}{node.name:<32} {describe_blockers(state, result)}")
        self.write("Ideas your scholars could try now (cost per turn):")
        self.write("\n".join(ready) if ready else "  (none)")
        if blocked:
            self.write("\nKnown ideas that are blocked (★ = a goal for another idea):")
            self.write("\n".join(blocked))
        elif not show_all:
            self.write("\nType 'ideas all' to also see ideas that are blocked for now.")

    def show_about(self, text: str) -> None:
        """Describe one idea in full."""
        node_id = self.resolve(text)
        if node_id is None:
            return
        state = self.state
        node = state.tech_nodes[node_id]
        result = feasibility(state, self.civ_id, node_id)
        civ = state.civs[self.civ_id]
        self.write(f"{node.name} ({node.category}, complexity {node.complexity})")
        self.write(f"First appeared around {year_text(node.year)}.")
        if node.flavour:
            self.write(f'"{node.flavour}"')
        needs = [
            f"{state.tech_nodes[p].name} {mark(p not in result.missing_prerequisites)}"
            for p in node.prerequisites
        ]
        needs += [
            f"{state.world.resources[m].name} {mark(m not in result.missing_materials)}"
            for m in node.requires.materials
        ]
        needs += [
            f"{state.tech_nodes[w].name} widespread {mark(w not in result.missing_widespread)}"
            for w in node.requires.widespread
        ]
        if node.requires.literacy_bp:
            ok = "✓" if not result.literacy_shortfall_bp else "✗ (more setbacks)"
            needs.append(f"literacy {pct(node.requires.literacy_bp)} {ok}")
        self.write(f"Needs: {', '.join(needs) if needs else 'nothing special'}")
        effects = [describe_effect(e.type, e.bp, e.target) for e in node.effects]
        self.write(f"Effects: {', '.join(effects) if effects else 'none'}")
        if node.resistance:
            opposed = ", ".join(f"{r.group} ({'!' * r.level})" for r in node.resistance)
            self.write(f"Opposed by: {opposed}")
        cost = project_costs(state, node_id)
        self.write(
            f"Cost per turn: labour {cost.labour} · materials {cost.materials} · "
            f"knowledge {cost.knowledge} · wealth {cost.wealth} · "
            f"about {plural(project_turns(state, node_id), 'turn')}"
        )
        known = civ.tech.get(node_id)
        if known and known.stage.is_adopted:
            self.write(f"Status: {known.stage} ({pct(known.spread_bp)} of the realm)")
        elif node_id in civ.projects:
            self.write(f"Status: in progress ({civ.projects[node_id].progress_bp // 100}%)")
        elif result.blocked:
            self.write(f"Status: blocked — {describe_blockers(state, result)}")
        else:
            self.write("Status: ready to start")

    def show_events(self, events: Sequence[Event]) -> None:
        """Print events concerning the player, and major news from abroad."""
        own = [e for e in events if e.civ == self.civ_id]
        abroad = [e for e in events if e.civ != self.civ_id and e.kind in ("revolt", "collapse")]
        if not own and not abroad:
            self.write("A quiet decade.")
        for event in own:
            self.write(f"• {event.message}")
        for event in abroad:
            self.write(f"• News from abroad: {event.message}")

    def show_world(self) -> None:
        """Summarise every civilisation."""
        self.write(
            f"{'Civilisation':<22} {'People':>9} {'Provinces':>9} {'Unrest':>7} {'Advances':>8}"
        )
        for civ_id, civ in sorted(self.state.civs.items()):
            adopted = sum(t.stage.is_adopted for t in civ.tech.values())
            marker = " (you)" if civ_id == self.civ_id else ""
            self.write(
                f"{civ.name + marker:<22} {self.state.population(civ_id):>9,} "
                f"{len(self.state.owned_provinces(civ_id)):>9} {pct(civ.stats.unrest_bp):>7} "
                f"{adopted:>8}"
            )

    # --- acting -------------------------------------------------------------------------------

    def resolve(self, text: str) -> str | None:
        """Find an idea by id, name or unique prefix; explain if it cannot be found."""
        wanted = text.strip().lower()
        if not wanted:
            self.write("Which idea? For example: about writing")
            return None
        nodes = self.state.tech_nodes
        for node_id, node in nodes.items():
            if wanted in (node_id, node.name.lower()):
                return node_id
        matches = sorted(
            node_id
            for node_id, node in nodes.items()
            if node_id.startswith(wanted.replace(" ", "_")) or node.name.lower().startswith(wanted)
        )
        if len(matches) == 1:
            return matches[0]
        if matches:
            names = ", ".join(nodes[m].name for m in matches[:6])
            self.write(f"'{text}' could mean: {names}. Please be more specific.")
        else:
            self.write(f"No idea called '{text}'. Type 'ideas all' to see the list.")
        return None

    def submit(self, action: Action) -> None:
        """Apply an action and report its outcome."""
        self.state, logged = apply_action(self.state, action)
        self.write(logged.message if logged.ok else f"Cannot do that: {logged.message}.")

    def start(self, text: str) -> None:
        """Start a project, optionally with a priority word at the end."""
        words = text.split()
        priority = Priority.NORMAL
        if words and words[-1].lower() in ("high", "low"):
            priority = Priority(words.pop().lower())
        node_id = self.resolve(" ".join(words))
        if node_id is not None:
            self.submit(StartProject(civ=self.civ_id, node_id=node_id, priority=priority))

    def act(
        self, text: str, kind: type[PauseProject | ResumeProject | CancelProject | ProposeIdea]
    ) -> None:
        """Pause, resume or cancel a project."""
        node_id = self.resolve(text)
        if node_id is not None:
            self.submit(kind(civ=self.civ_id, node_id=node_id))

    def priority(self, text: str) -> None:
        """Change a project's priority."""
        words = text.split()
        if len(words) < 2 or words[-1].lower() not in ("high", "normal", "low"):
            self.write("Usage: priority <idea> high|normal|low")
            return
        level = Priority(words.pop().lower())
        node_id = self.resolve(" ".join(words))
        if node_id is not None:
            self.submit(SetPriority(civ=self.civ_id, node_id=node_id, priority=level))

    def end_turn(self) -> None:
        """Let the rivals act, resolve the turn, and show what happened."""
        for civ_id in sorted(self.rivals):
            if civ_id == self.civ_id or not self.state.owned_provinces(civ_id):
                continue
            for action in self.rivals[civ_id].decide(self.state, civ_id):
                self.state, _ = apply_action(self.state, action)
        self.state, self.last_events = end_turn(self.state)
        self.write("")
        self.show_events(self.last_events)
        self.write("")
        self.show_status()

    def save(self, text: str) -> None:
        """Save the game to the saves folder."""
        path = self.saves_dir / f"{text.strip() or 'quicksave'}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(dumps(self.state), encoding="utf-8")
        self.write(f"Saved to {path}.")

    def load(self, text: str) -> None:
        """Load a game from the saves folder."""
        path = self.saves_dir / f"{text.strip() or 'quicksave'}.json"
        try:
            self.state = loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            self.write(f"No save called {path.name}.")
            return
        except SaveError as error:
            self.write(f"Could not load {path.name}: {error}")
            return
        self.write(f"Loaded {path}.")
        self.show_status()


def main(argv: Sequence[str] | None = None, read: Reader = input, write: Writer = print) -> int:
    """Start the text game."""
    parser = argparse.ArgumentParser(prog="anachronism", description="Play in a terminal.")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    parser.add_argument("--scenario", default="bronze_dawn")
    parser.add_argument("--seed", type=int, help="the same seed and moves replay the same game")
    parser.add_argument("--rivals", default="growth", choices=sorted(BOTS))
    parser.add_argument("--saves", type=Path, default=Path("saves"), help="folder for saves")
    args = parser.parse_args(argv)
    content = load_content()
    seed = args.seed if args.seed is not None else time.time_ns() % 1_000_000
    state = new_game(content, args.scenario, seed)
    rivals = {civ_id: make_bot(args.rivals) for civ_id in state.civs}
    console = Console(content, state, rivals, read=read, write=write, saves_dir=args.saves)
    return console.run()


if __name__ == "__main__":
    raise SystemExit(main())
