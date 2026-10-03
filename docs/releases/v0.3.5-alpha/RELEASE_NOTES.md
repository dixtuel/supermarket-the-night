# Supermarket: The Night — v0.3.5-alpha

Developer: dixtuel

Engine: Godot 4.7.2 (PortMaster package exported with Godot 4.7.1)

Platforms: Windows x86_64, Linux x86_64, Android 8+, and PortMaster (aarch64).

## What's new

### PortMaster & Handheld UI Improvements
- **Start+Select Freeze Fix**: Fixed `gptokeyb2` process name truncation (`TASK_COMM_LEN` 15 chars limit) by passing `godot471` instead of `godot471.aarch64`, preventing gptokeyb2 hang and player control freeze.
- **Shop UI Polish**:
  - Restored weapon sprite visibility on PortMaster shop layout (`z_index = 1` and fallback loading).
  - Added focused outline indicators for category return buttons ("Reyonlara Dön"), inventory items, and weapon slots.
  - Enlarged skill offer cards to fit 480p landscape without bottom dead space and optimized typography for readability.
- **Title Screen & Modals**:
  - Vertically centered main menu button labels and glyph icons.
  - Character Select: Properly framed action buttons ("Geri", "Zorluk Seç") with dashed rules and applied clean outline focus styles.
  - Difficulty Select: Fixed navigation cycling bugs when moving between difficulty tiers; scaled all 6 difficulty buttons to fit within 640×480 screen width without horizontal overflow; removed thick white glowing focus box on locked start button; compacted modifier descriptions.
  - How to Play: Added D-pad up/down scrolling support to the terminal guide, scaled row heights for handhelds, and lifted the "Back to Shift" button away from the screen bottom edge.

### Launcher & PortMaster Standard Compliance
- Updated `Supermarket The Night.sh` launcher script according to PortMaster upstream packaging guidelines, removing redundant control checks and using standard runtime bindings.
- Switched to official `gptokeyb2` `.ini` format and added upstream license files for `gptokeyb2` and `inih`.
