#!/usr/bin/env bash
# Builds the downloadable app (D-050):
#
#   scripts/package.sh mac [GODOT_BINARY]     -> build/Anachronism-mac.zip
#   scripts/package.sh linux [GODOT_BINARY]   -> build/linux/ (used by CI to test the
#                                                packaged app end to end: unpack, fetch
#                                                Python, answer, quit)
#
# The title screen shows "Version N" (N = the number of commits), so each build has a higher
# number than the last. Needs Godot 4.5.1 and its export templates (CI downloads both). The app carries the Python
# engine's source and uv inside it; on first launch it unpacks them and uv fetches Python
# and the libraries, so the owner installs nothing. Unsigned: see docs/GETTING_STARTED.md.
set -euo pipefail

PLATFORM="${1:?mac or linux}"
GODOT="${2:-godot}"
UV_VERSION="0.8.17"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$ROOT/client/engine_src"
CACHE="${ANACHRONISM_BUILD_CACHE:-$ROOT/build/cache}"

echo "==> Staging the engine inside the client"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$CACHE"
cp "$ROOT/pyproject.toml" "$ROOT/uv.lock" "$ROOT/README.md" "$ROOT/.python-version" "$STAGE/"
cp -R "$ROOT/src" "$STAGE/"
find "$STAGE/src" -name __pycache__ -prune -exec rm -rf {} +
git -C "$ROOT" rev-parse --short HEAD > "$STAGE/STAMP"
# the version shown on the title screen: the number of commits, so each build is higher
VERSION="$(git -C "$ROOT" rev-list --count HEAD)"
echo "Version $VERSION · $(date -u '+%-d %b %Y')" > "$STAGE/VERSION"
if [ "$PLATFORM" = mac ]; then
  ARCHES="aarch64 x86_64"; OS_TRIPLE="apple-darwin"
else
  ARCHES="x86_64"; OS_TRIPLE="unknown-linux-gnu"
fi
for arch in $ARCHES; do
  name="uv-$arch-$OS_TRIPLE"
  archive="$CACHE/$name-$UV_VERSION.tar.gz"
  if [ ! -f "$archive" ]; then
    curl -sSL -o "$archive" "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/$name.tar.gz"
  fi
  tar -xzf "$archive" -C "$CACHE" "$name/uv"
  cp "$CACHE/$name/uv" "$STAGE/bin/uv-$arch"
done

echo "==> Importing and testing the client (from source)"
"$GODOT" --headless --path "$ROOT/client" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/client" -- --smoke | tee /dev/stderr | grep -q "SMOKE OK"

echo "==> Exporting"
mkdir -p "$ROOT/build"
if [ "$PLATFORM" = mac ]; then
  OUT="$ROOT/build/Anachronism-mac.zip"
  rm -f "$OUT"
  "$GODOT" --headless --path "$ROOT/client" --export-release "macOS" "$OUT"
else
  rm -rf "$ROOT/build/linux"
  mkdir -p "$ROOT/build/linux"
  OUT="$ROOT/build/linux/anachronism.x86_64"
  "$GODOT" --headless --path "$ROOT/client" --export-release "Linux" "$OUT"
fi
rm -rf "$STAGE"
ls -la "$OUT"
