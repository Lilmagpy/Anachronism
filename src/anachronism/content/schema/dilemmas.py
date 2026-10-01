"""Dilemmas: moments when the court asks the ruler to choose (D-104).

A dilemma appears when its conditions hold (years, scenario, state, war, unrest, what is
known...), with a chance per decade. It offers two or three options, each with its
consequences: stores gained or spent, unrest, legitimacy and suspicion, the favour of
clergy, nobles and guilds, a new idea planted in the court's mind, or men who volunteer.
Content, not code: history's choices are YAML entries.
"""

from __future__ import annotations

from typing import Annotated

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier, Rate
from anachronism.content.schema.tech import SocialGroup

Swing = Annotated[int, Field(ge=-5000, le=5000)]
Text = Annotated[str, Field(min_length=1, max_length=400)]


class Choice(Frozen):
    """One way to answer a dilemma, and what follows."""

    label: Annotated[str, Field(min_length=1, max_length=60)]
    outcome: Text
    """What happens, told to the player once chosen."""
    food_bp: Swing = 0
    """Change to the stores, as shares of what is stored (bp)."""
    materials_bp: Swing = 0
    wealth_bp: Swing = 0
    knowledge_bp: Swing = 0
    unrest_bp: Swing = 0
    """Flat changes to the state's standing (points x100)."""
    legitimacy_bp: Swing = 0
    suspicion_bp: Swing = 0
    influence: dict[SocialGroup, Swing] = Field(default_factory=dict)
    idea: Identifier | None = None
    """An advancement the court now knows of (as an idea to pursue)."""
    volunteers_bp: Annotated[int, Field(ge=0, le=300)] = 0
    """Men who take up arms unbidden, as a share of the people (bp): a new army at the capital."""


class Dilemma(Frozen):
    """A choice put to the ruler."""

    id: Identifier
    title: Annotated[str, Field(min_length=1, max_length=80)]
    text: Text
    """The situation. Placeholders: {civ} {ruler} {adjective}."""
    chance_bp: Rate = 1500
    """Chance per decade, once the conditions hold."""
    once: bool = True
    """Asked at most once a game."""
    scenarios: tuple[Identifier, ...] = ()
    """Only in these scenarios (empty: any)."""
    civs: tuple[Identifier, ...] = ()
    """Only for these states, played by the player (empty: any)."""
    after_year: int | None = None
    before_year: int | None = None
    needs_adopted: tuple[Identifier, ...] = ()
    at_war: bool | None = None
    min_unrest_bp: Rate = 0
    min_suspicion_bp: Rate = 0
    max_legitimacy_bp: Rate = 10_000
    choices: tuple[Choice, ...] = Field(min_length=2, max_length=3)
