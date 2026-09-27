# Project instructions

## Product and runtime

- This is **Bakkal After Dark**, a single-player top-down 2D survival game made in GDScript.
- Target Godot **4.7.2** and desktop builds for Windows x86_64 and CachyOS/Arch Linux x86_64.
- Keep the project suitable for a free itch.io release. Do not add ads, online services, accounts, Steam integration, multiplayer, mobile/web targets, plugins, or external packages without a clear project need.
- Preserve the original grocery-store setting, art direction, names, UI, writing, and audio. Reference games inform general mechanics only; do not copy their code, assets, maps, text, or distinctive presentation.

## Structure and ownership

- Keep gameplay responsibilities split among `levels/`, `entities/`, `combat/`, `progression/`, `data/`, and `ui/`; avoid turning the arena into a general-purpose manager.
- Authored definitions in `data/` are read-only run inputs. Store mutable run state on runtime actors/controllers, not shared `.tres` resources.
- Use direct references and explicit signals. Add autoloads only for project-wide services with a clear need.
- Every external asset must have its exact source and license recorded in `ATTRIBUTION.md`; retain its license/provenance files. Project MIT licensing does not relicense art, fonts, audio, or other assets.
- Before parallel edits, agree on file ownership and shared interfaces. Do not overwrite another contributor's changes.

## Verification and reporting

- For GDScript, scene, resource, or project setting changes, run `godot --headless --path . --editor --quit` and report the result.
- For gameplay/UI changes, also perform an actual desktop smoke run and inspect the visible result where possible. Headless startup does not establish that controls, audio devices, layout, balance, or the complete run work.
- For release changes, validate both export presets and test each exported build on its target OS. State explicitly when a target machine is unavailable.
- Do not claim gameplay balance, full-run completion, visual QA, audio playback, performance, or platform compatibility from static inspection or a short headless launch.
- Do not add test infrastructure or run optional tests unless the task asks for verification; for this project, the milestone and release acceptance checks in the game plan are required verification.
