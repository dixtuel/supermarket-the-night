# Supermarket: The Night — v0.3.0-alpha

Producer: dixtuel  
Engine: Godot 4.7.2  
Platforms: Windows x86_64, Linux x86_64, Android 8+.

## What's new

- Choose Night Clerk or DNZ before an Endless or 20-wave shift. The title screen remembers the last character played.
- DNZ has a dedicated look, starting stats, and the Milk Hose, an elemental cone weapon with four shop tiers.
- The unkillable manager boss appears for DNZ in waves 8 and 16 of a 20-wave shift, then every 10 Endless waves after wave 20. His dash, flame burst, tether slow, hit reactions, and wall collision stuns make room to dodge without turning the fight into a damage race.
- Weapons now use their authored damage category: melee, ranged, elemental, or engineering. The new Box Cutter swings at nearby enemies and is available through the normal shop and tier system.
- Improved the turret, mine, helper-follow, depot crate, and manager-office table presentation.
- Character selection and controls remain usable with keyboard, gamepad, touch, and PortMaster input.

## Windows touchscreen status

The Windows package in this alpha was exported with Godot 4.7.2 because an official downloadable Godot 4.7.3 export toolchain is not available in this environment. Windows 11 sustained touchscreen joystick dragging has **not been verified for this build**; Godot 4.7.2 has an upstream freeze issue in that scenario. Use keyboard or gamepad on Windows for this version. The upstream fix has been cherry-picked into the 4.7 branch for 4.7.3; a later Windows build should be made with that toolchain and tested on a touchscreen device at 1920×1080.

## Downloads

- **Windows x86_64:** `SupermarketTheNight-0.3.0-alpha-Windows-x86_64.zip`
- **Linux x86_64:** `SupermarketTheNight-0.3.0-alpha-Linux-x86_64.zip`
- **Android 8+:** `SupermarketTheNight-0.3.0-alpha.apk` — one APK for ARMv7, ARM64, and x86_64; install the APK directly without extracting an archive.

This is an alpha build. Save data and balance may change before the first stable release.
