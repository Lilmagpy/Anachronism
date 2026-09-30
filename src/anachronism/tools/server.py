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
from anachronism.engine.actions import Action, StartProject
from anachronism.engine.bots import Bot, make_bot
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.save import SaveError, dumps, loads
from anachronism.engine.state import Event, GameState
from anachronism.tools.view import build_catalog, build_view
from anachronism.tools.voices import speak, voices_for_turn

ACTION = TypeAdapter[Action](Action)


class RequestError(Exception):
    """A request the server understood but cannot carry out; sent back as an error reply."""


class Session:
    """One game being played through the bridge."""

    def __init__(self, content: Content, saves_dir: Path) -> None:
        self.content = content
        self.saves_dir = saves_dir
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
        view = build_view(self.state)
        view["voices"] = [v for v in [speak(self.content, self.state, "game_start")] if v]
        return view

    def scenarios(self, args: dict[str, Any]) -> dict[str, Any]:
        """Every starting moment and its civilisations, for the picker."""
        return {"scenarios": build_catalog(self.content)}

    def view(self, args: dict[str, Any]) -> dict[str, Any]:
        """The current view, with the last turn's events."""
        return build_view(self.game(), self.events)

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
            "view": build_view(self.state, self.events),
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
        view = build_view(self.state, self.events)
        view["voices"] = voices_for_turn(self.content, self.state, self.events)
        return view

    def _path(self, args: dict[str, Any]) -> Path:
        name = str(args.get("name", "quicksave"))
        if not name.replace("_", "").replace("-", "").isalnum():
            raise RequestError("save names may use letters, digits, - and _ only")
        return self.saves_dir / f"{name}.json"

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
        view = build_view(self.state)
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
    session = Session(load_content(), Path(os.environ.get("ANACHRONISM_SAVES", "saves")))
    serve(sys.stdin, sys.stdout, session)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
