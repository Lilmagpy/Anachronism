"""The player's politics in the Senate (R2 follow-up, D-286): persuade, back, propose.

Rome is not ruled by its player: he asks. A consul (or a tribune) brings a matter to the
Senate (the ``relatio``: Aulus Gellius 14.7.9, unverified) and the Senate votes; the Senate
handles war, embassies and the treasury (Polybius 6.13.5-9) but the people deliberate on war
and peace and ratify treaties (Polybius 6.14.10-12), and a tribune of the plebs can stop the
Senate by interposing (Polybius 6.16.4; Livy 2.33.1-3). The vote is ``republic.senate_vote``,
weighted by the families' standing; here are the proposals, the tribune and what follows.

Every action here is an ordinary logged action, so a replay applies it again. The only
randomness is the tribune's chance, drawn from the state's ``GameRng`` and only when it is
above zero. Numbers are in ``republic_rules.senate`` (content), none are hard-coded.
"""

from __future__ import annotations

from dataclasses import dataclass

from anachronism.content.schema import Issue, RelationStatus, Stage
from anachronism.engine.actions import (
    BackCandidate,
    DeclareWar,
    MakePeace,
    Persuade,
    ProposeToSenate,
)
from anachronism.engine.diplomacy import apply_diplomacy
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP, clamp
from anachronism.engine.projects import begin_project
from anachronism.engine.republic import (
    Vote,
    back_candidate,
    family_weight,
    persuade,
    senate_vote,
)
from anachronism.engine.republic_state import Ballot, RepublicState
from anachronism.engine.rivals import alive, status
from anachronism.engine.rng import GameRng
from anachronism.engine.state import GameState
from anachronism.engine.tech import describe_blockers, feasibility, is_adopted

KINDS = ("war_with", "peace_with", "law", "fund", "colony")
"""The kinds of proposal: the part of ``proposal`` before the colon."""
FUND_LIST = 12
COLONY_LIST = 10
BALLOTS_KEPT = 20
"""How many of the player's recent matters the state remembers."""


@dataclass(frozen=True)
class Proposal:
    """One thing the player can put to the Senate."""

    issue: Issue
    proposal: str
    """``war_with:carthage``, ``law:land_reform``, ..."""
    label: str
    cost: int
    """Influence it costs to bring it, whatever the vote."""


@dataclass(frozen=True)
class Interposition:
    """A tribune of the plebs who may stand in the way, or carry the matter to the people."""

    kind: str
    """``veto`` (the Senate would pass it, the tribune may block it), ``force`` (the Senate
    would refuse it, the tribune may carry it), or ``""`` (no tribune acts)."""
    chance_bp: int
    tribune: str = ""
    """The name of the tribune."""


def _rep(state: GameState) -> RepublicState:
    assert state.republic is not None
    return state.republic


def _place(state: GameState, province_id: str) -> str:
    geo = state.world.geography.get(province_id)
    return geo.name if geo is not None else province_id


def split_proposal(state: GameState, proposal: str) -> tuple[str, str]:
    """``war_with:carthage`` -> ``("war_with", "carthage")``; a bare law id is a law."""
    kind, _, arg = proposal.partition(":")
    if not arg and any(law.id == kind for law in state.world.republic_rules.senate.laws):
        return "law", kind
    return kind, arg


def resolve(state: GameState, proposal: str) -> tuple[Proposal | None, str]:
    """What a proposal is (its issue, label and cost), or why it cannot be put now."""
    rep = _rep(state)
    rules = state.world.republic_rules.senate
    me = state.player_civ
    kind, arg = split_proposal(state, proposal)
    if kind not in KINDS:
        return None, f"the Senate does not know the proposal {proposal!r}"
    cost = int(getattr(rules.costs, kind))
    if kind in ("war_with", "peace_with"):
        other = state.civs.get(arg)
        if other is None or arg == me:
            return None, f"unknown state {arg!r}"
        if not alive(state, arg):
            return None, f"{other.name} is no more"
        current = status(state, me, arg)
        if current is None:
            return None, f"{other.name} is out of reach"
        if kind == "war_with":
            if current is RelationStatus.WAR:
                return None, f"already at war with {other.name}"
            return Proposal(Issue.WAR, f"war_with:{arg}", f"Declare war on {other.name}", cost), ""
        if current is not RelationStatus.WAR:
            return None, f"not at war with {other.name}"
        return Proposal(Issue.PEACE, f"peace_with:{arg}", f"Make peace with {other.name}", cost), ""
    if kind == "law":
        law = next((x for x in rules.laws if x.id == arg), None)
        if law is None:
            return None, f"unknown law {arg!r}"
        if not law.open_in(state.year):
            return None, f"{law.name} is not before the Senate in this age"
        if law.id in rep.laws:
            return None, f"{law.name} is already law"
        return Proposal(law.issue, f"law:{law.id}", law.name, cost), ""
    if kind == "fund":
        node = state.tech_nodes.get(arg)
        civ = state.civs[me]
        if node is None:
            return None, f"unknown work {arg!r}"
        if is_adopted(civ, arg):
            return None, f"{node.name} is already in use"
        if arg in civ.projects:
            return None, f"work on {node.name} is already under way"
        result = feasibility(state, me, arg)
        if result.blocked:
            return None, f"{node.name} cannot be begun: {describe_blockers(state, result)}"
        issue = Issue.BUILDING if node.builds else Issue.IDEA
        return Proposal(issue, f"fund:{arg}", f"Fund {node.name}", cost), ""
    province = state.provinces.get(arg)
    if province is None:
        return None, f"unknown province {arg!r}"
    if province.owner != me:
        return None, "a colony can only be founded on Roman land"
    if arg in rep.colonies:
        return None, "a colony is already resolved there"
    label = f"Found a colony in {_place(state, arg)}"
    return Proposal(Issue.COLONY, f"colony:{arg}", label, cost), ""


def available(state: GameState) -> list[Proposal]:
    """What the player can put to the Senate now (the view lists these), in a stable order."""
    rules = state.world.republic_rules.senate
    civ = state.civs[state.player_civ]
    wanted = [f"{kind}:{cid}" for kind in ("war_with", "peace_with") for cid in sorted(state.civs)]
    wanted += [f"law:{law.id}" for law in sorted(rules.laws, key=lambda x: x.id)]
    funds = [
        nid
        for nid in sorted(state.tech_nodes)
        if state.tech_nodes[nid].builds
        or (nid in civ.tech and civ.tech[nid].stage is Stage.CONCEPT)
    ]
    out: list[Proposal] = []
    for text in wanted:
        found, _ = resolve(state, text)
        if found is not None:
            out.append(found)
    listed = 0
    for nid in funds:
        found, _ = resolve(state, f"fund:{nid}")
        if found is not None and listed < FUND_LIST:
            out.append(found)
            listed += 1
    listed = 0
    for pid in state.owned_provinces(state.player_civ):
        found, _ = resolve(state, f"colony:{pid}")
        if found is not None and listed < COLONY_LIST:
            out.append(found)
            listed += 1
    return out


def _side_lean(state: GameState, vote: Vote, sign: int) -> int | None:
    """How popular (``popular_lean_bp``, weighted) the families on one side of a vote are."""
    rep = _rep(state)
    total = weight = 0
    for fid in sorted(vote.by_family):
        if vote.by_family[fid] * sign > 0:
            w = family_weight(rep.families[fid])
            total += w * state.world.gentes[fid].popular_lean_bp
            weight += w
    return total // weight if weight else None


def interposition(state: GameState, vote: Vote) -> Interposition:
    """Whether a tribune of the plebs may block this vote or carry the matter to the people.

    The tribune acts for the more popular side: the chance grows with how much more popular
    (``popular_lean_bp``, weighted by the families' standing) the losing side of the vote is
    than the winning side, up to a small ceiling. A veto is possible from the tribunate's
    start (Livy 2.33.1-3); carrying a refused matter to the plebs, from the Lex Hortensia.
    """
    rules = state.world.republic_rules.senate
    rep = _rep(state)
    tribunes = sorted(
        (m for m in rep.magistrates if m.office == rules.veto_office), key=lambda m: m.person
    )
    if not tribunes:
        return Interposition("", 0)
    yes, no = _side_lean(state, vote, 1), _side_lean(state, vote, -1)
    if yes is None or no is None:
        return Interposition("", 0)
    if vote.passes:
        kind, edge, from_year = "veto", no - yes, rules.veto_from_year
    else:
        kind, edge, from_year = "force", yes - no, rules.force_from_year
    if state.year < from_year or edge <= 0:
        return Interposition("", 0)
    chance = min(rules.veto_max_bp, edge * rules.veto_scale_bp // BP)
    return Interposition(kind, chance, tribunes[0].name) if chance > 0 else Interposition("", 0)


def _punish(state: GameState, vote: Vote, issue: Issue, shift: int, *, lose_standing: bool) -> None:
    """The families that voted no remember; a refused player also loses a little standing."""
    rep = _rep(state)
    rules = state.world.republic_rules.senate
    for fid in sorted(vote.by_family):
        if vote.by_family[fid] < 0:
            family = rep.families[fid]
            now = family.favour.get(issue.value, 0)
            family.favour[issue.value] = clamp(now - shift, -BP, BP)
    if lose_standing:
        rep.influence = max(0, rep.influence - rules.fail_influence_loss)
        stats = state.civs[state.player_civ].stats
        stats.legitimacy_bp = clamp(stats.legitimacy_bp - rules.fail_legitimacy_bp, 0, BP)


def _enact(state: GameState, found: Proposal) -> str:
    """Carry out what the Senate has resolved, through the engine's own paths."""
    rep = _rep(state)
    me = state.player_civ
    kind, arg = split_proposal(state, found.proposal)
    if kind == "war_with":
        return apply_diplomacy(state, DeclareWar(civ=me, target=arg), voted=True)[1]
    if kind == "peace_with":
        return apply_diplomacy(state, MakePeace(civ=me, target=arg))[1]
    if kind == "law":
        rep.laws[arg] = state.year
        return f"{found.label} becomes law."
    if kind == "colony":
        rep.colonies[arg] = state.year
        return f"A colony is resolved in {_place(state, arg)}."
    return begin_project(state, me, arg)[1]


def propose_to_senate(state: GameState, action: ProposeToSenate) -> tuple[bool, str]:
    """Put a matter to the Senate: spend influence, hold a recorded vote, then follow it.

    Rejected at once (``False``, nothing changes) if the proposal is unknown, closed, does not
    belong to ``issue`` or costs more than the player's influence. Otherwise the vote is held
    and the result is ``True`` whatever the outcome: ``passed`` (it takes effect), ``failed``
    (nothing happens but the player loses a little influence and legitimacy, and the families
    that voted no turn against him on the issue), ``vetoed`` (a tribune blocked a vote that
    would have passed; no further loss) or ``forced`` (a tribune carried a refused matter to
    the plebs: it takes effect and the families that opposed it are angrier still).
    """
    rep = state.republic
    if rep is None or action.civ != state.player_civ:
        return False, "only the Republic's own court addresses the Senate"
    try:
        issue = Issue(action.issue)
    except ValueError:
        return False, f"the Senate has no question called {action.issue!r}"
    found, why = resolve(state, action.proposal)
    if found is None:
        return False, why
    if found.issue is not issue:
        return False, f"that is a matter of {found.issue.value}, not {issue.value}"
    if rep.influence < found.cost:
        return False, f"not enough influence with the Senate ({found.cost} needed)"
    rules = state.world.republic_rules.senate
    rep.influence -= found.cost
    vote = senate_vote(state, issue, record=True)
    stand = interposition(state, vote)
    interposed = stand.chance_bp > 0 and GameRng(state.rng).chance(stand.chance_bp)
    pct = f"{vote.yes_bp // 100}% to {vote.no_bp // 100}%"
    if vote.passes and not interposed:
        outcome, text = "passed", f"The Senate votes for it, {pct}. {_enact(state, found)}"
    elif vote.passes:
        outcome = "vetoed"
        text = f"The Senate votes for it, {pct}, but the tribune {stand.tribune} interposes."
    elif interposed:
        outcome = "forced"
        _punish(state, vote, issue, rules.forced_favour_shift, lose_standing=False)
        text = (
            f"The Senate refuses it, {pct}, but the tribune {stand.tribune} carries it to the"
            f" people over their heads. {_enact(state, found)}"
        )
    else:
        outcome = "failed"
        _punish(state, vote, issue, rules.opposed_favour_shift, lose_standing=True)
        text = f"The Senate refuses it, {pct}. The families that opposed it will not forget."
    rep.ballots.append(
        Ballot(
            turn=state.turn,
            year=state.year,
            issue=issue.value,
            proposal=found.proposal,
            yes_bp=vote.yes_bp,
            no_bp=vote.no_bp,
            outcome=outcome,
        )
    )
    del rep.ballots[:-BALLOTS_KEPT]
    events = EventLog(turn=state.turn, year=state.year)
    events.add(action.civ, "senate", text, issue.value)
    state.events.extend(events.items)
    return True, text


def persuade_family(state: GameState, action: Persuade) -> tuple[bool, str]:
    """``Persuade``: spend influence to win a family over on an issue."""
    if state.republic is None or action.civ != state.player_civ:
        return False, "only the Republic's own court wins over the Senate"
    try:
        issue = Issue(action.issue)
    except ValueError:
        return False, f"the Senate has no question called {action.issue!r}"
    return persuade(state, action.family, issue)


def back_man(state: GameState, action: BackCandidate) -> tuple[bool, str]:
    """``BackCandidate``: spend influence to back a man at the next election."""
    if state.republic is None or action.civ != state.player_civ:
        return False, "only the Republic's own court backs a candidate"
    return back_candidate(state, action.person, action.office)
