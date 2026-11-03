"""The offline interpreter lands a Roman player's plain words on the right idea (F1 ideas)."""

from __future__ import annotations

import pytest

from anachronism.content.loader import Content, load_content
from anachronism.engine.game import new_game
from anachronism.engine.state import GameState
from anachronism.llm import offline

PHRASINGS = [
    ("bring spring water into the city on arches", "aqueduct"),
    ("an aqueduct", "aqueduct"),
    ("pave a road to Capua", "roads"),
    ("a paved highway for the legions", "roads"),
    ("mix lime with volcanic ash to make concrete", "concrete"),
    ("pozzolana", "concrete"),
    ("a concrete dome with an oculus", "concrete_dome"),
    ("build a stone theatre", "stone_theatre"),
    ("a permanent theatre with stone seats", "stone_theatre"),
    ("an amphitheatre for the gladiators", "amphitheatre"),
    ("a basilica beside the forum", "basilica"),
    ("a stone bridge over the Tiber", "stone_bridge"),
    ("heat the baths from under the floor", "hypocaust"),
    ("public baths for everyone", "public_baths"),
    ("a sundial", "sundial"),
    ("tell the time with a water clock", "water_clock"),
    ("a public library", "public_library"),
    ("collect Greek books in a library", "greek_library"),
    ("a fire brigade", "vigiles"),
    ("firemen to put out fires", "vigiles"),
    ("sewers under the streets", "sanitation"),
    ("a harbour at Ostia", "harbour_works"),
    ("public granaries to store grain", "granary"),
    ("a water mill to grind grain", "water_wheel"),
    ("a triumphal arch", "commemorative_arch"),
    ("a temple of marble", "marble_temple"),
    ("a colonnaded portico", "portico_hall"),
    ("pave the city streets", "street_paving"),
    ("tribunes of the plebs", "tribunate"),
    ("two censors to count the citizens", "censorship"),
    ("write the laws on twelve tables", "written_law"),
    ("publish the laws", "written_law"),
    ("let the plebiscites bind everyone", "citizen_assembly"),
    ("democracy", "citizen_assembly"),
    ("a secret ballot", "secret_ballot"),
    ("a court for foreigners", "praetor_peregrinus"),
    ("a minimum age for each office", "cursus_honorum"),
    ("jury courts to try corrupt governors", "jury_courts"),
    ("rule Sicily as a province with a governor", "provincial_governor"),
    ("cheap grain for the citizens", "grain_dole"),
    ("publish the senate's debates every day", "acta_diurna"),
    ("pay the soldiers", "military_pay"),
    ("a silver denarius", "denarius"),
    ("coins", "coinage"),
    ("a grain fleet from Sicily", "grain_fleet"),
    ("Greek doctors", "greek_medicine"),
    ("fix the calendar with a leap year", "julian_calendar"),
    ("shorthand to take down speeches", "shorthand"),
    ("books with pages instead of scrolls", "codex"),
    ("the solar calendar of 365 days", "julian_calendar"),
    ("a fortified camp every night", "marching_camp"),
    ("surround the city with siege lines", "siege_works"),
    ("a silver eagle for each legion", "eagle_standard"),
    ("a boarding bridge for the warships", "corvus"),
    ("build a fleet of quinqueremes", "quinquereme"),
    ("a relay post with fresh horses", "postal_relay"),
    ("cursus publicus", "postal_relay"),
    ("scorpions and ballistae", "crossbow"),
    ("catapults", "crossbow"),
    ("land for the veterans", "veteran_colonies"),
    ("survey and allot the conquered land in a grid", "centuriation"),
    ("teach rhetoric in Latin", "rhetoric_school"),
    ("Greek philosophers", "greek_philosophy"),
    ("write the history of Rome", "annals"),
    ("Latin poetry and plays", "latin_literature"),
    ("the printing press", "printing_press"),
    ("gunpowder", "gunpowder"),
    ("paper", "paper"),
]


@pytest.fixture(scope="module")
def game() -> GameState:
    content: Content = load_content()
    return new_game(content, "rome_509", seed=3)


@pytest.mark.parametrize(("text", "expected"), PHRASINGS)
def test_plain_roman_words_land_on_the_idea(game: GameState, text: str, expected: str) -> None:
    reply = offline.interpret(game, "rome", text)
    assert reply.ideas, text
    assert reply.ideas[0].matches == expected, (text, reply.ideas[0].matches)


def test_at_least_fifty_phrasings_are_checked() -> None:
    assert len(PHRASINGS) >= 50
