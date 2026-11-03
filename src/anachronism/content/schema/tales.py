"""How battles are told (D-103): short accounts chosen by the deciding soldiers and ground.

The engine picks the most fitting tale for a battle - the kind of soldier that won it, the
terrain, whether it was a rout - and fills in the names. Content, not code: a new way to
tell a battle is a YAML entry.
"""

from __future__ import annotations

from typing import Annotated

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier
from anachronism.content.schema.units import UnitKind


class Tale(Frozen):
    """One way of telling a battle."""

    id: Identifier
    sea: bool = False
    """A sea battle's tale (D-107): ``{unit}`` is then the winners' ships."""
    ships: tuple[Identifier, ...] = ()
    """For sea battles: the kind of warship that won it (empty: any)."""
    civs: tuple[Identifier, ...] = ()
    """Only when one of these states wins (empty: anyone) - Greek fire, the legions."""
    tactic: Identifier | None = None
    """Only when the winners fought with this battle plan (D-108)."""
    kind: UnitKind | None = None
    """The kind of soldier that won it (empty: any)."""
    terrain: tuple[Identifier, ...] = ()
    """The ground it was fought on (empty: any)."""
    rout: bool | None = None
    """Only for a rout (true), only for a hard fight (false), or either (empty)."""
    lines: tuple[Annotated[str, Field(min_length=1, max_length=300)], ...] = Field(min_length=1)
    """Placeholders: {place} {winner} {loser} (adjectives), {unit} (the winners' soldiers or
    ships)."""
