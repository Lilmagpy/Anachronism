"""Pack manifests and the kinds of content a pack file can hold."""

from __future__ import annotations

from typing import Any

from pydantic import TypeAdapter

from anachronism.content.schema.base import Frozen, Identifier, Positive
from anachronism.content.schema.civ import CivDefinition
from anachronism.content.schema.rules import Rules
from anachronism.content.schema.scenario import Scenario
from anachronism.content.schema.tech import EffectType, TechNode
from anachronism.content.schema.world import Era, MapResource, ProvinceGeography, Terrain


class PackManifest(Frozen):
    """``pack.yaml``: identifies a content pack and what it builds on."""

    id: Identifier
    name: str
    version: Positive
    depends_on: tuple[Identifier, ...] = ()


SINGLE_KINDS: dict[str, TypeAdapter[Any]] = {
    "pack": TypeAdapter(PackManifest),
    "rules": TypeAdapter(Rules),
    "eras": TypeAdapter(tuple[Era, ...]),
    "effect_caps": TypeAdapter(dict[EffectType, dict[Identifier, int]]),
}
"""Kinds defined once, as a whole."""

LIST_KINDS: dict[str, type[Frozen]] = {
    "terrain": Terrain,
    "resources": MapResource,
    "techs": TechNode,
    "provinces": ProvinceGeography,
    "civs": CivDefinition,
    "scenarios": Scenario,
}
"""Kinds holding a list of items with ids; each item is validated on its own."""

CONTENT_KINDS: tuple[str, ...] = (*SINGLE_KINDS, *LIST_KINDS)
