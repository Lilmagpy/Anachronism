"""The places of Rome and what the player can do at each this year (F2, D-304): ``view["places"]``.

Each standing building that served a role in the year maps to its role, title and blurb, the
actions available there now (exactly what the client sends to ``act``, with the cost, the
forecast, whether it is enabled and why not, and the spectacle it plays: ``watch``) and a few
``info`` lines (the treasury at Saturn, the Senate's mood at the Curia, the year's prodigies at
the temples, the levy pool on the Campus). The contract is in
``docs/plans/briefs/f2_play.md``; the roles follow history by year
(``republic_rules.city.places``): the Senate's house of the year, the Rostra before and after
44, the centuries on the Campus and the tribes in the Comitium or (from 145) the Forum, the
aerarium in Saturn, the temples standing that year.

Forecasts reuse the Senate's own code (``republic.senate_vote``, ``senate.interposition``) and
the actions' own checks (``engine/city_acts.plan_*``), so a forecast is what the action does.
"""

from __future__ import annotations

from typing import Any

from anachronism.content.schema import Issue, Stage
from anachronism.content.schema.places import PlacesRules
from anachronism.engine import city_acts
from anachronism.engine.actions import (
    ChooseSite,
    ConsultBooks,
    Contio,
    Expiate,
    GiveGames,
    VowTemple,
)
from anachronism.engine.armies import (
    composition,
    levy_size,
    mobilisation_cap,
    raise_cost,
)
from anachronism.engine.armies import under_arms as men_under_arms
from anachronism.engine.city import first_year, place_of_year, senate_house
from anachronism.engine.legions import era_at
from anachronism.engine.legions import levy as legions_levy
from anachronism.engine.republic import (
    _weight,
    eligible,
    faction_shares,
    senate_mood,
    senate_vote,
    senate_weights,
    year_label,
)
from anachronism.engine.senate import interposition
from anachronism.engine.state import GameState
from anachronism.engine.tech import describe_blockers, feasibility
from anachronism.engine.victory import income
from anachronism.tools.republic_view import _proposals, _tribune_note

Place = dict[str, Any]
LEVY_SIZES = ("small", "medium", "large")
HONOUREES_LISTED = 4


def _rules(state: GameState) -> PlacesRules:
    return state.world.republic_rules.city.places


def _num(n: int) -> str:
    return f"{n:,}"


def _pct(bp: int) -> str:
    return f"{bp / 100:.0f}%"


def _info(label: str, value: str, tip: str = "") -> dict[str, str]:
    return {"label": label, "value": value, "tip": tip}


def _act(
    ident: str,
    label: str,
    action: dict[str, Any],
    *,
    influence: int = 0,
    wealth: int = 0,
    forecast: dict[str, Any] | None = None,
    why: str = "",
    watch: str = "",
) -> dict[str, Any]:
    return {
        "id": ident,
        "label": label,
        "action": action,
        "cost": {"influence": influence, "wealth": wealth},
        "forecast": forecast or {},
        "enabled": not why,
        "why": why,
        "watch": watch,
    }


def _put(
    places: dict[str, Place],
    monument: str,
    role: str,
    title: str,
    blurb: str,
    actions: list[dict[str, Any]] | None = None,
    info: list[dict[str, str]] | None = None,
) -> None:
    """Add a place, or merge a second role of the same building into the first."""
    place = places.get(monument)
    if place is None:
        places[monument] = {
            "role": role,
            "roles": [role],
            "title": title,
            "blurb": blurb,
            "actions": list(actions or []),
            "info": list(info or []),
        }
        return
    if role not in place["roles"]:
        place["roles"].append(role)
    if blurb and blurb not in place["blurb"]:
        place["blurb"] = f"{place['blurb']} {blurb}".strip()
    place["actions"].extend(actions or [])
    place["info"].extend(info or [])


def _influence_why(state: GameState, cost: int) -> str:
    rep = state.republic
    assert rep is not None
    return f"not enough influence ({cost} needed)" if rep.influence < cost else ""


# ---------------------------------------------------------------- the Curia and the treasury


def _proposal_actions(
    state: GameState, proposals: list[dict[str, Any]], *, fund: bool
) -> list[dict[str, Any]]:
    """The Senate's proposals (with the Senate's own forecast), the funds or all the rest."""
    out = []
    for item in proposals:
        if item["proposal"].startswith("fund:") != fund:
            continue
        out.append(
            _act(
                f"senate:{item['proposal']}",
                f"Propose: {item['label']}",
                {"kind": "senate", "issue": item["issue"], "proposal": item["proposal"]},
                influence=item["cost"],
                forecast={
                    "yes_bp": item["forecast_yes_bp"],
                    "no_bp": item["forecast_no_bp"],
                    "passes": item["passes"],
                    "tribune": item["tribune"],
                    "tribune_bp": item["tribune_bp"],
                    "tribune_name": item["tribune_name"],
                    "note": item["tribune_note"],
                },
                why=_influence_why(state, item["cost"]),
                watch="senate",
            )
        )
    return out


def _persuade_actions(state: GameState, issues: list[Issue]) -> list[dict[str, Any]]:
    """Win over the weightiest families that lean against each matter before the Senate."""
    rep = state.republic
    assert rep is not None
    weights = senate_weights(state)
    out = []
    for issue in issues:
        vote = senate_vote(state, issue)
        against = sorted(
            (fid for fid in sorted(vote.by_family) if vote.by_family[fid] < 0),
            key=lambda fid: (-weights[fid], fid),
        )[: _rules(state).persuade_listed]
        for fid in against:
            out.append(_persuade(state, fid, issue, vote.by_family[fid], weights))
    return out


def _persuade(
    state: GameState, fid: str, issue: Issue, lean: int, weights: dict[str, int]
) -> dict[str, Any]:
    rules = state.world.republic_rules
    name = state.world.gentes[fid].name
    after = senate_vote(state, issue, extra={fid: rules.persuade_shift})
    return _act(
        f"persuade:{fid}:{issue.value}",
        f"Win over the {name} on {issue.value}",
        {"kind": "persuade", "family": fid, "issue": issue.value},
        influence=rules.persuade_cost,
        forecast={
            "lean_bp": lean,
            "after_bp": lean + rules.persuade_shift,
            "yes_bp": after.yes_bp,
            "no_bp": after.no_bp,
            "passes": after.passes,
            "weight_bp": weights[fid] * 10_000 // max(1, sum(weights.values())),
            "note": f"the {name} would lean {_pct(lean + rules.persuade_shift)} on {issue.value}",
        },
        why=_influence_why(state, rules.persuade_cost),
    )


def _curia(state: GameState, places: dict[str, Place], proposals: list[dict[str, Any]]) -> None:
    house = place_of_year(state, _rules(state).senate_houses)
    monument = house.monument if house is not None else senate_house(state)
    if not monument:
        return
    rep = state.republic
    assert rep is not None
    actions = _proposal_actions(state, proposals, fund=False)
    issues = sorted({Issue(a["action"]["issue"]) for a in actions}, key=list(Issue).index)
    actions += _persuade_actions(state, issues)
    info = [_info("Influence", _num(rep.influence), "what the player can spend in the Senate")]
    chair = presiding(state)
    if chair is not None:
        office = state.world.magistracies[chair.office].name.lower()
        info.append(_info("Presiding", f"{chair.name}, {office}", "he brings matters to the house"))
    for mood in senate_mood(state):
        info.append(
            _info(
                mood.name,
                f"{_pct(mood.weight_bp)} of the house, mood {mood.mood_bp:+d}",
                ", ".join(f"{k} {v:+d}" for k, v in sorted(mood.issues.items())),
            )
        )
    if rep.ballots:
        last = rep.ballots[-1]
        info.append(
            _info(
                "Last matter",
                f"{last.label or last.proposal}: {last.outcome}",
                f"{_pct(last.yes_bp)} for, {_pct(last.no_bp)} against ({year_label(last.year)})",
            )
        )
    title = house.name if house is not None else state.world.monuments[monument].english
    blurb = house.blurb if house is not None else "Where the Senate meets this year."
    status = state.city.standing.get(monument) if state.city is not None else None
    if status is not None and status.state != "standing":
        blurb += f" (still {status.state}; the Senate meets in it as it rises)"
    _put(places, monument, "senate_house", title, blurb, actions, info)


def presiding(state: GameState) -> Any:
    """The magistrate who presides over the Senate.

    The first office of ``places.presiding`` that is filled, and of its holders the first the
    year lists (the Fasti's order: Ap. Claudius Caudex in 264).
    """
    rep = state.republic
    assert rep is not None
    for office in _rules(state).presiding:
        for m in rep.magistrates:
            if m.office == office:
                return m
    return None


def _treasury(state: GameState, places: dict[str, Place], proposals: list[dict[str, Any]]) -> None:
    found = place_of_year(state, _rules(state).treasury)
    if found is None:
        return
    me = state.player_civ
    civ = state.civs[me]
    society = state.rome_society
    info = [
        _info("Treasury", _num(civ.stockpiles.wealth), "wealth in the aerarium now"),
        _info("Income a turn", _num(income(state, me)), "Rome's lands and its trade ties"),
    ]
    if society is not None:
        coin, grain, rel = society.coin, society.grain, society.religion
        info += [
            _info("Tribute this year", _num(coin.tribute), "from the provinces"),
            _info("Trade from the coinage", _num(coin.trade_bonus), "the coin reforms' bonus"),
            _info("Grain dole", _num(grain.dole_cost), "what the dole cost this year"),
            _info(
                "Expiations",
                _num(sum(p.cost for p in rel.prodigies if p.turn >= state.turn - 1 and p.expiated)),
                "paid to the gods for the last turn's prodigies",
            ),
        ]
    info.append(_info("Food in store", _num(civ.stockpiles.food), ""))
    actions = _proposal_actions(state, proposals, fund=True)
    _put(places, found.monument, "treasury", found.name, found.blurb, actions, info)


# ---------------------------------------------------------------- the Rostra and the assemblies


def _contio_forecast(state: GameState, issue: Issue, plan: city_acts.Plan) -> dict[str, Any]:
    if not plan.ok:
        return {"note": plan.why}
    before = senate_vote(state, issue)
    after = senate_vote(state, issue, extra=plan.shifts)
    stand = interposition(state, after)
    return {
        "yes_bp": after.yes_bp,
        "no_bp": after.no_bp,
        "passes": after.passes,
        "before_yes_bp": before.yes_bp,
        "shift_bp": plan.numbers["shift_bp"],
        "families": plan.numbers["families"],
        "speaker": plan.person,
        "tribune": stand.kind,
        "tribune_bp": stand.chance_bp,
        "note": _tribune_note(stand),
    }


def _rostra(state: GameState, places: dict[str, Place], issues: list[Issue]) -> None:
    found = city_acts.rostra(state)
    if found is None:
        return
    rep = state.republic
    assert rep is not None
    actions = []
    for issue in issues:
        for side in city_acts.SIDES:
            contio = Contio(civ=state.player_civ, issue=issue.value, side=side)
            plan = city_acts.plan_contio(state, contio)
            actions.append(
                _act(
                    f"contio:{issue.value}:{side}",
                    f"Speak {side} the matter of {issue.value}",
                    {"kind": "contio", "issue": issue.value, "side": side},
                    influence=_rules(state).contio.cost,
                    forecast=_contio_forecast(state, issue, plan),
                    why=plan.why,
                    watch="contio",
                )
            )
    seen: set[tuple[str, str]] = set()
    for backing in sorted(rep.backing, key=lambda b: (b.office, b.person)):
        key = (backing.person, backing.office)
        if backing.year != state.year + 1 or key in seen or backing.person not in rep.people:
            continue
        seen.add(key)
        contio = Contio(
            civ=state.player_civ, issue="candidate", side=backing.person, office=backing.office
        )
        plan = city_acts.plan_contio(state, contio)
        name = rep.people[backing.person].name
        office = state.world.magistracies[backing.office].name.lower()
        actions.append(
            _act(
                f"contio:candidate:{backing.office}:{backing.person}",
                f"Speak for {name} for the {office}",
                {
                    "kind": "contio",
                    "issue": "candidate",
                    "side": backing.person,
                    "office": backing.office,
                },
                influence=_rules(state).contio.cost,
                forecast={**plan.numbers, "speaker": plan.person, "note": plan.why},
                why=plan.why,
                watch="contio",
            )
        )
    info = [
        _info(
            "May call the people",
            ", ".join(
                f"{m.name} ({state.world.magistracies[m.office].name.lower()})"
                for m, _ in city_acts.speakers(state)
            )
            or "no one",
            "a consul's or a tribune's voice carries furthest",
        )
    ]
    _put(places, found.monument, "rostra", found.name, found.blurb, actions, info)


def _candidates(state: GameState, office: str, target: int) -> tuple[list[Any], int, int]:
    """The likeliest men for an office next year: (men, seats, the pool's total weight)."""
    rep = state.republic
    assert rep is not None
    mag = state.world.magistracies[office]
    era = mag.era_at(target)
    if era is None or not era.held_in(target) or era.appointed:
        return [], 0, 0
    shares = faction_shares(state, target)
    pool = [
        (p, _weight(state, rep, p, office, target, shares))
        for pid in sorted(rep.people)
        if (p := rep.people[pid]).alive and eligible(state, p, mag, era, target)
    ]
    total = sum(w for _, w in pool)
    best = sorted(pool, key=lambda pw: (-pw[1], pw[0].id))[: _rules(state).back_listed]
    return best, era.seats, total


def _assemblies(state: GameState, places: dict[str, Place]) -> None:
    rep = state.republic
    assert rep is not None
    rules = state.world.republic_rules
    target = state.year + 1
    for assembly in _rules(state).assemblies:
        found = place_of_year(state, assembly.places)
        if found is None:
            continue
        actions = []
        info = []
        for office in assembly.offices:
            if office not in state.world.magistracies:
                continue
            best, seats, total = _candidates(state, office, target)
            if not best:
                continue
            office_name = state.world.magistracies[office].name
            info.append(_info(office_name, f"{seats} to elect for {year_label(target)}"))
            for person, weight in best:
                backed = any(
                    b.person == person.id and b.office == office and b.year == target and not b.bp
                    for b in rep.backing
                )
                gain = rules.backing_bp
                chance = min(10_000, seats * weight * 10_000 // max(1, total))
                after = min(10_000, seats * (weight + gain) * 10_000 // max(1, total + gain))
                why = "already backed" if backed else _influence_why(state, rules.back_cost)
                actions.append(
                    _act(
                        f"back:{office}:{person.id}",
                        f"Back {person.name} for {office_name.lower()}",
                        {"kind": "back", "person": person.id, "office": office},
                        influence=rules.back_cost,
                        forecast={
                            "chance_bp": chance,
                            "after_bp": after,
                            "seats": seats,
                            "note": f"about {_pct(chance)} now, {_pct(after)} if backed",
                        },
                        why=why,
                        watch="election",
                    )
                )
        _put(places, found.monument, "assembly", found.name, found.blurb, actions, info)


# ---------------------------------------------------------------- temples


def _temples(state: GameState, places: dict[str, Place]) -> None:
    city = state.city
    society = state.rome_society
    assert city is not None
    rules = _rules(state)
    vowed = {v.monument: v for v in city.vows}
    recent = [p for p in society.religion.prodigies if p.turn >= state.turn - 1] if society else []
    prodigies = state.world.rome_society.prodigies
    cults = state.world.rome_society.cults
    for mid in sorted(state.world.monuments):
        monument = state.world.monuments[mid]
        status = city.standing.get(mid)
        if monument.type not in rules.temple_types or status is None:
            continue
        vow = vowed.get(mid)
        if status.state != "standing" and vow is None:
            continue
        built = first_year(monument)
        blurb = f"Dedicated {year_label(built)}." if built is not None else "Ancient."
        info = []
        if vow is not None:
            by = state.republic.people.get(vow.by) if state.republic else None
            blurb = f"Vowed {year_label(vow.year)} {('by ' + by.name) if by else ''}".strip()
            blurb += f"; to be dedicated {year_label(vow.completes)}."
        for record in recent:
            prodigy = prodigies.get(record.prodigy)
            if prodigy is not None and prodigy.monument == mid:
                info.append(
                    _info(
                        f"Prodigy, {year_label(record.year)}",
                        prodigy.sign,
                        prodigy.expiation if record.expiated else "not yet expiated",
                    )
                )
        for cid in sorted(cults):
            if cults[cid].monument == mid and society is not None and cid in society.religion.cults:
                info.append(
                    _info(
                        "Cult",
                        cults[cid].name,
                        f"received {year_label(society.religion.cults[cid])}",
                    )
                )
        title = monument.english or monument.latin or mid
        _put(places, mid, "temple", title, blurb, [], info)
    _vow_place(state, places)
    _rites(state, places)


def _rites(state: GameState, places: dict[str, Place]) -> None:
    """Expiate the prodigies left unexpiated, and consult the Sibylline Books (religion's API)."""
    for sibyl, kind, label in (
        (False, "expiate", "Expiate the prodigies left unexpiated"),
        (True, "sibyl", "Bid the decemviri consult the Sibylline Books"),
    ):
        monument = city_acts.rites_place(state, sibyl)
        if not monument:
            continue
        if sibyl:
            plan = city_acts.plan_sibyl(state, ConsultBooks(civ=state.player_civ))
        else:
            plan = city_acts.plan_expiate(state, Expiate(civ=state.player_civ))
        title = state.world.monuments[monument].english or monument
        action = _act(
            kind,
            label,
            {"kind": kind},
            wealth=plan.wealth,
            forecast={**plan.numbers, "note": plan.why},
            why=plan.why,
            watch="sacrifice",
        )
        _put(places, monument, "temple", title, "", [action], [])


def _vow_place(state: GameState, places: dict[str, Place]) -> None:
    found = city_acts.vow_place(state)
    vows = _rules(state).vow
    if found is None or vows is None:
        return
    actions = []
    for temple in city_acts.vow_candidates(state)[: vows.offered]:
        for cause in vows.causes:
            action = VowTemple(civ=state.player_civ, temple=temple.id, cause=cause.id)
            plan = city_acts.plan_vow(state, action)
            wealth = city_acts.vow_wealth(state)
            actions.append(
                _act(
                    f"vow:{temple.id}:{cause.id}",
                    f"Vow the {temple.english or temple.id} {cause.name}",
                    {"kind": "vow", "temple": temple.id, "cause": cause.id},
                    influence=vows.cost,
                    wealth=wealth,
                    forecast={
                        **plan.numbers,
                        "vower": plan.person,
                        "note": plan.why
                        or (
                            f"dedicated {year_label(plan.numbers['dedicated'])}, "
                            f"{plan.numbers['ahead']} years before history"
                        ),
                    },
                    why=plan.why,
                    watch="sacrifice",
                )
            )
    society = state.rome_society
    info = []
    if society is not None:
        rel = society.religion
        info.append(_info("Unexpiated prodigies", _num(rel.unexpiated), "they breed unrest"))
        info.append(
            _info(
                "The Sibylline Books",
                "lost" if rel.books_lost else "kept by the college",
                f"consulted {len(rel.consultations)} times",
            )
        )
        if rel.pontifex_maximus and state.republic is not None:
            chief = state.republic.people.get(rel.pontifex_maximus)
            if chief is not None:
                info.append(_info("Pontifex maximus", chief.name, ""))
    _put(places, found.monument, "temple", found.name, found.blurb, actions, info)


# ---------------------------------------------------------------- games


def _circus(state: GameState, places: dict[str, Place]) -> None:
    rules = _rules(state).games
    if rules is None:
        return
    calendar = state.world.republic_rules.city.ludi
    for entry in rules.circus:
        if place_of_year(state, [entry]) is None:
            continue
        action = GiveGames(civ=state.player_civ, games="ludi", venue=entry.monument)
        plan = city_acts.plan_games(state, action)
        actions = [
            _act(
                f"games:ludi:{entry.monument}",
                "Give races as aedile",
                {"kind": "games", "games": "ludi", "venue": entry.monument},
                wealth=city_acts.games_wealth(state, "ludi"),
                forecast={**plan.numbers, "giver": plan.person, "note": plan.why},
                why=plan.why,
                watch="race",
            )
        ]
        info = [
            _info(lu.name, f"month {lu.month}", f"since {year_label(lu.from_year)}")
            for lu in calendar
            if lu.venue == entry.monument and lu.from_year <= state.year
        ]
        _put(places, entry.monument, "circus", entry.name, entry.blurb, actions, info)


def _arenas(state: GameState, places: dict[str, Place]) -> None:
    rules = _rules(state).games
    city = state.city
    if rules is None or city is None:
        return
    dead = city_acts.honourees(state)[:HONOUREES_LISTED]
    blurbs = {e.monument: (e.name, e.blurb) for e in rules.munus_venues}
    for venue, name in city_acts.venues(state, "munus"):
        actions = []
        for man in dead:
            action = GiveGames(civ=state.player_civ, games="munus", venue=venue, honour=man.id)
            plan = city_acts.plan_games(state, action)
            actions.append(
                _act(
                    f"games:munus:{venue}:{man.id}",
                    f"Give a munus for {man.name}",
                    {"kind": "games", "games": "munus", "venue": venue, "honour": man.id},
                    wealth=city_acts.games_wealth(state, "munus"),
                    forecast={**plan.numbers, "giver": plan.person, "note": plan.why},
                    why=plan.why,
                    watch="munus",
                )
            )
        if not dead:
            actions.append(
                _act(
                    f"games:munus:{venue}",
                    "Give a munus",
                    {"kind": "games", "games": "munus", "venue": venue, "honour": ""},
                    why="no man of note has died in these last years",
                    watch="munus",
                )
            )
        title, blurb = blurbs.get(venue, (name, "A stone amphitheatre, ahead of its time."))
        _put(places, venue, "arena", title, blurb, actions, [])


# ---------------------------------------------------------------- the Campus and the gates


def _levy_forecast(state: GameState, size: str) -> tuple[dict[str, Any], str, int]:
    """What a levy of this size in Rome's own province would raise and cost, as ``raise`` does."""
    me = state.player_civ
    civ = state.civs[me]
    province = state.provinces.get(civ.capital)
    if province is None or province.owner != me:
        return {"note": "Rome does not hold its own land"}, "Rome does not hold its own land", 0
    men = levy_size(state, me, civ.capital, size)
    room = mobilisation_cap(state, me) - men_under_arms(state, me)
    men = min(men, room, province.population // 2)
    least = state.world.rules.armies.min_army
    if men < least:
        return {"men": max(0, men)}, "the realm cannot spare more men under arms", 0
    troops = composition(state, me, men, "balanced")
    men, troops = legions_levy(state, me, civ.capital, men, troops, "balanced")
    if men < least:
        return {"men": men}, "too few citizens of the classes are left to levy", 0
    food, materials, wealth = raise_cost(state, troops)
    stores = civ.stockpiles
    why = ""
    if stores.food < food or stores.materials < materials or stores.wealth < wealth:
        why = f"raising them needs {food} food, {materials} materials and {wealth} wealth"
    units = ", ".join(
        f"{n:,} {state.world.units[u].name.lower()}" for u, n in sorted(troops.items())
    )
    return (
        {
            "men": men,
            "legions": city_acts.legions_of(state, men),
            "food": food,
            "materials": materials,
            "wealth": wealth,
            "note": units,
        },
        why,
        wealth,
    )


def _campus(state: GameState, places: dict[str, Place]) -> None:
    found = city_acts.levy_place(state)
    if found is None:
        return
    me = state.player_civ
    capital = state.civs[me].capital
    actions = []
    for size in LEVY_SIZES:
        forecast, why, wealth = _levy_forecast(state, size)
        actions.append(
            _act(
                f"raise:{size}",
                f"Hold the levy: a {size} army ({_num(forecast.get('men', 0))} men)",
                {"kind": "raise", "province": capital, "size": size},
                wealth=wealth,
                forecast=forecast,
                why=why,
                watch="levy",
            )
        )
    info = []
    society = state.rome_society
    if society is not None:
        legions = society.legions
        era = era_at(state, state.year)
        info += [
            _info("The army", era.name if era is not None else legions.era, ""),
            _info(
                "Property qualification",
                f"{_num(legions.threshold_asses)} asses" if legions.threshold_asses else "none",
                "the census class below which a man is not levied",
            ),
            _info("Men who may be levied", _num(legions.assidui), "the assidui of the classes"),
            _info("Under arms", _num(legions.levied), "Rome's own men in the field"),
        ]
    _put(places, found.monument, "campus", found.name, found.blurb, actions, info)


def _gates(state: GameState, places: dict[str, Place]) -> None:
    me = state.player_civ
    armies = [a for a in state.armies.values() if a.owner == me and not a.garrison]
    triumphs = [e for e in state.city.events if e.kind == "triumph"] if state.city else []
    for entry in _rules(state).gates:
        if place_of_year(state, [entry]) is None:
            continue
        info = [
            _info(
                "Armies in the field", _num(len(armies)), _num(sum(a.men for a in armies)) + " men"
            ),
            _info("Triumphs this turn", _num(len(triumphs)), ""),
        ]
        _put(places, entry.monument, "gate", entry.name, entry.blurb, [], info)


# ---------------------------------------------------------------- workshops, harbours, works


def _trade(state: GameState, places: dict[str, Place]) -> None:
    me = state.player_civ
    civ = state.civs[me]
    limit = _rules(state).start_listed
    for entry in _rules(state).trade:
        if place_of_year(state, [entry]) is None:
            continue
        ideas = [
            nid
            for nid in sorted(civ.tech)
            if civ.tech[nid].stage is Stage.CONCEPT
            and nid not in civ.projects
            and nid in state.tech_nodes
            and state.tech_nodes[nid].category in entry.categories
        ]
        ready = [(nid, feasibility(state, me, nid)) for nid in ideas]
        ready.sort(key=lambda pair: (pair[1].blocked, state.tech_nodes[pair[0]].year, pair[0]))
        actions = []
        for nid, result in ready[:limit]:
            node = state.tech_nodes[nid]
            actions.append(
                _act(
                    f"start:{nid}",
                    f"Begin work on {node.name}",
                    {"kind": "start", "node_id": nid},
                    forecast={
                        "history_year": node.year,
                        "ahead": max(0, node.year - state.year),
                        "builds": node.builds or "",
                        "note": node.history,
                    },
                    why=describe_blockers(state, result) if result.blocked else "",
                    watch="building" if node.builds else "",
                )
            )
        actions.append(  # the client opens the idea box with the place as context
            _act(
                f"idea:{entry.monument}",
                "Whisper an idea to the people who could make it",
                {"kind": "idea", "context": entry.role},
                forecast={"categories": [c.value for c in entry.categories], "note": ""},
            )
        )
        info = [
            _info("Ideas worked here", ", ".join(c.value for c in entry.categories), ""),
            _info("Works under way", _num(len(civ.projects)), ""),
        ]
        _put(places, entry.monument, entry.role, entry.name, entry.blurb, actions, info)


def _works(state: GameState, places: dict[str, Place]) -> None:
    city = state.city
    assert city is not None
    civ = state.civs[state.player_civ]
    for work in city.anachronisms:
        info = [_info("Raised", year_label(work.year), f"{work.ahead} years before its time")]
        _put(
            places,
            work.id,
            "anachronism",
            work.name,
            f"A {work.builds.replace('_', ' ')}.",
            [],
            info,
        )
    standing = {a.tech for a in city.anachronisms}
    for tech in sorted(civ.projects):
        node = state.tech_nodes.get(tech)
        if node is None or not node.builds or tech in standing:
            continue
        project = civ.projects[tech]
        current = city_acts.chosen_site(state, tech)
        actions = []
        for site, where in city_acts.site_options(state, tech):
            if site == current:
                continue
            plan = city_acts.plan_site(
                state, ChooseSite(civ=state.player_civ, tech=tech, site=site)
            )
            actions.append(
                _act(
                    f"site:{tech}:{site}",
                    f"Build it at {where}",
                    {"kind": "site", "tech": tech, "site": site},
                    influence=_rules(state).site.cost,
                    forecast={"progress_bp": project.progress_bp, "note": where},
                    why=plan.why,
                    watch="building",
                )
            )
        here = dict(city_acts.site_options(state, tech)).get(current, current)
        info = [
            _info("Progress", _pct(project.progress_bp), "paused" if project.paused else ""),
            _info("Site", here, ""),
        ]
        blurb = (
            f"Work under way on {node.name.lower()}; history built it in {year_label(node.year)}."
        )
        _put(places, f"anachronism_{tech}", "anachronism", node.name, blurb, actions, info)


# ---------------------------------------------------------------- the houses of the families


def domus_owner(state: GameState, monument: str) -> tuple[str, str] | None:
    """The gens and the man holding a house this year, or ``None``.

    The rules' table (``places.domus``) gives owners of houses by years; a house this pass
    added (``role: domus`` in the dataset) belongs to its record's ``gens`` in the other years.
    """
    for owner in _rules(state).domus:
        if owner.monument == monument and owner.holds(state.year):
            return owner.gens, owner.owner
    record = state.world.monuments.get(monument)
    extra = (record.model_extra or {}) if record is not None else {}
    if extra.get("role") == "domus" and extra.get("gens"):
        return str(extra["gens"]), str(extra.get("owner", ""))
    return None


def _domus(state: GameState, places: dict[str, Place]) -> None:
    city = state.city
    rep = state.republic
    assert city is not None
    assert rep is not None
    rules = state.world.republic_rules
    houses = {o.monument for o in _rules(state).domus}
    houses |= {
        mid
        for mid, m in state.world.monuments.items()
        if (m.model_extra or {}).get("role") == "domus"
    }
    weights = senate_weights(state) if rep.families else {}
    for mid in sorted(houses):
        status = city.standing.get(mid)
        found = domus_owner(state, mid)
        if status is None or status.state != "standing" or found is None:
            continue
        gens_id, owner = found
        gens = state.world.gentes.get(gens_id)
        if gens is None:
            continue
        family = rep.families.get(gens_id)
        living = [p for p in rep.people.values() if p.alive and p.gens == gens_id]
        in_office = sorted(
            f"{m.name} ({state.world.magistracies[m.office].name.lower()})"
            for m in rep.magistrates
            if m.person in {p.id for p in living}
        )
        actions = []
        for issue in Issue:
            if family is None:
                actions.append(
                    _act(
                        f"persuade:{gens_id}:{issue.value}",
                        f"Win over the {gens.name} on {issue.value}",
                        {"kind": "persuade", "family": gens_id, "issue": issue.value},
                        influence=rules.persuade_cost,
                        why=f"the {gens.name} have no voice in the Senate this year",
                    )
                )
                continue
            lean = senate_vote(state, issue).by_family.get(gens_id, 0)
            actions.append(_persuade(state, gens_id, issue, lean, weights))
        info = [
            _info("Family", gens.name, f"{gens.order.value}"),
            _info("Living men", _num(len(living)), ""),
            _info("In office", ", ".join(in_office) or "none", ""),
        ]
        if family is not None:
            info.append(
                _info("Standing", f"dignitas {family.dignitas_bp}", f"clients {family.clients}")
            )
        monument = state.world.monuments[mid]
        title = monument.english or mid
        blurb = f"The house of {owner}." if owner else f"A house of the {gens.name}."
        _put(places, mid, "domus", title, blurb, actions, info)
        places[mid]["gens"] = gens_id


# ---------------------------------------------------------------- the whole


def places_view(state: GameState) -> dict[str, Any] | None:
    """Every place of the year with its role, actions and info, or ``None`` outside the Republic.

    Keyed by monument id (an idea's work is ``anachronism_<idea>``). A building with two roles
    in the year (the Comitium as platform and assembly before 338) is one place: ``role`` is
    its first, ``roles`` all of them, the actions of both.
    """
    if state.city is None or state.republic is None:
        return None
    places: dict[str, Place] = {}
    proposals = _proposals(state)
    issues = sorted(
        {Issue(p["issue"]) for p in proposals if not p["proposal"].startswith("fund:")},
        key=list(Issue).index,
    )
    _curia(state, places, proposals)
    _rostra(state, places, issues)
    _assemblies(state, places)
    _treasury(state, places, proposals)
    _temples(state, places)
    _circus(state, places)
    _arenas(state, places)
    _campus(state, places)
    _gates(state, places)
    _trade(state, places)
    _works(state, places)
    _domus(state, places)
    return dict(sorted(places.items()))
