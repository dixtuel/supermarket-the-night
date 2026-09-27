# Gameplay/reference source review

**Review date:** 2026-09-26  
**Scope:** Read-only source review at the pinned revisions in `research/reference-repos/`. These notes describe code and data paths, not a claim that the games were visually played. Nothing was copied into Bakkal After Dark. Repository licensing and asset exceptions are recorded in the reference manifests.

## Core four

### BESTAGON / 01-survivor — MIT code

**Observed in source:** `resources/run_schedule.gd` and `resources/wave_resource.gd` describe time phases, start time, cadence, health scaling, elite chance and weighted enemy types. `scenes/director/run_director.gd` owns elapsed time, spawn cadence, live and per-type caps, boss events and cleanup bookkeeping. Weighted choice accepts an injected RNG. `scripts/progression.gd` and `scripts/upgrade_pool.gd` separate XP math and gated/rarity-weighted card draws; pause, level-up and result panels own presentation.

**Useful design direction:** author wave/phase data separately from the runtime director; use reproducible random streams and explicit enemy caps. Our full game needs authored 20-wave encounter schedules, not only one clock with a multiplier.

### Vampire Survivors Clone — migalvalm — MIT code; bundled asset terms unknown

**Observed in source:** `scenes/manager/arena_time_manager.gd` owns the run timer and end state. `enemy_manager.gd` uses timed weighted spawns and progressively lowers cadence while unlocking enemy types at thresholds. `experience_manager.gd` and `upgrade_manager.gd` split progression and selection. Its XP implementation advances at most one level and resets XP, losing overflow. Ability controller scenes own weapon behavior; pause and end screens are separate.

**Useful design direction:** keep timing/spawning/progression responsibilities apart and add enemy roles through authored unlock thresholds. Preserve excess XP and queue multiple choices; do not repeat this repo's discarded-XP edge case. Its code is MIT, but no asset provenance/license file was found, so bundled art/audio are not reusable.

### Slime Survivors — MIT code; GDQuest art is CC BY-NC-SA

**Observed in source:** `scripts/game.gd::start_wave` sets a finite quota and a short countdown; a spawn timer emits one enemy at a time until quota, and the wave advances after every spawned enemy dies. Death disables the weapon, then presents game-over and pause. `scripts/gun.gd` targets the nearest overlapping enemy. `get_valid_spawn_position()` checks spacing but `spawn_mob()` selects a path position directly instead, so that helper does not protect the live spawn path.

**Useful design direction:** finite enemy budgets make wave completion predictable and transitions explicit. For Bakkal, route all spawn candidates through the same full-footprint blocker check; do not rely on unused validation helpers. No XP/shop/boss system is present to adopt. Do not reuse the separately licensed assets.

### Riftbound Survivors — GPL-3.0; study only

**Observed in source:** `scripts/game/game_session.gd::tick`, `spawn_enemies`, `finish_wave`, and `begin_round` sequence combat, cleanup and wave end; the next round waits until remaining actors and pending blasts clear. Enemy choices/caps/gates live in `scripts/data/`. Every fifth round enters a boss encounter. Materials from kills feed both currency and XP. `scripts/game/shop.gd` models four offers, inflation, rerolls, locked offers and weapon combining. `scripts/data/upgrade_catalog.gd` rolls level-up choices; `main.gd` routes title, armory, shop, settings, pause and results, and `GameSession.reset_run` clears run actors before rebuilding.

**Useful design direction:** make the boundary between combat, cleanup, shop and next wave explicit; keep the shop board as data/state separate from its UI; define how materials feed both character growth and purchases. GPL-3.0 code and its generated GPL art remain outside this project.

## Additional candidates

### canvas-vampire-survivors — MIT

**Observed in source:** `src/stages.js` holds stage definitions/modifiers; `src/main.js::start` drives run/reset; `src/weapons.js` centralizes weapon execution/configuration; transient reuse is in `src/pool.js`.

**Useful design direction:** data-authored stage variation and a clear executor/data boundary. Pooling is an optimization option only after measuring Bakkal's actual transient load.

### VampireSurvivorsClone — Matthias Broske — MIT code; third-party assets credited separately

**Observed in source:** `Assets/Scripts/Gameplay/MonsterSpawnTable.cs` uses serialized curves for spawn rate/chance/health scaling; `LevelManager.cs` owns run/restart and boss timing. `AbilitySelectionDialog.cs` pauses for a choice; `Gameplay/Inventory/Inventory.cs` owns inventory; a chest fallback handles capacity.

**Useful design direction:** inspect authored spawn curves and capacity fallbacks as alternatives for keeping later waves readable. Do not move its Unity/C# architecture into the Godot project.

### GDLastOfTheSurvivors — no repository-level reuse license

**Observed in source:** `LastOfTheSurvivors/src/utilities/enemy_spawner.gd` consumes timing resources in `spawn_info.gd`; `src/character/character.gd::upgrade_character` contains a monolithic upgrade path. `src/global/global.gd` saves JSON under `res://`.

**Useful design direction:** reusable data-shaped spawn timing is worth comparing. Keep our feature systems small and separated, and save writable progress under `user://`. No code/assets reuse due to missing project license.

### sentaur-survivors — Apache-2.0 with separately credited content

**Observed in source:** `Assets/Scripts/Upgrades/UpgradeManager.cs` and `UpgradePathBase.cs` model limited upgrade paths; `SceneManagers/BattleSceneManager.cs::OnTryAgain` reloads the battle scene for reset. Its `EventManager` uses string event names and `List<object>` payloads; upgrade paths cap at level 3.

**Useful design direction:** put clear rank/cap rules on upgrades and make run reset repeatable. Keep typed Godot signals/data over an untyped global event bus.

### SurvivorsStarterKit — MIT code; C#/.NET 8 and Jolt 3D

**Observed in source:** `Scripts/GameManager.cs::DisplayPowerups` pairs a player powerup with an enemy escalation; `Scripts/Enemies/EnemyManager.cs` owns enemy behavior. Its 3D Jolt/C# assumptions do not match our 2D GDScript stack.

**Useful design direction:** future intermission offers can be balanced against upcoming pressure so a purchase has an immediately legible consequence. Keep the enemy-coupled offer idea as an option, not an imported dependency or a fixed design choice.

## Brotato product research

### Officially stated by the developer's Steam page

The official Steam listing says Brotato defaults to auto-firing with optional manual aim, supports six weapons at once, describes runs as under 30 minutes, says waves last 20–90 seconds, and states that materials grant experience while purchases are made in a between-wave shop. These are product facts published by the developer/publisher, not claims about its internal source code. Sources: [Brotato on Steam](https://store.steampowered.com/app/1942280/Brotato/) and [Blobfish's announcement](https://www.blobfish.dev/my-new-game-brotato/).

### Secondary detail from the community-maintained Brotato Wiki

The wiki describes materials as both XP and shop currency; an automatic post-wave shop with up to four offers; purchases, rerolls, locked offers and item/weapon availability restrictions; and duplicate weapon merging. It also lists detailed XP/stat formulas. These are community-maintained reference data, not official source-code evidence, and should be rechecked against the currently played game before using exact numeric values. Sources: [Materials](https://brotato.wiki.spellsandguns.com/Materials), [Shop](https://brotato.wiki.spellsandguns.com/Shop), [Experience](https://brotato.wiki.spellsandguns.com/Experience).

### Bakkal decisions still open

The user authorizes adding enemies, throwable/projectile weapons and a shop with purchasable gear when research supports them. Before locking the design, compare the references and decide: number of weapon slots; whether XP and shop currency are one pickup or separate; whether upgrades resolve before or after the shop; shop offer count/reroll/lock rules; duplicate weapon upgrade/merge behavior; and how wave rewards forecast the next encounter. Treat Brotato as inspiration for this decision set, not as a blueprint for names, visuals, item data or exact balance.

## Limits of this review

These are static source findings and recommendations, not visual/playtest observations. We have not yet verified frame-to-frame feel, screen readability under pressure, shop decision time, or whole-run pacing by playing every clone. A future design lock should use those observations in addition to these source paths.
# Brotato Wiki catalog count check (26 September 2026)

The community Brotato Wiki's `Enemies` table was counted by category: Crash Zone has 22 regular rows (including neutral Tree), 8 elites, and 2 bosses; Abyss DLC has 23 regular rows, 9 elites, and 2 bosses. That's 66 named table entries, or 65 combat enemy types after excluding Tree. Elite/boss categories are counted separately; boss mutation phases are not separate identities; unused Corrupted Tree is excluded.

This is not a current-version-complete wiki count: the page's table omits 16 named enemy forms listed in official patch 1.1.15. Adding those named forms to the 65 combat entries gives an adjusted comparison count of 81. Unnamed Endless Nightmare buffed variants are not counted as separate types.

The `Weapons` page has 47 melee names and 31 ranged names, 78 distinct identities. The four tiers are variants of an identity, not four separate weapons per name. The stale table includes Vorpal Sword but omits Rail Gun; official patch 1.1.15 adds Rail Gun, giving a 79-name adjusted comparison count. The wiki page still labels its data as Patch 1.1.6.3, so don't present 65/78 as a current fully synced total.

These figures are research context, not Bakkal content targets. We should build a smaller original catalog where every item adds a distinct combat choice, then add depth based on play balance.

Sources: [Brotato Wiki — Enemies](https://brotato.wiki.spellsandguns.com/Enemies), [Brotato Wiki — Weapons](https://brotato.wiki.spellsandguns.com/Weapons), [official Steam announcements](https://steamcommunity.com/app/1942280/announcements/?l=english), especially the 1.1.15 enemy lists and Rail Gun addition, and [official Steam store page](https://store.steampowered.com/app/1942280/Brotato/).

## Follow-up source audit: integration risks to keep

A second static pass compared the current Godot integration against the pinned clone code at the revisions below. These are implementation audit items, not evidence of full-game playtesting.

- **Campaign completeness:** in the earlier `arena.gd` loader, a missing wave file stopped the loop and left a partial schedule that the shop could interpret as the campaign ending. The current loader now requires all 20 numbered resources, checks wave IDs, and rejects mismatched enemy/weight arrays rather than accepting an accidental short campaign.
- **Spawn cadence/caps:** BESTAGON `f68cb148c396`, `bestagon-01-survivor/scenes/director/run_director.gd:68-79,91-108,131-173` skips a missed spawn tick while capped rather than banking a backlog, tracks per-type live counts through exit signals, and supports seeded schedule selection. For Bakkal, preserve authored composition data, decide explicitly whether capped ticks are skipped, and ensure actual live actors are counted at the same scope as the cap.
- **Live spawn validation:** Slime Survivors `7629bca9a819`, `chaotic-legend-slime-survivors/scripts/game.gd:46-60,88-99` contains a valid-position helper that its spawn path does not call. Bakkal currently routes its enemy placement through `_spawn_point_is_clear`; any future spawn change must retain validation on the live path. Exercise corner obstacles, door thresholds, and the full actor clearance shape.
- **Room-scoped actors:** Bakkal deactivates enemies outside the active room, while a global alive-enemy count can still count those frozen actors against the current room's cap. Decide whether the budget is global or per-room and keep it consistent with room spawn ownership; do not accidentally freeze enemies that can never re-enter the count.
- **Milestone bosses:** Bakkal's wave 5/10/15 flags are milestones, not distinct elites. The current fallback sends the same Return Cart boss with different health multipliers. Treat that as placeholder encounter content until each milestone has its own attack/state design, readable warnings, recovery and health tuning.
- **Endless composition:** Bakkal used to permute campaign wave resources after wave 20 and apply cycle scalars. That is not an endless authored plan. The runtime now uses ten dedicated endless templates with distinct compositions, counts, caps, timings and two authored boss patterns; ten-wave cycles add modest pressure while each template's authored count delta can raise, lower or preserve its total. This still needs direct full-run balance review.
- **Weapon and reward edge cases:** BESTAGON `f68cb148c396`, `scenes/weapons/projectile.gd:10-17,69-75`, and Riftbound `71c40ec4c57f`, `scripts/actors/projectile.gd:49-75,90-115`, explicitly bound projectile lifetimes and track already-hit targets for pierce/ricochet. Inspect each Bakkal attack mode for no-target behavior, duplicate hits, expiry, room changes, and owner destruction. Riftbound `scripts/game/game_session.gd:334-355,868-980` also waits for pending blast cleanup before opening the next shop; Bakkal deferred XP/pickup creation and wave cleanup should be checked together.
- **XP overflow:** migalvalm `1c90e4f4c57f`, `scenes/manager/experience_manager.gd:16-25`, drops overflow and grants at most one level for a large pickup. Bakkal uses a `while` threshold loop in `entities/player/player.gd:119-130`; preserve it and verify each queued level-up resolves before the shop.
- **Room mood:** the old-phase selector still controls room artwork when authored campaign waves are active. The production wave event/act data must eventually own atmosphere state too, rather than displaying a phase unrelated to the active wave.
- **Run reset/results:** Riftbound `71c40ec4c57f`, `scripts/game/game_session.gd:217-242,334-355,384-390`, clears transient actors and guards the terminal result. Bakkal reloads the arena and guards duplicate results, but repeated restart/title transitions still need a runtime check for stale helpers, pickups, projectiles, boss UI and persistent records.

**Scope:** pinned source-code inspection only; no assets were copied, and this pass did not claim visual gameplay observation. Clone IDs and licenses remain in `research/reference-repos/core-four/CLONE_MANIFEST.md`.
