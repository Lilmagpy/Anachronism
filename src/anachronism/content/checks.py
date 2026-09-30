"""Cross-reference checks across all loaded content (run after each file validated alone)."""

from __future__ import annotations

from itertools import pairwise

from anachronism.content.issues import ContentIssue
from anachronism.content.registry import Registry
from anachronism.content.schema import NUMERIC_EFFECTS, EffectType, Stage


def cross_reference_issues(registry: Registry) -> list[ContentIssue]:
    """Return every broken reference or inconsistency between content files."""
    return [
        *_era_issues(registry),
        *_effect_cap_issues(registry),
        *_tech_issues(registry),
        *_province_issues(registry),
        *_scenario_issues(registry),
    ]


def _era_issues(registry: Registry) -> list[ContentIssue]:
    if registry.eras is None:
        return []
    issues: list[ContentIssue] = []
    where = registry.origin("eras", "eras")
    ids = [era.id for era in registry.eras]
    if len(ids) != len(set(ids)):
        issues.append(ContentIssue(where, "eras", "era ids must be unique"))
    ends = [era.ends for era in registry.eras]
    if not ends or ends[-1] is not None:
        issues.append(ContentIssue(where, "eras", "the last era must have 'ends: null'"))
    bounded = [end for end in ends[:-1] if end is not None]
    if len(bounded) != len(ends[:-1]):
        issues.append(ContentIssue(where, "eras", "only the last era may have 'ends: null'"))
    elif any(later <= earlier for earlier, later in pairwise(bounded)):
        issues.append(ContentIssue(where, "eras", "era end years must strictly increase"))
    return issues


def _effect_cap_issues(registry: Registry) -> list[ContentIssue]:
    caps = registry.effect_caps
    if caps is None or registry.eras is None:
        return []
    issues: list[ContentIssue] = []
    where = registry.origin("effect_caps", "effect_caps")
    era_ids = {era.id for era in registry.eras}
    for effect in NUMERIC_EFFECTS:
        if effect not in caps:
            issues.append(ContentIssue(where, "effect_caps", f"missing caps for {effect}"))
    for effect, per_era in caps.items():
        if effect.is_unlock:
            issues.append(ContentIssue(where, f"effect_caps.{effect}", "unlocks have no caps"))
            continue
        if set(per_era) != era_ids:
            issues.append(
                ContentIssue(where, f"effect_caps.{effect}", f"needs exactly the eras {era_ids}")
            )
        if any(value <= 0 for value in per_era.values()):
            issues.append(ContentIssue(where, f"effect_caps.{effect}", "caps must be positive"))
    return issues


def _tech_issues(registry: Registry) -> list[ContentIssue]:
    issues: list[ContentIssue] = []
    techs = registry.techs
    for node in techs.values():
        where = registry.origin("techs", node.id)
        label = f"techs ({node.id})"
        for prerequisite in node.prerequisites:
            if registry.is_unknown("techs", prerequisite):
                issues.append(ContentIssue(where, label, f"unknown prerequisite {prerequisite!r}"))
        for infrastructure in node.requires.widespread:
            if registry.is_unknown("techs", infrastructure):
                issues.append(ContentIssue(where, label, f"unknown widespread {infrastructure!r}"))
        for material in node.requires.materials:
            if registry.is_unknown("resources", material):
                issues.append(ContentIssue(where, label, f"unknown material {material!r}"))
        for effect in node.effects:
            if effect.type is EffectType.UNLOCKS_RESOURCE and registry.is_unknown(
                "resources", effect.target
            ):
                issues.append(ContentIssue(where, label, f"unknown resource {effect.target!r}"))
    cycle = _find_prerequisite_cycle(registry)
    if cycle:
        where = registry.origin("techs", cycle[0])
        issues.append(ContentIssue(where, "techs", "prerequisite cycle: " + " -> ".join(cycle)))
    return issues


def _find_prerequisite_cycle(registry: Registry) -> list[str]:
    """Return one prerequisite cycle as a path (first id repeated at the end), or []."""
    done: set[str] = set()
    path: list[str] = []
    on_path: set[str] = set()

    def visit(node_id: str) -> list[str]:
        if node_id in on_path:
            return [*path[path.index(node_id) :], node_id]
        if node_id in done or node_id not in registry.techs:
            return []
        path.append(node_id)
        on_path.add(node_id)
        for prerequisite in sorted(registry.techs[node_id].prerequisites):
            cycle = visit(prerequisite)
            if cycle:
                return cycle
        path.pop()
        on_path.discard(node_id)
        done.add(node_id)
        return []

    for node_id in sorted(registry.techs):
        cycle = visit(node_id)
        if cycle:
            return cycle
    return []


def _province_issues(registry: Registry) -> list[ContentIssue]:
    issues: list[ContentIssue] = []
    provinces = registry.provinces
    for province in provinces.values():
        where = registry.origin("provinces", province.id)
        label = f"provinces ({province.id})"
        if registry.is_unknown("terrain", province.terrain):
            issues.append(ContentIssue(where, label, f"unknown terrain {province.terrain!r}"))
        for resource in province.resources:
            if registry.is_unknown("resources", resource):
                issues.append(ContentIssue(where, label, f"unknown resource {resource!r}"))
        for neighbour in province.neighbours:
            other = provinces.get(neighbour)
            if other is None:
                if registry.is_unknown("provinces", neighbour):
                    issues.append(ContentIssue(where, label, f"unknown neighbour {neighbour!r}"))
            elif province.id not in other.neighbours:
                issues.append(
                    ContentIssue(where, label, f"{neighbour!r} does not list it as a neighbour")
                )
    return issues


def _scenario_issues(registry: Registry) -> list[ContentIssue]:
    issues: list[ContentIssue] = []
    for scenario in registry.scenarios.values():
        where = registry.origin("scenarios", scenario.id)
        label = f"scenarios ({scenario.id})"

        def report(message: str, where: str = where, label: str = label) -> None:
            issues.append(ContentIssue(where, label, message))

        if scenario.player_civ not in scenario.civs:
            report(f"player civ {scenario.player_civ!r} is not in the scenario")
        claimed: dict[str, str] = {}
        for province in scenario.unowned:
            claimed[province] = "unowned"
        for civ_id, start in scenario.civs.items():
            if registry.is_unknown("civs", civ_id):
                report(f"unknown civ {civ_id!r}")
            if start.capital not in start.provinces:
                report(f"{civ_id}: capital {start.capital!r} is not one of its provinces")
            for province in start.provinces:
                if province in claimed:
                    report(f"province {province!r} is held by {claimed[province]} and {civ_id}")
                claimed[province] = civ_id
            for tech_id, stage in start.techs.items():
                node = registry.techs.get(tech_id)
                if node is None:
                    if registry.is_unknown("techs", tech_id):
                        report(f"{civ_id}: unknown tech {tech_id!r}")
                    continue
                if node.stub:
                    report(f"{civ_id}: {tech_id!r} is a stub and cannot be a starting tech")
                if stage.is_adopted:
                    for prerequisite in node.prerequisites:
                        known = start.techs.get(prerequisite)
                        if known is None or not known.is_adopted:
                            report(
                                f"{civ_id}: {tech_id!r} is {stage} but its prerequisite "
                                f"{prerequisite!r} is not adopted"
                            )
                if stage is Stage.EXPERIMENTING:
                    report(f"{civ_id}: {tech_id!r} cannot start mid-experiment")
        for province in claimed:
            if registry.is_unknown("provinces", province):
                report(f"unknown province {province!r}")
            elif province in registry.provinces and registry.provinces[province].position is None:
                report(f"province {province!r} has no map position")
    return issues
