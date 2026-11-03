"""The player's politics as logged actions (R2 follow-up): persuade, back, propose to the Senate."""

# ruff: noqa: PT018

from __future__ import annotations

import dataclasses
import json

import pytest
from pydantic import TypeAdapter

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import Issue, Order, RelationStatus
from anachronism.engine.actions import (
    Action,
    BackCandidate,
    DeclareWar,
    Persuade,
    ProposeToSenate,
)
from anachronism.engine.events import EventLog
from anachronism.engine.game import apply_action, end_turn, new_game, replay
from anachronism.engine.republic import run_year as republic_run_year
from anachronism.engine.republic import senate_vote
from anachronism.engine.rivals import declare_war, status
from anachronism.engine.rng import GameRng
from anachronism.engine.save import dumps, loads
from anachronism.engine.senate import available, interposition, resolve
from anachronism.engine.state import GameState
from anachronism.tools.republic_view import republic_view

SEEDS = (1, 2, 3)
ACTION = TypeAdapter[Action](Action)


@pytest.fixture(scope="module")
def content() -> Content:
    """The real packs plus a Republic scenario in 264 BC made from the Punic Wars one."""
    base = load_content()
    punic = base.scenarios["punic_wars"]
    scenario = punic.model_copy(
        update={
            "id": "rome_264",
            "start_year": -264,
            "years_per_turn": 1,
            "campaign_years_per_turn": None,
            "republic": True,
        }
    )
    return dataclasses.replace(base, scenarios={**base.scenarios, "rome_264": scenario})


def fresh(content: Content, seed: int = 1, influence: int = 10_000) -> GameState:
    state = new_game(content, "rome_264", seed=seed)
    assert state.republic is not None
    state.republic.influence = influence
    return state


def sway(state: GameState, issue: Issue, *, yes: set[str], no: set[str]) -> None:
    """Set the families' leaning on an issue: ``yes`` for, ``no`` against, the rest neutral."""
    rep = state.republic
    assert rep is not None
    for fid in sorted(rep.families):
        stance = state.world.gentes[fid].stances.get(issue, 0)
        target = 2000 if fid in yes else -2000 if fid in no else 0
        rep.families[fid].favour[issue.value] = target - stance


def set_rules(state: GameState, **update: object) -> None:
    """Change the game's frozen republic rules (as a test fixture; replays copy the start)."""
    rules = state.world.republic_rules.model_copy(update=update)
    state.world = state.world.model_copy(update={"republic_rules": rules})


def everyone(state: GameState, issue: Issue, lean: int) -> None:
    rep = state.republic
    assert rep is not None
    for fid in sorted(rep.families):
        stance = state.world.gentes[fid].stances.get(issue, 0)
        rep.families[fid].favour[issue.value] = lean - stance


def senate_events(state: GameState) -> list[tuple[str, int, int]]:
    assert state.city is not None
    return [(e.ref, e.value, e.other) for e in state.city.events if e.kind == "senate"]


def war_with_carthage() -> ProposeToSenate:
    return ProposeToSenate(civ="rome", issue="war", proposal="war_with:carthage")


def test_action_shapes_parse_as_the_bridge_sends_them() -> None:
    persuade = ACTION.validate_python(
        {"kind": "persuade", "civ": "rome", "family": "cornelii", "issue": "land"}
    )
    back = ACTION.validate_python(
        {"kind": "back", "civ": "rome", "person": "p_12", "office": "consul"}
    )
    senate = ACTION.validate_python(
        {"kind": "senate", "civ": "rome", "issue": "war", "proposal": "war_with:carthage"}
    )
    assert isinstance(persuade, Persuade) and persuade.family == "cornelii"
    assert isinstance(back, BackCandidate) and back.office == "consul"
    assert isinstance(senate, ProposeToSenate) and senate.proposal == "war_with:carthage"


def test_a_war_the_senate_votes_for_is_declared(content: Content) -> None:
    state = fresh(content)
    assert status(state, "rome", "carthage") is not RelationStatus.WAR
    everyone(state, Issue.WAR, 6000)
    before = state.republic.influence  # type: ignore[union-attr]
    state, logged = apply_action(state, war_with_carthage())
    assert logged.ok, logged.message
    assert status(state, "rome", "carthage") is RelationStatus.WAR
    rep = state.republic
    assert rep is not None
    assert rep.influence == before - state.world.republic_rules.senate.costs.war_with
    assert [b.outcome for b in rep.ballots] == ["passed"]
    # one recorded vote, not two (the declaration knows the Senate has voted)
    assert senate_events(state) == [("war", 10_000, 0)]
    assert any(e.kind == "senate" for e in state.events)


def test_a_war_the_senate_refuses_does_not_happen(content: Content) -> None:
    state = fresh(content)
    everyone(state, Issue.WAR, -3000)
    rep = state.republic
    assert rep is not None
    rules = state.world.republic_rules.senate
    legitimacy = state.civs["rome"].stats.legitimacy_bp
    favour = {fid: f.favour[Issue.WAR.value] for fid, f in rep.families.items()}
    state, logged = apply_action(state, war_with_carthage())
    assert logged.ok  # the vote was held
    assert "refuses" in logged.message
    assert status(state, "rome", "carthage") is not RelationStatus.WAR
    rep = state.republic
    assert rep is not None
    assert rep.influence == 10_000 - rules.costs.war_with - rules.fail_influence_loss
    assert state.civs["rome"].stats.legitimacy_bp == legitimacy - rules.fail_legitimacy_bp
    for fid, f in rep.families.items():  # those who voted no remember
        assert f.favour[Issue.WAR.value] == favour[fid] - rules.opposed_favour_shift
    assert senate_events(state) == [("war", 0, 10_000)]
    assert [b.outcome for b in rep.ballots] == ["failed"]


def test_bad_proposals_are_rejected_and_change_nothing(content: Content) -> None:
    state = fresh(content)
    everyone(state, Issue.WAR, 6000)
    before = dumps(state)
    cases = [
        ProposeToSenate(civ="rome", issue="war", proposal="war_with:nowhere"),
        ProposeToSenate(civ="rome", issue="war", proposal="make_a_pie"),
        ProposeToSenate(civ="rome", issue="peace", proposal="war_with:carthage"),  # wrong issue
        ProposeToSenate(civ="rome", issue="gossip", proposal="war_with:carthage"),
        ProposeToSenate(civ="rome", issue="peace", proposal="peace_with:carthage"),  # no war
        ProposeToSenate(civ="rome", issue="land", proposal="law:no_such_law"),
        ProposeToSenate(civ="rome", issue="colony", proposal="colony:carthage"),  # not Roman land
        ProposeToSenate(civ="carthage", issue="war", proposal="war_with:rome"),  # not the player
    ]
    for action in cases:
        after, logged = apply_action(state, action)
        assert not logged.ok, action
        assert after.republic == state.republic and after.city == state.city
        assert dumps(after.model_copy(update={"action_log": []})) == before
    poor = fresh(content, influence=10)
    everyone(poor, Issue.WAR, 6000)
    poor, logged = apply_action(poor, war_with_carthage())
    assert not logged.ok and "influence" in logged.message
    assert poor.republic is not None and poor.republic.influence == 10


def test_peace_goes_through_the_senate_too(content: Content) -> None:
    state = fresh(content)
    everyone(state, Issue.WAR, 6000)
    state, logged = apply_action(state, war_with_carthage())
    assert logged.ok
    everyone(state, Issue.PEACE, 6000)
    assert resolve(state, "peace_with:carthage")[0] is not None
    assert resolve(state, "war_with:carthage")[0] is None
    state, logged = apply_action(
        state, ProposeToSenate(civ="rome", issue="peace", proposal="peace_with:carthage")
    )
    assert logged.ok, logged.message
    assert "votes for it" in logged.message
    assert [b.issue for b in state.republic.ballots] == ["war", "peace"]  # type: ignore[union-attr]


def test_laws_and_colonies_set_flags_the_content_can_read(content: Content) -> None:
    state = fresh(content)
    everyone(state, Issue.LAND, 6000)
    everyone(state, Issue.COLONY, 6000)
    state, logged = apply_action(
        state, ProposeToSenate(civ="rome", issue="land", proposal="land_reform")
    )  # a bare law id is a law
    assert logged.ok and "becomes law" in logged.message, logged.message
    rep = state.republic
    assert rep is not None and rep.laws == {"land_reform": -264}
    state, logged = apply_action(
        state, ProposeToSenate(civ="rome", issue="land", proposal="law:land_reform")
    )
    assert not logged.ok and "already law" in logged.message
    state, logged = apply_action(
        state, ProposeToSenate(civ="rome", issue="colony", proposal="colony:rom_latium")
    )
    assert logged.ok and "rom_latium" in state.republic.colonies, logged.message  # type: ignore[union-attr]
    # a law has its years: the grain dole is the Gracchi's, not for 264 BC
    assert resolve(state, "law:grain_dole")[0] is None
    state.year = -120
    assert resolve(state, "law:grain_dole")[0] is not None


def test_funding_a_work_begins_the_project(content: Content) -> None:
    state = fresh(content)
    options = [p for p in available(state) if p.proposal.startswith("fund:")]
    assert options, "no work to fund"
    choice = options[0]
    everyone(state, choice.issue, 6000)
    state, logged = apply_action(
        state, ProposeToSenate(civ="rome", issue=choice.issue.value, proposal=choice.proposal)
    )
    assert logged.ok, logged.message
    node = choice.proposal.removeprefix("fund:")
    assert node in state.civs["rome"].projects


def test_persuade_moves_a_family_and_costs_influence(content: Content) -> None:
    state = fresh(content)
    rep = state.republic
    assert rep is not None
    rules = state.world.republic_rules
    before = rep.families["cornelii"].favour.get("land", 0)
    state, logged = apply_action(state, Persuade(civ="rome", family="cornelii", issue="land"))
    assert logged.ok, logged.message
    rep = state.republic
    assert rep is not None
    assert rep.families["cornelii"].favour["land"] == before + rules.persuade_shift
    assert rep.influence == 10_000 - rules.persuade_cost
    for bad in (
        Persuade(civ="rome", family="nosuch", issue="land"),
        Persuade(civ="rome", family="cornelii", issue="gossip"),
        Persuade(civ="carthage", family="cornelii", issue="land"),
    ):
        after, logged = apply_action(state, bad)
        assert not logged.ok
        assert after.republic == state.republic
    state.republic.influence = 0  # type: ignore[union-attr]
    _, logged = apply_action(state, Persuade(civ="rome", family="cornelii", issue="land"))
    assert not logged.ok


def _candidate(state: GameState) -> str:
    """The least famous living patrician, made of age and with no office held."""
    rep = state.republic
    assert rep is not None
    man = min(
        (p for p in rep.people.values() if p.alive and p.order is Order.PATRICIAN),
        key=lambda p: (p.glory, p.id),
    )
    man.born = state.year + 1 - 50
    man.glory = 0
    man.offices.clear()
    return man.id


def test_backing_a_candidate_decides_an_election_when_large(content: Content) -> None:
    def wins(seed: int, backed: bool) -> bool:
        state = fresh(content, seed)
        rules = state.world.republic_rules
        set_rules(state, backing_bp=10_000_000)  # the weight of a backing, made enormous
        man = _candidate(state)
        if backed:
            state, logged = apply_action(
                state, BackCandidate(civ="rome", person=man, office="consul")
            )
            assert logged.ok, logged.message
            assert state.republic.influence == 10_000 - rules.back_cost  # type: ignore[union-attr]
        state, _ = end_turn(state)
        assert state.republic is not None
        return man in [m.person for m in state.republic.magistrates if m.office == "consul"]

    assert all(wins(seed, backed=True) for seed in SEEDS)
    # the same man, unbacked, is a poor choice: left to the draw he does not always win
    assert not all(wins(seed, backed=False) for seed in SEEDS)
    assert wins(1, backed=True) == wins(1, backed=True)


def test_backing_twice_and_without_influence_is_refused(content: Content) -> None:
    state = fresh(content)
    man = _candidate(state)
    state, logged = apply_action(state, BackCandidate(civ="rome", person=man, office="consul"))
    assert logged.ok, logged.message
    state, logged = apply_action(state, BackCandidate(civ="rome", person=man, office="consul"))
    assert not logged.ok and "already" in logged.message
    state.republic.influence = 0  # type: ignore[union-attr]
    _, logged = apply_action(state, BackCandidate(civ="rome", person="nobody", office="consul"))
    assert not logged.ok


def _make_popular(state: GameState, popular: set[str], others: set[str]) -> None:
    """Families in ``popular`` lean to the populares, those in ``others`` to the optimates."""
    for fid in popular:
        state.world.gentes[fid] = state.world.gentes[fid].model_copy(
            update={"popular_lean_bp": 9000}
        )
    for fid in others:
        state.world.gentes[fid] = state.world.gentes[fid].model_copy(
            update={"popular_lean_bp": 1000}
        )


def _certain_tribune(state: GameState) -> None:
    senate = state.world.republic_rules.senate.model_copy(
        update={"veto_scale_bp": 10_000, "veto_max_bp": 10_000}
    )
    set_rules(state, senate=senate)


def _split(state: GameState) -> tuple[set[str], set[str]]:
    rep = state.republic
    assert rep is not None
    ids = sorted(rep.families)
    return set(ids[: len(ids) // 2]), set(ids[len(ids) // 2 :])


def test_a_tribune_can_block_a_vote_that_would_pass(content: Content) -> None:
    state = fresh(content)
    _certain_tribune(state)
    left, right = _split(state)
    _make_popular(state, popular=right, others=left)  # the losing side is the popular one
    sway(state, Issue.WAR, yes=left, no=right)
    # weigh the sides so the yes side wins
    rep = state.republic
    assert rep is not None
    for fid in left:
        rep.families[fid].auctoritas_bp += 100_000
    stand = interposition(state, senate_vote(state, Issue.WAR))
    assert stand.kind == "veto" and stand.chance_bp == 8000 and stand.tribune
    favour = {fid: f.favour[Issue.WAR.value] for fid, f in rep.families.items()}
    state, logged = apply_action(state, war_with_carthage())
    assert logged.ok and "interposes" in logged.message
    assert status(state, "rome", "carthage") is not RelationStatus.WAR
    rep = state.republic
    assert rep is not None
    assert [b.outcome for b in rep.ballots] == ["vetoed"]
    assert rep.influence == 10_000 - state.world.republic_rules.senate.costs.war_with
    assert {fid: f.favour[Issue.WAR.value] for fid, f in rep.families.items()} == favour


def test_a_tribune_can_carry_a_matter_the_senate_refused(content: Content) -> None:
    state = fresh(content)
    _certain_tribune(state)
    left, right = _split(state)
    _make_popular(state, popular=left, others=right)  # the minority that wants it is popular
    sway(state, Issue.WAR, yes=left, no=right)
    rep = state.republic
    assert rep is not None
    for fid in right:
        rep.families[fid].auctoritas_bp += 100_000
    favour = {fid: f.favour[Issue.WAR.value] for fid, f in rep.families.items()}
    state, logged = apply_action(state, war_with_carthage())
    assert logged.ok and "carries it" in logged.message, logged.message
    assert status(state, "rome", "carthage") is RelationStatus.WAR
    rep = state.republic
    assert rep is not None
    rules = state.world.republic_rules.senate
    assert [b.outcome for b in rep.ballots] == ["forced"]
    assert rep.influence == 10_000 - rules.costs.war_with  # no failure penalty
    for fid in right:  # but the families that opposed it are angrier
        assert rep.families[fid].favour[Issue.WAR.value] == favour[fid] - rules.forced_favour_shift
    for fid in left:
        assert rep.families[fid].favour[Issue.WAR.value] == favour[fid]


def test_no_tribune_means_no_interposition_and_no_forcing_before_287(content: Content) -> None:
    state = fresh(content)
    left, right = _split(state)
    _make_popular(state, popular=left, others=right)
    sway(state, Issue.WAR, yes=left, no=right)
    rep = state.republic
    assert rep is not None
    for fid in right:
        rep.families[fid].auctoritas_bp += 100_000
    vote = senate_vote(state, Issue.WAR)
    assert not vote.passes and interposition(state, vote).kind == "force"
    state.year = -300  # before the Lex Hortensia a tribune cannot carry it to the plebs
    assert interposition(state, vote).kind == ""
    state.year = -264
    rep.magistrates = [m for m in rep.magistrates if m.office != "tribune_plebs"]
    assert interposition(state, vote).kind == ""


def test_wars_the_engine_makes_are_voted_on_for_the_player(content: Content) -> None:
    state = fresh(content)
    assert state.city is not None
    # a declaration by the player outside ProposeToSenate (the plain DeclareWar action)
    state, logged = apply_action(state, DeclareWar(civ="rome", target="carthage"))
    assert logged.ok
    assert [e[0] for e in senate_events(state)] == ["war"]
    # a rival's declaration on Rome, made while a turn resolves, keeps its vote for that turn
    other = fresh(content)
    events = EventLog(turn=other.turn + 1, year=other.year)
    declare_war(other, "carthage", "rome", events)
    assert [e[0] for e in senate_events(other)] == ["war"]
    other.turn += 1
    other.year += 1
    republic_run_year(other, GameRng(other.rng), events, other.year)
    assert [e[0] for e in senate_events(other)] == ["war"]
    # wars between others are none of the Senate's business
    third = fresh(content)
    declare_war(third, "carthage", "syracuse", EventLog(turn=1, year=third.year))
    assert senate_events(third) == []


def test_the_view_lists_proposals_with_the_senates_forecast(content: Content) -> None:
    state = fresh(content)
    everyone(state, Issue.WAR, 6000)
    view = republic_view(state)
    assert view is not None
    assert view["influence_costs"] == {"persuade": 150, "back": 250}
    proposals = {p["proposal"]: p for p in view["proposals"]}
    war = proposals["war_with:carthage"]
    assert set(war) == {
        "issue",
        "proposal",
        "label",
        "cost",
        "forecast_yes_bp",
        "forecast_no_bp",
        "passes",
        "tribune",
        "tribune_bp",
    }
    assert war["issue"] == "war" and war["cost"] == 200
    assert (war["forecast_yes_bp"], war["forecast_no_bp"]) == (10_000, 0)
    assert "law:land_reform" in proposals and "law:grain_dole" not in proposals
    assert view["last_votes"] == []
    state, _ = apply_action(state, war_with_carthage())
    view = republic_view(state)
    assert view is not None
    assert view["last_votes"] == [
        {
            "issue": "war",
            "year": -264,
            "turn": 0,
            "yes_bp": 10_000,
            "no_bp": 0,
            "house": view["last_votes"][0]["house"],
            "proposal": "war_with:carthage",
            "outcome": "passed",
        }
    ]
    assert "war_with:carthage" not in {p["proposal"] for p in view["proposals"]}
    assert "peace_with:carthage" in {p["proposal"] for p in view["proposals"]}
    json.dumps(view)  # everything is plain data


def _play(content: Content, seed: int) -> tuple[GameState, GameState]:
    """A short game with the player's politics scripted in; returns (start, end)."""
    state = fresh(content, seed)
    set_rules(state, backing_bp=1_000_000)
    # the start of the game (copied below), not actions: a split Senate on the land question,
    # the refusing side the heavier, the minority popular and a tribune who may carry it
    _certain_tribune(state)
    left, right = _split(state)
    _make_popular(state, popular=left, others=right)
    sway(state, Issue.LAND, yes=left, no=right)
    for fid in right:
        state.republic.families[fid].auctoritas_bp += 100_000  # type: ignore[union-attr]
    man = _candidate(state)
    initial = state.model_copy(deep=True)
    script: dict[int, list[Action]] = {
        0: [
            Persuade(civ="rome", family="cornelii", issue="war"),
            ProposeToSenate(civ="rome", issue="land", proposal="law:land_reform"),
            BackCandidate(civ="rome", person=man, office="consul"),
        ],
        1: [war_with_carthage(), Persuade(civ="rome", family="claudii", issue="war")],
        2: [ProposeToSenate(civ="rome", issue="war", proposal="war_with:syracuse")],
    }
    for turn in range(4):
        for action in script.get(turn, []):
            state, _ = apply_action(state, action)
        state, _ = end_turn(state)
    return initial, state


@pytest.mark.parametrize("seed", SEEDS)
def test_the_politics_replay_exactly_and_save_cleanly(content: Content, seed: int) -> None:
    initial, final = _play(content, seed)
    assert any(e.action.kind in ("persuade", "senate", "back") for e in final.action_log)
    assert [b.outcome for b in final.republic.ballots][:1] == ["forced"]  # type: ignore[union-attr]
    rebuilt = replay(initial, final.action_log, until_turn=final.turn)
    assert dumps(rebuilt) == dumps(final)
    text = dumps(final)
    assert dumps(loads(text)) == text
    assert loads(text).republic == final.republic


def test_the_politics_are_deterministic_and_seeds_differ(content: Content) -> None:
    dumped = {seed: dumps(_play(content, seed)[1]) for seed in SEEDS}
    for seed in SEEDS:
        assert dumps(_play(content, seed)[1]) == dumped[seed]
    assert len(set(dumped.values())) == len(SEEDS)
