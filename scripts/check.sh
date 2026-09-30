#!/usr/bin/env bash
# Run every automated check: the same ones CI runs. Usage: scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Installing exact locked dependencies"
uv sync --locked
echo "==> Lint (ruff)"
uv run ruff check .
echo "==> Formatting (ruff format)"
uv run ruff format --check .
echo "==> Types (mypy)"
uv run mypy
echo "==> Tests (pytest)"
uv run pytest
echo "All checks passed."
