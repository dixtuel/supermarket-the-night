#!/usr/bin/env bash
set -euo pipefail
umask 022

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
mkdir -p "$STAGE_DIR/supermarketthenight/licenses"
cp "$PCK_PATH" "$STAGE_DIR/supermarketthenight/"
cp "$GAME_ROOT/supermarketthenight.gptk" "$STAGE_DIR/supermarketthenight/"
cp "$PORT_ROOT/screenshot.png" "$STAGE_DIR/supermarketthenight/"
cp "$PORT_ROOT/port.json" "$STAGE_DIR/supermarketthenight/"
cp "$PORT_ROOT/README.md" "$STAGE_DIR/supermarketthenight/"
cp "$PORT_ROOT/gameinfo.xml" "$STAGE_DIR/supermarketthenight/"
cp "$GAME_ROOT/licenses/"* "$STAGE_DIR/supermarketthenight/licenses/"
# Root sessions may start with umask 077. Keep archive contents readable after
# HarbourMaster installs them; launcher scripts intentionally remain mode 0644.
chmod -R a+rX "$STAGE_DIR"
find "$STAGE_DIR" -type f -exec chmod 0644 {} +
find "$STAGE_DIR" -type d -exec chmod 0755 {} +
if command -v zip >/dev/null 2>&1; then
	(
		cd "$STAGE_DIR"
		zip -9 -FS -r "$PACKAGE_PATH" "Supermarket The Night.sh" supermarketthenight
	)
else
	python3 - "$STAGE_DIR" "$PACKAGE_PATH" <<'PY'
import os
import stat
import sys
import zipfile
from pathlib import Path

stage_dir = Path(sys.argv[1])
package_path = Path(sys.argv[2])
with zipfile.ZipFile(package_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
	for relative_path in (Path("Supermarket The Night.sh"), Path("supermarketthenight")):
		paths = [stage_dir / relative_path]
		if paths[0].is_dir():
			paths.extend(sorted(paths[0].rglob("*")))
		for path in paths:
			archive_name = path.relative_to(stage_dir).as_posix()
			info = zipfile.ZipInfo.from_file(path, archive_name)
			mode = stat.S_IMODE(path.stat().st_mode)
			info.external_attr = (stat.S_IFDIR if path.is_dir() else stat.S_IFREG | mode) << 16
			if path.is_dir():
				info.external_attr = (stat.S_IFDIR | mode) << 16
				info.filename = archive_name.rstrip("/") + "/"
			archive.writestr(info, b"" if path.is_dir() else path.read_bytes())
PY
fi

chmod 0644 "$PACKAGE_PATH"

echo "Created $PCK_PATH"
echo "Created $PACKAGE_PATH"
