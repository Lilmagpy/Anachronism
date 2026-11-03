"""Rival rulers voiced by the model (Phase 7): a line of speech, never a game effect.

A rival's line already exists in the content (``dialogue``). When a model is configured,
it rewrites that line in the ruler's own voice, from facts the engine knows (who, where,
when, temperament, grudges). The reply only replaces text in a speech bubble: it changes
nothing in the game, so replays need no record of it. Anything wrong or missing falls back
to the content line. The player's words are never part of the message.
"""

from __future__ import annotations

import re
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from anachronism.engine.rivals import relation, strength
from anachronism.engine.state import GameState

MAX_CHARS = 280
QUOTES = '"\u201c\u201d'

MOMENTS = {
    "rival_war": "has just declared war on the player",
    "rival_peace": "has just made peace with the player after a war",
    "rival_tribute": "has just submitted to the player and agreed to pay tribute",
    "rival_adopted": "has just mastered a new advancement ({subject}) and boasts of it",
    "rival_counsel": "has heard of the player's strange new arts and must decide what to do",
}


class VoiceReply(BaseModel):
    """The model's answer: one line of speech."""

    model_config = ConfigDict(extra="ignore")

    line: str = Field(min_length=1, max_length=600)


def voice_schema(about: str = "What the ruler says.") -> dict[str, Any]:
    """The JSON schema of the speech tool (and of the chronicler's, with ``about``)."""
    return {
        "type": "object",
        "properties": {"line": {"type": "string", "description": about}},
        "required": ["line"],
    }


def clean_line(text: str, max_chars: int = MAX_CHARS) -> str:
    """One tidy line: no markup or wrapping quotes, cut at a sentence end if too long."""
    text = re.sub(r"[<>*_#`]", "", " ".join(text.split())).strip().strip(QUOTES).strip()
    if len(text) <= max_chars:
        return text
    cut = text[:max_chars]
    end = max(cut.rfind(". "), cut.rfind("! "), cut.rfind("? "))
    return cut[: end + 1] if end > 40 else cut.rsplit(" ", 1)[0] + "..."


def facts(state: GameState, rival: str, moment: str, subject: str) -> dict[str, str]:
    """What the model may know when speaking for ``rival``: all from the game state."""
    civ = state.civs[rival]
    player = state.civs[state.player_civ]
    rel = relation(state, rival, state.player_civ)
    grudge = rel.grievance.get(rival, 0) if rel else 0
    year = f"{-state.year} BC" if state.year < 0 else f"AD {state.year}"
    return {
        "year": year,
        "speaker": f"{civ.ruler or 'the ruler'} of {civ.name} ({civ.adjective})",
        "speaker age": str(civ.ruler_age) if civ.ruler else "",
        "temperament": civ.disposition.value,
        "speaker faith": state.world.faiths[civ.faith].name
        if civ.faith in state.world.faiths
        else "",
        "addressing": f"{player.ruler or 'the ruler'} of {player.name}",
        "moment": f"{civ.name} " + MOMENTS.get(moment, "speaks").format(subject=subject),
        "grudge against the player": "deep" if grudge >= 3000 else "some" if grudge >= 1000 else "",
        "strength": _strength_words(state, rival),
    }


def _strength_words(state: GameState, rival: str) -> str:
    theirs, ours = strength(state, rival), strength(state, state.player_civ)
    if theirs >= ours * 2:
        return "far stronger than the player"
    if theirs * 2 <= ours:
        return "far weaker than the player"
    return "about as strong as the player"
