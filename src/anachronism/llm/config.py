"""Settings for the language model: key, model names, spending cap, debug log.

Read from the environment, then from a git-ignored ``.env`` file (in the working folder or
the game's data folder). Model names are configuration, never code: there is no default,
so without ``ANACHRONISM_MODEL`` the game plays offline.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class LlmConfig:
    """Everything the idea pipeline needs to know about the model it may call."""

    api_key: str = ""
    model: str = ""
    fast_model: str = ""
    base_url: str = "https://api.anthropic.com"
    offline: bool = False
    log: bool = True
    monthly_tokens: int = 2_000_000
    data_dir: Path = Path(".")
    """Where the ruling cache, usage ledger and debug log live."""

    @property
    def online(self) -> bool:
        """True when the model can be called (a key and a model name, not forced offline)."""
        return bool(self.api_key and self.model and not self.offline)

    @property
    def status(self) -> str:
        """A short description for the settings screen. Never includes the key."""
        if self.offline:
            return "offline (turned off in settings)"
        if not self.api_key:
            return "offline (no API key)"
        if not self.model:
            return "offline (no model chosen)"
        return f"online ({self.model})"


def read_env_file(path: Path) -> dict[str, str]:
    """``KEY=value`` lines of a .env file; comments and blank lines ignored."""
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def load_config(data_dir: Path | None = None, env: dict[str, str] | None = None) -> LlmConfig:
    """Build the configuration: environment first, then ``.env`` files, then defaults."""
    data = data_dir or Path(os.environ.get("ANACHRONISM_DATA", ".")).expanduser()
    merged: dict[str, str] = {}
    for candidate in (data / ".env", Path.cwd() / ".env"):
        for key, value in read_env_file(candidate).items():
            merged.setdefault(key, value)
    source = dict(os.environ) if env is None else env
    merged.update({k: v for k, v in source.items() if v != ""})

    def flag(name: str, default: bool) -> bool:
        value = merged.get(name, "").lower()
        return default if value == "" else value in ("1", "true", "yes", "on")

    try:
        monthly = int(merged.get("ANACHRONISM_MONTHLY_TOKENS", "2000000") or 0)
    except ValueError:
        monthly = 2_000_000
    model = merged.get("ANACHRONISM_MODEL", "")
    return LlmConfig(
        api_key=merged.get("ANTHROPIC_API_KEY", ""),
        model=model,
        fast_model=merged.get("ANACHRONISM_FAST_MODEL", "") or model,
        base_url=merged.get("ANTHROPIC_BASE_URL", "https://api.anthropic.com").rstrip("/"),
        offline=flag("ANACHRONISM_OFFLINE", False),
        log=flag("ANACHRONISM_LLM_LOG", True),
        monthly_tokens=max(0, monthly),
        data_dir=data,
    )
