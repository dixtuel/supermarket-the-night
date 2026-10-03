## Notes

Thanks to [dixtuel](https://github.com/dixtuel) for creating [Supermarket: The Night](https://github.com/dixtuel/supermarket-the-night), a top-down survival game set across four connected supermarket rooms.

## Controls

| Button | Action |
|---|---|
| Left stick | Move |
| D-pad | Navigate menus and choices |
| Right stick | Move the pointer |
| A | Confirm |
| B | Back or cancel |
| Start | Pause or resume |
| Select | Back or cancel |
| X | Interact |
| Y | Restart after a run |
| L1 / R1 | Left or right click |

## Compile

Install Godot 4.7.1 and its matching export templates. From the project root, import the assets and export the PortMaster pack:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --export-pack "PortMaster (Godot 4.7)" port/supermarketthenight/supermarketthenight/SupermarketTheNight.pck
```
