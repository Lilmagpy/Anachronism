"""Pydantic models for content packs. Unknown fields are errors, so typos are caught."""

from anachronism.content.schema.base import (
    CURRENT_SCHEMA_VERSION,
    Confidence,
    Frozen,
    Identifier,
    Rate,
)
from anachronism.content.schema.civ import CivDefinition
from anachronism.content.schema.dialogue import MOMENTS, SPECIAL_SPEAKERS, Dialogue, Speaker
from anachronism.content.schema.dilemmas import Choice, Dilemma
from anachronism.content.schema.happenings import Happening
from anachronism.content.schema.pack import CONTENT_KINDS, LIST_KINDS, SINGLE_KINDS, PackManifest
from anachronism.content.schema.rivals import (
    Disposition,
    Faith,
    Preconditions,
    RelationStatus,
    Script,
    ScriptGoal,
    StartingRelation,
)
from anachronism.content.schema.rules import Rules
from anachronism.content.schema.scenario import (
    General,
    GeneralTrait,
    Scenario,
    ScenarioCiv,
    StartingStats,
    StartingStockpiles,
    Successor,
)
from anachronism.content.schema.ships import Ship
from anachronism.content.schema.tales import Tale
from anachronism.content.schema.tech import (
    NUMERIC_EFFECTS,
    Category,
    Effect,
    EffectType,
    Provenance,
    Requirements,
    Resistance,
    SocialGroup,
    Stage,
    TechNode,
)
from anachronism.content.schema.units import Unit, UnitKind
from anachronism.content.schema.world import (
    Access,
    Era,
    MapResource,
    ProvinceGeography,
    SeaZone,
    Terrain,
)

__all__ = [
    "CONTENT_KINDS",
    "CURRENT_SCHEMA_VERSION",
    "LIST_KINDS",
    "MOMENTS",
    "NUMERIC_EFFECTS",
    "SINGLE_KINDS",
    "SPECIAL_SPEAKERS",
    "Access",
    "Category",
    "Choice",
    "CivDefinition",
    "Confidence",
    "Dialogue",
    "Dilemma",
    "Disposition",
    "Effect",
    "EffectType",
    "Era",
    "Faith",
    "Frozen",
    "General",
    "GeneralTrait",
    "Happening",
    "Identifier",
    "MapResource",
    "PackManifest",
    "Preconditions",
    "Provenance",
    "ProvinceGeography",
    "Rate",
    "RelationStatus",
    "Requirements",
    "Resistance",
    "Rules",
    "Scenario",
    "ScenarioCiv",
    "Script",
    "ScriptGoal",
    "SeaZone",
    "Ship",
    "SocialGroup",
    "Speaker",
    "Stage",
    "StartingRelation",
    "StartingStats",
    "StartingStockpiles",
    "Successor",
    "Tale",
    "TechNode",
    "Terrain",
    "Unit",
    "UnitKind",
]
