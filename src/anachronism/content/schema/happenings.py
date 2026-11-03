"""Things that happen to a state by chance: plague, flood, a bumper harvest (DESIGN §12).

Each happening has a chance per decade, a place it can strike (terrain, river, coast), what
it does, and what softens it (an effect such as ``health``). Numbers are bounded here and
again by the engine. Content, not code: new happenings need no code changes.
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import Field, model_validator

from anachronism.content.schema.base import Frozen, Identifier, Rate
from anachronism.content.schema.tech import EffectType, SocialGroup

Swing = Annotated[int, Field(ge=-5000, le=5000)]
"""A change of up to 50% either way, in basis points."""


class Happening(Frozen):
    """One kind of chance event."""

    id: Identifier
    name: Annotated[str, Field(min_length=1, max_length=60)]
    kind: Literal["disaster", "blessing", "consequence"]
    """A consequence is a second-order effect of an advancement (brief §6.7): it needs one."""
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
    suspicion_bp: Swing = 0
    """Flat change to suspicion (points x100)."""
    influence: dict[SocialGroup, Swing] = Field(default_factory=dict)
    """Change to each social group's influence (points x100): printing weakens the clergy."""
    softened_by: EffectType | None = None
    """An effect that reduces the harm, e.g. ``health`` for plague (by its percentage)."""

    @model_validator(mode="after")
    def _consequence_needs_a_cause(self) -> Happening:
        if self.kind == "consequence" and not self.needs_adopted:
            raise ValueError("a consequence needs the advancement it follows (needs_adopted)")
        return self
