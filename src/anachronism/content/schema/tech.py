"""Technology nodes: the advancements a civilisation can know, build and adopt."""

from __future__ import annotations

from enum import StrEnum
from typing import Annotated

from pydantic import Field, model_validator

from anachronism.content.schema.base import Confidence, Frozen, Identifier, Rate


class Category(StrEnum):
    """Broad field an advancement belongs to."""

    AGRICULTURE = "agriculture"
    METALLURGY = "metallurgy"
    CONSTRUCTION = "construction"
    CRAFT = "craft"
    KNOWLEDGE = "knowledge"
    GOVERNANCE = "governance"
    MILITARY = "military"
    TRADE = "trade"
    MARITIME = "maritime"
    HEALTH = "health"


class EffectType(StrEnum):
    """The fixed vocabulary of effects (DESIGN §9). Nothing outside it can be applied."""

    FOOD_OUTPUT = "food_output"
    LABOUR_OUTPUT = "labour_output"
    MATERIALS_OUTPUT = "materials_output"
    WEALTH_OUTPUT = "wealth_output"
    KNOWLEDGE_GAIN = "knowledge_gain"
    TRADE_INCOME = "trade_income"
    LITERACY_GROWTH = "literacy_growth"
    POPULATION_CAP = "population_cap"
    HEALTH = "health"
    MILITARY_STRENGTH = "military_strength"
    NAVAL_STRENGTH = "naval_strength"
    MOBILITY = "mobility"
    STORAGE = "storage"
    UNREST = "unrest"
    LEGITIMACY = "legitimacy"
    SUSPICION = "suspicion"
    INFORMATION_SPEED = "information_speed"
    SECRECY = "secrecy"
    CULTURAL_INFLUENCE = "cultural_influence"
    UNLOCKS_BUILDING = "unlocks_building"
    UNLOCKS_UNIT = "unlocks_unit"
    UNLOCKS_RESOURCE = "unlocks_resource"

    @property
    def is_unlock(self) -> bool:
        """True for effects that unlock something instead of changing a number."""
        return self.value.startswith("unlocks_")

    @property
    def may_be_negative(self) -> bool:
        """True for flat effects that can push a stat either way."""
        return self in (EffectType.UNREST, EffectType.LEGITIMACY)


NUMERIC_EFFECTS: tuple[EffectType, ...] = tuple(e for e in EffectType if not e.is_unlock)


class SocialGroup(StrEnum):
    """Groups whose acceptance an advancement may need."""

    CLERGY = "clergy"
    NOBILITY = "nobility"
    GUILDS = "guilds"


class Stage(StrEnum):
    """How far a civilisation has taken an advancement."""

    CONCEPT = "concept"
    EXPERIMENTING = "experimenting"
    ADOPTED = "adopted"
    WIDESPREAD = "widespread"

    @property
    def is_adopted(self) -> bool:
        """True once the advancement is in use (adopted or widespread)."""
        return self in (Stage.ADOPTED, Stage.WIDESPREAD)


class Provenance(StrEnum):
    """Where a node came from."""

    LIBRARY = "library"
    LLM = "llm"
    PLAYER_IDEA = "player_idea"


class Effect(Frozen):
    """One effect of an advancement: a magnitude in basis points, or an unlock target."""

    type: EffectType
    bp: int = 0
    target: Identifier | None = None

    @model_validator(mode="after")
    def _check_shape(self) -> Effect:
        if self.type.is_unlock:
            if self.target is None or self.bp != 0:
                raise ValueError(f"{self.type} needs a target and no bp")
        else:
            if self.target is not None:
                raise ValueError(f"{self.type} takes bp, not a target")
            if self.bp == 0:
                raise ValueError(f"{self.type} needs a non-zero bp")
            if self.bp < 0 and not self.type.may_be_negative:
                raise ValueError(f"{self.type} cannot be negative")
        return self


class Resistance(Frozen):
    """Opposition from a social group while the advancement is introduced."""

    group: SocialGroup
    level: Annotated[int, Field(ge=1, le=3)]


class Requirements(Frozen):
    """Structured conditions checked by the engine (DESIGN §6)."""

    materials: tuple[Identifier, ...] = ()
    """Map resources that must be accessible in a province the civilisation owns."""
    literacy_bp: Rate = 0
    """Soft: below this, experimentation suffers more setbacks."""
    widespread: tuple[Identifier, ...] = ()
    """Infrastructure: advancements that must already be widespread."""
    buildings: tuple[Identifier, ...] = ()
    """Infrastructure (D-114): buildings that must each stand somewhere in the realm (a
    building that replaced one, e.g. a bank for a market, counts for it)."""


class TechNode(Frozen):
    """An advancement in the tech graph."""

    id: Identifier
    name: Annotated[str, Field(min_length=1, max_length=80)]
    category: Category
    year: int
    """Approximate first historical appearance (negative = BC); drives suspicion."""
    complexity: Annotated[int, Field(ge=1, le=5)]
    visibility: Annotated[int, Field(ge=1, le=3)] = 2
    prerequisites: tuple[Identifier, ...] = ()
    requires: Requirements = Requirements()
    resistance: tuple[Resistance, ...] = ()
    effects: tuple[Effect, ...] = ()
    flavour: str = ""
    provenance: Provenance = Provenance.LIBRARY
    stub: bool = False
    """A placeholder named by a ruling; must be ruled on before it can be started."""
    sources: tuple[str, ...] = ()
    """Internal research notes; never shown to players."""
    confidence: Confidence = Confidence.LOW
    """How sure the date and effects are; internal only."""
    keywords: tuple[Annotated[str, Field(min_length=2, max_length=40)], ...] = ()
    """Words a player might use for this idea ("printing", "press"); the offline
    interpreter and the model's related-node search match on them."""

    @model_validator(mode="after")
    def _check_consistency(self) -> TechNode:
        if self.id in self.prerequisites:
            raise ValueError("a node cannot be its own prerequisite")
        types = [effect.type for effect in self.effects]
        if len(types) != len(set(types)):
            raise ValueError("each effect type may appear only once per node")
        return self
