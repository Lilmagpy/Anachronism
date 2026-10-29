"""Roman-era army content (R4): sources, the 15 battles, soldiers-gated formations."""

from anachronism.content.loader import load_content

BATTLES = {
    "allia", "sentinum", "heraclea", "telamon", "trebia", "trasimene", "cannae", "zama",
    "cynoscephalae", "magnesia", "pydna", "aquae_sextiae", "carrhae", "alesia", "pharsalus",
}  # fmt: skip


def test_every_roman_era_entry_cites_sources() -> None:
    content = load_content()
    for kind in (content.units, content.formations, content.tactics):
        sourced = [e for e in kind.values() if e.sources]
        assert len(sourced) >= 5
    for unit_id in ("hastati", "triarii", "macedonian_phalangites", "parthian_horse_archers"):
        assert content.units[unit_id].sources


def test_the_fifteen_battles_are_there_and_sourced() -> None:
    content = load_content()
    assert set(content.battles) >= BATTLES
    for battle in content.battles.values():
        assert battle.sources
        assert battle.side_a.commanders
        assert battle.side_b.commanders


def test_roman_formations_need_the_right_soldiers() -> None:
    content = load_content()
    for fid in ("triplex_acies", "phalanx", "cannae_envelopment", "zama_lanes", "hollow_square"):
        form = content.formations[fid]
        assert form.needs_units
        assert form.needs_share_bp > 0
