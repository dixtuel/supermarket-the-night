# Supermarket: The Night — v0.3.1-alpha

Producer: dixtuel  
Engine: Godot 4.7.2  
Platforms: Windows x86_64, Linux x86_64, Android 8+.

## What's new

- Added seven selectable difficulty levels, with each level applying its own progression profile to enemy health, damage and speed, economy, loot, wave pressure, elites, and environmental hazards.
- Difficulty levels unlock in order: complete the 20-wave shift on the current level to unlock the next one.
- Difficulty selection now follows character selection and shows the selected level's player-facing description and effects. Turkish text is supported by the bundled font.
- Difficulty tuning and its wave/economy effects were reconciled against the Brotato wiki reference notes in the repository.

## Also included

- Select Night Clerk or DNZ before an Endless or 20-wave shift. The title screen remembers the last character played.
- DNZ has a dedicated look, starting stats, and the Milk Hose, an elemental cone weapon with four shop tiers.
- The unkillable manager boss appears for DNZ in waves 8 and 16 of a 20-wave shift, then every 10 Endless waves after wave 20. His dash, flame burst, tether slow, hit reactions, and wall collision stuns make room to dodge without turning the fight into a damage race.
- Weapons use their authored damage category: melee, ranged, elemental, or engineering. The Box Cutter swings at nearby enemies and is available through the normal shop and tier system.
- Improved the turret, mine, helper-follow, depot crate, and manager-office table presentation.
- Character and difficulty selection work with keyboard, gamepad, touch, and PortMaster input.

## Windows touchscreen status

The Windows executable and package in this release were exported with Godot 4.7.2. Sustained Windows 11 touchscreen joystick dragging at 1920×1080 has not been verified. Godot 4.7.2 has an upstream freeze issue during sustained touchscreen dragging; use keyboard or gamepad on Windows if this affects your device. This limitation is specific to the Windows 4.7.2 build.

## Downloads

- **Windows x86_64:** `SupermarketTheNight-0.3.1-alpha-Windows-x86_64.zip`
- **Linux x86_64:** `SupermarketTheNight-0.3.1-alpha-Linux-x86_64.zip`
- **Android 8+:** `SupermarketTheNight-0.3.1-alpha.apk` — install the APK directly; it is not wrapped in a ZIP. Includes ARMv7, ARM64, and x86_64.

This is an alpha build. Save data and balance may change before the first stable release.
