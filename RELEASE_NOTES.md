# Supermarket: The Night — v0.3.2-alpha

Producer: dixtuel  
Engine: Godot 4.7.2  
Platforms: Windows x86_64, Linux x86_64, Android 8+.

## What's new

- Weapon class families now grant set bonuses when matching weapons are held together. Class bonuses feed into the live player stats and weapon calculations.
- Added the Stock Hook and Case Breaker weapons, with matching upgrade definitions, art, tier progression, and shop integration.
- Reworked the title, character and difficulty selection, shop, level-up choices, inventory details, and pause/help panels to use responsive layouts across desktop, mobile, and PortMaster screens.
- Shop offers and inventory entries show their actual names, values, levels, and prices; weapon and item details open in a readable modal. Inventory can exceed the six weapon slots.
- Added saved-run resume to the title screen when a valid run is available.
- Adjusted difficulty profiles, weapon/stat links, XP and material harvesting interactions, and weapon-class contributions.
- Filled the 1920×1080 gameplay viewport and removed black gutters at common desktop aspect ratios without changing the separate Android and PortMaster camera-fitting paths.
- Simplified gameplay HUD panels and left-aligned the cleared count and its room line like the health readout.

## Also included

- Seven selectable difficulty levels with distinct enemy, economy, loot, wave pressure, elite, and hazard profiles. Higher levels unlock by completing the 20-wave shift.
- Night Clerk and DNZ characters; DNZ keeps a dedicated starting weapon, stat profile, and manager-boss encounters.
- Weapons use their authored melee, ranged, elemental, and engineering categories. The shop, level-up, and inventory screens read the live weapon and stat data.
- Keyboard, mouse, gamepad, touch, and PortMaster controls remain available on their supported platforms.

## Windows touchscreen status

The Windows executable and package in this release were exported with Godot 4.7.2. Sustained Windows 11 touchscreen joystick dragging at 1920×1080 has not been verified. Godot 4.7.2 has an upstream freeze issue during sustained touchscreen dragging; use keyboard or gamepad on Windows if this affects your device. This limitation is specific to the Windows 4.7.2 build.

## Downloads

- **Windows x86_64:** `SupermarketTheNight-0.3.2-alpha-Windows-x86_64.zip`
- **Linux x86_64:** `SupermarketTheNight-0.3.2-alpha-Linux-x86_64.zip`
- **Android 8+:** `SupermarketTheNight-0.3.2-alpha.apk` — install the APK directly; it is not wrapped in a ZIP. Includes ARMv7, ARM64, and x86_64.
This is an alpha build. Save data and balance may change before the first stable release.
