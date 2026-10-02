"""Every tunable number the engine uses. Values live in ``packs/core/rules.yaml``.

Flows are per decade (``reference_years``) and scaled to the scenario's turn length.
All rates are basis points: 10_000 bp = 100%.
"""

from __future__ import annotations

from typing import Self

from pydantic import Field, model_validator

from anachronism.content.schema.base import Frozen, Identifier, NonNegative, Positive, Rate
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
    hoard_turns: Positive = 10
    """Materials, knowledge and wealth beyond this many turns of production waste away
    (D-119): timber rots, scrolls are lost, treasure is embezzled."""
    hoard_loss_bp: Rate = 2_000
    """Share of the excess lost each decade."""


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
    dynasty_legitimacy_bp: Rate = 4_000
    """A new dynasty's legitimacy after a collapse (D-113): a fresh but untested mandate."""
    dynasty_unrest_relief_bp: Rate = 5_000
    """Share of unrest the fall of the old dynasty releases."""
    restoration_uprising_x: Positive = 2
    """A fallen state's own people rise this many times as often to restore it."""


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
    explain_wealth_per_1000: NonNegative = 60
    """Wealth an explanation decree costs per 1,000 people (x100, like a festival)."""
    explain_suspicion_bp: Rate = 2000
    """Suspicion removed by proclaiming the new arts a gift of the gods."""
    explain_belief_legitimacy_bp: Rate = 5000
    """Legitimacy at which such a proclamation is believed (an ill framing turns to awe)."""
    sages_knowledge_per_1000: NonNegative = 30
    """Knowledge spent (x100 per 1,000 people) on crediting foreign sages."""
    sages_suspicion_bp: Rate = 3500
    """Suspicion removed by crediting foreign sages (rivals then hear of your arts sooner)."""
    explain_cooldown_turns: Positive = 3
    """Turns before the court can explain itself again (a story told too often is doubted)."""


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
    last_stand_defence_bp: Positive = 20000
    """A state's last province is defended to the end: its defence is multiplied by this."""
    envoy_offer_bp: Rate = 2500
    """Chance per decade that a rival court with something to propose sends envoys."""
    player_grace_turns: NonNegative = 2
    """For this many opening turns the player loses no provinces in war (time to respond)."""
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
    faith_rooted_resistance_bp: Rate = 1000
    """A court holding another spreading (organised) faith converts at this share of the
    usual chance: Cairo does not turn Latin Christian in a generation."""
    missionary_wealth: NonNegative
    missionary_chance_bp: Rate
    """Chance that missionaries convert the court they are sent to."""
    missionary_rooted_bp: Rate = 3000
    """Missionaries to a court of another world faith succeed at this share of the chance."""
    shared_faith_fade_bp: Rate
    """Extra share of grievance forgotten each decade between states of one faith."""
    festival_wealth_per_1000: NonNegative
    """Wealth a festival costs per 1,000 people (x100: 100 = one unit per 1,000)."""
    festival_legitimacy_bp: NonNegative
    festival_unrest_bp: NonNegative
    mercenary_wealth_per_1000: NonNegative
    mercenary_strength_bp: NonNegative
    """Extra strength while mercenaries serve (5_000 = +50%)."""
    mercenary_turns: Positive
    seal_turns: Positive = 3
    """How long sealed borders last: no trade, and news of your arts crawls (brief §7.3)."""
    seal_news_bp: NonNegative = 10000
    """Extra travel time for news leaving a sealed realm (10_000 = twice as slow)."""
    spy_wealth_per_1000: NonNegative = 25
    """Wealth a spy network in a rival court costs per 1,000 of your people (D-115)."""
    spy_turns: Positive = 5
    """How long a spy network lasts."""
    spy_caught_bp: Rate = 1_200
    """Chance per decade that a court catches your spies (they go, and it bears a grudge)."""
    spy_steal_bp: Rate = 2_000
    """Chance per decade that spies steal one of the court's advancements you lack."""
    spy_head_start_bp: Rate = 3_000
    """How much of the work a stolen advancement saves."""
    spy_grievance_bp: Rate = 1_500
    """The grudge a court bears when it catches spies."""
    rumour_wealth_per_1000: NonNegative = 80
    """Wealth false rumours cost per 1,000 people: news on the road arrives garbled."""
    envoy_wealth: NonNegative
    """Wealth an envoy costs."""
    tribute_strength_ratio_bp: Positive = 25000
    """A court submits as a tributary to a state this much stronger (25_000 = 2.5 times),
    or when beaten in a war."""
    coalition_share_bp: Rate = 3500
    """Once the player rules this share of the region's people, rivals start allying
    against them."""
    coalition_chance_bp: Rate = 1500
    """Chance each turn that a pair of the player's wary neighbours forms a league."""
    alliance_trust_turns: NonNegative = 2
    """Turns of trade before a court will ally with you (a common enemy is reason enough)."""
    capital_loss_legitimacy_bp: NonNegative
    military_victory_share_bp: Rate
    """Share of the scenario's people the player must rule for a military victory."""
    economic_victory_share_bp: Rate
    """Share of the other civilisations' people the player's trade network must reach."""
    economic_trading_weight_bp: Rate = 5000
    """How much a trading partner's people count towards your trade network; allies and
    tributaries count in full."""
    economic_partners_share_bp: Rate = 5000
    """Economic victory also needs friendly ties with this share of the other living states."""
    economic_income_share_bp: Rate = 5000
    """Economic victory also needs income per turn of at least this share of the largest
    rival economy's."""
    cultural_victory_share_bp: Rate
    cultural_influence_needed_bp: NonNegative
    """A cultural victory also needs this much cultural influence from adopted advancements
    (writing systems, printing, universities...): culture must be made, not just inherited."""
    victory_margin_bp: Rate
    """A path's target is at least the player's starting share plus this, so nobody wins
    by standing still."""
    """Share of the scenario's total culture (people x literacy and influence) needed."""


class ArmyRules(Frozen):
    """Armies, battles, sieges and supply (D-099).

    Shares are of a state's people, scaled by its mobilisation (``martial_bp``);
    percentages are basis points.
    """

    standing_army_bp: NonNegative = 80
    """Men under arms at the start of a scenario (80 = 0.8% of the people)."""
    peace_army_bp: NonNegative = 80
    """How large a rival court keeps its army in peacetime."""
    war_army_bp: NonNegative = 250
    """How large a rival court raises its army in wartime."""
    max_under_arms_bp: NonNegative = 1000
    """No state can keep more than this share of its people under arms."""
    raise_small_bp: NonNegative = 100
    """Share of a province's people called up by a small, medium or large levy."""
    raise_medium_bp: NonNegative = 250
    raise_large_bp: NonNegative = 500
    battle_luck_bp: Rate = 2000
    """Each side's power in a battle varies by up to this much (fortune, weather, nerve)."""
    loser_losses_bp: Rate = 2000
    """Share of the losing side killed or scattered, plus up to as much again in a rout."""
    winner_losses_bp: Rate = 1200
    """Share of the winning side lost in a close fight (less in a rout)."""
    morale_loss_bp: Rate = 3000
    """Morale a beaten army loses."""
    morale_recovery_bp: Rate = 1500
    """Morale an army regains each turn at home."""
    general_skill_bp: NonNegative = 800
    """Extra power per point of a general's skill (1-5)."""
    general_death_bp: Rate = 1500
    """Chance that a beaten army's general falls."""
    field_defence_share_bp: Rate = 6000
    """How much of the ground's defence (hills, mountains, marsh) helps its owner in a
    field battle (walls count in sieges, not here)."""
    attrition_home_bp: Rate = 100
    """Men lost each turn to sickness and desertion at home."""
    attrition_abroad_bp: Rate = 400
    """... and on campaign, before the land's own hardships."""
    attrition_terrain_bp: dict[Identifier, Rate] = Field(
        default_factory=lambda: {"desert": 800, "mountains": 500, "marsh": 500, "steppe": 200}
    )
    supply_people_per_man: Positive = 20
    """A province feeds one soldier per this many people; beyond that, men starve."""
    starving_attrition_bp: Rate = 2000
    """Extra loss for an army wholly beyond its province's supply."""
    unpaid_morale_bp: Rate = 2000
    """Morale lost in a turn the treasury or granaries cannot pay the army."""
    unpaid_desertion_bp: Rate = 1000
    siege_base_bp: NonNegative = 5000
    """Siege progress a turn by an army large enough to invest the walls (a normal province
    needs 10_000; hills, capitals and last strongholds need more)."""
    siege_point_bp: NonNegative = 100
    """Extra progress a turn per siege point (siege engines, cannon) per 1,000 men."""
    garrison_people_per_man: Positive = 100
    """An army must number at least a province's people / this to besiege it properly."""
    weariness_per_battle_bp: NonNegative = 700
    """War weariness for losing a battle."""
    min_army: Positive = 200
    standing_ships_per_100k: NonNegative = 3
    """Warships a seafaring state keeps at the start, per 100,000 people on its coasts."""
    standing_fleet_min: Positive = 10
    """Smaller starting navies than this are not kept at all."""
    blockade_weariness_bp: NonNegative = 100
    """War weariness a turn for each province whose harbours an enemy fleet closes."""
    blockade_trade_bp: Rate = 5000
    """Share of a blockaded province's trade lost (and its coastal trade bonus with it)."""
    uprising_bp: Rate = 1500
    """Chance per decade that an ungarrisoned conquered province rises (more with unrest)."""
    assimilation_years: Positive = 150
    """Years until a conquered people thinks of itself as its rulers' own."""
    wall_level_bp: NonNegative = 6000
    """Extra defence for each level of walls built in a province."""
    wall_materials: NonNegative = 150
    """Materials (times the scenario's cost scale) for each level of walls; wealth is half."""
    wall_techs: tuple[Identifier, ...] = ("masonry", "fortification", "star_fort")
    """The advancement each level of walls needs: stone, then towers, then bastions."""
    levy_unrest_bp: NonNegative = 300
    """Unrest from a levy, per 1% of the people called up (less for warlike peoples)."""
    pillage_people_bp: Rate = 800
    """Share of a pillaged province's people killed or driven off each turn."""
    pillage_loot_per_1000: NonNegative = 3
    """Wealth taken per 1,000 people of a pillaged province each turn."""
    pillage_grievance_bp: NonNegative = 1500
    """How bitterly a people remembers its province being pillaged."""
    ravaged_turns: Positive = 2
    """Turns a pillaged province takes to recover."""
    mercenary_men_bp: NonNegative = 150
    """A mercenary company numbers this share of the hiring state's people (1.5%)."""
    tactic_edge_bp: NonNegative = 3000
    """Extra power for a side whose battle plan beats the enemy's (doubled by a gifted general)."""
    reads_enemy_skill: Positive = 3
    """A general this skilled, left to choose, reads the enemy's plan and answers it."""
    veterancy_win_bp: NonNegative = 600
    """Power an army's men learn from a victory ..."""
    veterancy_loss_bp: NonNegative = 300
    """... and its survivors from a defeat ..."""
    max_veterancy_bp: NonNegative = 3000
    """... up to this much."""
    standing_veterancy_bp: NonNegative = 500
    """What a state's standing army has learned by the start."""
    mercenary_veterancy_bp: NonNegative = 2000
    """What a mercenary company has learned in other men's wars."""
    trait_bp: dict[Identifier, NonNegative] = Field(
        default_factory=lambda: {
            "horse": 2500,
            "siege": 5000,
            "shield": 2000,
            "bold": 2000,
            "quartermaster": 5000,
            "beloved": 5000,
        }
    )
    """How strong each general's gift is (see ``General``): bonus to cavalry, siege
    progress, defence, attack (and a tenth as much off defence), less attrition, faster
    morale recovery and gentler morale loss."""
    """An army reduced below this many men melts away."""


class BuildingRules(Frozen):
    """How many buildings a province holds and what more of them cost (D-111)."""

    base_slots: NonNegative = 2
    """Buildings any province can hold."""
    people_per_slot: Positive = 250_000
    """One more for each this many people (cities grow, and hold more)."""
    max_slots: NonNegative = 8
    extra_cost_bp: Rate = 2_500
    """Each building already standing makes the next cost this much more."""
    rival_reserve: Positive = 3
    """Rival courts build only while their stores hold this many times the cost."""


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
    armies: ArmyRules = Field(default_factory=ArmyRules)
    buildings: BuildingRules = Field(default_factory=BuildingRules)
    difficulty: dict[Identifier, dict[str, int]] = Field(default_factory=dict)
    """Named difficulty levels (``easy``, ``hard``...), each a set of overrides to the
    rival rules; ``normal`` is the rules as written. Unknown rule names are errors."""

    @model_validator(mode="after")
    def _known_overrides(self) -> Self:
        for level, overrides in self.difficulty.items():
            unknown = set(overrides) - set(RivalRules.model_fields)
            if unknown:
                raise ValueError(f"difficulty {level}: unknown rival rules {sorted(unknown)}")
        return self
