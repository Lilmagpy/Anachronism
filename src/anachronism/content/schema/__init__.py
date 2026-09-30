"""Pydantic models for content packs. Unknown fields are errors, so typos are caught."""

from anachronism.content.schema.base import CURRENT_SCHEMA_VERSION, Frozen, Identifier, Rate
from anachronism.content.schema.civ import CivDefinition
from anachronism.content.schema.dialogue import MOMENTS, SPECIAL_SPEAKERS, Dialogue, Speaker
from anachronism.content.schema.pack import CONTENT_KINDS, LIST_KINDS, SINGLE_KINDS, PackManifest
from anachronism.content.schema.rules import Rules
from anachronism.content.schema.scenario import (
    Scenario,
    ScenarioCiv,
    StartingStats,
    StartingStockpiles,
)
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
    "CivDefinition",
    "Dialogue",
    "Effect",
    "EffectType",
    "Era",
    "Frozen",
    "Identifier",
    "MapResource",
    "PackManifest",
    "Provenance",
    "ProvinceGeography",
    "Rate",
    "Requirements",
    "Resistance",
    "Rules",
    "Scenario",
    "ScenarioCiv",
    "SeaZone",
    "SocialGroup",
    "Speaker",
    "Stage",
    "StartingStats",
    "StartingStockpiles",
    "TechNode",
    "Terrain",
]
