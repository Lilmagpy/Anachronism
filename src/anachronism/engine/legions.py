"""The army's three systems and the census-class levy (R4, F1).

Rome's army moves through three eras (``recruitment.eras``): the Servian phalanx of the
classes (Livy 1.43), the manipular legion of hastati, principes, triarii and velites (Livy 8.8;
Polybius 6.19-26) and the cohort legion that Marius filled with the *capite censi* (Sallust,
Jugurtha 86.2; Plutarch, Marius 9.1). An era comes in history's year, or earlier if the player
has adopted its advancement (the Marian reform as an anachronism); when the year arrives and
the idea was never pursued, history adopts it anyway.

Recruitment runs through the census: the property threshold falls over time (11,000 asses in
Livy's Servian table, 400 drachmae in Polybius 6.19.2, 1,500 asses in Cicero, De re publica
2.40, none after 107), and only the *assidui* above it can be levied, a pool shrunk by the
latifundia (``roman_economy``) and restored by land laws. Polybius 6.19.2: sixteen campaigns
for the infantry before forty-six. After Marius a soldier's loyalty shifts from the state to
the general who leads him to victory and promises him land (Sulla's march on Rome in 88,
Caesar's crossing in 49), kept per general for the civil-war chapters to read.

The hooks ``levy`` and ``after_battle`` are called from ``armies.py`` (marked F1).
"""

from __future__ import annotations

from anachronism.content.schema import Stage
from anachronism.content.schema.rome_society import ArmyEra, Recruitment, Threshold
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp
from anachronism.engine.rome_society_state import LegionState, RomeSocietyState
from anachronism.engine.state import Army, GameState, TechState
from anachronism.engine.tech import is_adopted, usable_resources


def _society(state: GameState) -> RomeSocietyState | None:
    society = state.rome_society
    if society is None or not state.world.rome_society.recruitment.eras:
        return None
    return society


def _rules(state: GameState) -> Recruitment:
    return state.world.rome_society.recruitment


def eras(state: GameState) -> list[ArmyEra]:
    """The army's eras, earliest first."""
    return sorted(_rules(state).eras, key=lambda e: (e.from_year, e.id))


def era_at(state: GameState, year: int) -> ArmyEra | None:
    """The era in force: the latest whose year has come or whose advancement Rome uses."""
    civ = state.civs[state.player_civ]
    found: ArmyEra | None = None
    for era in eras(state):
        if era.from_year <= year or is_adopted(civ, era.tech):
            found = era
    return found


def threshold_at(state: GameState, year: int) -> Threshold | None:
    """The property qualification in force in a year."""
    found: Threshold | None = None
    for item in sorted(_rules(state).thresholds, key=lambda t: t.from_year):
        if item.from_year <= year:
            found = item
    return found


def citizens(state: GameState) -> int:
    """Adult male citizens, as the census counts them."""
    return apply_bp(state.population(state.player_civ), _rules(state).citizen_share_bp)


def assidui(state: GameState, year: int) -> int:
    """Men of the classes who can be levied this year (everyone, once the proletarii serve)."""
    society = state.rome_society
    assert society is not None
    threshold = threshold_at(state, year)
    era = era_at(state, year)
    all_men = citizens(state)
    if (era is not None and era.proletarii) or threshold is None or threshold.asses == 0:
        return all_men
    start_bp = max(1, state.world.rome_society.land.assidui_start_bp)
    qualify = threshold.qualify_bp * society.land.assidui_bp // start_bp
    return apply_bp(all_men, clamp(qualify, 0, BP))


def under_arms(state: GameState) -> int:
    """Rome's own men in the field (mercenaries and garrisons aside)."""
    return sum(
        a.men
        for a in state.armies.values()
        if a.owner == state.player_civ and not a.contract and not a.garrison
    )


def _refresh(state: GameState, legions: LegionState, year: int) -> None:
    threshold = threshold_at(state, year)
    legions.threshold_asses = threshold.asses if threshold is not None else 0
    era = era_at(state, year)
    legions.proletarii = (era is not None and era.proletarii) or legions.threshold_asses == 0
    legions.assidui = assidui(state, year)
    legions.levied = min(under_arms(state), legions.assidui)


def start(state: GameState, events: EventLog) -> None:
    """Set the era and the levy pool at the scenario's start."""
    society = _society(state)
    if society is None:
        return
    era = era_at(state, state.year)
    society.legions.era = era.id if era is not None else ""
    society.legions.era_since = state.year
    _refresh(state, society.legions, state.year)


def _switch_era(state: GameState, events: EventLog, year: int) -> None:
    society = state.rome_society
    assert society is not None
    legions = society.legions
    civ = state.civs[state.player_civ]
    order = [e.id for e in eras(state)]
    current = order.index(legions.era) if legions.era in order else -1
    for era in eras(state):
        # history's year has come: the idea the era rests on is in use, pursued or not
        if era.from_year <= year and not is_adopted(civ, era.tech) and era.tech in state.tech_nodes:
            civ.projects.pop(era.tech, None)  # a trial of it under way ends: it is in use
            civ.tech[era.tech] = TechState(
                stage=Stage.ADOPTED,
                spread_bp=state.world.rules.spread.baseline_adopted_bp,
                adopted_year=year,
            )
    era_now = era_at(state, year)
    if era_now is None or order.index(era_now.id) <= current:
        return
    legions.era = era_now.id
    legions.era_since = year
    early = era_now.from_year - year
    how = f", {early} years before its time" if early > 0 else ""
    events.add(
        state.player_civ,
        "army_era",
        f"The army is reformed: {era_now.name}{how}.",
        era_now.name,
    )


def _professional(state: GameState, legions: LegionState) -> bool:
    """True from the era in which soldiers follow their general (the cohort legion)."""
    order = [e.id for e in eras(state)]
    from_era = _rules(state).loyalty.from_era
    if legions.era not in order or from_era not in order:
        return False
    return order.index(legions.era) >= order.index(from_era)


def _loyalty_year(state: GameState) -> None:
    society = state.rome_society
    assert society is not None
    rules = _rules(state).loyalty
    legions = society.legions
    if not _professional(state, legions):
        return
    led = {a.general for a in state.armies.values() if a.owner == state.player_civ and a.general}
    land_law = state.republic is not None and "land_reform" in state.republic.laws
    for general in sorted(set(legions.loyalty) | led):
        now = legions.loyalty.get(general, 0)
        if general in led:
            now += rules.per_year_bp + (rules.land_law_bp if land_law else 0)
        else:
            now -= apply_bp(now, rules.fade_bp)
        if now <= 0:
            legions.loyalty.pop(general, None)
        else:
            legions.loyalty[general] = min(BP, now)


def run_year(state: GameState, events: EventLog, year: int) -> None:
    """The legions' year: the era, the threshold, the pool, the generals' hold on their men."""
    society = _society(state)
    if society is None:
        return
    _switch_era(state, events, year)
    _refresh(state, society.legions, year)
    _loyalty_year(state)


def composition_for(state: GameState, era: ArmyEra, men: int) -> dict[str, int]:
    """Divide ``men`` among the era's soldiers that Rome can raise now (empty if none)."""
    civ = state.civs[state.player_civ]
    have = usable_resources(state, state.player_civ)
    weights = dict(era.composition)
    if is_adopted(civ, era.allies_tech):
        for unit_id, weight in era.allies.items():
            weights[unit_id] = weights.get(unit_id, 0) + weight
    picks: list[tuple[str, int]] = []
    for unit_id in sorted(weights):
        unit = state.world.units.get(unit_id)
        if unit is None or weights[unit_id] <= 0:
            continue
        if all(is_adopted(civ, t) for t in unit.needs_techs) and all(
            r in have for r in unit.needs_resources
        ):
            picks.append((unit_id, weights[unit_id]))
    if not picks:
        return {}
    total = sum(w for _, w in picks)
    troops = {u: men * w // total for u, w in picks}
    troops[picks[0][0]] += men - sum(troops.values())
    return {u: n for u, n in troops.items() if n > 0}


def _rescale(troops: dict[str, int], men: int) -> dict[str, int]:
    total = max(1, sum(troops.values()))
    out = {u: n * men // total for u, n in sorted(troops.items())}
    if out:
        first = next(iter(out))
        out[first] += men - sum(out.values())
    return {u: n for u, n in out.items() if n > 0}


def levy(
    state: GameState, civ_id: str, province_id: str, men: int, troops: dict[str, int], style: str
) -> tuple[int, dict[str, int]]:
    """Rome's levy: capped by the assidui who may serve, made up as the era's legion.

    Other states' levies pass through unchanged, as does Rome's when the content has no eras.
    """
    society = _society(state)
    if society is None or civ_id != state.player_civ:
        return men, troops
    room = apply_bp(society.legions.assidui, _rules(state).levy_share_bp) - under_arms(state)
    men = max(0, min(men, room))
    if men <= 0:
        return 0, {}
    era = era_at(state, state.year)
    made = composition_for(state, era, men) if era is not None else {}
    return men, made or _rescale(troops, men)


def after_battle(
    state: GameState, winners: list[Army], losers: list[Army], events: EventLog
) -> None:
    """A victory binds a professional army closer to the general who won it."""
    society = _society(state)
    if society is None:
        return
    legions = society.legions
    if not _professional(state, legions):
        return
    rules = _rules(state).loyalty
    for army in sorted(winners, key=lambda a: a.id):
        if army.owner != state.player_civ or not army.general or army.contract:
            continue
        gain = rules.per_victory_bp + (rules.proletarii_bp if legions.proletarii else 0)
        legions.loyalty[army.general] = min(BP, legions.loyalty.get(army.general, 0) + gain)


def would_march_on_rome(state: GameState) -> list[str]:
    """Generals whose men would follow them against the city (for the civil-war chapters)."""
    society = _society(state)
    if society is None:
        return []
    threshold = _rules(state).loyalty.march_threshold_bp
    return sorted(g for g, bp in society.legions.loyalty.items() if bp >= threshold)
