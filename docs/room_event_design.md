# Room events — first production pass

Room art is already split into the market, depot, manager office and restroom. Each place gets one event in the first implementation pass; a second event can be added after the first pass is playable. The requested power-up and temporary-helper ideas are represented in the event definitions/runtime. AGY's hazard and objective ideas below remain candidates and are not yet implemented.

## First events

| Room | Event | Trigger and limit | Reward | Runtime status |
| --- | --- | --- | --- | --- |
| Market | Restock crate | A power-up appears once per wave after a seeded random delay while the market is the active room (18–42 seconds). | Energy pickup. | Authored in `data/room_events/market_restock.tres`; director logic is present. |
| Depot | Stock request | A seeded request asks for 3–5 stock bundles. A bounded enemy-drop hook can produce the requested token; it is not wired to the live arena yet. Interact at the depot console to submit it. | A little rolling helper follows the clerk and fires at nearby enemies for 28 seconds. | Definition, supply token, helper actor and `E` console are present. Main arena/room wiring is still pending. |
| Manager office | First-aid drawer | A first-aid pickup appears once per wave after a random delay while the office is active (28–48 seconds). | Health pickup. | Authored in `data/room_events/office_drawer.tres`; director logic is present. |
| Restroom | Cold drink | An energy pickup appears once per wave after a random delay while the restroom is active (22–46 seconds). | Temporary movement-speed pickup. | Authored in `data/room_events/restroom_vending_can.tres`; director logic is present. |

All random waits stop when the player is in a different room. Spawned pickups remain in the run's pickup layer across room transitions. The helper contract is capped at one completion per wave; the request count is chosen once at wave start and held in the director's runtime state. `RoomEventDefinition` resources remain read-only inputs.

## Candidates for a second room event

These came from the independent Antigravity research pass and need a design/gameplay review before production:

- **Market:** a clearly telegraphed glass spill that creates a short amber slick, or a 15-second freezer-compressor fog zone that slows enemies.
- **Depot:** a pallet collapse with a 2.5-second marked footprint, damage on impact and short-lived debris. Keep an escape lane open.
- **Manager office:** an optional safe/keypad defense lasting about 25 seconds; reward currency/discount only after the shop economy exists. Do not trap the player behind an enemy body block.
- **Restroom:** an optional vibrating stall that can be opened with several latch hits, with a medical-cache-versus-elite risk/reward outcome.

## Integration and art gate

The four room backgrounds are not yet wired into a playable portal graph. Until that is done, the current room-event code is reusable production groundwork, not a claim that these events are reachable during a run. Connect the director to the eventual room manager and wave director, connect enemy deaths to the bounded requested-supply drop roll, and place the console in the depot scene. Then make the visual assets for the chosen room-event props/effects: restock crate, supply bundle, helper, safe/pallet/stall as selected, hazard decals and readable telegraphs. Do not bake gameplay text into those images; display instructions and event counts through UI.

The delay, drop chance, helper duration/damage, pickup value and hazard sizes are initial tuning choices. Validate them in play and tune from run data; they are not source-game values.
