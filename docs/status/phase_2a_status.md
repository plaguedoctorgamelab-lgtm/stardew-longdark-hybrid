# Strange Ranger: Phase 2a Status

15 November 2026 · from the lab

## Summary

Phase 2a, The way out, is built to the signed-off spec. All automated tests pass: **126 passed, 0 failed.** A player can now take the fire tower from found to open.

This report says nothing about what ring two holds beyond counts, so the forest stays a surprise.

## What was built

1. **The whole forest region.**
   - The world is now the full forest region: 58 by 46 chunks.
   - Ring one, the phase one area, sits inside it, baked exactly as before.
   - Only chunks that hold something are built; the rest reads as rock until its ring comes.
   - Saves are now version 2. Phase one saves upgrade cleanly.
   - The map pans with the walking keys and zooms with the mouse wheel.
2. **Ring two.**
   - Built around ring one from the lab's private plan.
   - 810 chunks now hold something.
   - Three new places to reach, the run-down fire tower among them.
   - Two new kinds of ground.
   - Its edges are things you can see; there are no invisible walls.
3. **Trail work.**
   - The shovel and the saw.
   - Brush can be cleared with the axe in one action. Fallen trunks take the saw and three actions.
   - Digging turns grass, tall grass or forest floor into real trail.
   - Changes to the land are kept in the save, never in the baked world.
4. **The workbench.**
   - A workbench in the station makes trail signs, trail markers and repair kits.
   - Signs go up with the hammer on trail. Each names the station or any place you have mapped, and points the way.
   - Trail markers count as trail for the map marker at night.
5. **Sites.**
   - Six steps, in any order: found, mapped, reached, repaired, signposted, settled.
   - "Reached" means unbroken, cleared trail from the site's door to the station's.
   - Once every step is done, the door offers to declare the site open.
   - J now shows a Sites page under the jobs.
6. **The fire tower.**
   - Repaired, it is a full shelter: bed, stove, chest and radio.
   - Surveying from the top reveals a 90-tile circle.
   - After a collapse you wake at the nearest repaired shelter, never at a camp.
   - Notes from the last ranger can add rough, off-centre rumor circles to the map.
7. **Hidden things.**
   - 14 in all: 13 in ring two and 1 small addition to ring one.
   - Each has a test proving it can be found and works.
8. **Full pass.**
   - Every test, a windowed run across both rings, the input smoke test, and screenshots of every new feature.

## Test results

`python tools/run_tests.py`: **126 passed, 0 failed.** The run also does three checks:

- **Data check:** passed (14 tables).
- **Bake check:** two bakes are identical, and all 810 chunks match the repository.
- **Ring one check:** ring one is unchanged, tile by tile, apart from 42 tiles listed in the bake.

Walking times, measured with the real movement code in clear weather:

| Route | Measured | Target |
| --- | --- | --- |
| Forest edge | 59.6 minutes | 60 |
| Fork | 150.5 minutes | 150 |
| Outlook | 209.8 minutes | 210 |
| Cabin | 239.8 minutes | 240 |
| Ring two's three places | all within 1.2% | the plan's targets |

Checks run with a window:

- **Windowed performance.** The trails from the station through ring one and ring two were walked at three times speed, in rain at dusk. The run averaged 59.9 fps: none of 7,655 frames went over 17.5 ms, and the worst was 17.2 ms. This was on the lab machine's GeForce GT 1030.
- **Input smoke test:** 14 of 14 checks passed.

## Where this differs from the spec, and why

1. **Ring one changed in 42 tiles.**
   - The plan keeps ring one byte for byte, but the two rings have to meet somewhere.
   - So there is one opening where they join, and one hidden addition.
   - Every other tile is checked to be unchanged.
2. **Digging speed.** The clock moves in ten-minute steps, so a five-minute dig can't happen. The shovel digs two tiles per ten minutes instead, the same rate as the spec's one tile per five minutes.
3. **Taking a sign down** takes ten minutes, not five, for the same reason.
4. **Fords.** A trail counts as unbroken across a short wade through shallows (up to 24 tiles). A walk along a stream does not count as trail.
5. **No outlook in ring two.**
   - The spec asked for at least one new outlook, but the private plan, which fixes where everything goes, has none in ring two.
   - The fire tower is ring two's survey point.
6. **Repair kits** stand in for loose planks and nails only. Roofing and glass are still carried loose. Loose materials are used first.
7. **Status emails.** The eight build steps landed as eight commits, with one status email at the end instead of eight.
8. **World data size.** The baked world is now about 6.5 MB in the repository, up from under 1 MB.

## Questions for you

1. **Art for phase 2a.** Everything new uses plain stand-ins:
   - the tower in both states;
   - the two new grounds;
   - seven new outdoor objects;
   - signs, markers, the shovel and saw icons, and the workbench.

   *Suggested answer:* the lab writes Art Request 02. As you agreed, the few pictures the hidden things need go in under plain names.
2. **Signposting distance.** A sign counts for a site within 30 tiles of it. *Suggested answer:* keep 30, and judge it in play.
3. **Clearing effort.** Brush takes one axe action. A trunk takes three saw actions of 20 minutes each. *Suggested answer:* keep these until you've cleared a trail yourself.
4. **Next.** *Suggested answer:* you play 2a, and the lab starts 2b (gathering, cooking, magic-slot crafting and skills) once you sign it off.

## What comes next

- You play the 2a checklist in the spec and note any number that feels wrong.
- Art Request 02.
- Then phase 2b.

## How to run the current build

- **Play:** run `C:\Godot\Godot_v4.7.2-stable_win64.exe --path .` in the repository folder, or open `project.godot` in Godot and press F5. Phase one saves upgrade on Continue.
- **Keys:**
  - W A S D to walk.
  - X or right-click to interact; C or left-click to use the held item.
  - 1 to 0, - and = to choose an item.
  - E for the backpack.
  - M for the map: walk keys pan it and the wheel zooms.
  - J for jobs and sites.
  - Y or N to answer.
  - F1 for the debug panel, which can move you to ring two's places, clear, dig, put up signs and complete site steps.
- **Tests:** `python tools/run_tests.py`.
