"""Rival civilisations: contacts, news, awareness, scripts and free agents (brief §7).

- **News** of an adoption far ahead of its time travels outward from the inventor, a
  border at a time, faster along friendly ties and when people already whisper about the
  inventor (suspicion), slower when the inventor guards its secrets. Far news often arrives
  garbled; the truth follows later. A civilisation only reacts to what it has heard.
- **Awareness** (§7.2): on-script civilisations play out their scripts; aware ones still
  do, but also copy what they have heard of; free agents (wronged by the player, or at war
  with them) abandon their scripts and act on their ruler's temperament.
- **Scripts** (§7.1) fire when their preconditions hold, and lapse when their moment
  passes, their target is gone, or a script they depend on lapsed (§7.4).

Everything here is deterministic: civilisations in id order, randomness from the game RNG.
"""

from __future__ import annotations

from collections import deque
from collections.abc import Mapping

from anachronism.content.schema import (
    Disposition,
    EffectType,
    RelationStatus,
    Script,
    ScriptGoal,
    Stage,
)
from anachronism.engine.actions import Explain, Priority
from anachronism.engine.decrees import apply_decree, cost, explain_costs, explain_ready_in
from anachronism.engine.economy import Costs, labour, project_costs
from anachronism.engine.effects import Effects, civ_effects
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, apply_bp, clamp, div_round
from anachronism.engine.projects import hasten, hasten_cost
from anachronism.engine.reports import capacity
from anachronism.engine.rng import GameRng
from anachronism.engine.state import (
    Awareness,
    Event,
    GameState,
    Heard,
    NewsInTransit,
    Project,
    Relation,
    TechState,
    World,
)
from anachronism.engine.tech import feasibility, is_adopted, propose
from anachronism.engine.timeflow import rate_per_turn


def key(a: str, b: str) -> str:
    """The relations key of a pair, ids sorted."""
    return f"{a}|{b}" if a < b else f"{b}|{a}"


def relation(state: GameState, a: str, b: str) -> Relation | None:
    """How ``a`` and ``b`` stand, or ``None`` if they cannot reach each other."""
    return state.relations.get(key(a, b))


def status(state: GameState, a: str, b: str) -> RelationStatus | None:
    """The status of a pair, or ``None`` if they have no contact."""
    found = relation(state, a, b)
    return found.status if found else None


def alive(state: GameState, civ_id: str) -> bool:
    """True while a civilisation still holds land."""
    return bool(state.owned_provinces(civ_id))


# --- geography ----------------------------------------------------------------------------


def province_links(world: World) -> dict[str, set[str]]:
    """Each province's land neighbours plus the provinces across a shared sea."""
    links: dict[str, set[str]] = {pid: set(g.neighbours) for pid, g in world.geography.items()}
    for sea in world.seas.values():
        shore = [p for p in sea.neighbours if p in links]
        for p in shore:
            links[p].update(q for q in shore if q != p)
    return links


def contact_pairs(world: World, owners: Mapping[str, str | None]) -> set[tuple[str, str]]:
    """Pairs of civilisations whose lands touch by land or across a sea."""
    pairs: set[tuple[str, str]] = set()
    for pid, linked in province_links(world).items():
        a = owners.get(pid)
        for other in linked:
            b = owners.get(other)
            if a and b and a != b:
                pairs.add((min(a, b), max(a, b)))
    return pairs


def hops(state: GameState, source: str, target: str) -> int | None:
    """Borders news must cross from ``source``'s lands to ``target``'s (``None``: unreachable)."""
    links = province_links(state.world)
    start = state.owned_provinces(source)
    goal = set(state.owned_provinces(target))
    seen = set(start)
    queue = deque((pid, 0) for pid in start)
    while queue:
        pid, distance = queue.popleft()
        if pid in goal:
            return distance
        for nxt in sorted(links.get(pid, ())):
            if nxt not in seen:
                seen.add(nxt)
                queue.append((nxt, distance + 1))
    return None


def frontier(state: GameState, attacker: str, defender: str) -> list[str]:
    """``defender``'s provinces that ``attacker`` can reach: by land first, else by sea."""
    owned = set(state.owned_provinces(attacker))
    land = sorted(
        pid
        for pid in state.owned_provinces(defender)
        if owned & set(state.world.geography[pid].neighbours)
    )
    if land:
        return land
    links = province_links(state.world)
    return sorted(pid for pid in state.owned_provinces(defender) if owned & links.get(pid, set()))


# --- strength ----------------------------------------------------------------------------


def strength(state: GameState, civ_id: str, effects: Effects | None = None) -> int:
    """Military strength: workforce, raised by military advancements and legitimacy.

    A ruler people trust can raise and keep an army.
    """
    if not alive(state, civ_id):
        return 0
    effects = effects if effects is not None else civ_effects(state, civ_id)
    workers = labour(state, civ_id, effects).workforce
    base = apply_bp(workers, state.world.rules.rivals.strength_per_worker_bp)
    base = apply_bp(base, state.civs[civ_id].martial_bp)
    if state.civs[civ_id].mercenaries > 0:
        base = apply_bp(base, BP + state.world.rules.rivals.mercenary_strength_bp)
    base = apply_bp(base, BP + effects[EffectType.MILITARY_STRENGTH])
    return apply_bp(base, 5000 + state.civs[civ_id].stats.legitimacy_bp // 2)


def at_war(state: GameState, civ_id: str) -> list[str]:
    """Civilisations ``civ_id`` is at war with, sorted."""
    enemies = []
    for pair, rel in sorted(state.relations.items()):
        if rel.status is RelationStatus.WAR and civ_id in pair.split("|"):
            a, b = pair.split("|")
            enemies.append(b if a == civ_id else a)
    return enemies


def grievance(state: GameState, holder: str, against: str) -> int:
    """How much ``holder`` resents ``against``."""
    rel = relation(state, holder, against)
    return rel.grievance.get(holder, 0) if rel else 0


def add_grievance(state: GameState, holder: str, against: str, amount: int) -> None:
    """Add to ``holder``'s grudge against ``against`` (capped at 100%)."""
    rel = relation(state, holder, against)
    if rel is not None:
        rel.grievance[holder] = clamp(rel.grievance.get(holder, 0) + amount, 0, BP)


def set_status(state: GameState, a: str, b: str, new: RelationStatus) -> Relation:
    """Change a pair's status (creating the pair if they had no contact before)."""
    rel = state.relations.setdefault(key(a, b), Relation(status=new, since_turn=state.turn))
    if rel.status is not new:
        rel.status = new
        rel.since_turn = state.turn
    if new is not RelationStatus.WAR:
        rel.weariness.clear()
        rel.losses.clear()
    return rel


def declare_war(
    state: GameState, attacker: str, defender: str, events: EventLog, why: str = ""
) -> None:
    """Start a war; the defender's allies join it (and so the ripples spread, §7.4)."""
    if status(state, attacker, defender) is RelationStatus.WAR:
        return
    set_status(state, attacker, defender, RelationStatus.WAR)
    add_grievance(state, defender, attacker, 1000)
    # the player's own historical intention against this state has now come to pass, so
    # the plans of others that waited on it (Hannibal's war on the First Punic War) can follow
    for script in state.world.scripts.get(attacker, ()):
        if (
            attacker == state.player_civ
            and script.goal is ScriptGoal.CONQUER
            and script.target == defender
            and script.id not in state.scripts_fired
            and script.id not in state.scripts_lapsed
        ):
            state.scripts_fired[script.id] = state.turn
    a, d = state.civs[attacker], state.civs[defender]
    events.add(
        attacker, "war", f"War: the {a.adjective} court marches against {d.name}.{why}", d.name
    )
    events.add(defender, "war", f"The {a.adjective} court has declared war on {d.name}.", a.name)
    for pair, rel in sorted(state.relations.items()):
        protects = rel.status in (RelationStatus.ALLIED, RelationStatus.TRIBUTARY)
        if not protects or defender not in pair.split("|"):
            continue
        ally = next(c for c in pair.split("|") if c != defender)
        if ally == attacker or not alive(state, ally):
            continue
        if status(state, ally, attacker) is RelationStatus.WAR:
            continue
        if ally == state.player_civ:  # the player is told, and decides
            events.add(
                ally,
                "ally_attacked",
                f"The {a.adjective} court has attacked your friend {d.name}."
                " Will you march to their aid?",
                d.name,
            )
            continue
        set_status(state, ally, attacker, RelationStatus.WAR)
        events.add(
            ally,
            "war",
            f"The {state.civs[ally].adjective} court honours its bond with {d.name}"
            f" and marches against {a.name}.",
            a.name,
        )
    if defender == state.player_civ or attacker == state.player_civ:
        other = attacker if defender == state.player_civ else defender
        if state.civs[other].awareness is not Awareness.FREE_AGENT:
            state.civs[other].awareness = Awareness.FREE_AGENT


# --- news ---------------------------------------------------------------------------------


def spread_news(
    state: GameState, new_events: list[Event], effects_by_civ: dict[str, Effects], rng: GameRng
) -> None:
    """Send word of adoptions far ahead of their time toward every other civilisation."""
    rules = state.world.rules.rivals
    by_name = {node.name: node_id for node_id, node in state.tech_nodes.items()}
    for event in new_events:
        if event.kind != "adopted" or event.civ is None or event.subject not in by_name:
            continue
        node_id = by_name[event.subject]
        if state.tech_nodes[node_id].year - state.year < rules.news_ahead_years:
            continue
        inventor = state.civs[event.civ]
        effects = effects_by_civ.get(event.civ) or civ_effects(state, event.civ)
        for civ_id in sorted(state.civs):
            if civ_id == event.civ or not alive(state, civ_id):
                continue
            distance = hops(state, event.civ, civ_id)
            if distance is None:
                continue
            years = max(1, distance) * rules.news_years_per_hop
            rel = relation(state, event.civ, civ_id)
            if rel is not None and rel.status.friendly:
                years //= 2
            years = apply_bp(years, BP - inventor.stats.suspicion_bp // 2)  # people talk
            years = apply_bp(years, BP + effects[EffectType.SECRECY])
            if inventor.sealed:
                years = apply_bp(years, BP + rules.seal_news_bp)
            turns = max(1, div_round(years, state.world.years_per_turn))
            garbled_bp = clamp(max(0, distance - 1) * rules.garble_per_hop_bp, 0, 9000)
            garbled = rng.chance(garbled_bp)
            arrive = state.turn + turns
            state.news.append(
                NewsInTransit(
                    to_civ=civ_id,
                    about=event.civ,
                    node_id=node_id,
                    arrives_turn=arrive,
                    garbled=garbled,
                )
            )
            if garbled:
                later = arrive + max(1, div_round(rules.clarify_years, state.world.years_per_turn))
                state.news.append(
                    NewsInTransit(
                        to_civ=civ_id,
                        about=event.civ,
                        node_id=node_id,
                        arrives_turn=later,
                        garbled=False,
                    )
                )


def deliver_news(state: GameState, events: EventLog) -> None:
    """News that has arrived by now; hearing about the player makes a civilisation aware."""
    waiting = []
    for item in state.news:
        if item.arrives_turn > state.turn:
            waiting.append(item)
            continue
        civ = state.civs[item.to_civ]
        if any(
            h.node_id == item.node_id and h.about == item.about and not h.garbled for h in civ.heard
        ):
            continue
        civ.heard.append(
            Heard(about=item.about, node_id=item.node_id, turn=state.turn, garbled=item.garbled)
        )
        if item.about == state.player_civ:
            if civ.awareness is Awareness.ON_SCRIPT:
                civ.awareness = Awareness.AWARE
            node = state.tech_nodes[item.node_id]
            about = state.civs[item.about]
            if item.garbled:
                text = f"Rumours reach {civ.name} of strange doings in {about.name}."
            else:
                text = f"The {civ.adjective} court has heard of the {about.adjective} {node.name}."
            events.add(state.player_civ, "news", text, civ.name)
    state.news = waiting


# --- rivals' own decisions ------------------------------------------------------------------


def start_project(state: GameState, civ_id: str, node_id: str) -> bool:
    """A rival begins experimenting with an advancement, if it can and can afford the work."""
    civ = state.civs[civ_id]
    if node_id in civ.projects or is_adopted(civ, node_id) or node_id not in state.tech_nodes:
        return False
    if feasibility(state, civ_id, node_id).blocked:
        return False
    # a sensible court takes on only what its spare hands can carry: work beyond the surplus
    # pulls farmers off the fields, and famine and riots follow. What it cannot carry at
    # full pace it does as steady work (low priority: spare hands only, D-112), one at a time.
    priority = Priority.NORMAL
    if project_costs(state, node_id).labour > capacity(state, civ_id).free_labour:
        steady = [p for p in civ.projects.values() if p.priority is Priority.LOW]
        if steady or capacity(state, civ_id).free_labour <= 0:
            return False
        priority = Priority.LOW
    propose(state, civ_id, node_id)
    civ.tech[node_id] = TechState(stage=Stage.EXPERIMENTING)
    civ.projects[node_id] = Project(node_id=node_id, started_turn=state.turn, priority=priority)
    return True


def _imitate(state: GameState, civ_id: str, rng: GameRng, events: EventLog) -> None:
    civ = state.civs[civ_id]
    chance = state.world.rules.rivals.imitation_chance_bp
    for heard in civ.heard:
        if heard.garbled or heard.node_id in civ.projects or is_adopted(civ, heard.node_id):
            continue
        if feasibility(state, civ_id, heard.node_id).blocked:
            continue
        if rng.chance(chance) and start_project(state, civ_id, heard.node_id):
            name = state.tech_nodes[heard.node_id].name
            if heard.about == state.player_civ:
                events.add(
                    state.player_civ,
                    "imitation",
                    f"The {civ.adjective} court is trying to copy your {name}.",
                    civ.name,
                )
            return


def _preconditions_met(
    state: GameState, civ_id: str, script: Script, strengths: dict[str, int]
) -> bool:
    need = script.preconditions
    civ = state.civs[civ_id]
    if need.after_year is not None and state.year < need.after_year:
        return False
    if civ.stats.legitimacy_bp < need.min_legitimacy_bp or civ.stats.unrest_bp > need.max_unrest_bp:
        return False
    if any(not is_adopted(civ, t) for t in need.adopted):
        return False
    if need.at_peace and at_war(state, civ_id):
        return False
    if script.goal is not ScriptGoal.ADOPT:
        target = state.civs[script.target]
        if target.stats.unrest_bp < need.target_min_unrest_bp:
            return False
        if need.min_strength_ratio_bp:
            ours, theirs = strengths.get(civ_id, 0), strengths.get(script.target, 0)
            if ours * BP < need.min_strength_ratio_bp * max(1, theirs):
                return False
    return all(d in state.scripts_fired for d in script.depends_on)


def _lapses(state: GameState, script: Script) -> str:
    """Why a script can no longer happen, or ``""``."""
    need = script.preconditions
    if need.before_year is not None and state.year > need.before_year:
        return "its moment passed"
    if script.goal is not ScriptGoal.ADOPT and not alive(state, script.target):
        return "its target is gone"
    if any(d in state.scripts_lapsed for d in script.depends_on):
        return "what it depended on never happened"
    return ""


def _fire(state: GameState, civ_id: str, script: Script, events: EventLog) -> bool:
    civ = state.civs[civ_id]
    current = status(state, civ_id, script.target) if script.goal is not ScriptGoal.ADOPT else None
    if script.goal is ScriptGoal.CONQUER:
        if current is RelationStatus.ALLIED:
            return False  # not while allied; the script waits
        declare_war(state, civ_id, script.target, events)
    elif script.goal is ScriptGoal.ALLY:
        if current is RelationStatus.WAR:
            return False
        set_status(state, civ_id, script.target, RelationStatus.ALLIED)
        events.add(
            civ_id,
            "alliance",
            f"{civ.name} and {state.civs[script.target].name} form an alliance.",
            state.civs[script.target].name,
        )
    elif script.goal is ScriptGoal.TRADE:
        if current in (RelationStatus.WAR, RelationStatus.ALLIED, RelationStatus.TRIBUTARY):
            return current is not RelationStatus.WAR
        set_status(state, civ_id, script.target, RelationStatus.TRADING)
    elif not start_project(state, civ_id, script.target):
        return False
    return True


def run_scripts(state: GameState, strengths: dict[str, int], events: EventLog) -> None:
    """Fire every script whose moment has come; lapse those whose moment has gone."""
    changed = True
    while changed:  # lapses ripple through dependencies
        changed = False
        for civ_id in sorted(state.world.scripts):
            for script in state.world.scripts[civ_id]:
                if script.id in state.scripts_fired or script.id in state.scripts_lapsed:
                    continue
                if _lapses(state, script) or not alive(state, civ_id):
                    state.scripts_lapsed[script.id] = state.turn
                    changed = True
    for civ_id in sorted(state.world.scripts):
        civ = state.civs[civ_id]
        if (
            civ_id == state.player_civ
            or civ.awareness is Awareness.FREE_AGENT
            or not alive(state, civ_id)
        ):
            continue
        for script in state.world.scripts[civ_id]:
            if script.id in state.scripts_fired or script.id in state.scripts_lapsed:
                continue
            if _preconditions_met(state, civ_id, script, strengths) and _fire(
                state, civ_id, script, events
            ):
                state.scripts_fired[script.id] = state.turn


def pending_scripts(state: GameState, civ_id: str) -> list[Script]:
    """A court's intentions that have neither come to pass nor lapsed."""
    return [
        s
        for s in state.world.scripts.get(civ_id, ())
        if s.id not in state.scripts_fired and s.id not in state.scripts_lapsed
    ]


def free_agents(
    state: GameState, strengths: dict[str, int], rng: GameRng, events: EventLog
) -> None:
    """Civilisations off their scripts act on their temperament (brief §7.2).

    So do courts whose scripted plans are all spent (D-116): history has run out of
    instructions for them, and they make their own.
    """
    rules = state.world.rules.rivals
    for civ_id in sorted(state.civs):
        civ = state.civs[civ_id]
        if civ_id == state.player_civ or not alive(state, civ_id):
            continue
        if civ.awareness is not Awareness.FREE_AGENT and pending_scripts(state, civ_id):
            continue
        neighbours = sorted(
            other
            for pair in state.relations
            for other in pair.split("|")
            if civ_id in pair.split("|") and other != civ_id and alive(state, other)
        )
        warlike = civ.disposition is Disposition.AGGRESSIVE
        # other temperaments fight too, rarely: over an old grudge, against a far weaker foe
        chance = rules.aggressive_war_chance_bp if warlike else rules.aggressive_war_chance_bp // 5
        if (
            civ.disposition is not Disposition.MERCANTILE
            and not at_war(state, civ_id)
            and civ.stats.unrest_bp < 4000
            and rng.chance(chance)
        ):
            # the weakest neighbour it clearly outmatches; the player's court first if wronged
            targets = [
                n
                for n in neighbours
                if status(state, civ_id, n) is not RelationStatus.ALLIED
                and strengths.get(civ_id, 0) * 2 >= strengths.get(n, 0) * (3 if warlike else 4)
                and (warlike or grievance(state, civ_id, n) >= 3000)
            ]
            targets.sort(key=lambda n: (-grievance(state, civ_id, n), strengths.get(n, 0), n))
            if targets:
                target = targets[0]
                # a court far stronger often takes tribute instead of war (never from
                # the player, whose submission is the player's own choice)
                overawed = strengths.get(civ_id, 0) * BP >= (
                    strengths.get(target, 0) * rules.tribute_strength_ratio_bp
                )
                if overawed and target != state.player_civ and rng.chance(BP // 2):
                    set_status(state, civ_id, target, RelationStatus.TRIBUTARY)
                    add_grievance(state, target, civ_id, 1000)
                else:
                    declare_war(state, civ_id, target, events)
        if civ.disposition is Disposition.MERCANTILE:
            for other in neighbours:
                if (
                    status(state, civ_id, other) is RelationStatus.NEUTRAL
                    and grievance(state, civ_id, other) < 2000
                ):
                    set_status(state, civ_id, other, RelationStatus.TRADING)
                    if other == state.player_civ:
                        events.add(
                            other,
                            "alliance",
                            f"The {civ.adjective} court opens its markets to your merchants.",
                            civ.name,
                        )
                    break


def rival_decrees(state: GameState, events: EventLog) -> None:
    """Rival courts spend their treasuries too: swords for hire in wartime, feasts in unrest.

    A court keeps half its treasury in reserve, so decrees never empty it.
    """
    rules = state.world.rules.rivals
    for civ_id in sorted(state.civs):
        civ = state.civs[civ_id]
        if civ_id == state.player_civ or not alive(state, civ_id):
            continue
        if at_war(state, civ_id) and civ.mercenaries == 0:
            price = cost(state, civ_id, rules.mercenary_wealth_per_1000)
            if civ.stockpiles.wealth >= price * 2:
                civ.stockpiles.wealth -= price
                civ.mercenaries = rules.mercenary_turns
                from anachronism.engine.armies import hire_company  # armies builds on rivals

                hire_company(state, civ_id, rules.mercenary_turns)
                events.add(
                    civ_id,
                    "decree",
                    f"The {civ.adjective} court hires swords for its war.",
                    civ.name,
                )
                continue
        if civ.stats.suspicion_bp >= 4000 and not explain_ready_in(state, civ_id):
            wealth, _ = explain_costs(state, civ_id)
            if civ.stockpiles.wealth >= wealth * 2:  # priests proclaim the new arts divine
                apply_decree(state, Explain(civ=civ_id, story="divine"))
                continue
        if civ.stats.unrest_bp >= 3000 or civ.stats.legitimacy_bp < 2000:
            price = cost(state, civ_id, rules.festival_wealth_per_1000)
            if civ.stockpiles.wealth >= price * 2:
                civ.stockpiles.wealth -= price
                civ.stats.legitimacy_bp = clamp(
                    civ.stats.legitimacy_bp + rules.festival_legitimacy_bp, 0, BP
                )
                civ.stats.unrest_bp = clamp(civ.stats.unrest_bp - rules.festival_unrest_bp, 0, BP)


def rich_enough(state: GameState, civ_id: str, price: Costs, times: int = 5) -> bool:
    """True when the stores hold ``times`` the price in every resource it asks for."""
    stores = state.civs[civ_id].stockpiles
    return (
        stores.materials >= price.materials * times
        and stores.knowledge >= price.knowledge * times
        and stores.wealth >= price.wealth * times
    )


def rival_hastening(state: GameState) -> None:
    """Rich rival courts pay to hasten their work rather than let their stores pile up."""
    for civ_id in sorted(state.civs):
        civ = state.civs[civ_id]
        if civ_id == state.player_civ or not alive(state, civ_id):
            continue
        for node_id in sorted(civ.projects):
            if rich_enough(state, civ_id, hasten_cost(state, node_id)):
                hasten(state, civ, node_id)


def coalitions(state: GameState, rng: GameRng, events: EventLog) -> None:
    """A player grown too great frightens the others into leagues (the balance of power).

    Once the player rules a large share of the region's people (and more than at the
    start), two neighbours of the
    player that are at peace with each other may ally against them: at most one new
    league a turn.
    """
    rules = state.world.rules.rivals
    me = state.player_civ
    everyone = sum(state.population(c) for c in state.civs)
    # it is growth that frightens: a state that began great must grow further still
    threshold = max(rules.coalition_share_bp, state.victory_start.get("military", 0) + 1000)
    if state.population(me) * BP < everyone * threshold:
        return
    wary = [
        c
        for c in sorted(state.civs)
        if c != me
        and alive(state, c)
        and status(state, me, c) is not None
        and status(state, me, c) not in (RelationStatus.ALLIED, RelationStatus.TRIBUTARY)
    ]
    for i, a in enumerate(wary):
        for b in wary[i + 1 :]:
            if status(state, a, b) not in (RelationStatus.NEUTRAL, RelationStatus.TRADING):
                continue
            if not rng.chance(rules.coalition_chance_bp):
                continue
            set_status(state, a, b, RelationStatus.ALLIED)
            names = f"the {state.civs[a].adjective} and {state.civs[b].adjective} courts"
            events.add(me, "coalition", f"Fearing your power, {names} have allied.", names)
            return


def update_awareness(state: GameState) -> None:
    """Aware civilisations with a deep grudge against the player leave their scripts."""
    threshold = state.world.rules.rivals.free_agent_grievance_bp
    for civ_id in sorted(state.civs):
        civ = state.civs[civ_id]
        if civ_id == state.player_civ or civ.awareness is not Awareness.AWARE:
            continue
        if grievance(state, civ_id, state.player_civ) >= threshold:
            civ.awareness = Awareness.FREE_AGENT


def fade_grievances(state: GameState) -> None:
    """Old wrongs are slowly forgotten."""
    fade = rate_per_turn(state, state.world.rules.rivals.grievance_fade_bp)
    for _, rel in sorted(state.relations.items()):
        for holder in sorted(rel.grievance):
            rel.grievance[holder] -= apply_bp(rel.grievance[holder], fade)


def rivals_turn(
    state: GameState,
    effects_by_civ: dict[str, Effects],
    new_events: list[Event],
    rng: GameRng,
    events: EventLog,
) -> dict[str, int]:
    """The rivals' part of a turn. Returns each civilisation's military strength."""
    spread_news(state, new_events, effects_by_civ, rng)
    deliver_news(state, events)
    update_awareness(state)
    rival_decrees(state, events)
    rival_hastening(state)
    strengths = {c: strength(state, c, effects_by_civ.get(c)) for c in sorted(state.civs)}
    for civ_id in sorted(state.civs):
        civ = state.civs[civ_id]
        if (
            civ_id != state.player_civ
            and civ.awareness is not Awareness.ON_SCRIPT
            and alive(state, civ_id)
        ):
            _imitate(state, civ_id, rng, events)
    run_scripts(state, strengths, events)
    free_agents(state, strengths, rng, events)
    coalitions(state, rng, events)
    fade_grievances(state)
    return strengths
