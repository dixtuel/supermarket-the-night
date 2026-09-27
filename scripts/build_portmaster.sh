#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || command -v godot4 || true)}"
PRESET="PortMaster (Godot 4.7)"
PORT_ROOT="$REPO_ROOT/port/supermarketthenight"
GAME_ROOT="$PORT_ROOT/supermarketthenight"
PCK_PATH="$GAME_ROOT/SupermarketTheNight.pck"
OUTPUT_DIR="$REPO_ROOT/builds/portmaster"
PACKAGE_PATH="$OUTPUT_DIR/supermarketthenight.zip"

if [[ -z "$GODOT_BIN" || ! -x "$GODOT_BIN" ]]; then
  echo "Set GODOT_BIN to an executable Godot 4.7.1 binary." >&2
  exit 1
fi

GODOT_VERSION="$("$GODOT_BIN" --version)"
if [[ "$GODOT_VERSION" != 4.7.1* ]]; then
  echo "PortMaster runtime is Godot 4.7.1; found ${GODOT_VERSION}." >&2
  exit 1
fi

mkdir -p "$GAME_ROOT/licenses" "$OUTPUT_DIR"
"$GODOT_BIN" --headless --path "$REPO_ROOT" --editor --import --quit
"$GODOT_BIN" --headless --path "$REPO_ROOT" --export-pack "$PRESET" "$PCK_PATH"

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT
cp "$PORT_ROOT/Supermarket The Night.sh" "$STAGE_DIR/"
cp "$PORT_ROOT/supermarketthenight.gptk" "$STAGE_DIR/"
mkdir -p "$STAGE_DIR/supermarketthenight/licenses"
cp "$PCK_PATH" "$STAGE_DIR/supermarketthenight/"
cp "$PORT_ROOT/screenshot.png" "$STAGE_DIR/supermarketthenight/"
cp "$GAME_ROOT/licenses/"* "$STAGE_DIR/supermarketthenight/licenses/"
(
  cd "$STAGE_DIR"
  zip -9 -FS -r "$PACKAGE_PATH" "Supermarket The Night.sh" supermarketthenight.gptk supermarketthenight
)

echo "Created $PCK_PATH"
echo "Created $PACKAGE_PATH"
