"""Actions players and AIs take. Each is logged with its turn so games replay exactly."""

from __future__ import annotations

from enum import StrEnum
from typing import Annotated, Literal

from pydantic import Field

from anachronism.content.schema import Frozen
from anachronism.engine.rulings import Ruling


class Priority(StrEnum):
    """Funding order for projects when resources run short."""

    HIGH = "high"
    NORMAL = "normal"
    LOW = "low"

    @property
    def rank(self) -> int:
        """0 is funded first."""
        return list(Priority).index(self)


class ProposeIdea(Frozen):
    """Consider an idea: it becomes a known concept, and missing prerequisites become goals."""

    kind: Literal["propose"] = "propose"
    civ: str
    node_id: str


class StartProject(Frozen):
    """Commit resources to experimenting with a feasible concept."""

    kind: Literal["start"] = "start"
    civ: str
    node_id: str
    priority: Priority = Priority.NORMAL


class PauseProject(Frozen):
    """Stop funding a project; its progress slowly decays."""

    kind: Literal["pause"] = "pause"
    civ: str
    node_id: str


class ResumeProject(Frozen):
    """Fund a paused project again."""

    kind: Literal["resume"] = "resume"
    civ: str
    node_id: str


class CancelProject(Frozen):
    """Abandon a project and its progress; the idea stays known as a concept."""

    kind: Literal["cancel"] = "cancel"
    civ: str
    node_id: str


class SetPriority(Frozen):
    """Change the funding order of a project."""

    kind: Literal["priority"] = "priority"
    civ: str
    node_id: str
    priority: Priority


class RuleOnIdea(Frozen):
    """Apply the court's ruling on one of the player's own ideas (DESIGN §8).

    The whole ruling is stored, so replays apply it again without asking any model.
    """

    kind: Literal["ruling"] = "ruling"
    civ: str
    ruling: Ruling


Action = Annotated[
    ProposeIdea
    | StartProject
    | PauseProject
    | ResumeProject
    | CancelProject
    | SetPriority
    | RuleOnIdea,
    Field(discriminator="kind"),
]


class LoggedAction(Frozen):
    """An action as submitted, with its turn and outcome."""

    turn: int
    action: Action
    ok: bool
    message: str
