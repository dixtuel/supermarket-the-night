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

STAGE_PARENT="${TMPDIR:-$REPO_ROOT/builds/portmaster/.tmp}"
mkdir -p "$STAGE_PARENT"
STAGE_DIR="$(mktemp -d -p "$STAGE_PARENT" pm_stage.XXXXXX)"
trap 'rm -rf "$STAGE_DIR"' EXIT
cp "$PORT_ROOT/Supermarket The Night.sh" "$STAGE_DIR/"
mkdir -p "$STAGE_DIR/supermarketthenight/licenses"
cp "$PCK_PATH" "$STAGE_DIR/supermarketthenight/"
cp "$GAME_ROOT/supermarketthenight.ini" "$STAGE_DIR/supermarketthenight/"
cp "$PORT_ROOT/screenshot.png" "$STAGE_DIR/supermarketthenight/"
cp "$PORT_ROOT/port.json" "$STAGE_DIR/supermarketthenight/"
cp "$PORT_ROOT/README.md" "$STAGE_DIR/supermarketthenight/supermarketthenight.md"
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
	for relative_path in (
		Path("Supermarket The Night.sh"), Path("supermarketthenight"),
	):
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

python3 - "$PACKAGE_PATH" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET
import zipfile

package_path = sys.argv[1]
required = {
    "Supermarket The Night.sh",
    "supermarketthenight/port.json",
    "supermarketthenight/supermarketthenight.md",
    "supermarketthenight/gameinfo.xml",
    "supermarketthenight/screenshot.png",
    "supermarketthenight/supermarketthenight.ini",
    "supermarketthenight/SupermarketTheNight.pck",
}
with zipfile.ZipFile(package_path) as archive:
    names = set(archive.namelist())
    missing = sorted(required - names)
    if missing:
        raise SystemExit("PortMaster ZIP is missing required entries: " + ", ".join(missing))

    port = json.loads(archive.read("supermarketthenight/port.json"))
    if port.get("items") != ["Supermarket The Night.sh", "supermarketthenight"]:
        raise SystemExit("port.json items must contain only the launcher and game data folder")
    if port.get("attr", {}).get("runtime") != ["weston_pkg_0.2.squashfs", "godot_4.7.1.squashfs"]:
        raise SystemExit("port.json runtime keys do not match the PortMaster runtime catalog")
    if "supermarketthenight/supermarketthenight.gptk" in names:
        raise SystemExit("New packages must use the gptokeyb2 INI profile")
    if not archive.read("supermarketthenight/supermarketthenight.md").startswith(b"## Notes\n"):
        raise SystemExit("Port notes must start with the Notes section")
    if b"\xe2\x80\x94" in archive.read("supermarketthenight/supermarketthenight.md"):
        raise SystemExit("Port notes must not contain em dashes")

    root = ET.fromstring(archive.read("supermarketthenight/gameinfo.xml"))
    game = root.find("game")
    if game is None:
        raise SystemExit("gameinfo.xml has no game entry")
    launcher = game.findtext("path", "").removeprefix("./")
    image = game.findtext("image", "").removeprefix("./")
    if launcher not in names or image not in names:
        raise SystemExit("gameinfo.xml launcher or catalog image path does not exist in the ZIP")
PY

echo "Created $PCK_PATH"
echo "Created $PACKAGE_PATH"
