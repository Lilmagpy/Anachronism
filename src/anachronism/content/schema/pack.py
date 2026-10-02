"""Pack manifests and the kinds of content a pack file can hold."""

from __future__ import annotations

from typing import Any

from pydantic import TypeAdapter

from anachronism.content.schema.base import Frozen, Identifier, Positive
from anachronism.content.schema.buildings import Building
from anachronism.content.schema.civ import CivDefinition
from anachronism.content.schema.dialogue import Dialogue, Speaker
from anachronism.content.schema.dilemmas import Dilemma
from anachronism.content.schema.happenings import Happening
from anachronism.content.schema.rules import Rules
from anachronism.content.schema.scenario import Scenario
from anachronism.content.schema.ships import Ship
from anachronism.content.schema.symbols import Symbol
from anachronism.content.schema.tactics import Tactic
from anachronism.content.schema.tales import Tale
from anachronism.content.schema.tech import EffectType, TechNode
from anachronism.content.schema.units import Unit
from anachronism.content.schema.world import (
    Era,
    MapResource,
    ProvinceGeography,
    SeaZone,
    Terrain,
)


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
    "seas": SeaZone,
    "civs": CivDefinition,
    "scenarios": Scenario,
    "speakers": Speaker,
    "dialogue": Dialogue,
    "happenings": Happening,
    "units": Unit,
    "tales": Tale,
    "dilemmas": Dilemma,
    "ships": Ship,
    "buildings": Building,
    "tactics": Tactic,
    "symbols": Symbol,
}
"""Kinds holding a list of items with ids; each item is validated on its own."""

CONTENT_KINDS: tuple[str, ...] = (*SINGLE_KINDS, *LIST_KINDS)
