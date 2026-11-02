"""Land, slaves, grain, coin and debt (R4, F1): Rome's economy as the sources describe it.

- **Land.** The *ager publicus* grows with conquest; each year the rich take a share of what
  is still free into their estates (latifundia), and as the estates grow the small farmers who
  meet the property threshold for the legions (the *assidui*) decline, unless an agrarian law
  passes (the Licinian law of 367: Livy 6.35.4-5; the Gracchan law of 133: Plutarch, Tiberius
  Gracchus 8; Appian, Civil Wars 1.9-11). The legions read the assidui share.
- **Slaves** arrive with conquests and sacks and work the estates for wealth; a slave revolt
  can rise when they are many (Sicily 135 and 104, Spartacus 73: Plutarch, Crassus 8-11;
  Appian, Civil Wars 1.116-120; Obsequens 27, 45).
- **Grain.** The city's need grows with its people; Latium feeds a shrinking share, and the
  provinces feed the rest as Rome holds them (Sicily's tithe: Cicero, Verrines 2.3.12-15).
  A shortfall raises unrest; the grain dole (Gaius Gracchus, 123: Plutarch, C. Gracchus 5;
  free under Clodius, 58: Dio 38.13) steadies it at a cost to the treasury.
- **Coin.** Silver coinage from 269 and the denarius (Pliny, NH 33.42-46; the denarius'
  date is the numismatists' 211) raise the trade income; conquered provinces pay tribute.
- **Debt** rises with war years and bad harvests, falls in peace, is cut by the
  ``debt_relief`` law, and when ignored early brings a secession of the plebs (494: Livy
  2.32-33; 449: Livy 3.50-54; 287: Livy, Periochae 11).

Integers only; sorted loops; the only randomness is the slave-revolt and secession draws.
"""

from __future__ import annotations

from anachronism.content.schema.rome_society import Grain, Land
from anachronism.engine.culture import trade_income
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.rivals import at_war
from anachronism.engine.rng import GameRng
from anachronism.engine.rome_society_state import RomeSocietyState
from anachronism.engine.state import CivState, GameState


def _society(state: GameState) -> RomeSocietyState:
    assert state.rome_society is not None, "this game has no Roman society"
    return state.rome_society


def _civ(state: GameState) -> CivState:
    return state.civs[state.player_civ]


def _land(state: GameState) -> Land:
    return state.world.rome_society.land


def _grain(state: GameState) -> Grain:
    return state.world.rome_society.grain


def _law_year(state: GameState, law: str) -> int | None:
    return state.republic.laws.get(law) if state.republic is not None else None


# ---------------------------------------------------------------- start


def start(state: GameState) -> None:
    """Set the land, the grain and the coin as they stood at the scenario's start."""
    society = _society(state)
    rules = _land(state)
    people = state.population(state.player_civ)
    land = society.land
    land.ager_publicus = people // 1000 * rules.start_ager_per_1000
    land.latifundia = apply_bp(land.ager_publicus, rules.start_latifundia_bp)
    land.assidui_bp = rules.assidui_start_bp
    _grain_year(state, state.year, pay=False)
    _coin_reforms(state, state.year)
    society.coin.trade_bonus_bp = _trade_bonus_bp(state, state.year)


# ---------------------------------------------------------------- land and slaves


def conquests(state: GameState, events: EventLog) -> None:
    """Provinces taken and cities sacked this turn add public land and slaves."""
    society = _society(state)
    rules = _land(state)
    land = society.land
    by_name = {g.name: pid for pid, g in state.world.geography.items()}
    for item in events.items:
        if item.civ != state.player_civ:
            continue
        if item.kind == "conquest":
            pid = by_name.get(item.subject)
            if pid is None:
                continue
            people = state.provinces[pid].population // 1000
            land.ager_publicus += people * rules.ager_per_1000_conquered
            land.slaves += people * rules.slaves.per_1000_conquered
        elif item.kind == "spoils":
            sacked = int(item.spoils.get("sacked", 0))
            land.slaves += apply_bp(sacked, rules.slaves.sacked_enslaved_bp)


def estates_bp(state: GameState) -> int:
    """The great estates' share of the public land (bp)."""
    land = _society(state).land
    return land.latifundia * BP // max(1, land.ager_publicus)


def _land_year(state: GameState, events: EventLog, year: int) -> None:
    society = _society(state)
    rules = _land(state)
    land = society.land
    free = max(0, land.ager_publicus - land.latifundia)
    land.latifundia += apply_bp(free, rules.occupation_bp)
    land.assidui_bp = clamp(
        land.assidui_bp - apply_bp(rules.assidui_decline_bp, estates_bp(state)),
        rules.assidui_floor_bp,
        BP,
    )
    passed = _law_year(state, "land_reform")
    if passed is None or passed == land.reform_applied:
        return
    # the law the Senate passed is the latest of history's agrarian laws at or before its year
    reforms = sorted(rules.reforms, key=lambda r: r.year)
    chosen = next((r for r in reversed(reforms) if r.year <= passed), None)
    if chosen is None and reforms:
        chosen = reforms[0]
    land.reform_applied = passed
    if chosen is None:
        return
    given = apply_bp(land.latifundia, chosen.latifundia_cut_bp)
    land.latifundia -= given
    land.assidui_bp = clamp(land.assidui_bp + chosen.assidui_gain_bp, 0, BP)
    events.add(
        state.player_civ,
        "land_reform",
        f"{chosen.name}: no man may hold more than {chosen.limit_iugera} iugera of the public "
        f"land; {given:,} thousand iugera go to small farmers.",
        chosen.name,
    )


def _slaves_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    society = _society(state)
    rules = _land(state).slaves
    land = society.land
    civ = _civ(state)
    civ.stockpiles.wealth += land.slaves // 1000 * rules.estate_wealth_per_1000
    free_people = max(1, state.population(state.player_civ))
    ratio = land.slaves * BP // free_people
    dated = [r for r in rules.revolts if r.year == year]
    rises = bool(dated) and land.slaves >= 1000
    if not rises and ratio >= rules.revolt_threshold_bp and rng.chance(rules.revolt_chance_bp):
        rises = True
    if not rises:
        return
    revolt = dated[0] if dated else None
    where = revolt.province if revolt is not None and revolt.province in state.provinces else ""
    if not where:
        owned = state.owned_provinces(state.player_civ)
        where = max(owned, key=lambda p: (state.provinces[p].population, p)) if owned else ""
    if where and state.provinces[where].owner == state.player_civ:
        state.provinces[where].ravaged = max(state.provinces[where].ravaged, 1)
    lost = apply_bp(civ.stockpiles.wealth, rules.revolt_wealth_loss_bp)
    civ.stockpiles.wealth -= lost
    land.slaves -= apply_bp(land.slaves, rules.revolt_slaves_lost_bp)
    civ.stats.unrest_bp = clamp(civ.stats.unrest_bp + rules.revolt_unrest_bp, 0, BP)
    land.revolts.append(year)
    name = revolt.name if revolt is not None else "The slaves rise"
    place = state.world.geography[where].name if where else "the estates"
    events.add(
        state.player_civ,
        "slave_revolt",
        f"{name}: the slaves of {place} break out, burn the estates and take up arms; "
        f"{lost:,} wealth is lost putting them down.",
        place,
    )


# ---------------------------------------------------------------- grain


def city_people(state: GameState, year: int) -> int:
    """The city's people in a year: the latest estimate at or before it (the first if none)."""
    table = sorted(_grain(state).city, key=lambda c: c.year)
    if not table:
        return state.provinces[_civ(state).capital].population // 4
    best = table[0]
    for row in table:
        if row.year <= year:
            best = row
    return best.people


def supply_bp(state: GameState, year: int) -> tuple[int, list[str]]:
    """How much of the city's need is fed this year, and by which supplies."""
    rules = _grain(state)
    people = city_people(state, year)
    table = sorted(rules.city, key=lambda c: c.year)
    first = table[0].people if table else people
    grown = max(0, people - first) // 100_000
    total = max(0, rules.home_share_bp - grown * rules.home_fade_per_100k_bp)
    held: list[str] = []
    owner = state.player_civ
    for supply in sorted(rules.supplies, key=lambda s: s.id):
        if supply.from_year is not None and year < supply.from_year:
            continue
        mine = [p for p in supply.provinces if p in state.provinces]
        if not mine:
            continue
        have = sum(1 for p in mine if state.provinces[p].owner == owner)
        if have:
            total += supply.share_bp * have // len(mine)
            held.append(supply.id)
    return total, held


def _grain_year(state: GameState, year: int, pay: bool = True) -> None:
    society = _society(state)
    rules = _grain(state)
    grain = society.grain
    civ = _civ(state)
    grain.city_people = city_people(state, year)
    grain.supply_bp, grain.held = supply_bp(state, year)
    grain.shortfall_bp = max(0, BP - grain.supply_bp)
    passed = _law_year(state, rules.dole.law)
    dole = passed is not None
    if dole and grain.dole_since is None:
        grain.dole_since = passed
    if not dole:
        grain.dole_since = None
    grain.dole_cost = 0
    if not pay:
        return
    relief_share = 0
    if dole:
        cost = grain.city_people // 1000 * rules.dole.cost_per_1000
        free = rules.dole.free_from_year is not None and year >= rules.dole.free_from_year
        if free:
            cost += apply_bp(cost, rules.dole.free_cost_bp)
        if civ.stockpiles.wealth >= cost:
            civ.stockpiles.wealth -= cost
            grain.dole_cost = cost
            civ.stats.unrest_bp = clamp(civ.stats.unrest_bp - rules.dole.unrest_relief_bp, 0, BP)
            relief_share = rules.dole.shortage_relief_bp
    if grain.shortfall_bp:
        grain.shortages += 1
        unrest = apply_bp(rules.shortage_unrest_bp, grain.shortfall_bp)
        unrest -= apply_bp(unrest, relief_share)
        civ.stats.unrest_bp = clamp(civ.stats.unrest_bp + unrest, 0, BP)
    else:
        civ.stats.unrest_bp = clamp(civ.stats.unrest_bp - rules.surplus_calm_bp, 0, BP)


# ---------------------------------------------------------------- coin and tribute


def _coin_reforms(state: GameState, year: int) -> list[str]:
    coin = _society(state).coin
    reforms = sorted(state.world.rome_society.coinage.reforms, key=lambda r: (r.year, r.id))
    coin.reforms = [r.id for r in reforms if r.year <= year]
    return coin.reforms


def _trade_bonus_bp(state: GameState, year: int) -> int:
    reforms = state.world.rome_society.coinage.reforms
    return sum(r.trade_bonus_bp for r in reforms if r.year <= year)


def tribute_due(state: GameState) -> int:
    """What the conquered provinces pay this year."""
    rules = state.world.rome_society.coinage.tribute
    owner = state.player_civ
    total = 0
    for pid in state.owned_provinces(owner):
        province = state.provinces[pid]
        if province.people in (None, owner) or pid in rules.exempt:
            continue
        total += province.population // 1000 * rules.per_1000
    return total


def _coin_year(state: GameState, events: EventLog, year: int) -> None:
    society = _society(state)
    coin = society.coin
    civ = _civ(state)
    before = set(coin.reforms)
    reforms = state.world.rome_society.coinage.reforms
    for rid in _coin_reforms(state, year):
        if rid not in before:
            name = next(r.name for r in reforms if r.id == rid)
            events.add(state.player_civ, "coinage", f"{name}.", name)
    coin.trade_bonus_bp = _trade_bonus_bp(state, year)
    per_year = trade_income(state, state.player_civ) // max(1, state.world.years_per_turn)
    coin.trade_bonus = apply_bp(per_year, coin.trade_bonus_bp)
    coin.tribute = tribute_due(state)
    civ.stockpiles.wealth += coin.trade_bonus + coin.tribute


# ---------------------------------------------------------------- debt


def _debt_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    society = _society(state)
    rules = _land(state).debt
    land = society.land
    grain = society.grain
    civ = _civ(state)
    war = bool(at_war(state, state.player_civ))
    growth = rules.war_bp_per_year if war else 0
    if year == state.year and any(
        e.kind == "famine" and e.civ == state.player_civ for e in events.items
    ):
        growth += rules.famine_bp
    if grain.shortfall_bp:
        growth += rules.shortage_bp
    if growth:
        land.debt_bp = clamp(land.debt_bp + growth, 0, BP)
    else:
        land.debt_bp -= apply_bp(land.debt_bp, rules.peace_relief_bp)
    passed = _law_year(state, rules.law)
    if passed is not None and passed != land.relief_applied:
        land.relief_applied = passed
        land.debt_bp -= apply_bp(land.debt_bp, rules.relief_cut_bp)
        events.add(
            state.player_civ,
            "debt_relief",
            "The law to ease debt: what has been paid in interest is struck from the principal "
            "and the rest paid over three years.",
        )
    civ.stats.unrest_bp = clamp(
        civ.stats.unrest_bp + apply_bp(rules.unrest_per_debt_bp, land.debt_bp), 0, BP
    )
    dated = [s for s in rules.secessions if s.year == year]
    secedes = bool(dated) and land.debt_bp >= rules.secession_threshold_bp // 2
    if not secedes and land.debt_bp >= rules.secession_threshold_bp:
        secedes = rng.chance(rules.secession_chance_bp)
    if not secedes:
        return
    land.secessions.append(year)
    land.debt_bp -= apply_bp(land.debt_bp, rules.secession_relief_bp)
    civ.stats.unrest_bp = clamp(civ.stats.unrest_bp + rules.secession_unrest_bp, 0, BP)
    civ.stats.legitimacy_bp = clamp(civ.stats.legitimacy_bp - rules.secession_legitimacy_bp, 0, BP)
    name = dated[0].name if dated else "The plebs secede"
    events.add(
        state.player_civ,
        "secession",
        f"{name}: the plebs march out of the city and camp on the Sacred Mount until their "
        "debts are eased.",
        name,
    )


# ---------------------------------------------------------------- the year


def run_year(state: GameState, rng: GameRng, events: EventLog, year: int) -> None:
    """The economy's year: conquests, land, slaves, grain, coin, debt."""
    if year == state.year:
        conquests(state, events)
    _land_year(state, events, year)
    _slaves_year(state, rng, events, year)
    _grain_year(state, year)
    _coin_year(state, events, year)
    _debt_year(state, rng, events, year)
