"""Problems found while loading content."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass


@dataclass(frozen=True)
class ContentIssue:
    """One problem in a content file."""

    file: str
    """Path relative to the packs folder, e.g. ``core/techs/metallurgy.yaml``."""
    location: str
    """Where in the file, e.g. ``techs[3] (iron_working).effects[0].bp``; may be empty."""
    message: str

    def __str__(self) -> str:
        where = f"{self.file}: {self.location}" if self.location else self.file
        return f"{where}: {self.message}"


class ContentError(Exception):
    """Raised when content has problems; lists all of them."""

    def __init__(self, issues: Sequence[ContentIssue]) -> None:
        self.issues = tuple(issues)
        lines = "\n".join(f"  {issue}" for issue in self.issues)
        super().__init__(f"{len(self.issues)} content problem(s):\n{lines}")
