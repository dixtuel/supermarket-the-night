# Supermarket: The Night — v0.2.1-alpha

Producer: dixtuel  
Engine: Godot 4.7.2  
Platforms: Windows x86_64, Linux x86_64, and Android 8+.

## Changes

- Fixed repeated deployable creation that could freeze the game when placing turrets.
- Turrets now appear once per owned slot near the start of a wave, at a random nearby position. They stay fixed and indestructible; a small chance places one in another room.
- Mines stay where they are placed until triggered. After exploding, they return after a short delay at a different position.
- Turrets and mines are listed separately from weapons in the shop inventory and do not consume weapon slots. Shop cards identify them as deployable skills.
- Tightened the HUD layout for narrow desktop windows to prevent the health/XP and shift report panels from overlapping.

## Downloads

- **Windows x86_64:** `SupermarketTheNight-0.2.1-alpha-Windows-x86_64.zip`
- **Linux x86_64:** `SupermarketTheNight-0.2.1-alpha-Linux-x86_64.zip`
- **Android 8+:** `SupermarketTheNight-0.2.1-alpha.apk` — one APK with ARMv7, ARM64, and x86_64 support.

The Android APK is signed for direct itch.io installation. No archive extraction is needed on Android.

This is an alpha build. Balance and crowded-wave performance still need broader testing.
