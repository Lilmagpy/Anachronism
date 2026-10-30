"""What a model (or the offline interpreter) replies about the player's message.

This is the *model's* vocabulary: loose, human-scale numbers (percentages, 0-3 levels).
``guard.py`` turns it into engine ``Ruling`` objects with basis points and hard bounds.
Unknown fields are ignored rather than rejected, so a chatty model does not fail a ruling;
wrong types and out-of-range values are rejected, and the pipeline retries once.
"""

from __future__ import annotations

from typing import Annotated, Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from anachronism.content.schema import Category, EffectType, SocialGroup
from anachronism.engine.rulings import Mood, Role, Verdict


class _Loose(BaseModel):
    model_config = ConfigDict(extra="ignore", frozen=True)


class ModelEffect(_Loose):
    """One effect from the fixed menu; ``percent`` is +10 for +10%."""

    type: EffectType
    percent: Annotated[float, Field(ge=-50, le=100)]


class ModelMissing(_Loose):
    """Something the idea needs that nobody has thought of yet (becomes a goal stub)."""

    name: Annotated[str, Field(min_length=1, max_length=80)]
    category: Category


class ModelResistance(_Loose):
    """A social group that would resist the idea, and how strongly (1-3)."""

    group: SocialGroup
    level: Annotated[int, Field(ge=1, le=3)]


class ModelAdviser(_Loose):
    """An adviser's in-character reaction."""

    role: Role
    mood: Mood = "keen"
    text: Annotated[str, Field(min_length=1, max_length=280)]


class ModelIdea(_Loose):
    """The ruling on one idea in the player's message."""

    text: Annotated[str, Field(max_length=300)] = ""
    """The player's words for this idea."""
    verdict: Verdict
    matches: str = ""
    """Id of an existing related node this idea is the same as, or empty."""
    name: Annotated[str, Field(max_length=80)] = ""
    category: Category = Category.KNOWLEDGE
    complexity: Annotated[int, Field(ge=1, le=5)] = 2
    year: Annotated[int, Field(ge=-12_000, le=2_100)] = 0
    """When something like it first appeared in real history (negative = BC)."""
    prerequisites: list[str] = Field(default_factory=list)
    materials: list[str] = Field(default_factory=list)
    literacy_percent: Annotated[float, Field(ge=0, le=100)] = 0
    resistance: list[ModelResistance] = Field(default_factory=list)
    effects: list[ModelEffect] = Field(default_factory=list)
    missing: list[ModelMissing] = Field(default_factory=list)
    flavour: Annotated[str, Field(max_length=200)] = ""
    reason: Annotated[str, Field(max_length=400)] = ""
    hint: Annotated[str, Field(max_length=300)] = ""
    advisers: list[ModelAdviser] = Field(default_factory=list)
    stirs_unrest: Annotated[int, Field(ge=0, le=3)] = 0
    stirs_suspicion: Annotated[int, Field(ge=0, le=3)] = 0


class ModelReply(_Loose):
    """The whole reply: a clarifying question, or a ruling per idea."""

    clarify: Annotated[str, Field(max_length=200)] = ""
    """One short question, only when the message is truly too vague to rule on."""
    ideas: list[ModelIdea] = Field(default_factory=list)


def reply_schema() -> dict[str, Any]:
    """JSON schema of ``ModelReply``, given to the model as its tool's input schema."""
    return ModelReply.model_json_schema()


Status = Literal["ruled", "clarify", "error"]
