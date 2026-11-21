"""Rulings on the player's own ideas (DESIGN §8).

A ruling is what the idea pipeline (``llm/``) hands the engine: a verdict, the advancement
it refers to (an existing node, or a new one described in full), goal stubs for anything it
still needs, and the advisers' reactions. The ruling travels inside a ``RuleOnIdea`` action,
so it is stored in the save's action log and replays never ask a model again (D-021).

The engine does not trust a ruling: ``engine/judge.py`` clamps it once more before use.
"""

from __future__ import annotations

from enum import StrEnum
from typing import Annotated, Literal

from pydantic import Field

from anachronism.content.schema import Category, Frozen, Identifier, TechNode


class Verdict(StrEnum):
    """What the court decided about an idea."""

    FEASIBLE = "feasible"
    """It can be attempted now (or already could)."""
    BLOCKED = "blocked"
    """It makes sense, but something must come first; those become goal stubs."""
    IMPLAUSIBLE = "implausible_for_era"
    """Too far from anything this people knows; an in-world reason and a hint are given."""


Role = Literal["scholar", "steward", "general", "diviner"]
Mood = Literal["excited", "pleased", "keen", "doubtful", "alarmed"]
Source = Literal["library", "offline", "model", "cache", "fake"]


class StubSpec(Frozen):
    """A missing step named by a ruling. It becomes a goal that needs its own ruling."""

    id: Identifier
    name: Annotated[str, Field(min_length=1, max_length=80)]
    category: Category


class AdviserReaction(Frozen):
    """One adviser's reaction to an idea, shown as a speech bubble."""

    role: Role
    text: Annotated[str, Field(min_length=1, max_length=280)]
    mood: Mood = "keen"


class Ruling(Frozen):
    """The court's verdict on one idea. Numbers are bounded again when applied."""

    idea: Annotated[str, Field(max_length=300)]
    """The player's words for this idea (one part of a message that named several)."""
    verdict: Verdict
    node_id: Identifier | None = None
    """The advancement this idea is: an existing node, or ``new_node``'s id."""
    new_node: TechNode | None = None
    """A new advancement the idea describes, when nothing existing matches."""
    stubs: tuple[StubSpec, ...] = ()
    reason: Annotated[str, Field(max_length=400)] = ""
    """Why, in the world's own terms (shown to the player)."""
    hint: Annotated[str, Field(max_length=300)] = ""
    """For an implausible idea: what might bring it within reach."""
    advisers: tuple[AdviserReaction, ...] = ()
    unrest_bp: Annotated[int, Field(ge=0, le=10_000)] = 0
    """Unrest stirred by the advisers' reactions (alarmed priests, grumbling nobles)."""
    suspicion_bp: Annotated[int, Field(ge=0, le=10_000)] = 0
    source: Source = "offline"
    """Who made the ruling: the offline interpreter, a language model, or the ruling cache."""
    model: Annotated[str, Field(max_length=80)] = ""
    prompt_version: Annotated[str, Field(max_length=20)] = ""
