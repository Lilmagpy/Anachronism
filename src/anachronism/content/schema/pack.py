"""Pack manifests and the kinds of content a pack file can hold."""

from __future__ import annotations

from typing import Any

from pydantic import TypeAdapter

from anachronism.content.schema.base import Frozen, Identifier, Positive
from anachronism.content.schema.battles import Battle
from anachronism.content.schema.buildings import Building
from anachronism.content.schema.chapters import AlmanacEntry, Chapter
from anachronism.content.schema.civ import CivDefinition
from anachronism.content.schema.dialogue import Dialogue, Speaker
from anachronism.content.schema.dilemmas import Dilemma
from anachronism.content.schema.formations import Formation
from anachronism.content.schema.happenings import Happening
from anachronism.content.schema.monuments import CityTimeline, Monument
from anachronism.content.schema.republic import (
    FastiYear,
    Gens,
    HistoricalPerson,
    Magistracy,
    RepublicRules,
)
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
    external: tuple[str, ...] = ()
    """Glob patterns (relative to the pack folder) for dataset files outside the pack that hold
    one list kind keyed by name and no ``schema_version``: ``monuments`` (U7)."""


SINGLE_KINDS: dict[str, TypeAdapter[Any]] = {
    "pack": TypeAdapter(PackManifest),
    "rules": TypeAdapter(Rules),
    "republic_rules": TypeAdapter(RepublicRules),
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
    "chapters": Chapter,
    "almanac": AlmanacEntry,
    "tactics": Tactic,
    "formations": Formation,
    "symbols": Symbol,
    "magistracies": Magistracy,
    "gentes": Gens,
    "people": HistoricalPerson,
    "fasti": FastiYear,
    "battles": Battle,
    "monuments": Monument,
    "city_timeline": CityTimeline,
}
"""Kinds holding a list of items with ids; each item is validated on its own."""

CONTENT_KINDS: tuple[str, ...] = (*SINGLE_KINDS, *LIST_KINDS)
