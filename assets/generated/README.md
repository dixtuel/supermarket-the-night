# Generated game art

Generated with OpenAI ImageGen on 2026-09-26 for the original Supermarket: The Night project. These are project-local art assets; they are not copied from the GPL-3.0 or MIT reference game repositories. Original project-made art in this directory is dedicated under CC0 1.0; the source code's MIT `LICENSE` is separate. See [`ASSET_LICENSE.md`](../../ASSET_LICENSE.md).

## Original compact store backgrounds

All backgrounds use the same compact neighborhood grocery layout and are intended as full-screen top-down arena states. Source size: 1672×941 RGB PNG.

- `store_states/store_clean_shift_start.png` — stocked, clean, warm lights on.
- `store_states/store_tidy_lights_on.png` — alternate tidy, lit state.
- `store_states/store_messy_midrun.png` — scattered products, spills, and footprints; central paths remain open.
- `store_states/store_lights_out.png` — lights out with emergency red and refrigerator blue light.
- `store_states/store_entrance_open.png` — entrance open with cool night light entering.

The compact source backgrounds remain in place as historical artwork; they are no longer the gameplay room art. The current expanded environment uses the separate room scenes under [`rooms/`](rooms/README.md), with market, depot, manager office, and four-stall restroom each having five event-state variants.

## Exterior

- `exterior/night_street_backdrop.png` — original AI-generated neighborhood street and sidewalk backdrop, drawn behind the room art to frame the playable store with a night street.

## Characters

- `actors/player_night_clerk.png` — front-facing character presentation/portrait candidate.
- `actors/player_night_clerk_topdown.png` — earlier strict-overhead direction study; retained as a source-art candidate, not used for the current 3/4 gameplay camera.
- `actors/player_night_clerk_walk.png` — clerk four-direction, four-frame walk atlas used by the player scene.
- `actors/enemy_spoiled_customer.png` — spoiled-grocery customer enemy candidate.
- `actors/enemy_possessed_cart.png` — possessed shopping-cart enemy candidate.

Character PNGs retain transparency and full generated resolution. Before release, review the animation atlases at in-game scale, finalize each collision footprint, and complete any remaining weapon/pickup/effect animations. This catalog is intentionally updated as assets are completed.
- `actors/enemy_expired_regular.png` — common grocery-bag regular.
- `actors/enemy_runaway_cart.png` — fast cart charger.
- `actors/enemy_leaking_freezer.png` — slow cold-zone enemy.
- `actors/enemy_after_hours_shopper.png` — ranged late-night shopper.
- `actors/enemy_expired_regular_walk.png` — four-direction walk atlas for the basic chaser.
- `actors/enemy_runaway_cart_walk.png` — four-direction rolling atlas for the charger.
- `actors/enemy_leaking_freezer_walk.png` — four-direction rolling atlas for the area-denial enemy.
- `actors/enemy_after_hours_shopper_walk.png` — four-direction walk atlas for the ranged enemy.
- `actors/enemy_expiry_sprinter_walk.png` — four-direction walk atlas for the Short-Date Sprinter.
- `actors/enemy_overloaded_cart_walk.png` — four-direction rolling atlas for the Overloaded Stock Cart.
- `actors/temporary_shift_helper_walk.png` — four-direction rolling atlas for the temporary depot helper.

## Boss and weapons

- `boss/boss_return_cart.png` — oversized Return Cart boss.
- `boss/boss_return_cart_walk.png` — four-direction rolling atlas for the Return Cart boss.
- `weapons/projectile_tomato_can.png` — Can Launcher projectile.
- `weapons/mop_whirl.png` — Mop Whirl sweep effect.
- `weapons/receipt_boomerang.png` — blank receipt projectile.

## Pickups and area weapon

- `pickups/pickup_xp_token.png` — luminous XP pickup.
- `pickups/pickup_health_bag.png` — health pickup.
- `pickups/pickup_energy_can.png` — temporary speed pickup.
- `weapons/sale_tag_beacon.png` — Sale-Tag Beacon weapon marker/effect.
- `weapons/basket_orbit_stock_item.png` — the distinct grocery-stock projectile for Basket Orbit.
- `pickups/pickup_stock_bundle.png` — supply token used by the depot request event.

## Directional walk atlas convention

The nine `*_walk.png` atlases above were generated on 2026-09-26 from their
project-local character art with OpenAI ImageGen. Rows are up, left, right, down;
each row contains four walk poses. The Godot player/enemy scripts derive the
frame rectangle from the actual atlas size because ImageGen returned
1254×1254 pixels despite the 1024×1024 prompt. See
[`docs/asset_animation_spec.md`](../../docs/asset_animation_spec.md) for camera,
pivot, collision, and review rules. Generated artwork is part of the
CC0 1.0 asset dedication; see [`ASSET_LICENSE.md`](../../ASSET_LICENSE.md).

## Shop icons

The 20 transparent shop-card icons in `shop_icons/` are original project art,
prepared on 2026-09-27. They are dedicated under CC0 1.0; see [`ASSET_LICENSE.md`](../../ASSET_LICENSE.md).

- The seven weapon icons (`can_launcher`, `bulk_basket_fan`, `basket_orbit`,
  `circulation_return`, `mop_whirl`, `receipt_boomerang`, and
  `sale_tag_beacon`) and four upgrade icons (`better_wringing`,
  `bigger_discount`, `bulk_pack`, and `comfortable_shoes`) were generated in
  Antigravity with its built-in image-generation action. The session used
  Gemini 3.8 Flash Medium; Antigravity did not expose a separate image-model
  identifier.
- The remaining nine upgrade icons (`extra_basket`, `fresh_apron`,
  `heavier_cans`, `long_receipt`, `long_toss`, `longer_shift`,
  `quick_checkout`, `quick_stocking`, and `reinforced_receipts`) were generated
  with the built-in OpenAI ImageGen tool using existing project icons as style
  references. The image tool did not expose a separate image-model identifier.

Each PNG is 256×256 RGBA with a transparent background. The six `new_*`
weapon-unlock upgrades reuse the corresponding weapon icon rather than adding
duplicate upgrade art.

## Night shift content pack

Four original transparent pixel-art PNGs were generated with OpenAI ImageGen
on 2026-09-27 for the Barcode Reel weapon, Quiet-Shift Footwork upgrade, Receipt
Moth enemy, and Pallet Stacker boss. The weapon/upgrade icons are 256×256; the
static enemy sprites are 320×320 and 512×512 respectively. The enemy images do
not include walk animation frames. They are project-local art and are not
dedicated under CC0 1.0; see [`ASSET_LICENSE.md`](../../ASSET_LICENSE.md). The depot radio event uses the
existing energy-can pickup image.

Additional original transparent pixel-art art was generated with OpenAI
ImageGen on 2026-09-27 for the Wiki-inspired content pack. Five static enemy
sprites are in `content_pack/`: `scanline_runner.png`, `coupon_tosser.png`,
`cooler_dripper.png`, `pallet_jack_pusher.png`, and
`night_shift_supervisor.png`. Two upgrade/stat icons are also included:
`engineering_caddy.png` and `reinforced_apron_plus.png`. They use the existing
content-pack palette and transparent backgrounds. These source PNGs are
1254×1254 RGBA; the images are static sprites/icons and do not include walk
animation frames. Matching original weapon SVGs already in this directory are
used for Aisle Sentinel, Spill Tripmine, Thermal Price Gun, Tote-Stack Lobber,
and Deposit-Ring Reel. These generated assets are project-local artwork and are
dedicated under CC0 1.0; see [`ASSET_LICENSE.md`](../../ASSET_LICENSE.md).

## Directional enemy art update

Four-direction, four-frame walk atlases for the five Wiki-inspired enemies were
made with OpenAI ImageGen on 2026-09-27 from their project source sprites. They
are stored in `actors/enemy_scanline_runner_walk.png`,
`actors/enemy_cooler_dripper_walk.png`, `actors/enemy_coupon_tosser_walk.png`,
`actors/enemy_pallet_jack_pusher_walk.png`, and
`actors/enemy_night_shift_supervisor_walk.png`. Rows are up, left, right, down.
Scanline Runner uses the same compact atlas scale as the other roster sprites.

## Separate asset license

Original images and SVGs in this directory are dedicated under CC0 1.0, separate from the MIT code license. Third-party assets are excluded; see [`ATTRIBUTION.md`](../../ATTRIBUTION.md) and each asset pack provenance file.
