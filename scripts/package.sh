#!/usr/bin/env bash
# Builds the downloadable app (D-050):
#
#   scripts/package.sh mac [GODOT_BINARY]     -> build/Meritus-mac.zip
#   scripts/package.sh windows [GODOT_BINARY] -> build/Meritus-windows.zip (D-306; CI starts
#                                                it on a real Windows machine)
#   scripts/package.sh linux [GODOT_BINARY]   -> build/linux/ (used by CI to test the
#                                                packaged app end to end: unpack, fetch
#                                                Python, answer, quit)
#
# The title screen shows "Version N" (N = the number of commits), so each build has a higher
# number than the last. Needs Godot 4.5.1 and its export templates (CI downloads both). The app carries the Python
# engine's source and uv inside it; on first launch it unpacks them and uv fetches Python
# and the libraries, so the owner installs nothing. Unsigned: see docs/GETTING_STARTED.md.
set -euo pipefail

PLATFORM="${1:?mac, windows or linux}"
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
# The rome pack reads the city dataset from outside src/ (data/rome/city, D-289), so it ships too.
cp -R "$ROOT/data" "$STAGE/"
find "$STAGE/src" -name __pycache__ -prune -exec rm -rf {} +
git -C "$ROOT" rev-parse --short HEAD > "$STAGE/STAMP"
# the version shown on the title screen: the number of commits, so each build is higher
VERSION="$(git -C "$ROOT" rev-list --count HEAD)"
echo "Version $VERSION · $(date -u '+%-d %b %Y')" > "$STAGE/VERSION"
UV_RELEASES="https://github.com/astral-sh/uv/releases/download/$UV_VERSION"
if [ "$PLATFORM" = windows ]; then
  # one x86-64 build serves every PC (Windows on ARM runs it as it stands)
  name="uv-x86_64-pc-windows-msvc"
  archive="$CACHE/$name-$UV_VERSION.zip"
  if [ ! -f "$archive" ]; then
    curl -sSL -o "$archive" "$UV_RELEASES/$name.zip"
  fi
  unzip -q -o "$archive" uv.exe -d "$CACHE/$name"
  cp "$CACHE/$name/uv.exe" "$STAGE/bin/uv-x86_64.exe"
else
  if [ "$PLATFORM" = mac ]; then
    ARCHES="aarch64 x86_64"; OS_TRIPLE="apple-darwin"
  else
    ARCHES="x86_64"; OS_TRIPLE="unknown-linux-gnu"
  fi
  for arch in $ARCHES; do
    name="uv-$arch-$OS_TRIPLE"
    archive="$CACHE/$name-$UV_VERSION.tar.gz"
    if [ ! -f "$archive" ]; then
      curl -sSL -o "$archive" "$UV_RELEASES/$name.tar.gz"
    fi
    tar -xzf "$archive" -C "$CACHE" "$name/uv"
    cp "$CACHE/$name/uv" "$STAGE/bin/uv-$arch"
  done
fi

echo "==> Importing and testing the client (from source)"
"$GODOT" --headless --path "$ROOT/client" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/client" -- --smoke | tee /dev/stderr | grep -q "SMOKE OK"

echo "==> Exporting"
mkdir -p "$ROOT/build"
if [ "$PLATFORM" = mac ]; then
  OUT="$ROOT/build/Meritus-mac.zip"
  rm -f "$OUT"
  "$GODOT" --headless --path "$ROOT/client" --export-release "macOS" "$OUT"
elif [ "$PLATFORM" = windows ]; then
  # one file, Meritus.exe (the game data is inside it), zipped in a folder the owner unzips anywhere
  OUT="$ROOT/build/Meritus-windows.zip"
  rm -rf "$ROOT/build/windows" "$OUT"
  mkdir -p "$ROOT/build/windows/Meritus"
  "$GODOT" --headless --path "$ROOT/client" --export-release "Windows" "$ROOT/build/windows/Meritus/Meritus.exe"
  test -f "$ROOT/build/windows/Meritus/Meritus.exe"
  (cd "$ROOT/build/windows" && zip -q -r "$OUT" Meritus)
else
  rm -rf "$ROOT/build/linux"
  mkdir -p "$ROOT/build/linux"
  OUT="$ROOT/build/linux/anachronism.x86_64"
  "$GODOT" --headless --path "$ROOT/client" --export-release "Linux" "$OUT"
fi
rm -rf "$STAGE"
ls -la "$OUT"
