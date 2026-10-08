"""Load content packs from YAML, validate them and report every problem at once."""

from __future__ import annotations

import hashlib
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml
from pydantic import ValidationError

from anachronism.content.checks import cross_reference_issues
from anachronism.content.issues import ContentError, ContentIssue
from anachronism.content.registry import Registry
from anachronism.content.schema import (
    CONTENT_KINDS,
    CURRENT_SCHEMA_VERSION,
    LIST_KINDS,
    SINGLE_KINDS,
    AlmanacEntry,
    Building,
    Chapter,
    CivDefinition,
    Dialogue,
    Dilemma,
    EffectType,
    Era,
    Formation,
    Happening,
    MapResource,
    PackManifest,
    ProvinceGeography,
    Rules,
    Scenario,
    SeaZone,
    Ship,
    Speaker,
    Symbol,
    Tactic,
    Tale,
    TechNode,
    Terrain,
    Unit,
)

PACKS_DIR = Path(__file__).parent / "packs"
MANIFEST = "pack.yaml"


@dataclass(frozen=True)
class Content:
    """Everything loaded from a set of packs, validated and cross-checked."""

    packs: tuple[PackManifest, ...]
    rules: Rules
    eras: tuple[Era, ...]
    effect_caps: Mapping[EffectType, Mapping[str, int]]
    terrain: Mapping[str, Terrain]
    resources: Mapping[str, MapResource]
    techs: Mapping[str, TechNode]
    provinces: Mapping[str, ProvinceGeography]
    seas: Mapping[str, SeaZone]
    civs: Mapping[str, CivDefinition]
    scenarios: Mapping[str, Scenario]
    speakers: Mapping[str, Speaker]
    dialogue: Mapping[str, Dialogue]
    digest: str
    """SHA-256 of every loaded file, recorded in saves to identify the content version."""
    happenings: Mapping[str, Happening] = field(default_factory=dict)
    units: Mapping[str, Unit] = field(default_factory=dict)
    tales: Mapping[str, Tale] = field(default_factory=dict)
    dilemmas: Mapping[str, Dilemma] = field(default_factory=dict)
    ships: Mapping[str, Ship] = field(default_factory=dict)
    buildings: Mapping[str, Building] = field(default_factory=dict)
    chapters: Mapping[str, Chapter] = field(default_factory=dict)
    almanac: Mapping[str, AlmanacEntry] = field(default_factory=dict)
    tactics: Mapping[str, Tactic] = field(default_factory=dict)
    formations: Mapping[str, Formation] = field(default_factory=dict)
    symbols: Mapping[str, Symbol] = field(default_factory=dict)
    """Chance events (plague, flood, bumper harvests...)."""


@dataclass(frozen=True)
class ParsedFile:
    """A file's validated content: a single value, or the valid items of a list kind."""

    kind: str
    value: Any
    invalid_ids: tuple[str, ...] = ()


class _UniqueKeyLoader(yaml.SafeLoader):
    """A YAML loader that rejects duplicate keys instead of silently keeping the last one."""


def _construct_unique_mapping(loader: _UniqueKeyLoader, node: yaml.MappingNode) -> dict[Any, Any]:
    seen: set[Any] = set()
    for key_node, _ in node.value:
        key = loader.construct_object(key_node, deep=True)
        if key in seen:
            raise yaml.constructor.ConstructorError(
                None, None, f"duplicate key {key!r}", key_node.start_mark
            )
        seen.add(key)
    return loader.construct_mapping(node, deep=True)


_UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping
)


def load_content(pack_ids: Sequence[str] | None = None, root: Path = PACKS_DIR) -> Content:
    """Load packs (with their dependencies), or every pack under ``root`` if none are named.

    Raises:
        ContentError: listing every problem found, with file and location.
    """
    issues: list[ContentIssue] = []
    manifests = _discover_packs(root, issues)
    order = _resolve_order(manifests, pack_ids, issues)
    registry = Registry()
    digest = hashlib.sha256()
    for pack_id in order:
        pack_dir = root / pack_id
        registry.packs.append(manifests[pack_id])
        for path in sorted(pack_dir.rglob("*.yaml")):
            relative = path.relative_to(root).as_posix()
            data = path.read_bytes()
            digest.update(relative.encode() + b"\0" + data + b"\0")
            if path.name == MANIFEST and path.parent == pack_dir:
                continue
            parsed = _parse_file(relative, data, issues)
            if parsed is not None:
                _register(parsed, relative, registry, issues)
    issues.extend(_missing_singletons(registry))
    issues.extend(cross_reference_issues(registry))
    if issues:
        raise ContentError(issues)
    assert registry.rules is not None
    assert registry.eras is not None
    assert registry.effect_caps is not None
    return Content(
        packs=tuple(registry.packs),
        rules=registry.rules,
        eras=registry.eras,
        effect_caps=registry.effect_caps,
        terrain=registry.terrain,
        resources=registry.resources,
        techs=registry.techs,
        provinces=registry.provinces,
        seas=registry.seas,
        civs=registry.civs,
        scenarios=registry.scenarios,
        speakers=registry.speakers,
        dialogue=registry.dialogue,
        happenings=registry.happenings,
        units=registry.units,
        tales=registry.tales,
        dilemmas=registry.dilemmas,
        ships=registry.ships,
        buildings=registry.buildings,
        chapters=registry.chapters,
        almanac=registry.almanac,
        tactics=registry.tactics,
        formations=registry.formations,
        symbols=registry.symbols,
        digest=digest.hexdigest(),
    )


def _discover_packs(root: Path, issues: list[ContentIssue]) -> dict[str, PackManifest]:
    manifests: dict[str, PackManifest] = {}
    if not root.is_dir():
        issues.append(ContentIssue(str(root), "", "packs folder not found"))
        return manifests
    for manifest_path in sorted(root.glob(f"*/{MANIFEST}")):
        relative = manifest_path.relative_to(root).as_posix()
        parsed = _parse_file(relative, manifest_path.read_bytes(), issues)
        if parsed is None:
            continue
        if parsed.kind != "pack":
            issues.append(ContentIssue(relative, "", "pack.yaml must contain a 'pack' section"))
            continue
        manifest: PackManifest = parsed.value
        folder = manifest_path.parent.name
        if manifest.id != folder:
            issues.append(
                ContentIssue(relative, "pack.id", f"id {manifest.id!r} must match its folder")
            )
            continue
        manifests[folder] = manifest
    return manifests


def _resolve_order(
    manifests: Mapping[str, PackManifest],
    requested: Sequence[str] | None,
    issues: list[ContentIssue],
) -> list[str]:
    """Return pack ids with every dependency before the packs that need it."""
    order: list[str] = []
    visiting: set[str] = set()

    def visit(pack_id: str, needed_by: str | None) -> None:
        if pack_id in order:
            return
        if pack_id not in manifests:
            where = f"{needed_by}/{MANIFEST}" if needed_by else "(request)"
            issues.append(ContentIssue(where, "pack.depends_on", f"unknown pack {pack_id!r}"))
            return
        if pack_id in visiting:
            issues.append(ContentIssue(f"{pack_id}/{MANIFEST}", "", "circular pack dependency"))
            return
        visiting.add(pack_id)
        for dependency in manifests[pack_id].depends_on:
            visit(dependency, pack_id)
        visiting.discard(pack_id)
        order.append(pack_id)

    for pack_id in requested if requested is not None else sorted(manifests):
        visit(pack_id, None)
    return order


def _parse_file(relative: str, data: bytes, issues: list[ContentIssue]) -> ParsedFile | None:
    """Parse and validate one file.

    List items are validated one by one, so a broken item is reported without hiding its
    valid siblings.
    """
    try:
        raw = yaml.load(data, Loader=_UniqueKeyLoader)
    except yaml.YAMLError as error:
        issues.append(ContentIssue(relative, "", f"invalid YAML: {error}"))
        return None
    if not isinstance(raw, dict):
        issues.append(ContentIssue(relative, "", "file must be a mapping of keys to values"))
        return None
    version = raw.get("schema_version")
    if version != CURRENT_SCHEMA_VERSION:
        issues.append(
            ContentIssue(
                relative,
                "schema_version",
                f"expected schema_version {CURRENT_SCHEMA_VERSION}, found {version!r}",
            )
        )
        return None
    kinds = [key for key in raw if key != "schema_version"]
    if len(kinds) != 1 or kinds[0] not in CONTENT_KINDS:
        issues.append(
            ContentIssue(
                relative, "", f"expected exactly one of {', '.join(CONTENT_KINDS)}; found {kinds}"
            )
        )
        return None
    kind = kinds[0]
    body = raw[kind]
    if kind in SINGLE_KINDS:
        try:
            return ParsedFile(kind, SINGLE_KINDS[kind].validate_python(body))
        except ValidationError as error:
            _report(relative, kind, body, error, issues)
            return None
    if not isinstance(body, list):
        issues.append(ContentIssue(relative, kind, "must be a list of items"))
        return None
    valid: list[Any] = []
    invalid_ids: list[str] = []
    for index, item in enumerate(body):
        label = f"{kind}[{index}]"
        if isinstance(item, dict) and isinstance(item.get("id"), str):
            label += f" ({item['id']})"
        try:
            valid.append(LIST_KINDS[kind].model_validate(item))
        except ValidationError as error:
            _report(relative, label, item, error, issues)
            if isinstance(item, dict) and isinstance(item.get("id"), str):
                invalid_ids.append(item["id"])
    return ParsedFile(kind, tuple(valid), tuple(invalid_ids))


def _report(
    relative: str, prefix: str, raw: Any, error: ValidationError, issues: list[ContentIssue]
) -> None:
    for detail in error.errors():
        location = prefix + _describe_location(detail["loc"], raw)
        issues.append(ContentIssue(relative, location, detail["msg"]))


def _describe_location(loc: tuple[int | str, ...], raw: Any) -> str:
    """Turn a pydantic error location into e.g. ``.effects[0].bp``, naming nested ids."""
    parts: list[str] = []
    node = raw
    for step in loc:
        if isinstance(step, int):
            label = f"[{step}]"
            if isinstance(node, list) and 0 <= step < len(node):
                node = node[step]
                if isinstance(node, dict) and isinstance(node.get("id"), str):
                    label += f" ({node['id']})"
            else:
                node = None
            parts.append(label)
        else:
            parts.append(f".{step}")
            node = node.get(step) if isinstance(node, dict) else None
    return "".join(parts)


def _register(
    parsed: ParsedFile, relative: str, registry: Registry, issues: list[ContentIssue]
) -> None:
    kind = parsed.kind
    if kind == "pack":
        issues.append(ContentIssue(relative, "pack", "only pack.yaml may contain a 'pack' section"))
        return
    if kind in SINGLE_KINDS:
        if getattr(registry, kind) is not None:
            first = registry.origin(kind, kind)
            issues.append(ContentIssue(relative, kind, f"{kind} is already defined in {first}"))
            return
        value = dict(parsed.value) if kind == "effect_caps" else parsed.value
        setattr(registry, kind, value)
        registry.origins[(kind, kind)] = relative
        return
    registry.invalid.setdefault(kind, set()).update(parsed.invalid_ids)
    target: dict[str, Any] = getattr(registry, kind)
    for item in parsed.value:
        if item.id in target:
            first = registry.origin(kind, item.id)
            issues.append(
                ContentIssue(relative, f"{kind} ({item.id})", f"duplicate id, first in {first}")
            )
            continue
        target[item.id] = item
        registry.origins[(kind, item.id)] = relative


def _missing_singletons(registry: Registry) -> list[ContentIssue]:
    return [
        ContentIssue("(all packs)", kind, f"no pack defines {kind}")
        for kind in ("rules", "eras", "effect_caps")
        if getattr(registry, kind) is None
    ]
