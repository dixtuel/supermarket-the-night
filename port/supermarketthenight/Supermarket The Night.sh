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

GAMEDIR="/$directory/ports/supermarketthenight"
CONFDIR="$GAMEDIR/conf"
GODOT_RUNTIME="godot_4.7.1"
GODOT_EXECUTABLE="godot471.${DEVICE_ARCH}"
WESTON_RUNTIME="weston_pkg_0.2"
WESTON_DIR="/tmp/weston"
GODOT_DIR="/tmp/godot"

mkdir -p "$CONFDIR"
cd "$GAMEDIR" || exit 1
: > "$GAMEDIR/log.txt"
exec > >(tee "$GAMEDIR/log.txt") 2>&1

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
$GPTOKEYB "$GODOT_EXECUTABLE" -c "$GAMEDIR/supermarketthenight/supermarketthenight.gptk" &
pm_platform_helper "$GODOT_DIR/$GODOT_EXECUTABLE"

$ESUDO env "$WESTON_DIR/westonwrap.sh" headless noop kiosk crusty_x11egl \
  XDG_DATA_HOME="$CONFDIR" \
  "$GODOT_DIR/$GODOT_EXECUTABLE" \
  --resolution "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}" -f \
  --rendering-driver opengl3_es --audio-driver ALSA \
  --main-pack "$GAMEDIR/supermarketthenight/SupermarketTheNight.pck"

$ESUDO "$WESTON_DIR/westonwrap.sh" cleanup
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "$WESTON_DIR" >/dev/null 2>&1 || true
  $ESUDO umount "$GODOT_DIR" >/dev/null 2>&1 || true
fi
pm_finish
