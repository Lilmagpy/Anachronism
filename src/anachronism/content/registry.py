"""Content gathered from pack files, before cross-checking."""

from __future__ import annotations

from dataclasses import dataclass, field

from anachronism.content.schema import (
    CivDefinition,
    Dialogue,
    Dilemma,
    EffectType,
    Era,
    Happening,
    MapResource,
    PackManifest,
    ProvinceGeography,
    Rules,
    Scenario,
    SeaZone,
    Ship,
    Speaker,
    Tale,
    TechNode,
    Terrain,
    Unit,
)


@dataclass
class Registry:
    """Everything read so far. ``origins`` maps (kind, id) to the file that defined it."""

    packs: list[PackManifest] = field(default_factory=list)
    rules: Rules | None = None
    eras: tuple[Era, ...] | None = None
    effect_caps: dict[EffectType, dict[str, int]] | None = None
    terrain: dict[str, Terrain] = field(default_factory=dict)
    resources: dict[str, MapResource] = field(default_factory=dict)
    techs: dict[str, TechNode] = field(default_factory=dict)
    provinces: dict[str, ProvinceGeography] = field(default_factory=dict)
    seas: dict[str, SeaZone] = field(default_factory=dict)
    civs: dict[str, CivDefinition] = field(default_factory=dict)
    scenarios: dict[str, Scenario] = field(default_factory=dict)
    speakers: dict[str, Speaker] = field(default_factory=dict)
    dialogue: dict[str, Dialogue] = field(default_factory=dict)
    happenings: dict[str, Happening] = field(default_factory=dict)
    units: dict[str, Unit] = field(default_factory=dict)
    tales: dict[str, Tale] = field(default_factory=dict)
    dilemmas: dict[str, Dilemma] = field(default_factory=dict)
    ships: dict[str, Ship] = field(default_factory=dict)
    origins: dict[tuple[str, str], str] = field(default_factory=dict)
    invalid: dict[str, set[str]] = field(default_factory=dict)
    """Ids of items that exist but failed validation (already reported), per kind."""

    def is_unknown(self, kind: str, item_id: str | None) -> bool:
        """True if nothing with this id exists, not even an item that failed validation."""
        items: dict[str, object] = getattr(self, kind)
        return item_id not in items and item_id not in self.invalid.get(kind, set())

    def origin(self, kind: str, item_id: str) -> str:
        """Return the file that defined an item, or ``(unknown)``."""
        return self.origins.get((kind, item_id), "(unknown)")
