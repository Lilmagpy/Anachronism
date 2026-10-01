"""The story so far: the game told in chapters, an alternate history (brief §6.7).

Every few turns make a chapter. Its facts come from the game's own events (what the
player's people learned, their wars, the lands won and lost, rulers who died, the states
that fell). Offline, a chapter is told plainly from those facts; with a model configured,
the chronicler rewrites finished chapters as a short paragraph (see ``IdeaPipeline.narrate``).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from anachronism.engine.state import Event, GameState
from anachronism.tools.voices import year_text

CHAPTER_TURNS = 5


@dataclass
class Chapter:
    """One span of turns and what happened in it."""

    first_turn: int
    last_turn: int
    start_year: int
    end_year: int
    finished: bool
    facts: dict[str, str] = field(default_factory=dict)
    text: str = ""

    @property
    def title(self) -> str:
        """``336 BC - 286 BC``."""
        return f"{year_text(self.start_year)} - {year_text(self.end_year)}"


def _names(events: list[Event], kind: str, limit: int = 6) -> list[str]:
    seen: list[str] = []
    for e in events:
        if e.kind == kind and e.subject and e.subject not in seen:
            seen.append(e.subject)
    return seen[:limit]


def _about(people: int) -> str:
    """A round figure for a chronicle: ``about 1.4 million``, ``about 350,000``."""
    if people >= 1_000_000:
        return f"about {people / 1_000_000:.1f} million"
    return f"about {round(people, -3):,}"


def _join(items: list[str]) -> str:
    if len(items) <= 1:
        return "".join(items)
    return ", ".join(items[:-1]) + " and " + items[-1]


def chapters(state: GameState) -> list[Chapter]:
    """The game so far in chapters of ``CHAPTER_TURNS`` turns, oldest first."""
    player = state.player_civ
    civ = state.civs[player]
    by_turn: dict[int, list[Event]] = {}
    for e in state.events:
        by_turn.setdefault(e.turn, []).append(e)
    snapshots = {snap.turn: snap for snap in civ.history}
    step = state.world.years_per_turn
    start = state.year - state.turn * step
    out: list[Chapter] = []
    for first in range(1, state.turn + 1, CHAPTER_TURNS):  # events of turn n: year of turn n
        last = min(first + CHAPTER_TURNS - 1, state.turn)
        events = [e for t in range(first, last + 1) for e in by_turn.get(t, [])]
        mine = [e for e in events if e.civ == player]
        chapter = Chapter(
            first_turn=first,
            last_turn=last,
            start_year=start + (first - 1) * step,
            end_year=start + last * step,
            finished=last - first + 1 == CHAPTER_TURNS,
        )
        before = snapshots.get(first - 1)
        after = snapshots.get(last)
        wars = sorted({e.subject for e in mine if e.kind == "war" and e.subject})
        peace = sorted({e.subject for e in mine if e.kind == "peace" and e.subject})
        fallen = sorted({e.subject for e in events if e.kind == "destroyed" and e.subject})
        chapter.facts = {
            "years": chapter.title,
            "realm": f"{civ.name} ({civ.adjective})",
            "learned": _join(_names(mine, "adopted")),
            "wars with": _join(wars),
            "peace with": _join(peace),
            "battles won": _join(_names(mine, "battle_won")),
            "battles lost": _join(_names(mine, "battle_lost")),
            "lands won": _join(_names(mine, "conquest")),
            "lands lost": _join(_names(mine, "province_lost")),
            "rulers": " ".join(e.message for e in mine if e.kind == "ruler_died"),
            "how the people saw the court": " ".join(
                e.message for e in mine if e.kind == "framing"
            ),
            "troubles": _join(_names(mine, "revolt") + _names(mine, "famine")),
            "states that fell": _join(fallen),
            "people": (
                f"from {_about(before.population)} to {_about(after.population)}"
                if before is not None and after is not None
                else ""
            ),
        }
        chapter.text = plain_text(chapter)
        out.append(chapter)
    return out


def plain_text(chapter: Chapter) -> str:
    """The chapter told plainly from its facts (offline, and the model's starting point)."""
    f = chapter.facts
    realm = f["realm"].split(" (")[0]
    parts: list[str] = []
    if f["learned"]:
        parts.append(f"{realm} learned {f['learned']}.")
    if f["wars with"]:
        parts.append(f"There was war with {f['wars with']}.")
    if f["battles won"]:
        parts.append(f"Its armies won at {f['battles won']}.")
    if f["battles lost"]:
        parts.append(f"They were beaten at {f['battles lost']}.")
    if f["lands won"]:
        parts.append(f"Its armies took {f['lands won']}.")
    if f["lands lost"]:
        parts.append(f"It lost {f['lands lost']}.")
    if f["peace with"]:
        parts.append(f"Peace was made with {f['peace with']}.")
    if f["rulers"]:
        parts.append(f["rulers"])
    if f["how the people saw the court"]:
        parts.append(f["how the people saw the court"])
    if f["troubles"]:
        parts.append(f"Troubles came: {f['troubles']}.")
    if f["states that fell"]:
        parts.append(f"In the wider world, {f['states that fell']} fell.")
    if not parts:
        parts.append(f"Quiet years for {realm}: the fields were sown and the years went by.")
    if f["people"]:
        parts.append(f"Its people went {f['people']}.")
    return " ".join(parts)
