"""Everything that talks to a language model (arrives in Phase 2).

The model proposes, the engine decides: this package returns validated proposals and never
changes game state itself. It must not import pygame or the UI layer
(enforced by tests/test_architecture.py).
"""
