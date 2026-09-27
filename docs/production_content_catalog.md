# Supermarket: The Night — production target

**Status:** Full-game production plan; not a prototype or MVP completion list. The user's current goal and the attached 26 September 2026 plan supersede the earlier five-minute run and 90-second vertical-slice documents.

## Game promise

An original single-player 2D wave-survival game set in a neighborhood grocery during a strange night shift. The player moves around a compact store, builds a weapon/loadout through combat rewards and between-wave shop decisions, and tries to finish a complete 20-wave run. Camera art uses a consistent elevated 3/4 view: gameplay is from above, but the characters and store are angled enough to show the front-facing silhouettes. Strict orthographic top-down is not a requirement.

## Full-run target

- 20 authored campaign waves, approximately 45–90 seconds each, with short shop/intermission decisions. Expected total is about 20–30 minutes; tune from play data. Campaign has a final boss and a real ending.
- Add a separate **Endless Night** mode. It starts from wave 1 and has no terminal wave; pressure, spawn budgets and compositions continue to scale after the campaign's wave-20 content. Every endless wave still gets its own authored/composed spawn plan: enemy counts may rise, fall or stay level when role mix, threat budget or wave event changes. Endless is a first-class mode in title/run setup and has its own best-wave/score record. Do not simply repeat the campaign unchanged or apply one monotonic count multiplier.
- Four five-wave acts with visibly different store atmosphere, spawn composition, enemy combinations and pressure rules.
- Wave 5/10/15 introduce a distinct elite or mini-boss encounter; Wave 20 has the final boss and a real win condition.
- Every wave has an authored schedule: duration, spawn phases, enemy roles/weights/counts, active-enemy cap, entry regions, event/modifier, reward, and completion rule. Do not replace this with a rising scalar applied to one repeating spawn loop.
- First waves teach roles one at a time; later waves remix known roles using different timings, lanes, hazards and goals.
- Research-driven content scope: the community wiki's listed base game + Abyss tables contain 65 combat enemy types (66 named entries including neutral Tree) and 78 distinct weapon names (47 melee, 31 ranged); official patch 1.1.15 adds 16 named enemy forms and one Rail Gun absent from those stale wiki tables, for an adjusted comparison point of about 81 combat forms and 79 weapon names. Treat those counts as scale/context only, not a requirement to clone the reference's roster. Pick and document a substantial original Bakkal roster after the reference page scrape. Weapon families must include melee, ranged and genuinely throwable/projectile attacks, with distinct targeting/flight/impact behavior; the market sells real implemented weapons and items only. Vary per-wave enemy composition/counts deliberately instead of increasing every wave uniformly. Count methodology and caveats are in [`gameplay_reference_notes.md`](gameplay_reference_notes.md).
- Add a buyable between-wave market inspired by the readable offer-card layout in the user's screenshots. Use only live game data and actual implemented affordances; no placeholder buttons or invented stats. Keep four room assets conceptually separate: the large main market, spacious depot, manager's office, and shared restroom with 3–4 stalls. The market's rear-left staff door enters the separate depot. The depot connects onward to the office and WC; the office and WC have no market-floor entrances. Design each room as its own asset before composing/connecting room scenes in Godot. Add five consistent event-state backgrounds for each room, matching the original market set: clean shift start, entrance/connector open, lights out, messy mid-run, and tidy with lights on. Preserve room geometry, shelf widths, furniture footprints and exact door positions across those states; adapt which door is open and room lighting/clutter as appropriate. Collision colliders must match the actual shelf/fixture footprint; do not add invisible padding that makes the player bump into a shelf before reaching its visible edge. Show no empty gray exterior.
- Give each of the four rooms one or two distinct, playable room events. Examples from the user's direction: a room-specific power-up can spawn there at a random time, or an in-room request/button can ask the player to collect 3–5 units of a named supply during that wave and award a temporary helper. Specify spawn/interaction conditions, per-wave limits, rewards, failure/expiry behavior, and UI feedback before making event art. Preserve separate room access; the office and restroom remain reachable only through the depot.
- Wave-end shop/economy must coexist with level-up choices without burying combat in repeated menus. Settle purchase, reroll, lock, reward and XP timing at the design lock.
- Main menu should use the supplied visual direction while listing only real modes/settings. Add a Credits page with confirmed contributors, tools, third-party assets and their sites/licenses; keep community/news/mods links out unless implemented. Do not credit uncertain people or websites: verify the actual inventory before release.
- Complete run flow: title, settings, run, wave intermissions, pause, win/loss, run summary and local persistence/unlocks or challenges. No account/backend dependency.
- Original, consistently scaled and animated characters, enemies, bosses, weapons, pickups, store states, feedback effects, UI and audio. Record all third-party asset terms individually.

## Design and research rules

1. Finish source/code and gameplay observation of the local reference clones before locking wave/shop/economy details. Put observations and evidence in [`gameplay_reference_notes.md`](gameplay_reference_notes.md); label observed repo behavior separately from our recommendations.
2. Reference clones are isolated under `research/reference-repos/`. Keep their exact URL, branch/ref, HEAD SHA and code/art/audio licenses in their manifests. They are for read-only study. Never copy their code, art, sound, text, branding or maps into the game.
3. Brotato is a closed-source product reference, not a GitHub clone target. Verify claims against its official store/developer materials or direct play; mark community-wiki details as secondary evidence and engineering suggestions as suggestions.
4. Keep the Bakkal setting, writing, silhouettes, layouts, item names and presentation original.
5. Audit the finished game against the studied source implementations before release, focusing on wave scheduling, spawn caps/scaling, reward overflow/queues, weapon targets/lifetimes, enemy state transitions, pause/results ownership, cleanup and scene/resource boundaries. Record only applicable bugs or gaps.

## Current worktree versus target

The current game has a single five-minute schedule plus a separate 90-second test schedule, four enemy roles, one boss, four weapons and a dozen upgrades. Those are a usable starting foundation, not evidence that the 20-wave campaign, Endless Night, full market or expanded interior are done. Current reports describe Godot 4.7.2 headless import/startup smoke checks; they do not verify full-run balance, finished animation, Windows export, or a release build. The old `first_shift.tres` and older catalog prose must not be treated as the production endpoint.

Current clone metadata is recorded in [`research/reference-repos/core-four/CLONE_MANIFEST.md`](../research/reference-repos/core-four/CLONE_MANIFEST.md) and [`research/reference-repos/REPO_INVENTORY.md`](../research/reference-repos/REPO_INVENTORY.md). Initial source/gameplay comparison is still in progress.

## Release gate

Do not call the game complete until one uninterrupted 20-wave run is playable; all four acts read differently; elite/boss encounters have distinct attack loops; shop and upgrade choices visibly change builds; actors cannot spawn inside fixtures; final art/audio and every license are documented; and Windows x86_64 plus CachyOS/Linux x86_64 builds launch. A 90-second balance mode is not a release substitute.
