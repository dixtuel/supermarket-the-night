## Supermarket: The Night — PortMaster

This package runs the Godot 4.7 project through PortMaster's Godot and Westonpack runtimes. It targets 64-bit ARM handhelds such as the R36S and requires the Godot 4.7.1 and Westonpack 0.2 runtimes.

Thanks to Asrın Kılıç (dixtuel) for creating the game.

## Controls

| Button | Action |
| --- | --- |
| Left stick | Move the character |
| D-pad | Navigate menus and choices |
| A | Confirm, choose, or continue |
| Start | Pause or resume the shift |
| B / Back | Go back; pause or resume during a shift |
| X | Interact with nearby consoles |
| Y | Restart after a run |
| Select + Start | PortMaster's exit shortcut |

The game uses keyboard-style controls through PortMaster's `gptokeyb`. The left-stick WASD actions are reserved for gameplay movement; repeating arrow keys from the D-pad drive Godot menu focus without moving the player. A sends Enter (`ui_accept`), activating the currently focused Godot button like a confirm/click; it does not send a literal mouse click. Menus set an initial focus and expose focus navigation. Start + Select exits through `gptokeyb` kill mode. Desktop, Android, and touch movement keep the existing input path.

## Build

Run `scripts/build_portmaster.sh` from the repository root with Godot 4.7.1 installed. It imports the Godot project, exports the PortMaster PCK, then creates a PortMaster-ready ZIP. See `docs/portmaster.md` for requirements and packaging notes.

## Licenses

The game source is MIT licensed. License files for the game, Godot Engine and the PortMaster gptokeyb / Westonpack projects are in `supermarketthenight/licenses/`. Godot and Westonpack are installed by PortMaster as shared runtimes and are not included in this port package.
