#!/bin/bash
# Installs the project's exact locked dependencies when a Claude Code on the web session
# starts, so tests, linters and type checks work straight away. Does nothing locally.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# uv lives in ~/.local/bin in the cloud image; install it from PyPI if it is missing.
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
  python3 -m pip install --quiet --user uv
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"
uv sync --locked
