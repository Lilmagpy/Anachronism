"""Calling Anthropic's Messages API for rulings (brief §6.2-6.6).

Standard library only (``urllib``), so no new dependency. The reply is forced through a
single tool whose input schema is ``ModelReply``, which gives structured JSON. The system
prompt and tool definition never change, so they are marked for prompt caching. Rulings use
a low temperature for consistency. Rate limits and server errors are retried with backoff;
anything else raises ``ProviderError`` and the pipeline falls back to offline play.
"""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from typing import Any

from anachronism.llm.config import LlmConfig
from anachronism.llm.counsel import COUNSEL_TOOL
from anachronism.llm.prompts import TOOL_NAME, VOICE_TOOL
from anachronism.llm.provider import Completion, ProviderError

API_VERSION = "2023-06-01"
TOOL_DESCRIPTIONS = {
    TOOL_NAME: "Report the court's ruling on the player's ideas.",
    VOICE_TOOL: "Say the rival ruler's line.",
    COUNSEL_TOOL: "Decide the rival ruler's move toward the player and what they say.",
}
RETRY_STATUSES = frozenset({408, 409, 429, 500, 502, 503, 504, 529})


class AnthropicProvider:
    """Rulings from a Claude model, using the key and model names in the configuration."""

    name = "anthropic"

    def __init__(self, config: LlmConfig, *, timeout: float = 60.0, retries: int = 2) -> None:
        if not config.api_key or not config.model:
            raise ProviderError("an API key and a model name are both needed")
        self.config = config
        self.timeout = timeout
        self.retries = retries

    def request_body(
        self,
        system: str,
        user: str,
        schema: dict[str, Any],
        model: str,
        tool: str = TOOL_NAME,
        temperature: float = 0.2,
    ) -> dict[str, Any]:
        """The JSON body for one call (separate so tests can inspect it without a network)."""
        return {
            "model": model,
            "max_tokens": 2000,
            "temperature": temperature,
            "system": [{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
            "tools": [
                {
                    "name": tool,
                    "description": TOOL_DESCRIPTIONS.get(tool, "Report your answer."),
                    "input_schema": schema,
                }
            ],
            "tool_choice": {"type": "tool", "name": tool},
            "messages": [{"role": "user", "content": user}],
        }

    def complete(
        self,
        system: str,
        user: str,
        schema: dict[str, Any],
        *,
        fast: bool = False,
        tool: str = TOOL_NAME,
    ) -> Completion:
        """Call the API and return the tool input the model produced."""
        model = (self.config.fast_model or self.config.model) if fast else self.config.model
        temperature = 0.2 if tool == TOOL_NAME else 0.8  # rulings steady, speech lively
        body = json.dumps(
            self.request_body(system, user, schema, model, tool, temperature)
        ).encode()
        request = urllib.request.Request(
            f"{self.config.base_url}/v1/messages",
            data=body,
            method="POST",
            headers={
                "content-type": "application/json",
                "x-api-key": self.config.api_key,
                "anthropic-version": API_VERSION,
            },
        )
        reply = self._send(request)
        for block in reply.get("content", []):
            if block.get("type") == "tool_use" and block.get("name") == tool:
                usage = reply.get("usage", {})
                return Completion(
                    data=dict(block.get("input") or {}),
                    model=str(reply.get("model", model)),
                    usage={
                        "input": int(usage.get("input_tokens", 0)),
                        "output": int(usage.get("output_tokens", 0)),
                        "cache_read": int(usage.get("cache_read_input_tokens", 0) or 0),
                        "cache_write": int(usage.get("cache_creation_input_tokens", 0) or 0),
                    },
                )
        raise ProviderError(f"no ruling in the reply (stop reason {reply.get('stop_reason')})")

    def _send(self, request: urllib.request.Request) -> dict[str, Any]:
        delay = 1.0
        for attempt in range(self.retries + 1):
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    data: dict[str, Any] = json.loads(response.read().decode())
                    return data
            except urllib.error.HTTPError as error:
                if error.code not in RETRY_STATUSES or attempt == self.retries:
                    detail = error.read().decode(errors="replace")[:300]
                    raise ProviderError(f"API error {error.code}: {detail}") from error
            except (urllib.error.URLError, TimeoutError, OSError) as error:
                if attempt == self.retries:
                    raise ProviderError(f"could not reach the API: {error}") from error
            except json.JSONDecodeError as error:
                raise ProviderError("the API sent something that is not JSON") from error
            time.sleep(delay)
            delay *= 2
        raise ProviderError("unreachable")
