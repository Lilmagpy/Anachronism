"""Files the idea pipeline keeps between games: ruling cache, token ledger, debug log.

- The **ruling cache** reuses an earlier answer for the same idea in the same situation,
  for consistency and to save calls (brief §6.6). Keys are hashes of the normalised idea
  and a fingerprint of the relevant state.
- The **ledger** counts tokens per calendar month so a spending cap can be enforced.
- The **debug log** records every model input and output (JSON lines) so bad rulings can be
  inspected; it can be turned off in settings.

All three live in the configured data folder, which is git-ignored.
"""

from __future__ import annotations

import datetime
import hashlib
import json
from pathlib import Path
from typing import Any


def _read(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def _write(path: Path, data: dict[str, Any]) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, sort_keys=True), encoding="utf-8")
    except OSError:
        pass  # a read-only disk only costs us the cache


class RulingCache:
    """Earlier replies, keyed by idea and situation. ``path=None`` keeps it in memory."""

    LIMIT = 500

    def __init__(self, path: Path | None) -> None:
        self.path = path
        self.entries: dict[str, Any] = _read(path) if path else {}

    @staticmethod
    def key(idea: str, fingerprint: str) -> str:
        """Hash of the normalised idea text and the situation it was judged in."""
        normal = " ".join(idea.lower().split())
        return hashlib.sha256(f"{normal}|{fingerprint}".encode()).hexdigest()[:32]

    def get(self, key: str) -> dict[str, Any] | None:
        """The stored reply for a key, if any."""
        value = self.entries.get(key)
        return value if isinstance(value, dict) else None

    def put(self, key: str, reply: dict[str, Any]) -> None:
        """Remember a reply (oldest entries are dropped past ``LIMIT``)."""
        self.entries[key] = reply
        while len(self.entries) > self.LIMIT:
            self.entries.pop(next(iter(self.entries)))
        if self.path:
            _write(self.path, self.entries)


class Ledger:
    """Tokens used per month, to stop at the configured monthly cap."""

    def __init__(self, path: Path | None, monthly_tokens: int) -> None:
        self.path = path
        self.monthly_tokens = monthly_tokens
        self.data: dict[str, Any] = _read(path) if path else {}

    @staticmethod
    def month() -> str:
        """The current calendar month, e.g. ``2026-10``."""
        return datetime.date.today().strftime("%Y-%m")

    def used(self) -> int:
        """Tokens used so far this month."""
        return int(self.data.get(self.month(), {}).get("tokens", 0))

    def calls(self) -> int:
        """Model calls made this month."""
        return int(self.data.get(self.month(), {}).get("calls", 0))

    def allows(self) -> bool:
        """True while this month's use is under the cap (0 means no cap)."""
        return self.monthly_tokens == 0 or self.used() < self.monthly_tokens

    def add(self, usage: dict[str, int]) -> None:
        """Record one call's token use."""
        entry = self.data.setdefault(self.month(), {"tokens": 0, "calls": 0})
        entry["tokens"] = int(entry.get("tokens", 0)) + sum(int(v) for v in usage.values())
        entry["calls"] = int(entry.get("calls", 0)) + 1
        if self.path:
            _write(self.path, self.data)


class DebugLog:
    """Append-only JSON-lines log of model calls. Never records the API key."""

    def __init__(self, path: Path | None) -> None:
        self.path = path

    def write(self, record: dict[str, Any]) -> None:
        """Add one record with a timestamp."""
        if self.path is None:
            return
        record = {"at": datetime.datetime.now().isoformat(timespec="seconds"), **record}
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            with self.path.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(record, sort_keys=True) + "\n")
        except OSError:
            pass
