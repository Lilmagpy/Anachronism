"""Tests for the seeded PCG32 generator."""

from __future__ import annotations

from collections import Counter

import pytest

from anachronism.engine.rng import GameRng, RngState

# First outputs of the PCG reference implementation (pcg32-demo) for seed 42, stream 54.
PCG32_REFERENCE = [0xA15C02B7, 0x7B47F409, 0xBA1D3330, 0x83D2F293, 0xBFA4784B, 0xCBED606E]


def test_matches_pcg32_reference_outputs() -> None:
    rng = GameRng.from_seed(42, stream=54)
    assert [rng.next_u32() for _ in PCG32_REFERENCE] == PCG32_REFERENCE


def test_same_seed_gives_same_sequence_and_different_seeds_differ() -> None:
    first = GameRng.from_seed(7)
    second = GameRng.from_seed(7)
    other = GameRng.from_seed(8)
    sequence = [first.next_u32() for _ in range(20)]
    assert sequence == [second.next_u32() for _ in range(20)]
    assert sequence != [other.next_u32() for _ in range(20)]


def test_saved_state_continues_the_same_sequence() -> None:
    rng = GameRng.from_seed(2024)
    for _ in range(5):
        rng.next_u32()
    saved = rng.state.model_dump_json()
    expected = [rng.below(1_000) for _ in range(10)]
    restored = GameRng(RngState.model_validate_json(saved))
    assert [restored.below(1_000) for _ in range(10)] == expected


def test_below_stays_in_range_and_is_roughly_uniform() -> None:
    rng = GameRng.from_seed(1)
    counts = Counter(rng.below(10) for _ in range(20_000))
    assert set(counts) == set(range(10))
    assert all(1_800 < count < 2_200 for count in counts.values())


@pytest.mark.parametrize("bound", [0, -3, 2**32 + 1])
def test_below_rejects_invalid_bounds(bound: int) -> None:
    with pytest.raises(ValueError, match="bound"):
        GameRng.from_seed(1).below(bound)


def test_between_is_inclusive() -> None:
    rng = GameRng.from_seed(3)
    values = {rng.between(-2, 2) for _ in range(500)}
    assert values == {-2, -1, 0, 1, 2}


def test_chance_extremes_and_single_draw() -> None:
    rng = GameRng.from_seed(5)
    twin = GameRng.from_seed(5)
    assert not any(rng.chance(0) for _ in range(100))
    assert all(rng.chance(10_000) for _ in range(100))
    for _ in range(200):
        twin.next_u32()
    assert rng.next_u32() == twin.next_u32()


def test_pick_weighted_index_and_shuffle() -> None:
    rng = GameRng.from_seed(9)
    assert rng.pick(["only"]) == "only"
    with pytest.raises(ValueError, match="empty"):
        rng.pick([])
    picks = Counter(rng.weighted_index([0, 3, 1]) for _ in range(2_000))
    assert picks[0] == 0
    assert picks[1] > picks[2] > 0
    items = list(range(20))
    rng.shuffle(items)
    assert sorted(items) == list(range(20))
    assert items != list(range(20))


def test_rejects_even_increment() -> None:
    with pytest.raises(ValueError, match="odd"):
        GameRng(RngState(state=1, inc=2))
