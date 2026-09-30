"""Every tunable number the engine uses. Values live in ``packs/core/rules.yaml``.

Flows are per decade (``reference_years``) and scaled to the scenario's turn length.
All rates are basis points: 10_000 bp = 100%.
"""

from __future__ import annotations

from anachronism.content.schema.base import Frozen, NonNegative, Positive, Rate
from anachronism.content.schema.tech import Category

PerComplexity = tuple[NonNegative, NonNegative, NonNegative, NonNegative, NonNegative]
"""One value for each complexity level, 1 to 5."""


class EconomyRules(Frozen):
    """Production, upkeep and storage."""

    workforce_per_1000_bp: Positive
    """Labour units per 1,000 people (10_000 = 1 unit)."""
    surplus_share_bp: Rate
    """Share of the workforce that projects can use without hurting production."""
    diversion_floor_bp: Rate
    """Production never falls below this share because labour was diverted to projects."""
    food_consumption_per_1000_bp: Positive
    granary_per_1000_bp: Positive
    """Food storage capacity per 1,000 people."""
    spoilage_bp: Rate
    """Share of food above half the granary capacity that rots each decade."""
    wealth_per_1000_bp: NonNegative
    admin_upkeep_per_province: NonNegative
    """Wealth spent per owned province per decade."""
    knowledge_per_1000_literate_bp: NonNegative
    base_trade_bp: NonNegative
    """Trade income of any province, as a share of its taxes."""
    coastal_trade_bp: NonNegative
    """Extra trade share for a coastal province."""
    river_trade_bp: NonNegative
    resource_materials_accessible: NonNegative
    """Flat materials per decade from each accessible map resource in a province."""
    resource_materials_limited: NonNegative


class ProjectRules(Frozen):
    """Costs, duration and luck of experimentation projects."""

    labour: PerComplexity
    materials: PerComplexity
    knowledge: PerComplexity
    wealth: PerComplexity
    heavy_categories: tuple[Category, ...]
    """Categories that need extra materials."""
    heavy_materials_bp: Positive
    duration_decades: PerComplexity
    anachronism_bp_per_century: NonNegative
    """Extra cost for each century an advancement is ahead of its historical time."""
    anachronism_cap_bp: NonNegative
    setback_chance_bp: Rate
    setback_per_literacy_point_bp: NonNegative
    """Extra setback chance for each literacy point (100 bp) below the requirement."""
    setback_loss_bp: Rate
    """Progress lost in a setback, as a share of the whole project."""
    breakthrough_chance_bp: Rate
    breakthrough_gain_bp: Rate
    stall_funding_bp: Rate
    """Funding below this counts as a stalled turn."""
    stall_turns: Positive
    """Stalled turns in a row before progress starts to decay."""
    decay_bp: Rate
    """Progress lost per decade while decaying or paused."""
    initial_spread_bp: Rate
    """Spread when an advancement is first adopted (the capital region)."""


class SpreadRules(Frozen):
    """How adopted advancements spread through the civilisation."""

    base_bp: Rate
    """Spread gained per decade."""
    literacy_bonus_bp: NonNegative
    """Extra spread per decade at 100% literacy (scaled by actual literacy)."""
    widespread_at_bp: Rate
    baseline_adopted_bp: Rate
    """Spread given to advancements a scenario lists as adopted (widespread ones get 100%)."""


class SocietyRules(Frozen):
    """Strain, unrest, legitimacy, riots and revolts."""

    strain_from_shortfall_bp: NonNegative
    """Strain target added per unit of project or wealth shortfall."""
    strain_from_diversion_bp: NonNegative
    """Strain target added per unit of labour diverted from production."""
    strain_response_bp: Rate
    """Share of the gap between strain and its target closed each decade."""
    unrest_from_strain_bp: NonNegative
    unrest_from_famine_bp: NonNegative
    """Unrest added at a total famine (all food missing), scaled by the shortfall."""
    unrest_recovery_bp: Rate
    """Share of unrest that fades each decade."""
    unrest_recovery_legitimacy_bp: NonNegative
    """Extra unrest removed per decade at 100% legitimacy."""
    labour_penalty_at_full_unrest_bp: Rate
    resistance_unrest_bp: NonNegative
    """Unrest per decade per resistance level from a group with 100% influence."""
    legitimacy_baseline_bp: Rate
    legitimacy_drift_bp: Rate
    """Share of the gap to the baseline closed each decade."""
    famine_legitimacy_bp: NonNegative
    riot_threshold_bp: Rate
    riot_chance_per_excess_bp: NonNegative
    """Riot chance = (unrest above the threshold) * this / 10_000."""
    riot_loss_bp: Rate
    riot_legitimacy_bp: NonNegative
    revolt_threshold_bp: Rate
    revolt_chance_per_excess_bp: NonNegative
    revolt_unrest_release_bp: Rate
    revolt_legitimacy_bp: NonNegative
    collapse_share_bp: Rate
    """Losing this share of the starting provinces counts as collapse."""


class PopulationRules(Frozen):
    """Growth and starvation."""

    growth_bp: Rate
    """Growth per decade when a province is nearly empty (logistic toward capacity)."""
    deaths_per_missing_food: NonNegative
    """People who die for each unit of food missing."""
    overcrowding_loss_bp: Rate
    """Share of the population above capacity lost each decade."""


class SuspicionRules(Frozen):
    """How unexplained progress is noticed (DESIGN §7)."""

    gain_per_year_ahead_bp: NonNegative
    max_gain_bp: Rate
    visibility_bp: tuple[int, int, int]
    """Multiplier for visibility 1, 2 and 3."""
    decay_bp: Rate
    legitimacy_decay_bp: NonNegative
    """Extra suspicion removed per decade at 100% legitimacy."""
    framing_threshold_bp: Rate
    framing_clear_bp: Rate
    witchcraft_unrest_bp: NonNegative
    fraud_legitimacy_bp: NonNegative
    inspired_legitimacy_bp: NonNegative


class Rules(Frozen):
    """All engine rules, grouped by system."""

    reference_years: Positive
    stacking_decay_bp: Rate
    """Each further effect of the same type counts this much of the previous one."""
    economy: EconomyRules
    projects: ProjectRules
    spread: SpreadRules
    society: SocietyRules
    population: PopulationRules
    suspicion: SuspicionRules
