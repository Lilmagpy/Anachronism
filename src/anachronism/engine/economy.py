"""One civilisation's economy for one turn (docs/plans/phase-1.md, "Economy").

Order: workforce -> project funding (by priority, proportional within a tier, each project
limited by its scarcest input) -> labour diverted beyond the surplus cuts production ->
production -> upkeep -> storage and spoilage -> starvation if food runs out.
"""

from __future__ import annotations

from dataclasses import dataclass
from itertools import groupby

from anachronism.content.schema import Access, EffectType
from anachronism.engine.actions import Priority
from anachronism.engine.buildings import bonus
from anachronism.engine.buildings import upkeep as building_upkeep
from anachronism.engine.effects import Effects
from anachronism.engine.fixed import BP, apply_bp, div_round, ratio_bp, with_bonus
from anachronism.engine.state import GameState, Project, Stockpiles
from anachronism.engine.timeflow import per_turn, rate_per_turn

RESOURCES = ("labour", "materials", "knowledge", "wealth")
_PER_1000 = 1_000 * BP


@dataclass(frozen=True)
class Costs:
    """Per-turn amounts of each project input."""

    labour: int = 0
    materials: int = 0
    knowledge: int = 0
    wealth: int = 0

    def get(self, resource: str) -> int:
        """Return the amount of one input by name."""
        value: int = getattr(self, resource)
        return value

    def __add__(self, other: Costs) -> Costs:
        return Costs(*(self.get(r) + other.get(r) for r in RESOURCES))


@dataclass(frozen=True)
class Labour:
    """A civilisation's workforce this turn and the share projects can use for free."""

    workforce: int
    surplus: int


@dataclass(frozen=True)
class Production:
    """What the civilisation produced this turn."""

    food: int
    materials: int
    wealth: int
    knowledge: int


@dataclass(frozen=True)
class Allocation:
    """How this turn's project requests were funded."""

    funding: dict[str, int]
    """Funding of each active project, in basis points of its request."""
    requested: Costs
    used: Costs


@dataclass(frozen=True)
class EconomyOutcome:
    """Everything later systems need to know about this turn's economy."""

    labour: Labour
    allocation: Allocation
    diverted: int
    production_bp: int
    produced: Production
    food_needed: int
    famine_bp: int
    deaths: int
    wealth_shortfall_bp: int

    @property
    def shortfall_bp(self) -> int:
        """How far projects fell short of their requests, weighted by labour requested."""
        requested = self.allocation.requested.labour
        if requested == 0:
            return 0
        return BP - ratio_bp(self.allocation.used.labour, requested)

    @property
    def diversion_bp(self) -> int:
        """Share of the non-surplus workforce pulled off fields and workshops."""
        return ratio_bp(self.diverted, self.labour.workforce - self.labour.surplus)


def project_costs(state: GameState, node_id: str) -> Costs:
    """Per-turn cost of experimenting with an advancement, from engine formulas only."""
    node = state.tech_nodes[node_id]
    rules = state.world.rules.projects
    index = node.complexity - 1
    materials = rules.materials[index]
    if node.category in rules.heavy_categories:
        materials = apply_bp(materials, rules.heavy_materials_bp)
    years_ahead = max(0, node.year - state.year)
    premium = min(rules.anachronism_cap_bp, years_ahead * rules.anachronism_bp_per_century // 100)
    scale = state.world.cost_scale
    base = Costs(
        rules.labour[index] * scale,
        materials * scale,
        rules.knowledge[index] * scale,
        rules.wealth[index] * scale,
    )
    return Costs(*(per_turn(state, with_bonus(base.get(r), premium)) for r in RESOURCES))


def labour(state: GameState, civ_id: str, effects: Effects) -> Labour:
    """Workforce and surplus for this turn."""
    rules = state.world.rules
    civ = state.civs[civ_id]
    base = div_round(state.population(civ_id) * rules.economy.workforce_per_1000_bp, _PER_1000)
    penalty = apply_bp(civ.stats.unrest_bp, rules.society.labour_penalty_at_full_unrest_bp)
    efficiency = max(0, BP + effects[EffectType.LABOUR_OUTPUT] - penalty)
    workforce = per_turn(state, apply_bp(base, efficiency))
    return Labour(workforce, apply_bp(workforce, rules.economy.surplus_share_bp))


def active_projects(state: GameState, civ_id: str) -> list[Project]:
    """Unpaused projects in funding order: priority, then age, then id."""
    projects = [p for p in state.civs[civ_id].projects.values() if not p.paused]
    return sorted(projects, key=lambda p: (p.priority.rank, p.started_turn, p.node_id))


def allocate(
    state: GameState, civ_id: str, workforce: int, stock: Stockpiles, surplus: int | None = None
) -> Allocation:
    """Fund active projects from the workforce and start-of-turn stockpiles (no mutation).

    Low-priority projects are steady work (D-112): they take only spare hands, the
    ``surplus`` left after higher tiers, never farmers from the fields.
    """
    available = {
        "labour": workforce,
        "materials": stock.materials,
        "knowledge": stock.knowledge,
        "wealth": stock.wealth,
    }
    funding: dict[str, int] = {}
    requested = Costs()
    used = Costs()
    tiers = groupby(active_projects(state, civ_id), key=lambda p: p.priority)
    for priority, tier_projects in tiers:
        tier = list(tier_projects)
        steady = priority is Priority.LOW and surplus is not None
        if steady and surplus is not None:
            available["labour"] = min(available["labour"], max(0, surplus - used.labour))
        requests = {p.node_id: project_costs(state, p.node_id) for p in tier}
        totals = sum(requests.values(), Costs())
        fraction = {
            r: BP if totals.get(r) <= available[r] else ratio_bp(available[r], totals.get(r))
            for r in RESOURCES
        }
        for project in tier:
            request = requests[project.node_id]
            needed = [fraction[r] for r in RESOURCES if request.get(r) > 0]
            share = min(needed, default=BP)
            spent = Costs(*(request.get(r) * share // BP for r in RESOURCES))
            for resource in RESOURCES:
                available[resource] -= spent.get(resource)
            funding[project.node_id] = share
            # steady work asks only for what spare hands give: going slowly strains no one
            requested += spent if steady else request
            used += spent
    return Allocation(funding, requested, used)


def production(state: GameState, civ_id: str, effects: Effects, production_bp: int) -> Production:
    """What owned provinces produce this turn, after effects and labour diversion."""
    economy = state.world.rules.economy
    literacy = state.civs[civ_id].stats.literacy_bp
    food = materials = taxes = trade = knowledge = flat_materials = 0
    for province_id in state.owned_provinces(civ_id):
        province = state.provinces[province_id]
        geography = state.world.geography[province_id]
        terrain = state.world.terrain[geography.terrain]
        people = province.population
        ruin = 2 if province.ravaged else 1  # pillaged fields and burned workshops
        built = bonus(state, province_id)  # its markets, workshops, granaries (D-111)
        food += with_bonus(people * terrain.food_bp // ruin, built.food_bp)
        materials += with_bonus(people * terrain.materials_bp // ruin, built.materials_bp)
        taxes += with_bonus(people * economy.wealth_per_1000_bp // ruin, built.wealth_bp)
        trade_bp = economy.base_trade_bp
        trade_bp += economy.coastal_trade_bp if geography.coastal else 0
        trade_bp += economy.river_trade_bp if geography.river else 0
        if province.blockaded:  # enemy warships close the harbours (D-107)
            blockade = state.world.rules.armies.blockade_trade_bp
            trade_bp -= economy.coastal_trade_bp if geography.coastal else 0
            trade_bp -= apply_bp(trade_bp, blockade)
        trade += with_bonus(people * economy.wealth_per_1000_bp * trade_bp // BP, built.wealth_bp)
        learned = people * economy.knowledge_per_1000_bp
        learned += people * literacy // BP * economy.knowledge_per_1000_literate_bp
        knowledge += with_bonus(learned, built.knowledge_bp)
        for access in province.resources.values():
            if access is Access.ACCESSIBLE:
                flat_materials += economy.resource_materials_accessible
            elif access is Access.LIMITED:
                flat_materials += economy.resource_materials_limited

    def finish(total: int, effect: EffectType, diverted: bool = True) -> int:
        amount = with_bonus(div_round(total, _PER_1000), effects[effect])
        return per_turn(state, apply_bp(amount, production_bp) if diverted else amount)

    wealth = with_bonus(div_round(taxes, _PER_1000), effects[EffectType.WEALTH_OUTPUT])
    wealth += with_bonus(div_round(trade, _PER_1000), effects[EffectType.TRADE_INCOME])
    materials_total = div_round(materials, _PER_1000) + flat_materials
    return Production(
        food=finish(food, EffectType.FOOD_OUTPUT),
        materials=per_turn(
            state,
            apply_bp(
                with_bonus(materials_total, effects[EffectType.MATERIALS_OUTPUT]), production_bp
            ),
        ),
        wealth=per_turn(state, apply_bp(wealth, production_bp)),
        knowledge=finish(knowledge, EffectType.KNOWLEDGE_GAIN, diverted=False),
    )


def granary_capacity(state: GameState, civ_id: str, effects: Effects) -> int:
    """Food the civilisation can store."""
    per_1000 = state.world.rules.economy.granary_per_1000_bp
    base = div_round(state.population(civ_id) * per_1000, _PER_1000)
    return with_bonus(base, effects[EffectType.STORAGE])


def run_economy(state: GameState, civ_id: str, effects: Effects) -> EconomyOutcome:
    """Run this turn's economy: pay for projects, produce, eat, store. Mutates the state."""
    rules = state.world.rules
    civ = state.civs[civ_id]
    stock = civ.stockpiles
    work = labour(state, civ_id, effects)
    allocation = allocate(state, civ_id, work.workforce, stock, work.surplus)
    stock.materials -= allocation.used.materials
    stock.knowledge -= allocation.used.knowledge
    stock.wealth -= allocation.used.wealth

    diverted = max(0, allocation.used.labour - work.surplus)
    diverted_share = ratio_bp(diverted, work.workforce - work.surplus)
    production_bp = BP - apply_bp(diverted_share, BP - rules.economy.diversion_floor_bp)
    produced = production(state, civ_id, effects, production_bp)
    stock.food += produced.food
    stock.materials += produced.materials
    stock.knowledge += produced.knowledge

    upkeep = per_turn(
        state, rules.economy.admin_upkeep_per_province * len(state.owned_provinces(civ_id))
    )
    upkeep += building_upkeep(state, civ_id)
    wealth_balance = stock.wealth + produced.wealth - upkeep
    wealth_shortfall_bp = ratio_bp(-wealth_balance, upkeep) if wealth_balance < 0 else 0
    stock.wealth = max(0, wealth_balance)

    food_needed = per_turn(
        state,
        div_round(state.population(civ_id) * rules.economy.food_consumption_per_1000_bp, _PER_1000),
    )
    missing = max(0, food_needed - stock.food)
    stock.food = max(0, stock.food - food_needed)
    deaths = 0
    if missing:
        deaths = min(state.population(civ_id), missing * rules.population.deaths_per_missing_food)
        _apply_deaths(state, civ_id, deaths)

    capacity = granary_capacity(state, civ_id, effects)
    half = capacity // 2
    if stock.food > half:
        stock.food -= apply_bp(stock.food - half, rate_per_turn(state, rules.economy.spoilage_bp))
    stock.food = min(stock.food, capacity)

    return EconomyOutcome(
        labour=work,
        allocation=allocation,
        diverted=diverted,
        production_bp=production_bp,
        produced=produced,
        food_needed=food_needed,
        famine_bp=ratio_bp(missing, food_needed),
        deaths=deaths,
        wealth_shortfall_bp=min(BP, wealth_shortfall_bp),
    )


def _apply_deaths(state: GameState, civ_id: str, deaths: int) -> None:
    """Spread deaths over owned provinces in proportion to population (largest remainder)."""
    owned = state.owned_provinces(civ_id)
    total = sum(state.provinces[pid].population for pid in owned)
    if total == 0:
        return
    shares = {pid: deaths * state.provinces[pid].population // total for pid in owned}
    leftover = deaths - sum(shares.values())
    by_size = sorted(owned, key=lambda pid: (-state.provinces[pid].population, pid))
    for pid in by_size[:leftover]:
        shares[pid] += 1
    for pid, share in shares.items():
        province = state.provinces[pid]
        province.population = max(0, province.population - share)
