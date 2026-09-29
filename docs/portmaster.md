# PortMaster / R36S build

The PortMaster build is an additional Godot `Linux/X11` PCK export named `PortMaster (Godot 4.7)`. Its `portmaster` custom feature isolates handheld startup, 4:3 UI scaling, and fixed-screen settings from the Android, desktop Linux, and Windows exports.

## R36S 3.5-inch screen layout

R36S uses a 640×480 4:3 display. At PortMaster startup the game sets Godot's `content_scale_size` to 1.5 times the detected panel dimensions and uses `CANVAS_ITEMS` with `EXPAND`. On a 640×480 panel this makes a 960×720 logical canvas, giving interface text and panels more physical pixels than the desktop 1920×1080 design canvas while preserving the display aspect. The PortMaster title panel gets extra width for long Turkish labels, and the title character shifts right to keep the menu clear. Controller UI sizes do not use phone DPI-derived touch sizing. The camera fits the full store width on 4:3. All these changes are behind the `portmaster` feature; the Android, desktop Linux, and Windows project scale and camera paths remain unchanged.

The 640×480 layout was reviewed in an x86_64 Godot/Xvfb simulation. Title, help, settings, records, credits, pause, in-game settings, bonus choices, shop offers, weapon details, results, and an active arena were captured. D-pad focus moved through the title menu; the exported arena and controls were exercised in the simulation. This is not a physical R36S test; ARM64 performance, analog-stick hardware, audio, and firmware compatibility still need device validation.

## Device and runtime requirements

- 64-bit ARM (`aarch64`) handheld running a PortMaster-compatible firmware. This includes current R36S ArkOS-family builds when their PortMaster runtime supports the device.
- PortMaster's Godot 4.7.1 and Westonpack 0.2 shared runtimes.
- Compatibility renderer, ETC2 texture export, keyboard-emulated controller input through `gptokeyb`.
- PortMaster input is isolated by the `portmaster` custom feature: left stick sends WASD to gameplay movement, D-pad arrows navigate focused menus without auto-repeat, and native joypad events are removed from Godot's UI actions to prevent duplicate navigation. A sends Enter to activate the focused control; B sends Escape to cancel/go back; X sends E for interaction; Y sends R to restart after a run; Start sends Escape to pause/resume; L1/R1 send left/right mouse clicks while the right stick moves the pointer. The launcher uses PortMaster's `GPTOKEYB2` helper (falling back to `GPTOKEYB`) so keyboard and mouse events are delivered through its SDL/Weston path. The helper supplies firmware-specific Select + Start exit behavior. Existing desktop and Android input paths remain in place.
- Internet access the first time the two shared runtimes are installed.

The PortMaster New runtime manifest currently includes `godot_4.7.1.squashfs` and `weston_pkg_0.2.squashfs` in the `aarch64` runtime bundle. The Godot runtime contains `godot471.aarch64`; the Westonpack runtime contains `westonwrap.sh` and its `crusty_x11egl` renderer. The launcher uses those published filenames.

The game targets Godot 4.7 and the runtime registry currently exposes Godot 4.7.1. The R36S hardware and each firmware build still need a device-level launch, input, audio, suspend/resume, and performance check before claiming release compatibility.

## Controller mapping references

The mapping uses PortMaster's logical controller names, not raw button IDs: D-pad arrows drive Godot focus, left analog directions map to WASD, and right analog directions move the mouse. dArkOSRE's EmulationStation configuration records device-specific physical button/axis IDs for supported R36S board variants; PortMaster resolves those through its controller database before exposing the logical names to gptokeyb2. This is why the port does not hard-code a single R36S GUID. The legacy ArkOS-R3XS repository points R36S users to dArkOSRE.

References: [PortMaster gptokeyb documentation](https://portmaster.games/gptokeyb-documentation.html), [dArkOSRE R36S wiki](https://github.com/southoz/dArkOSRE-R36/wiki/EmulationStation), [ArkOS-R3XS repository](https://github.com/AeolusUX/ArkOS-R3XS).

## Build a package

Install Godot 4.7.1 and set `GODOT_BIN` if the executable is not on `PATH`:

```sh
GODOT_BIN=/path/to/godot-4.7.1 ./scripts/build_portmaster.sh
```

The script imports project assets, exports the PCK into `port/supermarketthenight/supermarketthenight/`, and creates `builds/portmaster/supermarketthenight.zip` with the launcher, runtime data, `port.json`, README, screenshot, and `gameinfo.xml`. The metadata includes the catalog description, release date, and installed screenshot path. It does not export or rewrite the Android, desktop Linux, or Windows presets.

PortMaster catalog metadata is kept alongside the package in `port/supermarketthenight/`: `port.json`, `README.md`, the launcher, `gameinfo.xml`, 4:3 gameplay screenshot, controller mapping inside the port directory, and license notices. The Godot and Westonpack runtimes are installed by PortMaster and are not copied into the game archive.

The launcher is tracked with mode `0644` per current PortMaster-New reviewer guidance. The catalog screenshot is a clean 640×480 gameplay capture. The local test ZIP carries `port.json`, README, `gameinfo.xml`, and the screenshot alongside the game data inside its `supermarketthenight/` folder, matching the paths produced by PortMaster-New.

## PortMaster-New submission steps

The game repository package is a candidate package, not an official catalog submission. Before opening a PortMaster-New PR, follow the current upstream contribution instructions: test the release package with the PortMaster community in Discord `#testing-n-dev`, fix reported issues, and document a hardware/firmware matrix. Current reviewer guidance expects coverage beyond a single device, including Rocknix, MuOS, dArkOS, Knulli, and ArkOS, with a 640×480 test resolution. Then add only this port under `ports/supermarketthenight/` in a PortMaster-New fork, run `python3 tools/build_release.py --do-check`, and submit a PR. The existing x86_64/Xvfb validation does not satisfy the community hardware test stage.

References: [PortMaster-New submission guide](https://github.com/PortsMaster/PortMaster-New#submitting-a-pr), [PortMaster-New reviewer/testing requirements](https://github.com/PortsMaster/PortMaster-New/blob/main/AGENTS.md).

## Controls

The PortMaster controller profile maps left stick to WASD gameplay actions, D-pad to non-repeating arrow keys for menu focus, right stick to mouse movement, A to Enter (focused UI confirmation), B to Escape (back/cancel), X to E (nearby console interaction), Y to R (restart from results), Start to Escape (pause), and L1/R1 to left/right mouse clicks. The UI removes direct joypad events from its directional and accept/cancel actions on this export to avoid duplicate D-pad handling. WASD and arrow keys are separate in the PortMaster player movement path. The standard desktop, Linux, Windows, Android, and touch input paths remain unchanged.
