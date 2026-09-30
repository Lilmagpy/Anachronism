"""Seeded, serialisable random numbers: the only source of randomness in the game.

The generator is PCG32 (the XSH-RR variant, https://www.pcg-random.org), implemented here in
pure Python so the sequence is identical on every computer and every Python version (D-030).
Its whole state is two integers kept in ``GameState.rng``, so a saved game continues with
exactly the numbers it would have drawn anyway.
"""

from __future__ import annotations

from collections.abc import MutableSequence, Sequence

from pydantic import BaseModel, ConfigDict, Field

from anachronism.engine.fixed import BP

_MASK32 = 0xFFFF_FFFF
_MASK64 = 0xFFFF_FFFF_FFFF_FFFF
_MULTIPLIER = 6_364_136_223_846_793_005
_TWO_32 = 1 << 32
DEFAULT_STREAM = 54


class RngState(BaseModel):
    """The complete, serialisable state of a :class:`GameRng`."""

    model_config = ConfigDict(extra="forbid")

    state: int = Field(ge=0, le=_MASK64)
    inc: int = Field(ge=1, le=_MASK64)


class GameRng:
    """A PCG32 generator that reads and updates an :class:`RngState` in place."""

    def __init__(self, state: RngState) -> None:
        if state.inc % 2 == 0:
            raise ValueError("RngState.inc must be odd")
        self._state = state

    @classmethod
    def from_seed(cls, seed: int, stream: int = DEFAULT_STREAM) -> GameRng:
        """Create a generator from a seed, following the PCG reference seeding procedure."""
        state = RngState(state=0, inc=((stream << 1) | 1) & _MASK64)
        rng = cls(state)
        rng.next_u32()
        state.state = (state.state + seed) & _MASK64
        rng.next_u32()
        return rng

    @property
    def state(self) -> RngState:
        """The state object this generator updates (store it to save the generator)."""
        return self._state

    def next_u32(self) -> int:
        """Return the next raw 32-bit output."""
        old = self._state.state
        self._state.state = (old * _MULTIPLIER + self._state.inc) & _MASK64
        xorshifted = (((old >> 18) ^ old) >> 27) & _MASK32
        rotation = old >> 59
        return ((xorshifted >> rotation) | (xorshifted << (-rotation & 31))) & _MASK32

    def below(self, bound: int) -> int:
        """Return a uniformly distributed integer in ``[0, bound)``, without modulo bias."""
        if not 0 < bound <= _TWO_32:
            raise ValueError(f"bound must be between 1 and 2**32, got {bound}")
        threshold = (_TWO_32 - bound) % bound
        while True:
            value = self.next_u32()
            if value >= threshold:
                return value % bound

    def between(self, low: int, high: int) -> int:
        """Return a uniformly distributed integer in the inclusive range ``[low, high]``."""
        if low > high:
            raise ValueError(f"empty range: {low} > {high}")
        return low + self.below(high - low + 1)

    def chance(self, bp: int) -> bool:
        """Return True with probability ``bp / 10_000``.

        Always consumes exactly one draw, so changing a probability never shifts the numbers
        drawn afterwards.
        """
        return self.below(BP) < bp

    def pick[T](self, items: Sequence[T]) -> T:
        """Return one element of ``items``, chosen uniformly."""
        if not items:
            raise ValueError("cannot pick from an empty sequence")
        return items[self.below(len(items))]

    def weighted_index(self, weights: Sequence[int]) -> int:
        """Return an index chosen with probability proportional to its non-negative weight."""
        if any(weight < 0 for weight in weights):
            raise ValueError("weights must not be negative")
        total = sum(weights)
        if total == 0:
            raise ValueError("at least one weight must be positive")
        target = self.below(total)
        for index, weight in enumerate(weights):
            if target < weight:
                return index
            target -= weight
        raise AssertionError("unreachable: target always falls inside the total")

    def shuffle[T](self, items: MutableSequence[T]) -> None:
        """Shuffle ``items`` in place (Fisher-Yates)."""
        for index in range(len(items) - 1, 0, -1):
            other = self.below(index + 1)
            items[index], items[other] = items[other], items[index]
