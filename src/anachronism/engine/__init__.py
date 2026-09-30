"""Pure, deterministic game rules.

Rules for this package (enforced by tests/test_architecture.py):
- no pygame, no network, no imports from ``anachronism.llm``, ``ui`` or ``tools``;
- no randomness except through ``engine.rng.GameRng`` (arrives in Phase 1);
- no wall-clock time and no threads: the same seed and actions must replay the same game.
"""
