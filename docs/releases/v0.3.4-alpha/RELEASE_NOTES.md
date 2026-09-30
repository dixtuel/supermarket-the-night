# Supermarket: The Night — v0.3.4-alpha

Developer: dixtuel

Engine: Godot 4.7.2 (PortMaster package exported with Godot 4.7.1)

Platforms: Windows x86_64, Linux x86_64, Android 8+, and a separate PortMaster package.

## What's new

- Shop offers now use the full available landscape height without putting offer-card text in a broken scroll view.
- Android shop details and inventory panels use wider layouts with explicit label/value columns, readable wrapping, working touch close actions, and touch swipe scrolling.
- Reduced oversized Android shop action buttons so more offer content stays visible.
- Kept the PortMaster-specific scrolling and controller layout intact.

## Previous release changes

- The title and in-game settings now use the same settings panel and controls.
- Resolution and window-mode choices are shown on desktop only. They are hidden in both settings menus on Android and PortMaster.
- The title screen now exposes the manual and credits on mobile layouts, and offers Resume only when a saved run is available.
- Fixed Android HUD script loading so health/level HUD, enemies, and pickups appear during a run.
- The PortMaster launcher checks the installed game-data paths before reporting a missing PCK, with clearer recovery guidance.
- Losslessly optimized generated PNG assets without changing decoded image pixels.

## Android signing change

The previous 0.3.3 APK uses the new **dixtuel alpha release signing key**. The 0.3.2 APK was signed with Godot's default debug certificate, so Android will not install this APK over that copy. Uninstall the previous debug-signed APK before installing an alpha-signed build.

**Uninstalling removes the app's local save data. Back up any run or settings data before uninstalling if you need to keep it.** Alpha APKs keep the same alpha signing key so they can update in place.

## Windows touchscreen status

The Windows executable and package use Godot 4.7.2. Sustained Windows 11 touchscreen joystick dragging at 1920×1080 has not been verified. Godot 4.7.2 has an upstream freeze issue during sustained touchscreen dragging; use keyboard or gamepad on Windows if this affects your device.

## PortMaster status

The PortMaster archive targets Godot 4.7.1 and aarch64 handhelds. The launcher and archive layout were checked, but this release has not been validated on a physical R36S or across the full PortMaster firmware matrix.

## Downloads

- **Windows x86_64:** `SupermarketTheNight-0.3.4-alpha-Windows-x86_64.zip`
- **Linux x86_64:** `SupermarketTheNight-0.3.4-alpha-Linux-x86_64.zip`
- **Android 8+:** `SupermarketTheNight-0.3.4-alpha.apk` — install the APK directly; it is not wrapped in a ZIP. Includes ARMv7, ARM64, and x86_64.
- **PortMaster:** `supermarketthenight.zip` — separate handoff package; requires PortMaster's Godot 4.7.1 and Westonpack 0.2 shared runtimes.

This is an alpha build. Save data and balance may change before the first stable release.
