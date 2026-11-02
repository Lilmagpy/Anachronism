"""Roman names for the court's voices (F1 ideas): the magistrate in office, or a man of a gens.

A speaker in ``speakers.yaml`` is an office. When the Republic engine runs, the man who holds
that office this year speaks (``state.republic.magistrates``); for the offices the engine does
not seat (the pontifex maximus, the princeps senatus, an augur, a Greek freedman) a name is
drawn deterministically from the gentes of the year, so the same game always hears the same
men and nothing is invented outside the families the content knows.

Hook for the lead (tools/voices.py, ``speak``): ``name = speaker_name(content, state,
dialogue.speaker) or adviser.title``.
"""

from __future__ import annotations

import zlib

from anachronism.content.loader import Content
from anachronism.engine.state import GameState

OFFICES: dict[str, tuple[str, ...]] = {
    "steward": ("quaestor",),
    "censor": ("censor",),
    "tribune": ("tribune_plebs",),
    "general": ("consul", "praetor", "dictator"),
    "princeps": ("censor", "consul"),  # the senior man: an ex-censor or consul leads the Senate
}
"""Which magistracy's holder speaks for a speaker id (first office found in that order)."""

GREEK_NAMES = ("Andronicus", "Crates", "Diophanes", "Apollonius", "Philodemus", "Tyrannio")
"""Greek freedmen scholars at Rome (Livius Andronicus; Crates of Mallos, Suet. Gramm. 2;
Diophanes of Mytilene, Plut. Ti. Gracchus 8; Tyrannio, Plut. Sulla 26)."""


def speaker_name(content: Content, state: GameState, speaker: str) -> str | None:
    """The name of the man who speaks as ``speaker`` this year, or ``None`` outside a Republic."""
    rep = state.republic
    if rep is None:
        return None
    for office in OFFICES.get(speaker, ()):
        holders = sorted(
            (m.name for m in rep.magistrates if m.office == office and m.name), key=str
        )
        if holders:
            return holders[0]
    if speaker == "scholar":
        return GREEK_NAMES[zlib.crc32(f"{state.seed}:{state.year // 20}".encode()) % 6]
    return gens_name(content, state, speaker)


def gens_name(content: Content, state: GameState, salt: str) -> str | None:
    """A man of one of the families in play, named from his gens' praenomina and cognomina.

    The choice is a hash of the seed, the decade and ``salt``: stable within a decade, so an
    augur keeps his name for a while, and never a name the gentes do not carry.
    """
    rep = state.republic
    if rep is None or not rep.families:
        return None
    families = sorted(rep.families)
    key = f"{state.seed}:{state.year // 10}:{salt}".encode()
    gens = content.gentes.get(families[zlib.crc32(key) % len(families)])
    if gens is None:
        return None
    praenomina = gens.praenomina or ("Gaius",)
    praenomen = praenomina[zlib.crc32(key + b":p") % len(praenomina)]
    cognomen = (
        " " + gens.cognomina[zlib.crc32(key + b":c") % len(gens.cognomina)]
        if gens.cognomina
        else ""
    )
    return f"{praenomen} {gens.nomen}{cognomen}"
