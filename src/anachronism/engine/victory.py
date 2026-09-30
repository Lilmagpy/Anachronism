"""Tiered victory (brief §5.11, DESIGN §11): military, economic or cultural dominance.

A scenario is one region, so for now every victory is *regional*; hemispheric and world
tiers need several regions in one game (Phase 8). The three paths:

- **Military**: rule over half of all the people in the scenario.
- **Economic**: your trade network (trading partners, allies, tributaries) reaches most of
  everyone else's people, and your treasury is the richest.
- **Cultural**: your share of the region's culture (people weighted by literacy and
  cultural influence, plus half the culture of every court that shares your faith) passes
  the threshold, and no one's culture is larger.

Defeat comes with collapse, or the loss of every province.
"""

from __future__ import annotations

from typing import Any

from anachronism.content.schema import EffectType
from anachronism.engine.culture import shares_faith
from anachronism.engine.effects import civ_effects
from anachronism.engine.events import EventLog
from anachronism.engine.fixed import BP
from anachronism.engine.rivals import alive, status
from anachronism.engine.state import GameState, Outcome


def culture(state: GameState, civ_id: str) -> int:
    """People weighted by literacy and cultural influence (in thousands)."""
    if not alive(state, civ_id):
        return 0
    influence = civ_effects(state, civ_id)[EffectType.CULTURAL_INFLUENCE]
    weight = 1000 + state.civs[civ_id].stats.literacy_bp + influence
    return state.population(civ_id) // 1000 * weight // BP


def progress(state: GameState) -> dict[str, Any]:
    """How close the player is on each path, as shares in basis points with the targets."""
    rules = state.world.rules.rivals
    me = state.player_civ
    everyone = sum(state.population(c) for c in state.civs)
    mine = state.population(me)
    others = everyone - mine
    reached = sum(
        state.population(c)
        for c in sorted(state.civs)
        if c != me and alive(state, c) and (s := status(state, me, c)) is not None and s.friendly
    )
    cultures = {c: culture(state, c) for c in sorted(state.civs)}
    total_culture = sum(cultures.values())
    # courts that share your faith carry half their culture into your sphere (brief §5.11)
    my_sphere = cultures[me] + sum(
        cultures[c] // 2 for c in sorted(state.civs) if c != me and shares_faith(state, me, c)
    )
    margin = rules.victory_margin_bp
    start = state.victory_start

    def target(path: str, base: int) -> int:
        return min(BP, max(base, start.get(path, 0) + margin))

    richest = max(
        sorted(state.civs),
        key=lambda c: (state.civs[c].stockpiles.wealth if alive(state, c) else -1, c == me),
    )
    return {
        "military": {
            "share_bp": mine * BP // max(1, everyone),
            "target_bp": target("military", rules.military_victory_share_bp),
        },
        "economic": {
            "share_bp": reached * BP // max(1, others),
            "target_bp": target("economic", rules.economic_victory_share_bp),
            "richest": richest == me,
        },
        "cultural": {
            "share_bp": min(BP, my_sphere * BP // max(1, total_culture)),
            "target_bp": target("cultural", rules.cultural_victory_share_bp),
            "leading": my_sphere >= max(cultures.values()),
        },
    }


def record_start(state: GameState) -> None:
    """Remember the player's starting share on each path (called by ``new_game``)."""
    state.victory_start = {path: values["share_bp"] for path, values in progress(state).items()}


def check_outcome(state: GameState, events: EventLog) -> None:
    """Decide whether the game has been won or lost (once)."""
    if state.outcome is not None:
        return
    me = state.civs[state.player_civ]
    if me.collapsed or not alive(state, me.id):
        state.outcome = Outcome(
            result="defeat", path="collapse", tier="regional", turn=state.turn, year=state.year
        )
        events.add(me.id, "defeat", f"{me.name} has fallen. The age moves on without you.")
        return
    paths = progress(state)
    won = ""
    if paths["military"]["share_bp"] >= paths["military"]["target_bp"]:
        won = "military"
    elif (
        paths["economic"]["share_bp"] >= paths["economic"]["target_bp"]
        and paths["economic"]["richest"]
    ):
        won = "economic"
    elif (
        paths["cultural"]["share_bp"] >= paths["cultural"]["target_bp"]
        and paths["cultural"]["leading"]
    ):
        won = "cultural"
    if won:
        state.outcome = Outcome(
            result="victory", path=won, tier="regional", turn=state.turn, year=state.year
        )
        words = {
            "military": "by the sword",
            "economic": "through trade",
            "cultural": "by the pen and the word",
        }
        events.add(me.id, "victory", f"{me.name} dominates the region {words[won]}!")
