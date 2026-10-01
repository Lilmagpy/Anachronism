"""The engine bridge for the 3D client (D-048): ``uv run anachronism-server``.

One JSON request per line on stdin, one JSON reply per line on stdout:
``{"id": 1, "cmd": "view"}`` → ``{"id": 1, "ok": true, "result": {...}}``.
Nothing else is ever written to stdout, so the client can trust every line.
"""

from __future__ import annotations

import json
import os
import sys
from collections.abc import Callable, Iterable
from pathlib import Path
from typing import Any, TextIO

from pydantic import TypeAdapter, ValidationError

from anachronism.content.loader import Content, load_content
from anachronism.engine.actions import Action, RuleOnIdea, StartProject
from anachronism.engine.bots import Bot, make_bot
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.rulings import Verdict
from anachronism.engine.save import SaveError, dumps, loads
from anachronism.engine.state import Event, GameState
from anachronism.llm.config import LlmConfig, load_config
from anachronism.llm.pipeline import IdeaPipeline, make_pipeline
from anachronism.tools.view import build_catalog, build_view
from anachronism.tools.voices import adviser_voice, opening_voices, speak, voices_for_turn

ACTION = TypeAdapter[Action](Action)


AUTOSAVE = "autosave"
"""The save slot written after every turn."""


class RequestError(Exception):
    """A request the server understood but cannot carry out; sent back as an error reply."""


class Session:
    """One game being played through the bridge."""

    def __init__(
        self, content: Content, saves_dir: Path, pipeline: IdeaPipeline | None = None
    ) -> None:
        self.content = content
        self.saves_dir = saves_dir
        self.pipeline = pipeline or IdeaPipeline(LlmConfig(offline=True), use_files=False)
        self.state: GameState | None = None
        self.rivals: dict[str, Bot] = {}
        self.events: list[Event] = []

    def game(self) -> GameState:
        """The current game, or an error if none has started."""
        if self.state is None:
            raise RequestError("no game yet: send new_game or load first")
        return self.state

    def new_game(self, args: dict[str, Any]) -> dict[str, Any]:
        """Start a scenario: ``{"scenario": "bronze_dawn", "civ": "veyra", "seed": 1}``.

        ``civ`` (optional) is the civilisation the player guides; ``rivals`` picks the bots.
        """
        civ = args.get("civ")
        try:
            self.state = new_game(
                self.content,
                str(args.get("scenario", "bronze_dawn")),
                int(args.get("seed", 1)),
                None if civ is None else str(civ),
            )
            rivals = str(args.get("rivals", "growth"))
            self.rivals = {
                c: make_bot(rivals) for c in self.state.civs if c != self.state.player_civ
            }
        except ValueError as error:
            raise RequestError(str(error)) from error
        self.events = []
        view = self._view([])
        view["voices"] = opening_voices(self.content, self.state)
        return view

    def scenarios(self, args: dict[str, Any]) -> dict[str, Any]:
        """Every starting moment and its civilisations, for the picker."""
        return {"scenarios": build_catalog(self.content)}

    def view(self, args: dict[str, Any]) -> dict[str, Any]:
        """The current view, with the last turn's events."""
        return self._view(self.events, self.game())

    def act(self, args: dict[str, Any]) -> dict[str, Any]:
        """Apply a player action: ``{"action": {"kind": "start", "node_id": "paper"}}``."""
        state = self.game()
        raw = dict(args.get("action") or {})
        raw["civ"] = state.player_civ
        try:
            action = ACTION.validate_python(raw)
        except ValidationError as error:
            raise RequestError(f"bad action: {error.errors()[0]['msg']}") from error
        self.state, logged = apply_action(state, action)
        voices = []
        if logged.ok and isinstance(action, StartProject):
            name = self.state.tech_nodes[action.node_id].name
            voices = [v for v in [speak(self.content, self.state, "project_started", name)] if v]
        return {
            "accepted": logged.ok,
            "message": logged.message,
            "view": self._view(self.events),
            "voices": voices,
        }

    def end_turn(self, args: dict[str, Any]) -> dict[str, Any]:
        """Let the rivals act, resolve the turn, and return the new view with its events."""
        state = self.game()
        for civ_id in sorted(self.rivals):
            if state.owned_provinces(civ_id):
                for action in self.rivals[civ_id].decide(state, civ_id):
                    state, _ = apply_action(state, action)
        self.state, self.events = end_turn(state)
        self._autosave()
        view = self._view(self.events)
        view["voices"] = voices_for_turn(self.content, self.state, self.events)
        return view

    def _view(self, events: list[Event], state: GameState | None = None) -> dict[str, Any]:
        """The player's view, with each civilisation's emblem and portrait from the content."""
        view = build_view(state or self.game(), events)
        for civ in view["civs"]:
            definition = self.content.civs.get(civ["id"])
            civ["emblem"] = (definition.emblem or definition.adjective[:1]) if definition else "?"
            civ["portrait"] = definition.portrait if definition else ""
        return view

    def idea(self, args: dict[str, Any]) -> dict[str, Any]:
        """Rule on the player's own words: ``{"text": "...", "answer": "..."}`` (DESIGN §8).

        Replies with a clarifying ``question``, or with one ``rulings`` entry per idea found,
        the new view, and the advisers' reactions as ``voices``.
        """
        state = self.game()
        text = str(args.get("text", ""))[:600]
        outcome = self.pipeline.consider(state, state.player_civ, text, str(args.get("answer", "")))
        base = {"source": outcome.source, "note": outcome.note, "usage": outcome.usage}
        if outcome.question:
            return {**base, "question": outcome.question, "rulings": [], "voices": []}
        rulings: list[dict[str, Any]] = []
        voices: list[dict[str, Any]] = []
        for ruling in outcome.rulings:
            self.state, logged = apply_action(
                self.game(), RuleOnIdea(civ=state.player_civ, ruling=ruling)
            )
            node = self.state.tech_nodes.get(ruling.node_id or "")
            name = node.name if node else ruling.idea
            rulings.append(
                {
                    "idea": ruling.idea,
                    "verdict": ruling.verdict.value,
                    "node_id": ruling.node_id if node else None,
                    "name": name,
                    "new": ruling.new_node is not None,
                    "stubs": [s.name for s in ruling.stubs],
                    "reason": ruling.reason,
                    "hint": ruling.hint,
                    "message": logged.message,
                    "accepted": logged.ok,
                }
            )
            if ruling.advisers:
                for reaction in ruling.advisers:
                    voices.append(
                        adviser_voice(
                            self.content, self.state, reaction.role, reaction.text, reaction.mood
                        )
                    )
            else:
                moment = {
                    Verdict.FEASIBLE: "idea_feasible",
                    Verdict.BLOCKED: "idea_blocked",
                    Verdict.IMPLAUSIBLE: "idea_implausible",
                }[ruling.verdict]
                voice = speak(self.content, self.state, moment, name)
                if voice:
                    voices.append(voice)
        return {
            **base,
            "question": "",
            "rulings": rulings,
            "voices": voices[:3],
            "view": self._view(self.events),
        }

    def settings(self, args: dict[str, Any]) -> dict[str, Any]:
        """The model connection's status, for the settings screen.

        ``{"offline": true}`` switches to offline play for this session. The API key itself
        is never sent.
        """
        config = self.pipeline.config
        if "offline" in args:
            from dataclasses import replace

            config = replace(config, offline=bool(args["offline"]))
            self.pipeline.config = config
        return {
            "status": config.status,
            "online": self.pipeline.online,
            "has_key": bool(config.api_key),
            "model": config.model,
            "fast_model": config.fast_model,
            "offline": config.offline,
            "debug_log": config.log,
            "tokens_this_month": self.pipeline.ledger.used(),
            "calls_this_month": self.pipeline.ledger.calls(),
            "monthly_tokens": config.monthly_tokens,
            "env_file": str((config.data_dir / ".env").resolve()),
        }

    def saves(self, args: dict[str, Any]) -> dict[str, Any]:
        """Saved games, newest first: ``{"saves": [{"name", "modified"}]}``."""
        found: list[tuple[int, str]] = []
        if self.saves_dir.is_dir():
            found = [(int(p.stat().st_mtime), p.stem) for p in self.saves_dir.glob("*.json")]
        found.sort(key=lambda item: (-item[0], item[1]))
        return {"saves": [{"name": name, "modified": when} for when, name in found]}

    def chronicle(self, args: dict[str, Any]) -> dict[str, Any]:
        """Everything that has happened to the player and the great events of the world."""
        state = self.game()
        major = {"war", "peace", "conquest", "destroyed", "alliance", "revolt", "collapse"}
        entries: list[dict[str, Any]] = []
        seen: set[tuple[int, str]] = set()  # a peace is logged for each side: show it once
        for e in state.events:
            if e.civ != state.player_civ and (
                e.kind not in major or "declared war on" in e.message
            ):
                continue
            if (e.turn, e.message) in seen:
                continue
            seen.add((e.turn, e.message))
            entries.append(
                {
                    "turn": e.turn,
                    "year": e.year,
                    "kind": e.kind,
                    "message": e.message,
                    "mine": e.civ == state.player_civ,
                }
            )
        return {"entries": entries[-400:]}

    def history(self, args: dict[str, Any]) -> dict[str, Any]:
        """Each turn's key numbers for the player, and the population of every state."""
        state = self.game()
        mine = [snap.model_dump() for snap in state.civs[state.player_civ].history]
        populations = {
            civ_id: [snap.population for snap in civ.history]
            for civ_id, civ in sorted(state.civs.items())
        }
        return {"player": mine, "populations": populations}

    def tree(self, args: dict[str, Any]) -> dict[str, Any]:
        """The whole tech graph from the player's point of view, for the tech tree screen."""
        state = self.game()
        civ = state.civs[state.player_civ]
        nodes = []
        for node_id, node in sorted(state.tech_nodes.items()):
            known = civ.tech.get(node_id)
            nodes.append(
                {
                    "id": node_id,
                    "name": node.name,
                    "category": node.category.value,
                    "year": node.year,
                    "complexity": node.complexity,
                    "prerequisites": list(node.prerequisites),
                    "stage": known.stage.value if known else None,
                    "goal": bool(known and known.goal),
                    "stub": node.stub,
                    "provenance": node.provenance.value,
                    "flavour": node.flavour,
                }
            )
        return {"nodes": nodes, "year": state.year}

    def _path(self, args: dict[str, Any]) -> Path:
        name = str(args.get("name", "quicksave"))
        if not name.replace("_", "").replace("-", "").isalnum():
            raise RequestError("save names may use letters, digits, - and _ only")
        return self.saves_dir / f"{name}.json"

    def _autosave(self) -> None:
        """Keep the latest turn in the "autosave" slot, for Continue on the title screen."""
        try:
            self.saves_dir.mkdir(parents=True, exist_ok=True)
            (self.saves_dir / f"{AUTOSAVE}.json").write_text(dumps(self.game()), encoding="utf-8")
        except OSError:
            pass  # a full or read-only disk must not stop the game

    def save(self, args: dict[str, Any]) -> dict[str, Any]:
        """Save to the saves folder: ``{"name": "mygame"}``."""
        path = self._path(args)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(dumps(self.game()), encoding="utf-8")
        return {"saved": path.name}

    def load(self, args: dict[str, Any]) -> dict[str, Any]:
        """Load from the saves folder: ``{"name": "mygame"}``."""
        path = self._path(args)
        try:
            self.state = loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError as error:
            raise RequestError(f"no save called {path.name}") from error
        except SaveError as error:
            raise RequestError(str(error)) from error
        self.rivals = {c: make_bot("growth") for c in self.state.civs if c != self.state.player_civ}
        self.events = []
        view = self._view([])
        view["voices"] = [v for v in [speak(self.content, self.state, "game_start")] if v]
        return view


def handle(session: Session, line: str) -> tuple[dict[str, Any], bool]:
    """Answer one request line. Returns the reply and whether to keep running."""
    try:
        request = json.loads(line)
        if not isinstance(request, dict):
            raise ValueError("a request must be a JSON object")
    except ValueError as error:
        return {"id": None, "ok": False, "error": f"unreadable request: {error}"}, True
    request_id = request.get("id")
    command = request.get("cmd")
    args = request.get("args") or {}
    if command == "quit":
        return {"id": request_id, "ok": True, "result": {}}, False
    commands: dict[str, Callable[[dict[str, Any]], dict[str, Any]]] = {
        "new_game": session.new_game,
        "scenarios": session.scenarios,
        "view": session.view,
        "act": session.act,
        "end_turn": session.end_turn,
        "save": session.save,
        "load": session.load,
        "idea": session.idea,
        "saves": session.saves,
        "chronicle": session.chronicle,
        "tree": session.tree,
        "history": session.history,
        "settings": session.settings,
    }
    handler = commands.get(str(command))
    if handler is None or not isinstance(args, dict):
        return {"id": request_id, "ok": False, "error": f"unknown command {command!r}"}, True
    try:
        return {"id": request_id, "ok": True, "result": handler(args)}, True
    except RequestError as error:
        return {"id": request_id, "ok": False, "error": str(error)}, True


def serve(lines: Iterable[str], out: TextIO, session: Session) -> None:
    """Answer requests until ``quit`` or the end of input."""
    for line in lines:
        if not line.strip():
            continue
        reply, keep_going = handle(session, line)
        out.write(json.dumps(reply, separators=(",", ":")) + "\n")
        out.flush()
        if not keep_going:
            return


def main() -> int:
    """Run the bridge on stdin/stdout. Saves go to $ANACHRONISM_SAVES (default ./saves)."""
    saves = Path(os.environ.get("ANACHRONISM_SAVES", "saves"))
    config = load_config(Path(os.environ.get("ANACHRONISM_DATA", str(saves.parent))))
    session = Session(load_content(), saves, make_pipeline(config))
    serve(sys.stdin, sys.stdout, session)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
