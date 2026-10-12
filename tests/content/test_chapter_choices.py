"""Chronicle choices must not give history away (D-265, D-266)."""

from __future__ import annotations

from anachronism.content.loader import load_content
from anachronism.content.schema import ChapterChoice

NUMBERS = ("food_bp", "materials_bp", "wealth_bp", "knowledge_bp", "legitimacy_bp")


def _net(choice: ChapterChoice) -> int:
    """Gains minus losses, as a player would read the hint."""
    gains: int = sum(int(getattr(choice, f)) for f in NUMBERS)
    return gains - choice.unrest_bp


def _shows_deeds(choice: ChapterChoice) -> bool:
    d = choice.deeds
    return bool(
        d.war_with
        or d.peace_with
        or d.ally_with
        or d.tributaries
        or d.take
        or d.conquer
        or d.give
        or d.break_away
        or d.capital
        or d.ships
        or d.men
        or d.martial_bp
    )


def test_every_chapter_offers_three_real_choices() -> None:
    for chapter in load_content().chapters.values():
        ordinary = [c for c in chapter.choices if not c.needs_adopted]
        assert len(ordinary) >= 3, f"{chapter.id}: only {len(ordinary)} ordinary choices"


def test_history_is_never_the_only_choice_that_changes_the_world() -> None:
    for chapter in load_content().chapters.values():
        ordinary = [c for c in chapter.choices if not c.needs_adopted]
        others = [c for c in ordinary if not c.historical]
        history = [c for c in ordinary if c.historical]
        if history and _shows_deeds(history[0]):
            assert any(_shows_deeds(c) for c in others), f"{chapter.id}: only history shows deeds"


def test_history_does_not_usually_have_the_best_numbers() -> None:
    best = total = 0
    for chapter in load_content().chapters.values():
        ordinary = [c for c in chapter.choices if not c.needs_adopted]
        history = [c for c in ordinary if c.historical]
        if not history:
            continue
        total += 1
        best += _net(history[0]) > max(_net(c) for c in ordinary if not c.historical)
    assert best / total < 0.4, f"history has the best numbers in {best / total:.0%} of chapters"
