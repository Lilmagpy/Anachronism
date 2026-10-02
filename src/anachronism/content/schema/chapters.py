"""Chronicle mode (D-120): a playthrough along history, told in chapters.

A campaign is a scenario's chapters for one civilisation. Each chapter opens in its year
(when its conditions hold): a scene from what really happened, told at some length, and
two to four choices - one of them what history chose. Each choice has its consequences
(the same as a dilemma's, plus deeds in the world: wars, peace, alliances, land taken or
given up, fleets built, men raised), what follows it, and afterwards the player reads what
really happened and how their state compares with the real one at that date. A chapter
whose world no longer exists (the player changed it) is passed over with a short note of
how history turned. ``almanac`` entries tell what happened elsewhere in the world that year.

History here is "defensible and well-researched" (brief §2.14), lightly romanticised in the
telling but never in the facts; ``sources`` keep notes for developers.

Chronicle mode adds to the game rather than replacing it: the player still whispers ideas
ahead of their time, builds, raises armies and makes treaties between chapters, and the
ideas they bring in can open choices at history's turning points that history never had.
"""

from __future__ import annotations

from typing import Annotated

from pydantic import Field

from anachronism.content.schema.base import Frozen, Identifier, Positive
from anachronism.content.schema.dilemmas import Choice

Story = Annotated[str, Field(min_length=1, max_length=2400)]
Note = Annotated[str, Field(max_length=1200)]


class Deeds(Frozen):
    """What a chapter's choice does in the world, beyond the court's own stores and mood."""

    war_with: tuple[Identifier, ...] = ()
    peace_with: tuple[Identifier, ...] = ()
    ally_with: tuple[Identifier, ...] = ()
    tributaries: tuple[Identifier, ...] = ()
    """States that submit and send you tribute."""
    take: tuple[Identifier, ...] = ()
    """Provinces that become yours (from whoever holds them, or nobody)."""
    conquer: tuple[Identifier, ...] = ()
    """States whose every remaining province becomes yours (the state falls)."""
    give: tuple[Identifier, ...] = ()
    """Your provinces that pass to ``give_to`` (or to nobody)."""
    give_to: Identifier | None = None
    ships: Annotated[int, Field(ge=0, le=500)] = 0
    """Warships built at once, off your capital's coast (or your first coastal province)."""
    men: Annotated[int, Field(ge=0, le=200_000)] = 0
    """Soldiers raised at once at the capital, unpaid for by the stores."""
    martial_bp: Annotated[int, Field(ge=-10_000, le=10_000)] = 0
    """A lasting change to how many of the people the state can put under arms (bp; 10000
    doubles the usual share): reforms like Shang Yang's that make a state a war machine."""
    ruler_falls: Annotated[str, Field(max_length=60)] = ""
    """If set, the ruler's reign ends here, told this way ("is killed at Honno-ji"), and the
    next in line takes the throne."""
    grudges: dict[Identifier, Annotated[int, Field(ge=0, le=10_000)]] = Field(default_factory=dict)
    """Grievance other states now bear you (bp)."""


class ChapterChoice(Choice):
    """One way to meet a chapter's moment."""

    label: Annotated[str, Field(min_length=1, max_length=90)]
    outcome: Note
    """What follows, told at once."""
    historical: bool = False
    """What history chose."""
    needs_adopted: tuple[Identifier, ...] = ()
    """Open only if the player has brought these ideas into use: the anachronisms of the
    player's own making that history never had (shown locked otherwise)."""
    deeds: Deeds = Deeds()


class Chapter(Frozen):
    """One scene of a campaign."""

    id: Identifier
    scenario: Identifier
    civ: Identifier
    """Whose campaign it belongs to (the player's civilisation)."""
    year: int
    """The year it opens (negative = BC)."""
    until_year: int | None = None
    """If its conditions do not hold by this year, history has turned: it is passed over."""
    title: Annotated[str, Field(min_length=1, max_length=80)]
    place: Annotated[str, Field(max_length=80)] = ""
    speaker: Identifier = "ruler"
    """Who brings the moment to you: ``ruler``, an adviser's id (``general``...), or a
    civilisation's id (its ruler speaks)."""
    speaker_name: Annotated[str, Field(max_length=60)] = ""
    """The speaker's own name, when it matters (Shang Yang rather than "Grand Steward")."""
    speaker_title: Annotated[str, Field(max_length=60)] = ""
    story: Story
    """The scene, in a few short paragraphs (separated by blank lines)."""
    needs_alive: tuple[Identifier, ...] = ()
    needs_war_with: tuple[Identifier, ...] = ()
    needs_peace_with: tuple[Identifier, ...] = ()
    needs_stronger_than: dict[Identifier, Annotated[int, Field(ge=0, le=100_000)]] = Field(
        default_factory=dict
    )
    """State -> how strong the player must be against it (bp: 15000 = half as strong again):
    a turning point the player's state must be able to bring about."""
    needs_owner: dict[Identifier, Identifier] = Field(default_factory=dict)
    """Province -> who must hold it (``nobody`` for no one)."""
    needs_not_owner: dict[Identifier, Identifier] = Field(default_factory=dict)
    after: tuple[Identifier, ...] = ()
    """Chapters that must have been played first."""
    after_choice: dict[Identifier, int] = Field(default_factory=dict)
    """Only if an earlier chapter was answered with this choice (index)."""
    choices: tuple[ChapterChoice, ...] = Field(min_length=1, max_length=4)
    history: Note = ""
    """What really happened, shown once the player has chosen."""
    diverged: Note = ""
    """Told if the chapter is passed over because history has turned."""
    benchmark_provinces: Positive | None = None
    """How many provinces the state really held at this date, to compare with the player."""
    sources: tuple[str, ...] = ()


class AlmanacEntry(Frozen):
    """Meanwhile, in the world: something that really happened, told in its year."""

    id: Identifier
    scenario: Identifier
    year: int
    text: Annotated[str, Field(min_length=1, max_length=500)]
    needs_alive: tuple[Identifier, ...] = ()
    """Told only while these states still stand (history may have changed)."""
    sources: tuple[str, ...] = ()
