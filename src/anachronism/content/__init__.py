"""Data-pack schemas, loading and validation.

Content is data (YAML files), never code. This package may use pydantic and pyyaml but must
not import the engine, LLM or UI layers (enforced by tests/test_architecture.py).
"""
