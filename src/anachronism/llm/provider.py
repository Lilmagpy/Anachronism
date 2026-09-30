"""The interface every language-model provider implements, and its errors."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Protocol


class ProviderError(Exception):
    """A call failed (network, refusal, bad reply). The pipeline falls back to offline."""


@dataclass(frozen=True)
class Completion:
    """A provider's structured answer and what it cost."""

    data: dict[str, Any]
    """The tool input the model produced (to be validated as a ``ModelReply``)."""
    model: str
    usage: dict[str, int] = field(default_factory=dict)
    """Token counts: input, output, cache_read, cache_write."""


class Provider(Protocol):
    """Something that can answer a ruling request with structured data."""

    name: str

    def complete(
        self, system: str, user: str, schema: dict[str, Any], *, fast: bool = False
    ) -> Completion:
        """Send the fixed ``system`` prompt and one ``user`` message; return the tool input.

        ``fast`` asks for the cheaper model where one is configured (clarifying steps).
        Raises ``ProviderError`` on any failure.
        """
        ...
