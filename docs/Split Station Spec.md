# Strange Ranger: the split station

From the lab, 28 November 2026. This is a small spec, done before Mark starts play testing 5b and 6a. The art is in Art Request 29 (`docs/art/art_request_29_split_station.md`). The rough view is `docs/art/split_station_mock.png`.

## What changes

At the moment the ranger station is one room, 13 × 11 tiles. Bed, stove, radio, workbench and desk all share it.

In the new station, **a living half is built onto the left of the station.** Each half has its own door outside, and a doorway joins them inside. The plan is the Stardew two-room house turned round: the small room (the bedroom) is on the left, and the big room is on the right.

```
 ┌──────────────┬──────────────────────────┐
 │ bed  ▫ table │ radio  notes  CLOSET staff│   back wall (windows above)
 │ bed          │                           │
 │              │                           │
 │    (rug)     │          (rug)     desk   │
 │              ▒   workbench               │   ▒ = inside doorway
 │ stove  chest │                    chest  │
 └─────door─────┴─────────door──────────────┘
    living half          station half
 ▫ = nightstand
```

## The room

The whole station is still **one room** in the game, 22 × 11 tiles, with a wall down it. At 352 × 176 pixels it fits on the 480 × 270 screen, so you see both halves at once, as in the Stardew picture. A doorway in the wall joins them, with no loading between them.

- **Living half:** 7 tiles wide, on the left (x 1–7).
- **The inside wall:** one tile thick (x 8), from the back wall to the front. It has a doorway one tile wide, near the front (y 7), like the narrow passage in the picture.
- **Station half:** 12 tiles wide, on the right (x 9–20).

### Living half

| Piece | Where | Size | Art |
| --- | --- | --- | --- |
| Bed | top left (1, 3) | 2 × 2 | `int_bed`, as now |
| Nightstand | beside the bed (3, 3) | 1 × 1 | **new**: `furniture_nightstand`, with the oil lamp on it |
| Table and chair | top right (5, 3) | 2 × 2 | `furniture_table_chairs`, as now |
| Woodstove | lower left (1, 8) | 2 × 1 | `furniture_stove` (the black stove, which has a lit picture) |
| Chest | lower right (5, 8) | 2 × 1 | `int_chest`, as now |
| Door out | front wall (4, 10) | | `furniture_door` |
| Window, picture, rug | back wall (4, 0) and (6, 1); round rug in the middle | | as now |

### Station half

| Piece | Where | Size | Art |
| --- | --- | --- | --- |
| Radio | back wall (10, 3) | 1 × 1 | `furniture_radio`, as now |
| Note board | back wall (12, 3) | 1 × 1 | `furniture_note_board`, as now |
| Supply closet | back wall (14, 3) | 2 × 1 | **new**: `furniture_supply_closet`, which takes over from the supply shelf (same shelf stock) |
| Employee board | back wall (17, 3) | 1 × 1 | `furniture_staff_board`, as now |
| Oil lamp | back wall (19, 3) | 1 × 1 | as now |
| Desk | right (17, 6) | 2 × 1 | `furniture_catalog_desk`: the catalog, as now |
| Workbench | left, near the doorway (10, 7) | 3 × 1 | `int_workbench`, as now |
| Second chest | lower right (18, 8) | 2 × 1 | **new**: `int_chest_station`, a green park footlocker, so the two chests look different |
| Door out | front wall (15, 10) | | `furniture_door` |
| Windows, picture, coat hook, rug | back wall (11, 0), (18, 0), (13, 1), (16, 1); rug in the middle | | as now |

The house rules from tracker #27 still hold: a tile between pieces, a clear way from each door to the back wall, and no more than 40% of the floor covered.

## How it plays

- **Two doors outside.** From outside, the left door leads into the living half and the right door into the station half. Leaving by either door puts you outside in front of it.
- **Sleeping** is in the living half's bed, as now. You wake by the bed, and rescues and fainting bring you there too.
- **The woodstove** does what the small stove does now: it cooks the berry preserves (tracker #64) and warms the room.
- **Two chests.** Each has its own 12 slots, so storage goes up from 12 to 24. The starting tools (axe, bedroll and shovel) go in the station chest. The living chest starts empty.
- **The station's jobs** stay in the station half: the radio, note board, employee board, catalog desk and workbench. The job spots that a job puts inside the station move to the station half.
- **Decorating** works in both halves. Nothing may be placed in the inside wall or its doorway. The way from both doors to every used piece must stay clear, and that now includes the inside doorway.
- **Warmth:** it's all one room for warmth, so nothing changes there.

### The station's upgrades

These change slightly because of the new half. These are the lab's suggested answers to Questions 1 and 2:

1. **Shipshape:** no change. It gets new outside art (S1).
2. **A proper kitchen:** the cooking range replaces the woodstove in the same corner. The range cooks without a fire and warms as the woodstove did. The pantry goes in the living half against the inside wall, at (5, 6).
3. **A second room** becomes **a bigger office.** The station half grows to the right, as the second room does now, and the reading chair goes there with a bookcase. The price and materials stay the same.

## Outside

At the moment the station is 6 × 4 tiles, with its door in the middle. The living wing adds about 3 tiles on the left, and that wing has its own door.

- The station's own door stays where it is, so the yard trail, mailbox and job spots outside don't move.
- The yard is 14 tiles round, which leaves room for the wing. The lab checks the trail from the gate still reaches both doors.
- New outside art is needed for the plain station, Shipshape, and the bigger office (S1).

## Old saves

- Pieces moved by decorating go back to their new places once, with a note: "The station's been rearranged: the living half is through the left door."
- Placed furniture keeps its spot if it still fits. If it doesn't, it moves to the nearest clear floor.
- Anything in the old chest stays in the living chest.

## Questions, with suggested answers

| # | Question | Suggested answer |
| --- | --- | --- |
| 1 | The kitchen upgrade: where does the range go? | It replaces the woodstove in the living half. The pantry goes by the inside wall. |
| 2 | The second room upgrade, now there's a living half already? | It becomes "a bigger office": the station half grows right, with the reading chair and a bookcase. Same price. |
| 3 | Two chests, or one shared chest you can open from both? | Two chests, 12 slots each. Starting tools go in the station chest. |
| 4 | Where do you wake? | In the living half by the bed, as now. |
| 5 | The inside doorway: an open gap, or a real door? | An open gap with a door frame, like the picture. |
| 6 | The supply closet: new art, or keep the supply shelf? | New art (S3). It has the same stock and works the same way. |

## Build

This is a small build, about one version (0.9.1), and it can go in before 6b.

1. Add the new station row in `structures.json`: 22 × 11, the inside wall and its doorway, and two exits. `InteriorLayout` learns about more than one exit and the inside wall.
2. Add the second outside door to the station's row, and enter by the door you came through.
3. Add the second chest and its inventory, and save it.
4. Rework the kitchen and the bigger office in `home.gd`.
5. Move old saves over to the new layout.
6. Add stand-ins until Mark's art arrives. The rough view uses the oil lamp for the nightstand, the wardrobe for the closet and the plain chest for the station chest.
7. Tests: both doors, the inside doorway, two chests, the kitchen and office upgrades, decorating's clear way, and loading an old save. Then screenshots.
