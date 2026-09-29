# Difficulty selection and progression analysis

## Sources and limits

This pass uses the project’s Brotato wiki snapshot (`research/brotato/wiki_inventory.json`), its scope and freshness notes (`research/brotato/COVERAGE.md` and `capture_reconciliation.json`), and the current Danger Levels, Waves, Shop, Stats, and Progress pages. The project checkout has a normalized page/table snapshot, not the raw `.txt` exports mentioned in the earlier research notes. The snapshot labels the Weapons page 1.1.6.3 and warns that the wiki is community-maintained and behind the official 1.1.15.4 patch line; exact table claims below were cross-checked against the current Danger Levels and Waves pages.

Sources: [Danger Levels](https://brotato.wiki.spellsandguns.com/Danger_Levels), [Waves](https://brotato.wiki.spellsandguns.com/Waves), [Shop](https://brotato.wiki.spellsandguns.com/Shop), [Stats](https://brotato.wiki.spellsandguns.com/Stats), [Progress](https://brotato.wiki.spellsandguns.com/Progress).

## What the reference difficulty system changes

Each Danger level inherits the previous level’s mechanics. The health and damage percentages are totals relative to the baseline, not values to add together. The wiki’s progression is:

| Reference level | Enemy / wave changes | Total enemy health and damage modifier | Boss / environment changes |
|---|---|---:|---|
| Danger 0 | No difficulty modifiers | 0% | — |
| Danger 1 | New enemies appear | 0% | — |
| Danger 2 | One elite or horde wave, on wave 11 or 12; new enemies | 0% | Elites on wave 11–12 have 75% health and drop a high-value crate in Brotato |
| Danger 3 | Danger 2 plus stronger enemies | +12% | — |
| Danger 4 | Three elite/horde waves distributed across 11–18 | +26% | First two may be hordes (40%) or elites (60%); third is guaranteed elite on 17 or 18 |
| Danger 5 | Danger 4 plus two wave-20 bosses | +40% | Each final boss has 75% of its usual health |
| Nightmare | Danger 5 rules, environmental projectiles and obscuring fog | +60% health and damage; +10% speed | Difficulty remains cumulative in mechanics; these are Nightmare’s total enemy stat modifiers |

The three late challenge-wave windows are 11–12, 14–15, and 17–18. At Danger 2–3 only the first window is used. At Danger 4–5, the first two waves each have a 40% horde / 60% elite outcome; the final wave is always elite. Brotato’s optional accessibility sliders are separate from Danger progression: they alter enemy damage, health, and speed and are shown alongside the Danger level. They are not automatically part of the tier unlock system.

The current Shop reference says that shop prices scale by base item cost and wave, and that Danger-based shop inflation was a behavior of earlier versions. It does not list current shop-price or player-stat multipliers for Danger 0–5. Wave length, level-up reward sizes, and normal shop offer rarity use their own progression rules. Elite crate rewards are a separate challenge-wave reward, not a general shop discount or player-stat bonus.

## Mapping into Supermarket: The Night

This project has authored immutable `WaveDefinition` resources (campaign: `data/waves/`, Endless: `data/endless/`), an adaptive `RuntimeWaveDirector`, a 20-wave campaign, boss/resource actors, and wave-based shop price inflation. Difficulty operates on per-run copies of authored wave resources; it does not mutate shared `.tres` data.

| New game tier | Project effect and owner | What stays independent |
|---|---|---|
| 0 — Quiet Shift | Existing authored enemy mix and tuning. | Shop, level-up choices, player stats, durations, and boss schedule retain their current rules. |
| 1 — Late Delivery | Adds the fast Scanline Runner to wave pools from the early campaign. | No flat enemy stat increase. |
| 2 — Busy Night | Adds the Cooler Dripper to unlocked pools; one randomly selected 11–12 pressure wave. The wave gets +24% spawn budget, +25% live-enemy cap, and 12% faster spawn cadence. | No direct price, XP value, level-up, weapon, or player-stat multiplier. More defeated enemies can yield more normal pickups. |
| 3 — Overtime | Adds the Coupon Tosser and multiplies normal enemy health and incoming damage by 1.12. Keeps one random 11–12 challenge wave. | Player offense and upgrade values do not get an artificial bonus or penalty. |
| 4 — Stockroom Rush | Adds the Pallet Jack Pusher; total enemy health and damage ×1.26; three challenge waves in 11–12, 14–15, and 17–18. Each has the same density/cadence increase; the final challenge spawns an elite Supervisor. | Normal shop-price inflation and upgrade rolls still follow the game’s existing wave/player progression. |
| 5 — Closing Time | Adds the Night Shift Supervisor to the enemy mix; total enemy health and damage ×1.40; same three challenge windows; two wave-20 bosses, each at 75% of its normal health. | The DNZ Manager remains in its character-specific waves and is not duplicated as an immortal boss. |
| 6 — Nightmare | Inherits Closing Time; enemy health and damage ×1.60, movement speed ×1.10, faint screen-space haze, and periodic environmental shots from outside the play area. | Haze opacity is intentionally low for readability; there are no accessibility sliders in this pass. |

Challenge-wave candidate windows and outcomes are rolled once per run and retained for all menu/runtime reporting. The per-run wave resources are duplicated before difficulty changes, including Endless patterns. Enemy health is applied through the existing health multiplier; enemy damage through the current survivability-aware damage director; Nightmare speed through `EnemyActor` movement; special waves use bounded spawn count/cap/cadence changes. The paired wave and economy code is in `levels/arena/arena.gd`; difficulty descriptions and values are in `data/difficulty_catalog.gd`.

The direct player-side systems do not currently have a rarity tier/rarity table analogous to Brotato. The game already has its own wave/level-based offer rarity and upgrade amount rules. Applying Danger as a second multiplier to shop weapons, player stats, or upgrade effects would compound those systems without support from the current wiki reference or the game’s existing balance model, so those remain unchanged. This is an intentional explicit boundary, not an unintegrated difficulty hook.

## Unlock and selection flow

The menu sequence is now: select a character → inspect/select difficulty → start the chosen run. Campaign completion at wave 20 unlocks the next difficulty, up through Nightmare; this is saved in the existing `bakkal_records.cfg` progression section. The unlock is global across characters so a player does not have to replay earlier difficulties for every character. Endless uses the selected difficulty, but an Endless survival record alone does not unlock the next campaign tier. Resume restores the run’s selected tier. Restart must keep the same tier.

On desktop and PortMaster, the difficulty carousel supports left/right and up/down actions, focus navigation, and the focused start/back buttons. On touch devices, character carousel arrows and action buttons have larger minimum targets; the character and difficulty dialogs can scroll within the safe-area card. The UI states exact enemy percentages, challenge-wave windows, Nightmare additions, and that shop prices/player upgrade amounts are unchanged. A locked tier may be previewed but cannot be started; its Start button explains the Wave 20 prerequisite.

## Font coverage

The title UI keeps its current display face and adds a packaged DejaVu Sans glyph fallback for Turkish characters (Ç, Ğ, İ, Ö, Ş, Ü and lowercase variants). The same fallback is set as Godot’s theme fallback so default-font Controls use it on desktop, Android, and handheld builds. The regular font’s license is retained next to the asset.

## Verification still required

- Godot 4.7.2 headless editor parse and Android debug APK export succeeded. The APK installed and launched on an API 36 emulator using the host NVIDIA GPU.
- Character and difficulty screens were visually inspected on the emulator. Turkish glyphs render, both selection steps are navigable, level 1 is visibly locked and cannot be started, and the longest Nightmare details fit within the card. Character carousel arrows were enlarged after the first inspection.
- Still to verify: full 20-wave campaign completion and unlock persistence across difficulty 0→1; locked/unlocked boundaries; Endless and resume/restart difficulty retention; narrow native-phone layout and PortMaster 960×720 physical device/controller behavior.
- SwiftShader/software-GPU rendering launched the process but produced a black screen with a GL shader-uniform-limit error. Host-GPU rendering is clean; the software renderer issue matches [Godot issue #109550](https://github.com/godotengine/godot/issues/109550).

Difficulty numbers are reference-informed first tuning, not playtested balance. Density events, the original game's adaptive damage director, and Nightmare projectiles interact; these effects need full-run balancing after the UI/runtime smoke checks.
