#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

if [ ! -f "$controlfolder/control.txt" ]; then
  echo "PortMaster control.txt not found at $controlfolder" >&2
  exit 1
fi
source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GAMEDIR="/$directory/ports/supermarketthenight"
CONFDIR="$GAMEDIR/conf"
PCK_PATH="$GAMEDIR/supermarketthenight/SupermarketTheNight.pck"
GODOT_RUNTIME="godot_4.7.1"
GODOT_EXECUTABLE="godot471.${DEVICE_ARCH}"
WESTON_RUNTIME="weston_pkg_0.2"
WESTON_DIR="/tmp/weston"
GODOT_DIR="/tmp/godot"

mkdir -p "$CONFDIR"
cd "$GAMEDIR" || exit 1
: > "$GAMEDIR/log.txt"
exec > >(tee "$GAMEDIR/log.txt") 2>&1

if [[ ! -s "$PCK_PATH" ]]; then
  # PortMaster installs under /$directory/ports, but some frontends launch a
  # copied entry or mount the ROM root at a different path. Resolve the bundled
  # PCK from the launcher location as a fallback before reporting a bad install.
  for candidate in \
    "$SCRIPT_DIR/supermarketthenight/SupermarketTheNight.pck" \
    "$GAMEDIR/SupermarketTheNight.pck" \
    "$SCRIPT_DIR/SupermarketTheNight.pck"; do
    if [[ -s "$candidate" ]]; then
      PCK_PATH="$candidate"
      break
    fi
  done
fi

if [[ ! -s "$PCK_PATH" ]]; then
  pm_message "Game data is missing under $GAMEDIR. Check the installed port folder and reinstall the full ZIP if SupermarketTheNight.pck is absent."
  sleep 5
  exit 1
fi

runtime_check_and_mount() {
  local runtime_name="$1"
  local mount_point="$2"
  local runtime_file="$controlfolder/libs/${runtime_name}.squashfs"

  if [ ! -f "$runtime_file" ]; then
    if [ ! -f "$controlfolder/harbourmaster" ]; then
      pm_message "This port requires the latest PortMaster and its ${runtime_name} runtime."
      sleep 5
      exit 1
    fi
    $ESUDO "$controlfolder/harbourmaster" --quiet --no-check runtime_check "${runtime_name}.squashfs"
  fi

  $ESUDO mkdir -p "$mount_point"
  if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "$mount_point" >/dev/null 2>&1 || true
  fi
  $ESUDO mount "$runtime_file" "$mount_point"
}

runtime_check_and_mount "$WESTON_RUNTIME" "$WESTON_DIR"
runtime_check_and_mount "$GODOT_RUNTIME" "$GODOT_DIR"

if [ ! -x "$GODOT_DIR/$GODOT_EXECUTABLE" ]; then
  pm_message "${GODOT_EXECUTABLE} is missing from the installed Godot 4.7.1 runtime."
  sleep 5
  exit 1
fi

export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export XDG_CONFIG_HOME="$CONFDIR"
KEYB_HELPER="${GPTOKEYB2:-$GPTOKEYB}"
$KEYB_HELPER "$GODOT_EXECUTABLE" -c "$GAMEDIR/supermarketthenight/supermarketthenight.gptk" &
pm_platform_helper "$GODOT_DIR/$GODOT_EXECUTABLE"

$ESUDO env "$WESTON_DIR/westonwrap.sh" headless noop kiosk crusty_x11egl \
  XDG_DATA_HOME="$CONFDIR" \
  "$GODOT_DIR/$GODOT_EXECUTABLE" \
  --resolution "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}" -f \
  --rendering-driver opengl3_es --audio-driver ALSA \
  --main-pack "$PCK_PATH"

$ESUDO "$WESTON_DIR/westonwrap.sh" cleanup
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "$WESTON_DIR" >/dev/null 2>&1 || true
  $ESUDO umount "$GODOT_DIR" >/dev/null 2>&1 || true
fi
pm_finish
