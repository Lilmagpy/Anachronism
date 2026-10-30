r"""The idea pipeline: the player's words in, bounded rulings out (brief §6.1, DESIGN §8).

    summary.build -> cache? -> provider -> ModelReply (retry once) -> guard -> Rulings
                                   \\-> on any failure: the offline interpreter

This never changes game state. The caller turns each ``Ruling`` into a ``RuleOnIdea``
action, which the engine bounds again and records in the save (D-021).
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass, field

from pydantic import ValidationError

from anachronism.engine.actions import Action
from anachronism.engine.rulings import Ruling
from anachronism.engine.state import GameState
from anachronism.engine.summary import build, related_nodes
from anachronism.engine.tech import is_adopted
from anachronism.engine.timeflow import current_era
from anachronism.llm import offline
from anachronism.llm.config import LlmConfig
from anachronism.llm.counsel import (
    COUNSEL_SYSTEM,
    COUNSEL_TOOL,
    CounselReply,
    counsel_facts,
    counsel_schema,
    to_action,
)
from anachronism.llm.guard import to_rulings
from anachronism.llm.prompts import (
    NARRATE_SYSTEM,
    NARRATE_TOOL,
    PROMPT_VERSION,
    SYSTEM,
    VOICE_SYSTEM,
    VOICE_TOOL,
    clean_player_text,
    facts_message,
    user_message,
    voice_message,
)
from anachronism.llm.provider import Provider, ProviderError
from anachronism.llm.schemas import ModelReply, reply_schema
from anachronism.llm.store import DebugLog, Ledger, RulingCache
from anachronism.llm.voice import VoiceReply, clean_line, facts, voice_schema


@dataclass
class Outcome:
    """What the court made of a message."""

    rulings: list[Ruling] = field(default_factory=list)
    question: str = ""
    """A clarifying question, when the message was too vague to rule on."""
    source: str = "offline"
    note: str = ""
    """Why the court ruled offline, if it did (shown in the developer overlay)."""
    usage: dict[str, int] = field(default_factory=dict)


def fingerprint(state: GameState, civ_id: str, idea: str) -> str:
    """The parts of the situation a ruling depends on: era and what is known nearby."""
    civ = state.civs[civ_id]
    related = related_nodes(state, idea)
    known = ",".join(f"{n.id}:{int(is_adopted(civ, n.id))}" for n in related)
    return hashlib.sha256(
        f"{state.world.scenario_id}|{civ_id}|{current_era(state).id}|{known}|{PROMPT_VERSION}".encode()
    ).hexdigest()[:16]


class IdeaPipeline:
    """Rules on the player's ideas with a model when one is configured, offline otherwise."""

    def __init__(
        self,
        config: LlmConfig,
        provider: Provider | None = None,
        *,
        use_files: bool = True,
    ) -> None:
        self.config = config
        self.provider = provider
        folder = config.data_dir / "llm"
        self.cache = RulingCache(folder / "rulings.json" if use_files else None)
        self.ledger = Ledger(folder / "usage.json" if use_files else None, config.monthly_tokens)
        self.log = DebugLog(folder / "calls.jsonl" if use_files and config.log else None)

    @property
    def online(self) -> bool:
        """True when a provider is ready and the monthly cap has room."""
        return self.provider is not None and not self.config.offline and self.ledger.allows()

    def consider(self, state: GameState, civ_id: str, text: str, answer: str = "") -> Outcome:
        """Rule on a message (and the answer to an earlier clarifying question, if any)."""
        text = clean_player_text(text)
        if not text:
            return Outcome(note="nothing was said")
        if not self.online:
            note = (
                "offline mode"
                if self.provider is None or self.config.offline
                else "monthly limit reached"
            )
            return self._offline(state, civ_id, text, note)
        key = RulingCache.key(f"{text}|{answer}", fingerprint(state, civ_id, text))
        cached = self.cache.get(key)
        if cached is not None:
            try:
                earlier = ModelReply.model_validate(cached)
                return Outcome(
                    rulings=to_rulings(state, earlier, "cache", self.config.model, PROMPT_VERSION),
                    source="cache",
                )
            except ValidationError:
                pass
        user = user_message(build(state, civ_id, text), text, answer)
        reply, usage, error = self._ask(user)
        if reply is None:
            return self._offline(state, civ_id, text, f"the scholars could not agree ({error})")
        if reply.clarify and not reply.ideas and not answer:
            return Outcome(question=reply.clarify, source="model", usage=usage)
        self.cache.put(key, reply.model_dump(mode="json"))
        rulings = to_rulings(state, reply, "model", self.config.model, PROMPT_VERSION)
        if not rulings:
            return self._offline(state, civ_id, text, "the model named no idea")
        return Outcome(rulings=rulings, source="model", usage=usage)

    def _ask(self, user: str) -> tuple[ModelReply | None, dict[str, int], str]:
        """Call the provider; retry once with the validation error if the reply is malformed."""
        assert self.provider is not None
        usage: dict[str, int] = {}
        message = user
        error = ""
        for _ in range(2):
            try:
                completion = self.provider.complete(SYSTEM, message, reply_schema())
            except ProviderError as failure:
                self.log.write({"user": message, "error": str(failure)})
                return None, usage, str(failure)[:120]
            for name, value in completion.usage.items():
                usage[name] = usage.get(name, 0) + value
            self.ledger.add(completion.usage)
            try:
                reply = ModelReply.model_validate(completion.data)
            except ValidationError as failure:
                error = f"invalid reply: {failure.errors()[0]['msg']}"
                self.log.write({"user": message, "reply": completion.data, "error": error})
                message = (
                    f"{user}\n\nYour last reply was invalid ({error}). "
                    "Reply again, following the schema."
                )
                continue
            self.log.write(
                {
                    "user": message,
                    "reply": completion.data,
                    "model": completion.model,
                    "usage": completion.usage,
                }
            )
            return reply, usage, ""
        return None, usage, error

    def voice_rival(
        self, state: GameState, rival: str, moment: str, subject: str, line: str
    ) -> tuple[str, str]:
        """A rival ruler's ``line``, rewritten in their own voice when a model is available.

        Returns the text and where it came from ("content", "cache" or "model"). Any
        failure keeps the content line: speech is flavour and must never block a turn.
        """
        if not self.online or rival not in state.civs:
            return line, "content"
        known = facts(state, rival, moment, subject)
        key = RulingCache.key(f"voice|{moment}|{line}", "|".join(known.values()))
        cached = self.cache.get(key)
        if cached is not None and isinstance(cached.get("line"), str):
            return cached["line"], "cache"
        user = voice_message(known, line)
        try:
            completion = self.provider.complete(  # type: ignore[union-attr]
                VOICE_SYSTEM, user, voice_schema(), fast=True, tool=VOICE_TOOL
            )
            self.ledger.add(completion.usage)
            spoken = clean_line(VoiceReply.model_validate(completion.data).line)
        except (ProviderError, ValidationError) as failure:
            self.log.write({"user": user, "error": str(failure)[:200]})
            return line, "content"
        if not spoken:
            return line, "content"
        self.log.write({"user": user, "reply": completion.data, "model": completion.model})
        self.cache.put(key, {"line": spoken})
        return spoken, "model"

    def counsel(self, state: GameState, rival: str) -> tuple[Action | None, str]:
        """How an aware rival court responds to the player this turn (brief §7.2).

        Returns the guarded engine action (``None`` to wait) and the ruler's line ("" when
        offline or on any failure, in which case the court just follows its usual rules).
        """
        if not self.online or rival not in state.civs:
            return None, ""
        known = {**facts(state, rival, "rival_counsel", ""), **counsel_facts(state, rival)}
        user = facts_message(known)
        try:
            completion = self.provider.complete(  # type: ignore[union-attr]
                COUNSEL_SYSTEM, user, counsel_schema(), fast=True, tool=COUNSEL_TOOL
            )
            self.ledger.add(completion.usage)
            reply = CounselReply.model_validate(completion.data)
        except (ProviderError, ValidationError) as failure:
            self.log.write({"user": user, "error": str(failure)[:200]})
            return None, ""
        self.log.write({"user": user, "reply": completion.data, "model": completion.model})
        return to_action(state, rival, reply.move), clean_line(reply.line)

    def narrate(self, facts: dict[str, str], plain: str, *, call: bool = True) -> tuple[str, str]:
        """A finished chapter of the chronicle, told by the model when one is configured.

        Returns the text and its source ("content", "cache" or "model"). With ``call=False``
        only the cache is consulted (to bound how many calls one request makes).
        """
        if not self.online:
            return plain, "content"
        key = RulingCache.key("chronicle", "|".join(f"{k}={v}" for k, v in facts.items()))
        cached = self.cache.get(key)
        if cached is not None and isinstance(cached.get("line"), str):
            return cached["line"], "cache"
        if not call:
            return plain, "content"
        user = facts_message(facts)
        try:
            completion = self.provider.complete(  # type: ignore[union-attr]
                NARRATE_SYSTEM, user, voice_schema("The chapter."), fast=True, tool=NARRATE_TOOL
            )
            self.ledger.add(completion.usage)
            text = clean_line(VoiceReply.model_validate(completion.data).line, 700)
        except (ProviderError, ValidationError) as failure:
            self.log.write({"user": user, "error": str(failure)[:200]})
            return plain, "content"
        if not text:
            return plain, "content"
        self.log.write({"user": user, "reply": completion.data, "model": completion.model})
        self.cache.put(key, {"line": text})
        return text, "model"

    def _offline(self, state: GameState, civ_id: str, text: str, note: str) -> Outcome:
        reply = offline.interpret(state, civ_id, text)
        return Outcome(rulings=to_rulings(state, reply, "offline"), source="offline", note=note)


def make_pipeline(config: LlmConfig) -> IdeaPipeline:
    """A pipeline for real play: the Anthropic provider when configured, offline otherwise."""
    provider: Provider | None = None
    if config.online:
        from anachronism.llm.anthropic import AnthropicProvider

        provider = AnthropicProvider(config)
    return IdeaPipeline(config, provider)
