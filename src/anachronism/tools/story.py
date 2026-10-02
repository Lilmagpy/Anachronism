"""Chronicle mode for the client (D-120).

The waiting chapter, the last one's aftermath, and how the player's state stands against
history so far.
"""

from __future__ import annotations

from typing import Any

from anachronism.content.loader import Content
from anachronism.engine.campaign import PASSED_OVER, available, benchmark, year_text
from anachronism.engine.dilemmas import effects_text, fill
from anachronism.engine.state import GameState


def speaker_card(content: Content, state: GameState, speaker: str) -> dict[str, Any]:
    """Who brings a chapter: a name, a title and a portrait style for the client."""
    player = state.player_civ
    civ_id = speaker if speaker in state.civs else player
    civ_def = content.civs[civ_id]
    if speaker == "ruler" or speaker in state.civs:
        ruler = state.civs[civ_id].ruler or f"The ruler of {state.civs[civ_id].name}"
        name, title, portrait = ruler, f"{civ_def.name}", civ_def.portrait
    else:
        adviser = content.speakers.get(speaker)
        name = adviser.title if adviser else speaker.title()
        title = f"{content.civs[player].adjective} court"
        portrait = (adviser.portrait if adviser else "") or civ_def.portrait
    return {
        "name": name,
        "title": title,
        "portrait": portrait,
        "culture": civ_def.portrait,
        "colour": civ_def.colour,
        "symbol": civ_def.symbol or "",
        "civ": civ_id,
    }


def chronicle_block(content: Content, state: GameState) -> dict[str, Any] | None:
    """Everything the client shows of chronicle mode, or None in free play."""
    if not state.chronicle_mode:
        return None
    chapters = state.world.chapters
    out: dict[str, Any] = {
        "total": len(chapters),
        "done": sum(1 for v in state.chapters_done.values() if v != PASSED_OVER),
        "passed": sum(1 for v in state.chapters_done.values() if v == PASSED_OVER),
        "chapter": None,
        "result": None,
        "versus": _versus(state),
        "next": None,
    }
    if state.chapter is not None:
        chapter = chapters[state.chapter]
        out["chapter"] = {
            "id": chapter.id,
            "title": chapter.title,
            "year": year_text(chapter.year),
            "place": chapter.place,
            "speaker": speaker_card(content, state, chapter.speaker),
            "story": fill(state, chapter.story).split("\n\n"),
            "choices": [
                {
                    "label": c.label,
                    "hint": effects_text(c) + _deeds_text(state, c.deeds),
                    "locked": ""
                    if available(state, c)
                    else "needs "
                    + ", ".join(
                        state.tech_nodes[t].name for t in c.needs_adopted if t in state.tech_nodes
                    ),
                    "anachronism": bool(c.needs_adopted),
                }
                for c in chapter.choices
            ],
        }
    result = state.chapter_result
    if result is not None and result.chapter in chapters:
        chapter = chapters[result.chapter]
        historical = next((c.label for c in chapter.choices if c.historical), "")
        out["result"] = {
            "title": chapter.title,
            "year": year_text(chapter.year),
            "chose": chapter.choices[result.choice].label,
            "outcome": result.outcome,
            "history": result.history,
            "historical": result.historical,
            "history_chose": historical,
            "benchmark": result.benchmark,
        }
    upcoming = [c for c in chapters.values() if c.id not in state.chapters_done]
    if upcoming and state.chapter is None:
        out["next"] = {"title": upcoming[0].title, "year": year_text(upcoming[0].year)}
    if not upcoming and state.chapter is None and chapters:
        out["verdict"] = _verdict(state)
    return out


def _verdict(state: GameState) -> str:
    """The end of the chronicle: did the player outdo history?"""
    marks = [c for c in state.world.chapters.values() if c.benchmark_provinces is not None]
    me = state.civs[state.player_civ]
    held = len(state.owned_provinces(me.id))
    real = max((c.benchmark_provinces or 0) for c in marks) if marks else held
    same = sum(
        1
        for cid, choice in state.chapters_done.items()
        if choice >= 0 and state.world.chapters[cid].choices[choice].historical
    )
    played = sum(1 for choice in state.chapters_done.values() if choice >= 0)
    if held > real:
        judged = "You have outdone history."
    elif held == real:
        judged = "You have matched history - no small thing."
    else:
        judged = "History did better than you."
    return (
        f"The chronicle is complete. At its height the real {me.name} held {real} provinces;"
        f" yours holds {held}. You chose as history did in {same} of {played} chapters."
        f" {judged}"
    )


def _versus(state: GameState) -> str:
    """The latest yardstick: the real state at the most recent date with one."""
    marks = [
        c
        for c in state.world.chapters.values()
        if c.benchmark_provinces is not None and c.year <= state.year
    ]
    return benchmark(state, marks[-1]) if marks else ""


def _deeds_text(state: GameState, deeds: Any) -> str:
    """A few words on what a choice does in the world."""

    def names(ids: tuple[str, ...]) -> str:
        return ", ".join(state.civs[i].name if i in state.civs else i for i in ids)

    parts = []
    if deeds.war_with:
        parts.append(f"war with {names(deeds.war_with)}")
    if deeds.peace_with:
        parts.append(f"peace with {names(deeds.peace_with)}")
    if deeds.ally_with:
        parts.append(f"alliance with {names(deeds.ally_with)}")
    if deeds.tributaries:
        parts.append(f"{names(deeds.tributaries)} pays tribute")
    if deeds.take:
        places = ", ".join(
            state.world.geography[p].name for p in deeds.take if p in state.world.geography
        )
        parts.append(f"gain {places}")
    if deeds.give:
        places = ", ".join(
            state.world.geography[p].name for p in deeds.give if p in state.world.geography
        )
        parts.append(f"lose {places}")
    if deeds.ships:
        parts.append(f"{deeds.ships} warships")
    if deeds.men:
        parts.append(f"{deeds.men:,} men")
    return ("; " if parts else "") + "; ".join(parts)
