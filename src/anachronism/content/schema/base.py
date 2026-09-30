"""Shared building blocks for content models."""

from __future__ import annotations

from typing import Annotated, Any, Self

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

CURRENT_SCHEMA_VERSION = 1

Identifier = Annotated[str, StringConstraints(pattern=r"^[a-z][a-z0-9_]*$", max_length=64)]
"""Lower-case snake_case id, e.g. ``iron_working``."""

Rate = Annotated[int, Field(ge=0, le=10_000)]
"""A share or 0-100 stat in basis points (10_000 = 100%)."""

NonNegative = Annotated[int, Field(ge=0)]
Positive = Annotated[int, Field(ge=1)]
HexColour = Annotated[str, StringConstraints(pattern=r"^#[0-9a-fA-F]{6}$")]


class Frozen(BaseModel):
    """Immutable content model: unknown fields are errors, and copies share the instance."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    def __deepcopy__(self, memo: dict[int, Any] | None = None) -> Self:
        """Return self: frozen content is never mutated, so deep copies can share it."""
        return self
