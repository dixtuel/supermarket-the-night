# 20-wave schedule authoring notes

These resources are an initial encounter plan for the production campaign, not verified balance. They use the existing `EnemyDefinition` roster and roles only. Each wave has a different teaching, remix, pacing, or finale purpose; counts intentionally rise, fall, and hold rather than following a single escalating curve.

## Proposed arc

- **Waves 1–5 — Learn the aisles:** establish the regular chaser, then introduce the sprinter and telegraphed cart charge. Wave 5 is a milestone encounter using a reduced-health Return Cart; it is a temporary reuse of the one existing boss actor, not a distinct elite design.
- **Waves 6–10 — Read the floor:** introduce ranged harassment and freezer slicks, then combine existing roles. Wave 10 uses a stronger reduced-health Return Cart as an act capstone.
- **Waves 11–15 — Mixed stock:** rotate familiar threats, make heavy blockers less frequent, and vary spawn count/cap to create relief among denser waves. Wave 15 uses another scaled Return Cart milestone encounter.
- **Waves 16–20 — Closing shift:** alternate broad compositions with count relief, then finish with the existing Return Cart boss. The boss is scheduled 12 seconds into wave 20; the target count describes regular spawns and excludes that one boss.

## Integration contract and limits

`WaveDefinition` is an immutable resource input. `enemy_definitions` and `spawn_weights` are parallel arrays; weights are authored to sum to 1.0. The arena now loads `wave_01.tres` through `wave_20.tres`, enforces the planned regular-enemy count budget and alive cap, applies cadence and health, then runs XP cleanup, queued stat choices and the shop. This is an authored-data/runtime integration; complete wave pacing and rewards still require a full-playthrough balance pass.

The runtime wave director selects from each wave's positive-weight enemy pool. It introduces the pool's roles early, then adjusts selection modestly using the player's level, weapons and upgrades while retaining authored weights. Enemy hit damage is calculated for each spawned actor from actual run survivability (health, dodge, lifesteal, protection, movement), offense and wave pressure. Protection is a run-only stat; authored enemy resources remain unchanged. Individual hits are capped relative to maximum health as an Endless safety bound. These rules need direct play balance and do not establish a fixed damage target for any round.

## Round intermission contract

At round clear, collect remaining XP. If this creates level-ups, present each earned stat choice before opening one shop visit for that round. The shop displays exactly three actionable offers. Buying an offer replaces only its sold slot on the same screen; rerolling refreshes the three slots. **Continue** closes the shop and starts the next round directly. A round without a level-up still has one shop visit. The next shop must not open until the next round is cleared.

`event_tag` and `event_description` are authoring/UI metadata only. The current roster contains only one boss resource; waves 5, 10, and 15 reuse it at reduced health, and wave 20 uses its full authored health scale. Distinct mid-campaign elites and their attack patterns still require new actors and content.

Endless Night starts at wave 1, follows the campaign through wave 20, then uses the ten dedicated plans in `data/endless/`. Each plan has its own role mix, count, cadence, cap and optional boss. The plan loop repeats every ten endless waves; each ten-wave cycle modestly raises enemy health/cap and adjusts its authored count delta, so adjacent wave totals can rise, fall or remain stable. This is a data-driven first pass, not a balance claim. Endless-specific events, later enemy roles, and telemetry-driven tuning remain open.

Durations range from 50–90 seconds as first tuning proposals, leaving room for short intermissions while aiming at the production plan's 20–30 minute run. Spawn counts/caps, interval, and health scale are correlated starting values, not evidence of a balanced run. The regular enemy weights can be renormalized by the runtime if necessary, but the serialized values should remain aligned with their resource array.
