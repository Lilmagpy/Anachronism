"""Keeping inventions secret: sealed borders and false rumours (brief §7.3)."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content
from anachronism.engine.actions import SealBorders, SpreadRumours
from anachronism.engine.culture import trade_income
from anachronism.engine.game import apply_action, end_turn, new_game
from anachronism.engine.state import GameState, NewsInTransit


@pytest.fixture
def qin(content: Content) -> GameState:
    state = new_game(content, "warring_states", seed=1, player_civ="qin")
    state.civs["qin"].stockpiles.wealth = 100_000
    return state


def test_sealed_borders_stop_trade_then_reopen(qin: GameState) -> None:
    partner = next(
        p.split("|")[1 if p.startswith("qin|") else 0]
        for p, rel in sorted(qin.relations.items())
        if "qin" in p.split("|") and rel.status.friendly
    )
    assert trade_income(qin, "qin") > 0
    before = trade_income(qin, partner)
    state, logged = apply_action(qin, SealBorders(civ="qin"))
    assert logged.ok
    assert trade_income(state, "qin") == 0
    assert trade_income(state, partner) < before  # the partner loses the trade too
    assert not apply_action(state, SealBorders(civ="qin"))[1].ok
    for _ in range(state.world.rules.rivals.seal_turns):
        state, _ = end_turn(state)
    assert state.civs["qin"].sealed == 0


def test_rumours_garble_news_on_the_road(qin: GameState) -> None:
    assert not apply_action(qin, SpreadRumours(civ="qin"))[1].ok  # nothing to garble
    qin.news.append(
        NewsInTransit(to_civ="wei", about="qin", node_id="paper", arrives_turn=3, garbled=False)
    )
    state, logged = apply_action(qin, SpreadRumours(civ="qin"))
    assert logged.ok
    about_qin = [n for n in state.news if n.about == "qin"]
    assert [n.garbled for n in about_qin] == [True, False]
    assert about_qin[1].arrives_turn > 3  # the truth comes, but later
    assert state.civs["qin"].stockpiles.wealth < 100_000
