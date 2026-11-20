"""F2 places (D-304): the places of the year, what the player does there, and its spectacles."""

from __future__ import annotations

import json

import pytest
from pydantic import TypeAdapter

from anachronism.content.loader import Content, load_content
from anachronism.content.schema import Issue, Stage
from anachronism.engine import city_acts
from anachronism.engine.actions import (
    Action,
    ChooseSite,
    Contio,
    DeclareWar,
    GiveGames,
    RaiseArmy,
    StartProject,
    VowTemple,
)
from anachronism.engine.city import senate_house, status_map
from anachronism.engine.events import EventLog
from anachronism.engine.game import apply_action, end_turn, new_game, replay
from anachronism.engine.republic import kill_person, senate_vote
from anachronism.engine.rivals import declare_war
from anachronism.engine.save import dumps, loads
from anachronism.engine.state import GameState, TechState
from anachronism.tools.city_view import city_view
from anachronism.tools.places_view import domus_owner, places_view

SEEDS = (1, 2, 3)
STARTS = ("rome_509", "rome_390", "rome_340", "rome_264", "rome_133", "rome_49")
ACTION = TypeAdapter[Action](Action)
ROLES = {
    "senate_house",
    "rostra",
    "assembly",
    "treasury",
    "temple",
    "circus",
    "arena",
    "campus",
    "gate",
    "workshop",
    "harbour",
    "domus",
    "anachronism",
}
WATCHES = {
    "",
    "senate",
    "contio",
    "election",
    "sacrifice",
    "race",
    "munus",
    "levy",
    "triumph",
    "building",
}


@pytest.fixture(scope="module")
def content() -> Content:
    """The real packs."""
    return load_content()


def fresh(content: Content, seed: int = 1, scenario: str = "rome_264") -> GameState:
    state = new_game(content, scenario, seed=seed)
    assert state.republic is not None
    state.republic.influence = 10_000
    state.civs[state.player_civ].stockpiles.wealth = 1_000_000
    return state


def at_year(state: GameState, year: int) -> GameState:
    """The same game moved to another year's city (for the places of that year)."""
    state = state.model_copy(deep=True)
    state.year = year
    assert state.city is not None
    state.city.year = year
    state.city.standing = status_map(state.world, year, state.city.vows)
    return state


def act(state: GameState, action: Action) -> tuple[GameState, bool, str]:
    new, logged = apply_action(state, action)
    return new, logged.ok, logged.message


def turn_events(state: GameState, kind: str) -> list[object]:
    assert state.city is not None
    return [e for e in state.city.events if e.kind == kind and e.turn == state.turn]


# ---------------------------------------------------------------- the contract


def test_new_actions_parse_as_the_bridge_sends_them() -> None:
    raw = [
        {"kind": "contio", "civ": "rome", "issue": "land", "side": "for"},
        {"kind": "contio", "civ": "rome", "issue": "candidate", "side": "p1", "office": "consul"},
        {"kind": "vow", "civ": "rome", "temple": "aedes_fidei", "cause": "battle"},
        {"kind": "games", "civ": "rome", "games": "ludi", "venue": "circus_maximus"},
        {"kind": "games", "civ": "rome", "games": "munus", "venue": "forum_boarium", "honour": "p"},
        {"kind": "site", "civ": "rome", "tech": "amphitheatre", "site": "amphitheatre_campus"},
    ]
    kinds = [type(ACTION.validate_python(r)).__name__ for r in raw]
    assert kinds == ["Contio", "Contio", "VowTemple", "GiveGames", "GiveGames", "ChooseSite"]


@pytest.mark.parametrize("scenario", STARTS)
def test_every_start_has_places_to_the_contract(content: Content, scenario: str) -> None:
    state = new_game(content, scenario, seed=1)
    places = places_view(state)
    assert places is not None
    json.dumps(places)  # plain data
    assert any(p["role"] == "senate_house" for p in places.values())
    for mid, place in places.items():
        assert mid in state.world.monuments or mid.startswith("anachronism_"), mid
        assert place["role"] in ROLES
        assert set(place) >= {"role", "title", "blurb", "actions", "info"}
        for item in place["info"]:
            assert set(item) == {"label", "value", "tip"}
            assert all(isinstance(v, str) for v in item.values())
        for entry in place["actions"]:
            assert set(entry) == {
                "id",
                "label",
                "action",
                "cost",
                "forecast",
                "enabled",
                "why",
                "watch",
            }
            assert entry["watch"] in WATCHES
            assert set(entry["cost"]) == {"influence", "wealth"}
            assert entry["enabled"] == (entry["why"] == "")
            ACTION.validate_python({**entry["action"], "civ": state.player_civ})
        ids = [a["id"] for a in place["actions"]]
        assert len(ids) == len(set(ids)), mid


def test_every_enabled_action_of_264_is_accepted(content: Content) -> None:
    state = fresh(content)
    places = places_view(state)
    assert places is not None
    tried = 0
    for place in places.values():
        for entry in place["actions"]:
            if not entry["enabled"]:
                continue
            action = ACTION.validate_python({**entry["action"], "civ": state.player_civ})
            _, ok, message = act(state, action)
            assert ok, (entry["id"], message)
            tried += 1
    assert tried > 50


def test_places_view_is_wired_into_the_view(content: Content) -> None:
    from anachronism.tools.view import build_view

    view = build_view(new_game(content, "rome_264", seed=1))
    assert view["places"]["curia_hostilia"]["title"] == "Curia Hostilia"


# ---------------------------------------------------------------- the places follow history


@pytest.mark.parametrize(
    ("year", "house", "title"),
    [
        (-264, "curia_hostilia", "Curia Hostilia"),
        (-81, "curia_hostilia", "Curia Hostilia"),
        (-80, "curia_hostilia", "Curia Cornelia"),
        (-53, "curia_hostilia", "Curia Cornelia"),
        (-52, "curia_pompeia", "Curia Pompeia"),
        (-45, "curia_pompeia", "Curia Pompeia"),
        (-44, "curia_iulia", "Curia Iulia"),
        (-30, "curia_iulia", "Curia Iulia"),
    ],
)
def test_the_senate_meets_in_the_house_of_the_year(
    content: Content, year: int, house: str, title: str
) -> None:
    state = at_year(new_game(content, "rome_264", seed=1), year)
    assert senate_house(state) == house
    places = places_view(state)
    assert places is not None
    assert places[house]["role"] == "senate_house"
    assert places[house]["title"] == title
    others = [m for m, p in places.items() if p["role"] == "senate_house"]
    assert others == [house]


@pytest.mark.parametrize(
    ("year", "rostra", "tribes", "centuries", "levy", "treasury"),
    [
        (-440, "comitium", "comitium", "campus_martius", "campus_martius", "aedes_saturni"),
        (-264, "rostra_republic", "comitium", "campus_martius", "villa_publica", "aedes_saturni"),
        (
            -145,
            "rostra_republic",
            "forum_romanum",
            "campus_martius",
            "villa_publica",
            "aedes_saturni",
        ),
        (
            -44,
            "rostra_augusti",
            "forum_romanum",
            "campus_martius",
            "villa_publica",
            "aedes_saturni",
        ),
    ],
)
def test_the_rostra_assemblies_levy_and_treasury_by_year(
    content: Content,
    year: int,
    rostra: str,
    tribes: str,
    centuries: str,
    levy: str,
    treasury: str,
) -> None:
    state = at_year(new_game(content, "rome_264", seed=1), year)
    places = places_view(state)
    assert places is not None
    roles = {mid: set(p["roles"]) for mid, p in places.items()}
    assert "rostra" in roles[rostra]
    assert "assembly" in roles[tribes]
    assert "assembly" in roles[centuries]
    assert "campus" in roles[levy]
    assert "treasury" in roles[treasury]
    gone = {"rostra_republic"} if year >= -44 else {"rostra_augusti"}
    assert not any("rostra" in roles.get(m, set()) for m in gone)


def test_only_standing_temples_are_places(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    places = places_view(state)
    assert places is not None
    assert state.city is not None
    temples = [m for m, p in places.items() if "temple" in p["roles"]]
    assert "aedes_saturni" in temples  # the treasury is a temple too
    assert all(state.city.standing[m].state == "standing" for m in temples)
    assert "aedes_magnae_matris" not in temples  # 191 BC


def test_the_forum_stands_before_its_shops_burned_in_210(content: Content) -> None:
    for year in (-500, -264, -211, -210, -209):
        assert status_map(content_world(content), year)["forum_romanum"].state == "standing"


def content_world(content: Content):  # type: ignore[no-untyped-def]
    return new_game(content, "rome_264", seed=1).world


def test_houses_belong_to_their_families_in_their_years(content: Content) -> None:
    state = new_game(content, "rome_264", seed=1)
    for year, house, gens in [
        (-500, "domus_valerii_velia", "valerii"),
        (-500, "domus_cassii_carinae", "cassii"),
        (-190, "domus_scipionis_africani", "cornelii"),
        (-92, "domus_livii_drusi", "livii"),
        (-70, "domus_livii_drusi", "licinii"),
        (-60, "domus_ciceronis", "tullii"),
        (-60, "domus_pompeii_carinae", "pompeii"),
        (-40, "domus_pompeii_carinae", "antonii"),
        (-55, "domus_clodii", "claudii"),
    ]:
        moved = at_year(state, year)
        assert (domus_owner(moved, house) or ("", ""))[0] == gens, (year, house)
        places = places_view(moved)
        assert places is not None
        assert places[house]["role"] == "domus"
        assert places[house]["gens"] == gens
        assert [a["action"]["kind"] for a in places[house]["actions"]] == ["persuade"] * len(Issue)
    assert domus_owner(at_year(state, -100), "domus_ciceronis") is None
    late = places_view(at_year(state, -400))
    assert late is not None
    assert "domus_cassii_carinae" not in late  # razed 485


# ---------------------------------------------------------------- contio


def test_a_contio_moves_the_popular_families_most(content: Content) -> None:
    state = fresh(content)
    rules = state.world.republic_rules.city.places.contio
    speaker, weight = city_acts.speakers(state)[0]
    assert speaker.office in ("consul", "tribune_plebs", "dictator")
    before = senate_vote(state, Issue.LAND)
    plan = city_acts.plan_contio(state, Contio(civ="rome", issue="land", side="for"))
    forecast = senate_vote(state, Issue.LAND, extra=plan.shifts)
    new, ok, message = act(state, Contio(civ="rome", issue="land", side="for"))
    assert ok, message
    assert new.republic is not None
    assert state.republic is not None
    assert new.republic.influence == state.republic.influence - rules.cost
    after = senate_vote(new, Issue.LAND)
    assert after.yes_bp == forecast.yes_bp > before.yes_bp
    base = rules.shift_bp * weight // 10_000
    for fid in sorted(new.republic.families):
        moved = new.republic.families[fid].favour.get("land", 0) - state.republic.families[
            fid
        ].favour.get("land", 0)
        popular = new.world.gentes[fid].popular_lean_bp >= rules.popular_from_bp
        assert moved == (base if popular else base * rules.others_share_bp // 10_000)
    (event,) = turn_events(new, "contio")
    assert event.ref == "land"  # type: ignore[attr-defined]
    assert event.monument == "rostra_republic"  # type: ignore[attr-defined]
    assert event.person == speaker.person  # type: ignore[attr-defined]
    assert event.value == base  # type: ignore[attr-defined]
    against, ok, _ = act(state, Contio(civ="rome", issue="land", side="against"))
    assert ok
    assert senate_vote(against, Issue.LAND).yes_bp < before.yes_bp


def test_a_contio_needs_a_magistrate_and_influence(content: Content) -> None:
    state = fresh(content)
    assert state.republic is not None
    state.republic.influence = 0
    _, ok, why = act(state, Contio(civ="rome", issue="land", side="for"))
    assert not ok and "influence" in why  # noqa: PT018
    state.republic.influence = 10_000
    _, ok, _ = act(state, Contio(civ="rome", issue="land", side="sideways"))
    assert not ok
    _, ok, _ = act(state, Contio(civ="rome", issue="taxes", side="for"))
    assert not ok
    quaestor = next(m for m in state.republic.magistrates if m.office == "quaestor")
    _, ok, _ = act(state, Contio(civ="rome", issue="land", side="for", speaker=quaestor.person))
    assert not ok
    tribune = next(m for m in state.republic.magistrates if m.office == "tribune_plebs")
    new, ok, _ = act(state, Contio(civ="rome", issue="land", side="for", speaker=tribune.person))
    assert ok
    assert turn_events(new, "contio")[0].person == tribune.person  # type: ignore[attr-defined]
    state.republic.magistrates = []
    _, ok, why = act(state, Contio(civ="rome", issue="land", side="for"))
    assert not ok and "magistrate" in why  # noqa: PT018


def _candidate(state: GameState, office: str = "consul") -> str:
    places = places_view(state)
    assert places is not None
    for entry in places["campus_martius"]["actions"]:
        if entry["action"]["kind"] == "back" and entry["action"]["office"] == office:
            return str(entry["action"]["person"])
    raise AssertionError("no candidate offered")


def test_a_contio_for_a_candidate_weighs_in_the_election(content: Content) -> None:
    state = fresh(content)
    man = _candidate(state)
    new, ok, message = act(state, Contio(civ="rome", issue="candidate", side=man, office="consul"))
    assert ok, message
    assert new.republic is not None
    (backing,) = [b for b in new.republic.backing if b.person == man]
    assert 0 < backing.bp < new.world.republic_rules.backing_bp
    # a contio does not stop the player backing the man as well
    new, ok, _ = act(
        new,
        ACTION.validate_python({"kind": "back", "civ": "rome", "person": man, "office": "consul"}),
    )
    assert ok
    (event,) = turn_events(new, "contio")
    assert event.ref == "candidate:consul"  # type: ignore[attr-defined]
    ended, _ = end_turn(new)
    assert ended.city is not None
    elections = [e for e in ended.city.events if e.kind == "election"]
    assert [e.person for e in elections] == [man]
    assert elections[0].monument == "campus_martius"
    assert elections[0].year == state.year + 1
    assert elections[0].value in (0, 1)
    holders = [
        m.person
        for m in ended.republic.record + ended.republic.magistrates  # type: ignore[union-attr]
        if m.office == "consul" and m.year == state.year + 1
    ]
    assert elections[0].value == int(man in holders)


# ---------------------------------------------------------------- vow


def test_a_vowed_temple_is_dedicated_early_and_played(content: Content) -> None:
    state = fresh(content)
    rules = state.world.republic_rules.city.places.vow
    assert rules is not None
    temple = city_acts.vow_candidates(state)[0]
    history = temple.built.year if temple.built else None
    assert history is not None and history > state.year + rules.build_years  # noqa: PT018
    wealth = state.civs["rome"].stockpiles.wealth
    new, ok, message = act(state, VowTemple(civ="rome", temple=temple.id, cause="pestilence"))
    assert ok, message
    assert new.civs["rome"].stockpiles.wealth == wealth - city_acts.vow_wealth(state)
    (event,) = [e for e in turn_events(new, "sacrifice") if e.ref == "vow"]  # type: ignore[attr-defined]
    assert event.monument == temple.id  # type: ignore[attr-defined]
    assert event.value == state.year + rules.build_years  # type: ignore[attr-defined]
    _, ok, why = act(new, VowTemple(civ="rome", temple=temple.id, cause="pestilence"))
    assert not ok and "already vowed" in why  # noqa: PT018
    ended, _ = end_turn(new)
    assert ended.city is not None
    assert ended.city.standing[temple.id].state == "standing"
    assert ended.city.standing[temple.id].since == state.year + rules.build_years
    dedications = [
        e for e in ended.city.events if e.kind == "sacrifice" and e.monument == temple.id
    ]
    assert [e.ref for e in dedications] == ["dedication"]
    places = places_view(ended)
    assert places is not None
    assert places[temple.id]["role"] == "temple"


def test_a_vow_in_battle_needs_a_war(content: Content) -> None:
    state = fresh(content)
    temple = city_acts.vow_candidates(state)[0].id
    _, ok, why = act(state, VowTemple(civ="rome", temple=temple, cause="battle"))
    assert not ok and "war" in why  # noqa: PT018
    declare_war(state, "rome", "carthage", EventLog(turn=state.turn, year=state.year))
    _, ok, message = act(state, VowTemple(civ="rome", temple=temple, cause="battle"))
    assert ok, message
    for bad in ("aedes_saturni", "circus_maximus", "nowhere"):
        _, ok, _ = act(state, VowTemple(civ="rome", temple=bad, cause="pestilence"))
        assert not ok


# ---------------------------------------------------------------- games


def test_races_are_given_by_an_aedile_once_a_year_at_a_circus(content: Content) -> None:
    state = fresh(content)
    rules = state.world.republic_rules.city.places.games
    assert rules is not None
    unrest = state.civs["rome"].stats.unrest_bp
    new, ok, message = act(state, GiveGames(civ="rome", games="ludi", venue="circus_maximus"))
    assert ok, message
    assert new.civs["rome"].stats.unrest_bp == max(0, unrest + rules.ludi_unrest_bp)
    (event,) = turn_events(new, "race")
    giver = event.person  # type: ignore[attr-defined]
    assert new.republic is not None
    assert any(m.person == giver and m.office in rules.givers for m in new.republic.magistrates)
    assert event.value == city_acts.games_wealth(state, "ludi")  # type: ignore[attr-defined]
    _, ok, why = act(new, GiveGames(civ="rome", games="ludi", venue="circus_maximus"))
    assert not ok and "this year" in why  # noqa: PT018
    _, ok, _ = act(state, GiveGames(civ="rome", games="ludi", venue="circus_flaminius"))
    assert not ok  # built 220
    _, ok, _ = act(state, GiveGames(civ="rome", games="ludi", venue="forum_boarium"))
    assert not ok
    assert state.republic is not None
    state.republic.magistrates = [
        m for m in state.republic.magistrates if m.office not in rules.givers
    ]
    _, ok, why = act(state, GiveGames(civ="rome", games="ludi", venue="circus_maximus"))
    assert not ok and "aedile" in why  # noqa: PT018


def test_a_munus_honours_a_dead_man_at_the_venue_of_the_year(content: Content) -> None:
    state = fresh(content)
    assert state.republic is not None
    consular = next(
        p
        for pid, p in sorted(state.republic.people.items())
        if p.alive
        and any(h.office == "consul" for h in p.offices)
        and any(
            q.alive and q.gens == p.gens and q.id != p.id for q in state.republic.people.values()
        )
    )
    kill_person(state, consular.id)
    assert consular.id in {p.id for p in city_acts.honourees(state)}
    places = places_view(state)
    assert places is not None
    offered = [a["action"] for a in places["forum_boarium"]["actions"]]
    assert {
        "kind": "games",
        "games": "munus",
        "venue": "forum_boarium",
        "honour": consular.id,
    } in offered
    new, ok, message = act(
        state, GiveGames(civ="rome", games="munus", venue="forum_boarium", honour=consular.id)
    )
    assert ok, message
    (event,) = turn_events(new, "munus")
    assert event.person == consular.id  # type: ignore[attr-defined]
    giver = new.republic.people[event.ref]  # type: ignore[union-attr, attr-defined]
    assert giver.gens == consular.gens and giver.alive  # noqa: PT018
    _, ok, _ = act(
        new, GiveGames(civ="rome", games="munus", venue="forum_boarium", honour=consular.id)
    )
    assert not ok  # honoured already (and the venue is used this year)
    later = at_year(state, -200)
    assert ("forum_romanum", "Wooden stands in the Forum") in city_acts.venues(later, "munus")
    assert "forum_boarium" not in dict(city_acts.venues(later, "munus"))


# ---------------------------------------------------------------- site


def _with_project(state: GameState, tech: str) -> GameState:
    civ = state.civs["rome"]
    civ.tech[tech] = TechState(stage=Stage.CONCEPT)
    new, logged = apply_action(state, StartProject(civ="rome", node_id=tech))
    if not logged.ok:  # not feasible yet: force the work under way for the test
        from anachronism.engine.state import Project

        new.civs["rome"].tech[tech] = TechState(stage=Stage.EXPERIMENTING)
        new.civs["rome"].projects[tech] = Project(node_id=tech, started_turn=new.turn)
    return new


def test_a_great_work_rises_at_the_site_chosen(content: Content) -> None:
    state = _with_project(fresh(content), "amphitheatre")
    places = places_view(state)
    assert places is not None
    work = places["anachronism_amphitheatre"]
    assert work["role"] == "anachronism"
    sites = [a["action"]["site"] for a in work["actions"]]
    assert sites == ["amphitheatre_campus", "amphitheatre_boarium"]
    new, ok, message = act(
        state, ChooseSite(civ="rome", tech="amphitheatre", site="amphitheatre_campus")
    )
    assert ok, message
    assert new.city is not None
    assert new.city.sites == {"amphitheatre": "amphitheatre_campus"}
    (event,) = turn_events(new, "building")
    assert event.monument == "anachronism_amphitheatre"  # type: ignore[attr-defined]
    _, ok, _ = act(new, ChooseSite(civ="rome", tech="amphitheatre", site="amphitheatre_campus"))
    assert not ok  # already chosen
    _, ok, _ = act(new, ChooseSite(civ="rome", tech="amphitheatre", site="theatre_apollo"))
    assert not ok  # a site for another kind
    # once adopted, the work stands where it was put, not in the Flavian valley
    civ = new.civs["rome"]
    civ.projects.pop("amphitheatre")
    civ.tech["amphitheatre"] = TechState(stage=Stage.ADOPTED, adopted_year=new.year)
    ended, _ = end_turn(new)
    view = city_view(ended)
    assert view is not None
    (built,) = [a for a in view["anachronisms"] if a["tech"] == "amphitheatre"]
    tauri = ended.world.monuments["amphitheatrum_tauri"]
    assert built["form"]["lat"] == pytest.approx(tauri.lat)
    assert built["form"]["twin"] == ""
    _, ok, why = act(ended, ChooseSite(civ="rome", tech="amphitheatre", site="history"))
    assert not ok and "already stands" in why  # noqa: PT018


# ---------------------------------------------------------------- levy


def test_the_players_levy_plays_on_the_campus(content: Content) -> None:
    state = fresh(content)
    places = places_view(state)
    assert places is not None
    (entry,) = [a for a in places["villa_publica"]["actions"] if a["id"] == "raise:small"]
    capital = state.civs["rome"].capital
    new, ok, message = act(state, RaiseArmy(civ="rome", province=capital, size="small"))
    assert ok, message
    (event,) = turn_events(new, "levy")
    assert event.monument == "villa_publica"  # type: ignore[attr-defined]
    assert event.value == entry["forecast"]["men"]  # type: ignore[attr-defined]
    assert event.ref in new.armies  # type: ignore[attr-defined]


# ---------------------------------------------------------------- replay and saves


def _play(content: Content, seed: int) -> tuple[GameState, GameState]:
    state = fresh(content, seed)
    initial = state.model_copy(deep=True)
    temple = city_acts.vow_candidates(state)[0].id
    man = _candidate(state)
    capital = state.civs["rome"].capital
    script: dict[int, list[Action]] = {
        0: [
            Contio(civ="rome", issue="land", side="for"),
            Contio(civ="rome", issue="candidate", side=man, office="consul"),
            VowTemple(civ="rome", temple=temple, cause="pestilence"),
            GiveGames(civ="rome", games="ludi", venue="circus_maximus"),
            RaiseArmy(civ="rome", province=capital, size="small"),
        ],
        1: [
            DeclareWar(civ="rome", target="carthage"),
            Contio(civ="rome", issue="war", side="against"),
            GiveGames(civ="rome", games="ludi", venue="circus_maximus"),
        ],
    }
    for turn in range(3):
        for action in script.get(turn, []):
            state, _ = apply_action(state, action)
        state, _ = end_turn(state)
    return initial, state


@pytest.mark.parametrize("seed", SEEDS)
def test_the_places_actions_replay_exactly_and_save_cleanly(content: Content, seed: int) -> None:
    initial, final = _play(content, seed)
    kinds = {e.action.kind for e in final.action_log if e.ok}
    assert {"contio", "vow", "games", "raise"} <= kinds
    assert final.city is not None
    assert final.city.vows
    rebuilt = replay(initial, final.action_log, until_turn=final.turn)
    assert dumps(rebuilt) == dumps(final)
    text = dumps(final)
    assert dumps(loads(text)) == text
    assert loads(text).city == final.city


def test_the_places_actions_are_deterministic(content: Content) -> None:
    first = {seed: dumps(_play(content, seed)[1]) for seed in SEEDS[:2]}
    for seed in SEEDS[:2]:
        assert dumps(_play(content, seed)[1]) == first[seed]
    assert first[1] != first[2]
