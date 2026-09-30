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
    knowledge_per_1000_bp: NonNegative
    """Knowledge from everyone (crafts, lore, observation), per 1,000 people."""
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
    literacy_attrition_bp: Rate
    """Share of literacy lost each decade unless teaching replaces it (so literacy effects
    set a sustainable level rather than growing forever)."""
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
    death_chance_per_year_of_age_bp: NonNegative
    """A ruler's chance of dying each decade, per year of age above 30."""
    succession_legitimacy_bp: NonNegative
    """Legitimacy lost when a ruler dies (the new one must earn it)."""
    succession_crisis_below_bp: Rate
    """Below this legitimacy, a death brings a succession crisis (unrest)."""
    succession_crisis_unrest_bp: NonNegative
    happening_frequency_bp: NonNegative
    """Scales the chance of every happening (0 switches them off)."""
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


class RulingRules(Frozen):
    """Limits on what one ruling on a player's idea can do (DESIGN §8, D-020).

    The model (or the offline interpreter) proposes; these bounds are enforced twice, by
    ``llm/guard.py`` and again by the engine when the ruling is applied.
    """

    max_ideas_per_message: Positive
    """A message naming more ideas than this has the rest ignored (no bundling)."""
    max_effects: Positive
    """Effects one new advancement may have."""
    max_stubs: NonNegative
    """New goal stubs one ruling may name."""
    max_prerequisites: NonNegative
    adviser_unrest_bp: NonNegative
    """Most unrest the advisers' reactions to one idea may add."""
    adviser_suspicion_bp: NonNegative
    """Most suspicion the advisers' reactions to one idea may add."""
    min_complexity_per_prerequisite_tier: Positive
    """A new node is at least as complex as its most complex prerequisite, minus this."""


class RivalRules(Frozen):
    """News, awareness, relations, war and victory (brief §7, DESIGN §10-11)."""

    news_ahead_years: NonNegative
    """An adoption at least this many years ahead of its time is news worth spreading."""
    news_years_per_hop: Positive
    """Years news takes to cross one province border (halved along friendly ties)."""
    garble_per_hop_bp: Rate
    """Chance per border crossed that the news arrives garbled."""
    clarify_years: Positive
    """Years after garbled news until the truth arrives."""
    free_agent_grievance_bp: Rate
    """An aware civilisation with this much grievance toward the player breaks from its
    script and acts on its own judgement."""
    imitation_chance_bp: Rate
    """Chance per turn that an aware civilisation starts copying an idea it heard about."""
    strength_per_worker_bp: Positive
    """Military strength from each unit of workforce (before effects and legitimacy)."""
    capture_per_excess_bp: NonNegative
    """Chance per turn to take a frontier province, per 100% of strength advantage."""
    max_capture_bp: Rate
    capital_defence_bp: Positive
    """Walls and the court's guard: a capital is this much harder to take (10_000 = normal)."""
    war_losses_bp: Rate
    """Share of each frontier province's people lost per turn of war."""
    war_unrest_bp: NonNegative
    """Unrest per turn at war."""
    weariness_per_turn_bp: NonNegative
    weariness_per_loss_bp: NonNegative
    """Extra weariness for each province lost."""
    peace_weariness_bp: Rate
    """A side this weary sues for peace (or accepts it)."""
    war_grievance_bp: NonNegative
    """Grievance the side that lost ground carries away from a war."""
    grievance_fade_bp: Rate
    """Share of grievance forgotten each decade."""
    aggressive_war_chance_bp: Rate
    """Chance per turn that an aggressive free agent attacks a much weaker neighbour."""
    trade_wealth_per_1000_bp: NonNegative
    """Wealth each turn from each friendly partner, per 1,000 of the smaller side's people
    (per decade, scaled like every flow)."""
    faith_spread_bp: Rate
    """Chance per decade that a spreading faith crosses to a neighbour of another faith."""
    missionary_wealth: NonNegative
    missionary_chance_bp: Rate
    """Chance that missionaries convert the court they are sent to."""
    shared_faith_fade_bp: Rate
    """Extra share of grievance forgotten each decade between states of one faith."""
    envoy_wealth: NonNegative
    """Wealth an envoy costs."""
    capital_loss_legitimacy_bp: NonNegative
    military_victory_share_bp: Rate
    """Share of the scenario's people the player must rule for a military victory."""
    economic_victory_share_bp: Rate
    """Share of the other civilisations' people the player's trade network must reach."""
    cultural_victory_share_bp: Rate
    victory_margin_bp: Rate
    """A path's target is at least the player's starting share plus this, so nobody wins
    by standing still."""
    """Share of the scenario's total culture (people x literacy and influence) needed."""


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
    rulings: RulingRules
    rivals: RivalRules
