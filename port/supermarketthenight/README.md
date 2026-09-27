## Supermarket: The Night — PortMaster

This package runs the Godot 4.7 project through PortMaster's Godot and Westonpack runtimes. It targets 64-bit ARM handhelds such as the R36S and requires the Godot 4.7.1 and Westonpack 0.2 runtimes.

Thanks to Asrın Kılıç (dixtuel) for creating the game.

## Controls

| Button | Action |
| --- | --- |
| D-pad / left stick | Move and navigate menus |
| A / Start | Confirm, choose, or continue |
| B / Back | Pause or go back |
| X | Interact with nearby consoles |
| Y | Restart after a run |
| Select + Start | PortMaster's exit shortcut |

The game uses keyboard-style controls through PortMaster's `gptokeyb`; no game-specific native libraries are bundled.

## Build

Run `scripts/build_portmaster.sh` from the repository root with Godot 4.7.1 installed. It imports the Godot project, exports the PortMaster PCK, then creates a PortMaster-ready ZIP. See `docs/portmaster.md` for requirements and packaging notes.

## Licenses

The game source is MIT licensed. License files for the game, Godot Engine and the PortMaster gptokeyb / Westonpack projects are in `supermarketthenight/licenses/`. Godot and Westonpack are installed by PortMaster as shared runtimes and are not included in this port package.
