"""A deterministic stand-in for a language model, for tests (no network, ever)."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from anachronism.llm.provider import Completion, ProviderError

Reply = dict[str, Any] | Exception | Callable[[str, str], dict[str, Any]]


class FakeProvider:
    """Answers each call with the next scripted reply, and records what it was sent.

    A reply may be a dict (the tool input), an exception to raise, or a function of
    ``(system, user)`` returning a dict. When the script runs out the last reply repeats.
    """

    name = "fake"

    def __init__(self, *replies: Reply, model: str = "fake-model") -> None:
        self.replies = list(replies)
        self.model = model
        self.calls: list[tuple[str, str]] = []

    def complete(
        self,
        system: str,
        user: str,
        schema: dict[str, Any],
        *,
        fast: bool = False,
        tool: str = "rule_on_ideas",
    ) -> Completion:
        """Return the next scripted reply."""
        self.calls.append((system, user))
        if not self.replies:
            raise ProviderError("the fake has no replies")
        reply = self.replies.pop(0) if len(self.replies) > 1 else self.replies[0]
        if isinstance(reply, Exception):
            raise reply
        data = reply(system, user) if callable(reply) else reply
        return Completion(data=data, model=self.model, usage={"input": 100, "output": 50})
