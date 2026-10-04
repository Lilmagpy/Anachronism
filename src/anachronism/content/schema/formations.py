"""Battle formations (D-267): how an army draws up its line before the clash.

Each formation beats some others (a strong wing turns a balanced line's flank, a deep
reserve plugs the breach a strong centre makes). A side whose formation beats the enemy's
gets that formation's edge in the clash. Content, not code: a new formation is a YAML entry.
"""

from __future__ import annotations

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier, Rate


class Formation(Frozen):
    """One way of drawing up the army."""

    id: Identifier
    name: str = Field(min_length=1, max_length=40)
    description: str = Field(min_length=1, max_length=300)
    """One plain sentence for the player: what it is and what it is good against."""
    beats: tuple[Identifier, ...] = ()
    """Formations this one beats: its side has the edge against them."""
    loses_to: tuple[Identifier, ...] = ()
    """Formations that beat this one (for the player's picker; checked against ``beats``)."""
    duel: tuple[Identifier, ...] = ()
    """Formations it meets as an equal: the better general (higher skill) has the edge."""
    edge_bp: Rate = 2000
    """Extra fighting power in the clash when it beats the enemy's formation."""
    power_bp: int = Field(default=0, ge=-5000, le=5000)
    """Extra (or less) fighting power in the first clash."""
    reserve_bp: int = Field(default=0, ge=0, le=5000)
    """Extra power when a held-back reserve commits in the clash (if the line has not broken)."""
    natural_bp: int = Field(default=0, ge=0, le=5000)
    """How readily a general reaches for it when he knows nothing of the enemy."""
    needs_ratio_bp: int = Field(default=0, ge=0, le=100_000)
    """It needs at least this many men for every 10,000 of the enemy's (12_000 = 1.2 to 1) ..."""
    thin_bp: int = Field(default=0, ge=0, le=5000)
    """... and without them the line is thin: this much less power, and no edge."""
