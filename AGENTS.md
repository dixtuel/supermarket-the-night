# Project Instructions & Agent Guidelines

## Product and Runtime

- **Game Title:** **Supermarket: The Night**
- **Repository Description:** A 2D top-down rogue-lite horde-survival game set inside an eerie night-shift supermarket. Hold the aisles, upgrade your gear, manage stockrooms, and survive the 20-wave graveyard shift.
- **Engine & Version:** Godot **4.7.2** (GDScript)
- **Target Platforms:** Desktop builds for CachyOS / Arch Linux x86_64 and Windows x86_64.
- **Release Target:** Free itch.io release (`https://dixtuel.itch.io/supermarket-the-night`). Keep the codebase lean, self-contained, and free of external DRM, accounts, or telemetry.

## Structure and Ownership

- Keep gameplay responsibilities strictly divided:
  - `levels/`: Arena wave loops, multi-room state machine (`market`, `depot`, `restroom`, `manager_office`), and room events.
  - `entities/`: Player actor, enemy actors, AI movement, slow patches, and temporary shift helpers.
  - `combat/`: Weapons, projectile physics, damage calculations, and automatic targeting.
  - `progression/`: XP orbs, consumable pickups, supply request drops, and upgrade catalog.
  - `data/`: Read-only definitions (`.tres`) for waves, shifts, upgrades, weapons, and enemies.
  - `ui/`: Compact HUD, shift shop, pause/settings modals, resolution switcher, and credits.
- Collision boundaries and room hitboxes must strictly match physical ground-contact footprints with pixel-level precision. Avoid oversized generic rectangular colliders; author non-overlapping, custom collision shapes and polygons that allow natural player navigation.
- All external assets and pack licenses are documented in `ATTRIBUTION.md`. The MIT code license applies to authored codebase only.

## Verification and Quality Standards

- Verify changes using `godot --headless --path . --editor --quit` or dedicated test scenes.
- Smoke-test full gameplay loops, room portal transitions, and shop interactions on desktop.
- Before committing and pushing releases, ensure export presets cleanly build and upload to itch.io via Butler and push to GitHub.
