# Difficulty selection and progression analysis

## Sources and limits

This pass uses the locally collected wiki tables and their scope/freshness notes, with a cross-check of the current Danger Levels, Elite and Horde Waves, Materials, Shop, Enemies, and Endless Mode pages. The collection contains normalized JSON tables, not the separate raw `.txt` exports mentioned in earlier notes. The wiki is community-maintained, so version-dependent values below are tied to the captured page revisions.

Source pages reviewed: Danger Levels, Elite and Horde Waves, Materials, Shop, Enemies, and Endless Mode.

## What the reference difficulty system changes

Each Danger level inherits the previous level’s mechanics. The health and damage percentages are totals relative to the baseline, not values to add together. The wiki’s progression is:

| Reference level | Enemy / wave changes | Total enemy health and damage modifier | Boss / environment changes |
|---|---|---:|---|
| Danger 0 | No difficulty modifiers | 0% | — |
| Danger 1 | New enemies appear | 0% | — |
| Danger 2 | One elite or horde wave, on wave 11 or 12; new enemies | 0% | Elites on wave 11–12 have 75% health and drop a high-value crate |
| Danger 3 | Danger 2 plus stronger enemies | +12% | — |
| Danger 4 | Three elite/horde waves distributed across 11–18 | +26% | First two may be hordes (40%) or elites (60%); third is guaranteed elite on 17 or 18 |
| Danger 5 | Danger 4 plus two wave-20 bosses | +40% | Each final boss has 75% of its usual health |
| Nightmare | Danger 5 rules, environmental projectiles and obscuring fog | +60% health and damage; +10% speed | Difficulty remains cumulative in mechanics; these are Nightmare’s total enemy stat modifiers |

The three campaign challenge windows are 11–12, 14–15, and 17–18. At Danger 2–3 only the first window is used. At Danger 4–5, the first two events each have a 40% Horde / 60% Elite outcome; the third is always an Elite. Challenge waves are added on top of the regular wave roster; an Elite does not replace an authored boss or the wave's regular enemies. Campaign elites are selected without repetition from the project's three authored elite enemy resources. Elites on wave 12 or earlier use 75% health and their campaign reward is a Tier IV item plus a 100 HP heal. Danger 5 has two wave-20 bosses, each at 75% of their normal health.

Hordes add enemies and multiply each enemy's material-drop chance by 0.65; they do not reduce the material amount on a successful drop. The normal enemy material-drop chance is 100% through wave 4, then drops by 1.5 percentage points per wave to a 50% floor. Horde's 0.65 multiplier is applied after that floor and can take the total chance below 50%. The Shop shows the next challenge event. Current Danger Levels do not add general shop inflation or player-stat/upgrade multipliers; older Danger inflation is explicitly called out as historical behavior.

Endless organizes rounds into 10-wave blocks after wave 20. Hordes stop. Danger 2–3 adds one randomly placed Elite event per block; Danger 4–5 adds three. Both regular bosses spawn every tenth round regardless of selected Danger. Endless adds one more Elite to each Elite or boss event per completed 10-wave block. The reference Endless Factor is zero through wave 20, then `triangular((wave - 20)) / 100 × (2 + max(0, (wave - 35) × 0.2))`; enemy damage uses `1 + factor`, enemy HP uses `1 + 2.25 × factor`, enemy speed uses `1 + min(1.75, factor / 13.33)`, and item prices use `1 + factor / 5`. Endless enemy material-drop chance continues the 1.5 percentage-point decay to a 50% floor.

The current Shop reference says that shop prices scale by base item cost and wave, and that Danger-based shop inflation was a behavior of earlier versions. It does not list current shop-price or player-stat multipliers for Danger 0–5. Wave length, level-up reward sizes, and normal shop offer rarity use their own progression rules. Elite crate rewards are a separate challenge-wave reward, not a general shop discount or player-stat bonus.

## Mapping into Supermarket: The Night

This project has authored immutable `WaveDefinition` resources (campaign: `data/waves/`, Endless: `data/endless/`), an adaptive `RuntimeWaveDirector`, a 20-wave campaign, boss/resource actors, and wave-based shop price inflation. Difficulty operates on per-run copies of authored wave resources; it does not mutate shared `.tres` data.

| New game tier | Project effect and owner | What stays independent |
|---|---|---|
| 0 — Quiet Shift | Existing authored enemy mix and tuning. | Shop, level-up choices, player stats, durations, and boss schedule retain their current rules. |
| 1 — Late Delivery | Adds the fast Scanline Runner to wave pools from the early campaign. | No flat enemy stat increase. |
| 2 — Busy Night | Adds the Cooler Dripper to unlocked pools; one randomly selected 11–12 event. It is a Horde (40%) or an Elite (60%). Elites use a unique authored elite archetype and 75% health through wave 12. | No difficulty-tier shop inflation or direct player/weapon/stat modifier. Horde changes material-drop chance, not the amount per successful drop. |
| 3 — Overtime | Adds the Coupon Tosser and multiplies normal enemy health and incoming damage by 1.12. Keeps one random 11–12 challenge wave. | Player offense and upgrade values do not get an artificial bonus or penalty. |
| 4 — Stockroom Rush | Adds the Pallet Jack Pusher; total enemy health and damage ×1.26; three challenge events in 11–12, 14–15, and 17–18. The first two are Horde (40%) or Elite (60%); the last is guaranteed Elite. Horde adds enough authored budget and spawn cadence to reach a denser 60-second encounter. | Normal shop-price inflation and upgrade rolls still follow the game’s own campaign progression. |
| 5 — Closing Time | Adds the Night Shift Supervisor to the enemy mix; total enemy health and damage ×1.40; same three challenge windows; two wave-20 bosses at 75% normal health. | The DNZ Manager remains character-specific and is not duplicated as an immortal boss. |
| 6 — Nightmare | Inherits Closing Time; enemy health and damage ×1.60, movement speed ×1.10, low-opacity fog, and periodic environmental shots that travel toward the player. | Fog remains faint for readability; the game has no accessibility sliders in this pass. |

Project-side roster tuning: each unlocked added archetype enters from `max(3, 9 - tier)` and receives a 3.5% spawn weight on eligible rounds; the remaining authored weights are normalized to 96.5%. Horde waves multiply the authored planned count by 1.6, the live-enemy cap by 1.5 (bounded by the game's 54-enemy cap), and divide spawn interval by 1.6 (bounded at 0.35 seconds). The 1.6 factor is the project's density setting for a fixed 60-second round; it is not claimed to match the source game's exact Horde count.

Challenge-wave rounds and campaign Elite choices are rolled once per run, saved, and shown before the wave. Endless challenge rounds are rolled once per 10-wave block and saved; Endless Elites may repeat, as the reference allows. Every wave is duplicated before its changes. Horde converts this game's fixed-duration spawn budget and cadence into a denser encounter, and the exact 0.65 material-drop chance factor is applied independently of the existing custom token reward scale. Existing three elite `.tres` definitions supply the encounter behaviors; their authored HP/damage growth remains in effect. The Endless Factor is applied to enemy HP, damage, speed, material-drop chance, item prices, and reroll costs. Endless boss rounds also spawn the reference-counted extra Elites. The code is in `levels/arena/arena.gd`; tier values are in `data/difficulty_catalog.gd`.

The direct player-side systems use their own rarity tables. Campaign difficulty does not add shop inflation or modify weapon damage, player stats, or upgrade effects; the reviewed wiki pages likewise list no current Danger modifiers for these. The project's existing wave/level progression remains authoritative. Endless shop prices and reroll costs do change with the Endless Factor, while offer rarity remains on the existing project progression.

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
