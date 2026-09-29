## Supermarket: The Night — PortMaster

This package runs the Godot 4.7 project through PortMaster's Godot and Westonpack runtimes. It targets 64-bit ARM handhelds such as the R36S and requires the Godot 4.7.1 and Westonpack 0.2 runtimes.

The 640×480 screenshot shows the game running with the PortMaster handheld layout. It was captured in an x86_64/Xvfb simulation; physical handheld compatibility has not yet been confirmed.

Thanks to Asrın Kılıç (dixtuel) for creating the game.

## Controls

| Button | Action |
| --- | --- |
| Left stick | Move the character |
| D-pad | Navigate menus and choices with focus |
| Right stick | Move the mouse pointer |
| A | Confirm the focused control |
| B | Back or cancel |
| Start | Pause or resume the shift |
| Select | Go back or cancel |
| X | Interact with nearby consoles |
| Y | Restart after a run |
| L1 / R1 | Left-click / right-click at the pointer |
| Select + Start | PortMaster's exit shortcut |

The game uses PortMaster's `GPTOKEYB2` mapping (with the legacy helper as a fallback): left-stick WASD moves the character, D-pad arrows navigate menu focus without key repeat, and the right stick moves the pointer. A sends Enter to activate the focused control; B sends Escape to go back or cancel. X remains E for nearby console interaction, Y remains R to restart after a run, and L1/R1 send left/right mouse clicks. Start pauses and Select goes back; PortMaster's helper supplies the firmware-specific Select + Start exit behavior. Desktop, Linux, Windows, Android, and touch input keep their existing paths.

The package includes `gameinfo.xml`, catalog screenshot, and `port.json` beside the game data so local installs can display the release date, description, and image in the PortMaster/EmulationStation metadata flow.

## Build

Run `scripts/build_portmaster.sh` from the repository root with Godot 4.7.1 installed. It imports the Godot project, exports the PortMaster PCK, then creates a PortMaster-ready ZIP. See `docs/portmaster.md` for requirements and packaging notes.

## Licenses

The game source is MIT licensed. License files for the game, Godot Engine and the PortMaster gptokeyb / Westonpack projects are in `supermarketthenight/licenses/`. Godot and Westonpack are installed by PortMaster as shared runtimes and are not included in this port package.
