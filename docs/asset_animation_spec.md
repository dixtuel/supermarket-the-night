# Character art and arena collision specification

## Room background set

- Build four separate room assets before combining them in Godot: market, large depot, manager's office, and shared WC with 3–4 stalls. The market's rear-left staff door connects to the depot; only the depot connects to the office and WC.
- Give each room the same five state backgrounds as the original store set: clean shift start, entrance/connector open, lights out, messy mid-run, and tidy lights on. Every state for one room must preserve the same boundaries, furniture/shelf footprints, and door anchor coordinates; only the event state changes.
- Use the first market image as the style reference. Keep all separate room assets at one agreed pixel-to-world scale and matching camera/elevation so doorway anchors can join without visible scale jumps. The room scenes and door triggers are composed only after each base room and its state variants have been reviewed.
- Match each collider to the actual rendered floor footprint of its fixture. Do not add a visible/debug border or a broad invisible safety ring around shelves; actor collision radius is accounted for separately. Keep all approach lanes wider than the sum of two actor radii. No one background image should contain the market, depot, office, and WC together.

## Camera and depth

- Use the shared elevated 3/4 overhead camera in every gameplay background and actor. The game is still played from above; avoid side-scroller/front-portrait staging and avoid mixing in the strict overhead clerk sprite.
- World origin for each actor is its ground contact point. Put shadows beneath the feet/wheels, not across the torso. Actor roots use Y sorting so an actor nearer the bottom of the screen draws in front of an actor nearer the top.
- Keep stable in-game actor height and silhouette across idle/walk directions. Telegraphed attack effects need contrast over every store state.
- Art and collision are one arena specification: every shelf/counter/display visible as solid must have a matching collider; floor dressing with no blocking geometry must be explicitly marked non-solid. Spawn selection checks the full actor footprint against physics, not only the center point.

## Four-direction animation atlas

The current clerk atlas is `assets/generated/actors/player_night_clerk_walk.png`. The same layout is required for regular enemies and bosses:

| Atlas rows, top to bottom | Facing | Animations |
| --- | --- | --- |
| 0 | up / away | `walk_up`, `idle_up` |
| 1 | left | `walk_left`, `idle_left` |
| 2 | right | `walk_right`, `idle_right` |
| 3 | down / toward camera | `walk_down`, `idle_down` |

Each row has four sequential walk-cycle poses; idle uses its first pose. All directions retain the same outfit, markings, outline, light direction and pixel scale. Use a shared ground-contact baseline and alpha transparency. Keep one generation per actor so its identity stays stable. A sheet is only accepted when row and frame boundaries are uniform, no art clips between cells, the alpha is clean, and every direction reads correctly at in-game scale.

The image generator may return a 1254×1254 image despite a 1024×1024 request; code must derive frame size from the actual imported atlas dimensions. Do not assume generated canvas dimensions without checking the file.

## Acceptance for each actor

1. Inspect each direction/frame at native scale and at in-game size.
2. Verify every row depicts the correct facing direction and frames move the feet/legs, not only the whole image.
3. Verify root origin remains on the foot/wheel contact for all frames; collision stays centered under the body footprint.
4. Verify direction changes follow movement and retain the last facing when idle.
5. Compare player, all normal enemies and all bosses side by side on the clean and dark store states.
6. Record source/generation date and resulting path in `assets/generated/README.md`; do not imply generated art is covered by the code's MIT license.
