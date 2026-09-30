"""Saving and loading games as canonical JSON text (the caller writes the file)."""

from __future__ import annotations

import json

from pydantic import ValidationError

from anachronism.engine.state import SAVE_SCHEMA_VERSION, GameState


class SaveError(Exception):
    """Raised when a save cannot be loaded."""


def dumps(state: GameState) -> str:
    """Serialise a game to canonical JSON: keys sorted, so equal games give equal text."""
    return json.dumps(state.model_dump(mode="json"), sort_keys=True, indent=1) + "\n"


def loads(text: str) -> GameState:
    """Load a game saved by :func:`dumps`.

    Raises:
        SaveError: if the text is not a valid save for this version of the game.
    """
    try:
        raw = json.loads(text)
    except json.JSONDecodeError as error:
        raise SaveError(f"not a save file: {error}") from error
    version = raw.get("schema_version") if isinstance(raw, dict) else None
    if version != SAVE_SCHEMA_VERSION:
        raise SaveError(
            f"save format {version!r} is not supported (this version reads {SAVE_SCHEMA_VERSION})"
        )
    try:
        return GameState.model_validate(raw)
    except ValidationError as error:
        raise SaveError(f"save file is damaged: {error}") from error
