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

# Cloud graphics toolchain (Godot, render queue, reference still) lives in /tmp and is wiped by
# a container restart; rebuild it in the background so a restart costs a minute, not a day (D-293).
if [ -d /tmp/claude-0 ] || mkdir -p /tmp/claude-0 2>/dev/null; then
  nohup bash scripts/dev/cloud-toolchain.sh > /tmp/claude-0/toolchain.log 2>&1 &
fi
