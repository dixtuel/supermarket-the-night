# Modular room artwork

Generated as original Bakkal After Dark art with OpenAI ImageGen on 26 September 2026. Each room is a separate 1672×941 background so the game can connect spaces through doors. The first market artwork is the style reference; no reference-game maps, assets, or presentation were copied. These images are not covered by the project's MIT code license.

## Room states

Each room has five event states. The variants are intended to preserve the room's layout and door locations; inspect each before using them as interchangeable gameplay backgrounds because generated variants can drift slightly.

| Room | Clean start | Tidy, lights on | Entrance open | Lights out | Messy mid-run |
| --- | --- | --- | --- | --- | --- |
| Market | `market_clean_shift_start.png` | `market_tidy_lights_on.png` | `market_entrance_open.png` | `market_lights_out.png` | `market_messy_midrun.png` |
| Depot | `depot_clean_shift_start.png` | `depot_tidy_lights_on.png` | `depot_entrance_open.png` | `depot_lights_out.png` | `depot_messy_midrun.png` |
| Manager office | `manager_office_clean_shift_start.png` | `manager_office_tidy_lights_on.png` | `manager_office_entrance_open.png` | `manager_office_lights_out.png` | `manager_office_messy_midrun.png` |
| Restroom | `restroom_clean_shift_start.png` | `restroom_tidy_lights_on.png` | `restroom_entrance_open.png` | `restroom_lights_out.png` | `restroom_messy_midrun.png` |

## Room graph and door anchors

- The market's rear-left staff door connects to the separate depot.
- The depot's northwest door connects to the four-stall restroom.
- The depot's northeast door connects to the manager office.
- The office and restroom are only reached through the depot.

Door centers in the source illustrations were estimated visually, not authored as embedded metadata. When the room scenes are built, place portal triggers and safe arrival points from the base image, then use explicit faded room transitions. Do not align full-screen backgrounds by stacking them into one continuous map, and do not assume the generated event variants are pixel-identical.

## Provenance

These are AI-generated project assets guided by the project's own first-market image. They are not third-party assets and are not licensed under the code's MIT license. Keep the source PNGs and this provenance note with the project.
