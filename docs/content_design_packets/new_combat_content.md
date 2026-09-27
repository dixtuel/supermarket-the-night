# New combat content packet

**Status:** authored data proposals for review; no runtime code or assets copied.  
**Runtime checked against:** `EnemyDefinition`, `WeaponDefinition`, `UpgradeDefinition`, `EnemyActor`, `SurvivorAutoWeapon`, `SurvivorProjectile`, and `SurvivorPlayer` in this project.  
**Tuning status:** every number below is an initial tuning proposal, not a verified balance result.

## Source observations and boundaries

These observations are evidence for general design patterns only:

- BESTAGON's MIT-licensed reference separates enemy profiles into `resources/enemies/*.tres`; its `dart.tres` and `bulwark.tres` use speed/health differences to create fragile-fast and slow-durable pressures. Weapon profiles likewise separate `scattergun.tres` and `orbital.tres`, and upgrade data includes `scatter.tres` and `orbit_count.tres`. Sources: [enemy profiles](https://github.com/Brock-Chain/01-survivor/tree/main/resources/enemies), [weapon profiles](https://github.com/Brock-Chain/01-survivor/tree/main/resources/weapons), [upgrade profiles](https://github.com/Brock-Chain/01-survivor/tree/main/resources/upgrades), [repository MIT license](https://github.com/Brock-Chain/01-survivor/blob/main/LICENSE).
- The Brotato developer's official Steam description confirms auto-fire, short waves, materials/experience, and between-wave purchases as genre-product context. Its community wiki documents weapon families and enemy categories. These are not implementation sources and supply no item names, art, stats, or text for this packet: [official Steam listing](https://store.steampowered.com/app/1942280/Brotato/), [community weapon index](https://brotato.wiki.spellsandguns.com/Weapons), [community enemy index](https://brotato.wiki.spellsandguns.com/Enemies).
- Reference inspection notes are in [`gameplay_reference_notes.md`](../gameplay_reference_notes.md). Slime Survivors' project code is MIT but its credited GDQuest art is CC BY-NC-SA; Riftbound Survivors is GPL-3.0. Neither repository's code, assets, names, descriptions, or distinctive presentation are included here. Only broad patterns are discussed. Project code's MIT license does not relicense generated art or future third-party content.

No exact Brotato item, enemy, upgrade, name, stat, text, or artwork is used. The authored grocery-store names and parameter combinations below are original proposals for Bakkal After Dark.

## Enemy archetypes

The current runtime implements five `EnemyDefinition.Role` states, and the current roster already uses CHASER, CHARGER, AREA_DENIAL, RANGED, and BOSS. Because this task permits data files only, these two additions are **new authored enemy archetypes, not new AI state machines or enum roles**. Both use CHASER, which follows the player and applies contact damage. Their differing movement, durability, reward, art, and low spawn weight change the encounter mix. `EnemyActor` currently uses the same 18-pixel collision radius for both; the overloaded cart will not physically occupy a larger footprint until runtime support is added.

### Short-Date Sprinter — `expiry_sprinter`

- **Role and encounter effect:** fast, fragile CHASER. It closes gaps quickly and interrupts safe kiting; the existing charger remains the telegraphed line-threat archetype.
- **Original difference:** the character is a near-expiry customer who rushes the clerk. This is continuous pursuit/contact behavior, without a charge telegraph or ranged projectile.
- **Verified source observation:** BESTAGON `resources/enemies/dart.tres` expresses the fragile-fast end of an enemy profile through its data fields. It does not supply this character, its grocery theme, or these values.
- **Initial tuning proposal:** speed 88, health 22, contact damage 5, range 34, interval 0.85, XP 1, spawn weight 0.32. Compared with `expired_regular.tres` (62 speed, 32 health, 8 damage, range 38, interval 1.1, XP 1), this is about 42% faster, 31% lower health, 38% lower contact damage, and has a shorter hit interval. Validate that increased hit cadence does not make its low damage unexpectedly punishing.
- **Runtime compatibility:** all fields exist in `EnemyDefinition`; `EnemyActor` reads `move_speed`, `max_health`, contact values, XP, and CHASER. The existing static `enemy_spoiled_customer.png` is referenced; it is a project-generated asset documented in `assets/generated/README.md`.
- **Art status:** a four-direction walk atlas was generated for this archetype from its existing project-local silhouette. It is wired into the enemy definition; review its cropped frames in the running game before calling the animation final. No third-party art is introduced.

### Overloaded Stock Cart — `overloaded_cart`

- **Role and encounter effect:** slow, durable CHASER that advances as an attrition/blocking threat. It can hold space while faster enemies approach.
- **Original difference:** the cart is packed with returned goods, with a distinctly slower approach and high contact cost. It has no charge, scatter, or area attack in the current design.
- **Verified source observation:** BESTAGON `resources/enemies/bulwark.tres` illustrates a durable, slower data-authored profile. That general role contrast is the reference; its implementation and numbers are not used.
- **Initial tuning proposal:** speed 36, health 92, contact damage 16, range 40, interval 1.35, XP 4, spawn weight 0.12. Compared with `expired_regular.tres`, this is about 42% slower, 2.9× health, 2× damage, 4× XP, and slightly longer range. Low frequency is intended to prevent a screen of high-health blockers; test with the Sprinter before adjusting either weight.
- **Runtime compatibility:** supported `EnemyDefinition` CHASER fields only. The existing `enemy_possessed_cart.png` is referenced; it is a project-generated asset documented in `assets/generated/README.md`. The controller does not expose a larger body radius for this authored type.
- **Art status:** a four-direction rolling atlas was generated for this archetype from its existing project-local cart silhouette and wired into the enemy definition. Review cropped frames at gameplay scale; the actor still uses the shared 18-pixel radius until runtime footprint support is designed.

## Weapons and attack patterns

The runtime already supports targeted projectiles, returning projectiles, orbiting contact projectiles, and deployed slow zones. These additions compose existing attack modes; they do not add new executor code. Their differences are spatial patterns (fan, paired return lanes, ring coverage), not new attack categories. BESTAGON's `resources/weapons/scattergun.tres` and `orbital.tres` are source observations for authored spread/orbit profiles, not copied implementations or art.

### Bulk Basket Fan — `bulk_basket_fan`

- **Pattern:** three targeted cans in a narrow fan. The executor offsets three projectiles by ±0.12 radians around the nearest-target direction.
- **Difference from the current Can Launcher:** one wider-coverage volley, with less damage per can and a slower repeat cadence.
- **Initial tuning proposal:** 5 damage × 3 projectiles every 1.05 seconds, 360 range, speed 470, lifetime 1.0. `can_launcher.tres` is 12 damage × 1 every 0.68 seconds, range 420, speed 520. A complete hit gives 15 nominal damage per fan versus 12 per can shot, but the fan fires less often and has less range; practical hit rate requires playtesting.
- **Compatibility and art:** `TARGETED_PROJECTILE` plus `projectile_count` is directly handled by `SurvivorAutoWeapon._fire_weapon`; uses existing generated tomato-can projectile art because the attack is still a can volley. A distinct basket launcher/icon is future art, not included.

### Circulation Return — `circulation_return`

- **Pattern:** two receipt rolls leave on slightly diverging lines, pierce once, then return toward the clerk after traveling the authored distance.
- **Difference from the current Receipt Boomerang:** paired, shorter-lane return paths favor coverage close to the player; the current one-projectile weapon travels farther and pierces two targets.
- **Initial tuning proposal:** 9 damage × 2, interval 1.65, range 310, speed 420, lifetime 1.8, one pierce, return distance 175. `receipt_boomerang.tres` is 18 damage × 1, interval 2.0, range 380, speed 360, lifetime 2.2, two pierces, and return distance 260. Both have 18 nominal damage per volley before hit opportunities; the new shorter lane and paired projectiles change coverage rather than raise that nominal volley total.
- **Compatibility and art:** `RETURNING_PROJECTILE`, `projectile_count`, `pierce_count`, and `return_distance` are all consumed by existing runtime methods. Reuses the project-generated receipt-roll art; a visually distinct perforated receipt / two-roll launcher icon would improve recognition later.

### Basket Orbit — `basket_orbit`

- **Pattern:** three stock items orbit the clerk to create a moving contact ring and cover multiple directions.
- **Difference from the current Mop Whirl:** three orbiting objects form broader ring coverage; it trades the single mop's stronger individual hit for more surrounding contact points. It does not add a new orbit executor.
- **Initial tuning proposal:** 4 damage per contact, three orbitals, radius 104, angular speed 2.15. `mop_whirl.tres` is one orbital at radius 82, damage 8, speed 2.8. Both profiles need contact-frequency and crowd playtesting; damage per second cannot be inferred from the data alone because hits are triggered by contact events.
- **Compatibility and art:** `ORBITAL_CONTACT` and its count/radius/speed/damage values are supported by `SurvivorAutoWeapon._ensure_orbitals` and `SurvivorProjectile.launch_orbit`. Sprite is left unset rather than displaying a mop as a basket item.
- **Art status:** a distinct transparent grocery-stock sprite is generated and wired to this weapon. Review its rotated scale in a gameplay run. The UI is text-first and `UpgradeDefinition` has no icon property, so no card icon is needed yet.

## Passive upgrade cards

`UpgradeDefinition` supports these four effects already. The runtime has no generic active-use upgrade/power-up effect or effect duration in this Resource schema, so this packet adds passive/instant level-up cards only. BESTAGON `resources/upgrades/scatter.tres` and `orbit_count.tres` demonstrate data-authored count changes; the authored Bakkal IDs/text below are different.

### Reinforced Receipt Rolls — `reinforced_receipts`

- **Effect:** Circulation Return pierces one additional enemy; max rank 2.
- **Initial tuning proposal:** +1 pierce per rank. Its weapon starts at one pierce, so the two ranks reach three.
- **Compatibility:** `WEAPON_PIERCE_ADD` (`effect = 6`) and `target_weapon_id` are applied by `SurvivorAutoWeapon.apply_upgrade`. The offer system must include this resource and should gate it on unlocking `circulation_return` if that eligibility feature exists; no gate field exists on `UpgradeDefinition` itself.
- **Art need:** none for current text-first upgrade cards.

### One More Basket — `extra_basket`

- **Effect:** Basket Orbit gains one additional orbiting item; max rank 2.
- **Initial tuning proposal:** +1 orbital per rank, from three to five.
- **Compatibility:** `PROJECTILE_COUNT_ADD` (`effect = 3`) is implemented; `SurvivorAutoWeapon._ensure_orbitals` creates orbitals to match the updated count.
- **Art need:** shares the future Basket Orbit item sprite; no new UI icon property is supported.

### Extra Padded Apron — `longer_shift`

- **Effect:** maximum health +12 and immediately heal 8; max rank 2.
- **Initial tuning proposal:** compare with current `fresh_apron.tres` (+15 max health, heal 10, max rank 3). This is a smaller, lower-cap survival card.
- **Compatibility:** `PLAYER_MAX_HEALTH_ADD` (`effect = 9`) and `immediate_heal` are handled by `SurvivorPlayer.apply_upgrade`.
- **Art need:** none for current text-first upgrade cards.

### Quick Checkout — `quick_checkout`

- **Effect:** all unlocked automatic weapons fire 8% faster; max rank 3.
- **Initial tuning proposal:** +8% per rank, compared with `quick_stocking.tres` at +12% per rank. The runtime converts this to a reduced interval by dividing by `1 + value`.
- **Compatibility:** `FIRE_RATE_MULTIPLIER` (`effect = 2`) with empty `target_weapon_id` applies globally.
- **Art need:** none for current text-first upgrade cards.

## Integration needs and limits

- The new resources are now explicitly loaded into the weapon and upgrade catalogs; the two enemy profiles are weighted into the later `lights_out` and `open_door` phases of the existing five-minute schedule. They are intentionally not present in the opening/cart phases. This is a first integration point, not the planned authored 20-wave schedule.
- The three new weapons are surfaced through separate one-rank unlock cards. The between-wave shop is not implemented yet, so weapon unlocks currently use the existing level-up offer flow.
- This is not a shop inventory or active consumable system. Those require owned runtime/UI work and additional data fields for cost, duration, charges, offer gating, or explicit activation.
- The authored packet contains nine resources under `data/enemies/`, `data/weapons/`, and `data/upgrades/`; three additional one-rank cards unlock the new weapons. No GPL-licensed source/assets or other reference project content is copied. Existing image references are project-generated assets. The new basket-orbit sprite is intentionally unset so it does not reuse the mop image; the dedicated orbit-item art remains to be made.
- No visual balance claim is made. The supplied numbers are comparison-based tuning starts. Enemy encounter pressure, projectile hit rates, orbital contact rates, readability, upgrade offer quality, and complete-run balance require in-game validation.
