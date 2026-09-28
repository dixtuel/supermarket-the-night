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
| A | Left-click the pointed control |
| B | Right-click |
| Start | Pause or resume the shift |
| Select | Go back or cancel |
| X | Interact with nearby consoles |
| Y | Restart after a run |
| Select + Start | PortMaster's exit shortcut |

The game uses PortMaster's `gptokeyb` mapping: left-stick WASD moves the character, repeating D-pad arrows move menu focus, and the right stick moves the pointer. A/B send literal left/right mouse clicks. Since each physical button has one mapping, A is reserved for left-click; point at a UI control with the right stick to activate it. X remains E for nearby console interaction, Y remains R to restart after a run, Start pauses, and Select cancels. PortMaster's `$GPTOKEYB` helper supplies the firmware-specific Start + Select exit behavior. Desktop, Android, and touch movement keep the existing input path.

## Build

Run `scripts/build_portmaster.sh` from the repository root with Godot 4.7.1 installed. It imports the Godot project, exports the PortMaster PCK, then creates a PortMaster-ready ZIP. See `docs/portmaster.md` for requirements and packaging notes.

## Licenses

The game source is MIT licensed. License files for the game, Godot Engine and the PortMaster gptokeyb / Westonpack projects are in `supermarketthenight/licenses/`. Godot and Westonpack are installed by PortMaster as shared runtimes and are not included in this port package.
