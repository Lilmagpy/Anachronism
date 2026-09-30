"""Tests for integer fixed-point maths."""

from __future__ import annotations

import pytest

from anachronism.engine.fixed import BP, apply_bp, clamp, div_round, ratio_bp, with_bonus


@pytest.mark.parametrize(
    ("numerator", "denominator", "expected"),
    [
        (7, 2, 4),
        (5, 2, 3),
        (-5, 2, -3),
        (4, 3, 1),
        (-4, 3, -1),
        (5, -2, -3),
        (0, 7, 0),
        (10, 5, 2),
    ],
)
def test_div_round_rounds_halves_away_from_zero(
    numerator: int, denominator: int, expected: int
) -> None:
    assert div_round(numerator, denominator) == expected


def test_div_round_rejects_zero_denominator() -> None:
    with pytest.raises(ZeroDivisionError):
        div_round(1, 0)


def test_apply_bp() -> None:
    assert apply_bp(200, 1_500) == 30
    assert apply_bp(3, 5_000) == 2  # 1.5 rounds up
    assert apply_bp(-3, 5_000) == -2
    assert apply_bp(123, BP) == 123


def test_with_bonus() -> None:
    assert with_bonus(1_000, 1_200) == 1_120
    assert with_bonus(1_000, -2_500) == 750


def test_ratio_bp() -> None:
    assert ratio_bp(1, 3) == 3_333
    assert ratio_bp(2, 3) == 6_667
    assert ratio_bp(5, 0) == 0


def test_clamp() -> None:
    assert clamp(15, 0, 10) == 10
    assert clamp(-1, 0, 10) == 0
    assert clamp(5, 0, 10) == 5
    with pytest.raises(ValueError, match="empty"):
        clamp(1, 5, 0)
