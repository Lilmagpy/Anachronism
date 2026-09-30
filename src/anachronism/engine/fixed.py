"""Integer fixed-point maths.

The engine uses integers only, so every computer produces identical results (D-035).
Rates and 0-100 stats are basis points: ``10_000 bp = 100%``.
"""

from __future__ import annotations

BP = 10_000


def div_round(numerator: int, denominator: int) -> int:
    """Divide and round to the nearest integer, with halves rounded away from zero."""
    if denominator == 0:
        raise ZeroDivisionError("div_round() denominator is zero")
    if denominator < 0:
        numerator, denominator = -numerator, -denominator
    quotient, remainder = divmod(abs(numerator), denominator)
    if 2 * remainder >= denominator:
        quotient += 1
    return quotient if numerator >= 0 else -quotient


def apply_bp(value: int, bp: int) -> int:
    """Return ``value * bp / 10_000``, rounded (e.g. ``apply_bp(200, 1_500) == 30``)."""
    return div_round(value * bp, BP)


def with_bonus(value: int, bonus_bp: int) -> int:
    """Return ``value`` increased by ``bonus_bp`` (negative bonuses reduce it), rounded."""
    return div_round(value * (BP + bonus_bp), BP)


def ratio_bp(part: int, whole: int) -> int:
    """Return ``part / whole`` in basis points, rounded; a zero ``whole`` gives 0."""
    if whole == 0:
        return 0
    return div_round(part * BP, whole)


def clamp(value: int, low: int, high: int) -> int:
    """Limit ``value`` to the inclusive range ``[low, high]``."""
    if low > high:
        raise ValueError(f"clamp() range is empty: {low} > {high}")
    return max(low, min(high, value))
