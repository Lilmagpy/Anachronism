"""Things that happen to a state by chance: plague, flood, a bumper harvest (DESIGN §12).

Each happening has a chance per decade, a place it can strike (terrain, river, coast), what
it does, and what softens it (an effect such as ``health``). Numbers are bounded here and
again by the engine. Content, not code: new happenings need no code changes.
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier, Rate
from anachronism.content.schema.tech import EffectType

Swing = Annotated[int, Field(ge=-5000, le=5000)]
"""A change of up to 50% either way, in basis points."""


class Happening(Frozen):
    """One kind of chance event."""

    id: Identifier
    name: Annotated[str, Field(min_length=1, max_length=60)]
    kind: Literal["disaster", "blessing"]
    message: Annotated[str, Field(min_length=1, max_length=200)]
    """Shown in the chronicle; ``{civ}`` and ``{province}`` are filled in."""
    chance_bp: Rate
    """Chance per decade that it strikes a given state."""
    terrain: tuple[Identifier, ...] = ()
    """Terrain it can strike (empty: any)."""
    river: bool = False
    """Only provinces on a river."""
    coastal: bool = False
    """Only coastal provinces."""
    needs_adopted: tuple[Identifier, ...] = ()
    """Advancements the state must use for it to happen (a silver strike needs prospecting)."""
    population_bp: Swing = 0
    """Change to the struck province's people."""
    food_bp: Swing = 0
    """Change to the stores (all four are shares of what is stored)."""
    materials_bp: Swing = 0
    wealth_bp: Swing = 0
    knowledge_bp: Swing = 0
    unrest_bp: Swing = 0
    """Flat change to unrest (points x100)."""
    legitimacy_bp: Swing = 0
    softened_by: EffectType | None = None
    """An effect that reduces the harm, e.g. ``health`` for plague (by its percentage)."""
