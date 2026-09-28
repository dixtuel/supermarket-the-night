# PortMaster / R36S build

The PortMaster build is an additional Godot `Linux/X11` PCK export named `PortMaster (Godot 4.7)`. Its `portmaster` custom feature isolates handheld startup, 4:3 UI scaling, and fixed-screen settings from the Android, desktop Linux, and Windows exports.

## Device and runtime requirements

- 64-bit ARM (`aarch64`) handheld running a PortMaster-compatible firmware. This includes current R36S ArkOS-family builds when their PortMaster runtime supports the device.
- PortMaster's Godot 4.7.1 and Westonpack 0.2 shared runtimes.
- Compatibility renderer, ETC2 texture export, keyboard-emulated controller input through `gptokeyb`.
- PortMaster input is isolated by the `portmaster` custom feature: left stick sends WASD to gameplay movement, D-pad arrows navigate focused menus, A confirms, Start pauses/resumes, B/Select cancels, X interacts, and Y restarts after a run. The PortMaster `$GPTOKEYB` helper supplies firmware-specific Start + Select exit behavior. Existing desktop and Android input paths remain in place.
- Internet access the first time the two shared runtimes are installed.

The PortMaster New runtime manifest currently includes `godot_4.7.1.squashfs` and `weston_pkg_0.2.squashfs` in the `aarch64` runtime bundle. The Godot runtime contains `godot471.aarch64`; the Westonpack runtime contains `westonwrap.sh` and its `crusty_x11egl` renderer. The launcher uses those published filenames.

The game targets Godot 4.7 and the runtime registry currently exposes Godot 4.7.1. The R36S hardware and each firmware build still need a device-level launch, input, audio, suspend/resume, and performance check before claiming release compatibility.

## Controller mapping references

The mapping follows the PortMaster `gptokeyb` configuration model: logical D-pad buttons map to keyboard arrows and the left analog directions map to WASD. `$GPTOKEYB` chooses the firmware-specific exit hotkey and kill method; firmware supplies the SDL controller layout, so the port uses PortMaster logical button names instead of hard-coded raw event IDs. dArkOSRE documents standard D-pad navigation and A confirmation while supporting multiple R36S/clone board variants; the retired ArkOS-R3XS repository points R36S users to dArkOSRE.

References: [PortMaster gptokeyb documentation](https://portmaster.games/gptokeyb-documentation.html), [dArkOSRE R36S wiki](https://github.com/southoz/dArkOSRE-R36/wiki/EmulationStation), [ArkOS-R3XS repository](https://github.com/AeolusUX/ArkOS-R3XS).

## Build a package

Install Godot 4.7.1 and set `GODOT_BIN` if the executable is not on `PATH`:

```sh
GODOT_BIN=/path/to/godot-4.7.1 ./scripts/build_portmaster.sh
```

The script imports project assets, exports the PCK into `port/supermarketthenight/supermarketthenight/`, and creates `builds/portmaster/supermarketthenight.zip`. It does not export or rewrite the Android, desktop Linux, or Windows presets.

PortMaster catalog metadata is kept alongside the package in `port/supermarketthenight/`: `port.json`, `README.md`, the launcher, `gameinfo.xml`, 4:3 gameplay screenshot, controller mapping, and license notices. The Godot and Westonpack runtimes are installed by PortMaster and are not copied into the game archive.

## Controls

The controller profile maps left stick to WASD gameplay actions, D-pad to repeating arrow keys for menu focus, A to Enter (`ui_accept` on the focused Godot control), Start and B/Select to Escape, X to E (nearby console interaction), and Y to R (restart from results). A activates focused buttons through Godot UI input rather than emitting a literal mouse click. The title, pause, choice, and shop screens create focusable controls. WASD and arrow keys are separate in the PortMaster player movement path. The standard desktop keyboard movement and Android touch movement continue to use their original actions.
