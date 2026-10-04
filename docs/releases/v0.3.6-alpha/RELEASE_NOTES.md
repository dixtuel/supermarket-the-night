# Supermarket: The Night — v0.3.6-alpha

Developer: dixtuel

Engine: Godot 4.7.2 (PortMaster package exported with Godot 4.7.1)

Platforms: Windows x86_64, Linux x86_64, Android 8+, and PortMaster (aarch64).

## What's new

### R36S & PortMaster Thermal and Performance Optimization
- **60 FPS Framerate Cap**: Capped rendering to 60 FPS via `--max-fps 60` in `Supermarket The Night.sh` and `Engine.max_fps = 60` in `display_manager.gd`.
  - In headless Westonpack (`weston_pkg_0.2` + `crusty_x11egl`), swap-buffers calls do not block on display vblank. Without an explicit frame cap, the game previously rendered at uncapped 200–400+ FPS, maxing out all 4 CPU cores and the GPU at 100% duty cycle and causing severe heating.
  - Capping to 60 FPS allows CPU and GPU execution units to sleep between frames, substantially lowering device temperature and preserving battery life.

### PortMaster Right-Stick Cursor
- Added an integrated, lightweight custom mouse pointer indicator (`PortMasterCursor`) that appears dynamically when using right-stick mouse emulation on handhelds and auto-hides after inactivity.

### Internationalization
- Set default startup language to English (`en`) for international accessibility while retaining full Turkish language support selectable in the Settings menu.

## PortMaster Testing Package
- Package Archive: `supermarketthenight.zip` (available on Google Drive testing link).
- Runtimes: Requires PortMaster's Godot 4.7.1 and Westonpack 0.2 squashfs runtimes.

This is an alpha build. Save data and balance may change before the first stable release.
