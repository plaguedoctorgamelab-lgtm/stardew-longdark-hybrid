# Strange Ranger: Phase One Status

15 November 2026 · from the lab

## Summary

Phase one (Bedrock) is built to the spec and every automated test passes:
**75 passed, 0 failed.** The game runs and is ready for your play checklist.
Your raw art has been cleaned and is in the game: 86 images passed and 1 failed.

## What was built

- **Foundations.** A Godot 4.7.2 project drawn at 480 by 270 and scaled up by whole numbers, with nearest-neighbor filtering, the input map, the spec's folder layout, `tuning.json`, seven content tables, the Python data check and a one-command test runner.
- **World and movement.** A bake tool turns `data/world/layout.json` into 96 chunks of 32 by 32 tiles (384 by 256 tiles in all). The map has the station and gate, the meadow, the forest edge, the stream with its ford and deep pool, the fork with its dead tree, the outlook on a rocky rise, and the cabin in the far northeast. The ranger walks in eight directions and faces four. Each ground type has its own speed, solid things block, the camera follows, and chunks stream in and out.
- **Time and light.** Clock, calendar and seasons; sunrise and sunset by season; warm dawn and dusk, deep-blue night, and the lantern's circle of light.
- **Weather.** Three blocks a day drawn from the season's odds, with a leaning toward staying the same. Weather sets the tint, how far you can see (fog 6 tiles, blizzard 4), walking speed and whether you can survey. Rain, snow and blizzard streaks are drawn by the game, wind streaks and a shift in the light give an hour's warning, and the station radio gives the forecast.
- **Energy and warmth.** Both bars, food, hot soup, exhaustion, chill, indoor and stove warmth, and collapse and rescue to the nearer bed.
- **Backpack and buildings.** A 12-slot backpack and item bar, a supply shelf that restocks each morning, 12-slot chests, separate interiors, the four-step cabin repair, the wood stove, sleeping and saving.
- **The map.** Trace, survey, location mapping, the outlook survey, the map screen, the percentage revealed, and the three marker rules, with the trace walked while lost held back until the marker returns.
- **Debug panel (F1).** Has every tool the spec lists. Every debug action is also called by the tests.
- **Art cleanup tool.** Run against all nine raw images.

## Test results

`python tools/run_tests.py`: **75 passed, 0 failed**. It also runs the data check, which passed, and the bake check: two bakes are identical and all 96 chunks match the repository.

| Area | Result |
| --- | --- |
| Data, time, movement, world, weather | all pass |
| Warmth, energy, collapse | all pass |
| Backpack, cabin, sleep and save | all pass |
| Map, tuning reload, debug actions | all pass |
| Performance, headless | 10,039 frames walking the whole trail. The game's own work averages 0.2 ms per frame; the worst frame is 6.6 ms, and no frame went over 16.7 ms |
| Full proving-scene playthrough | passes |
| Shortcut in fog | passes |

Walking times by trail in clear weather, against the spec's targets:

| From the station to | Measured | Target |
| --- | --- | --- |
| Forest edge | 59.6 minutes | 60 |
| Fork | 150.5 minutes | 150 |
| Outlook | 209.8 minutes | 210 |
| Cabin | 239.8 minutes | 240 |

Checks run with a window, outside the one command:

- **Windowed performance.** The game walked the whole trail at three times speed in rain at dusk, with drawing on. It averaged 59.9 fps, locked to the screen's refresh rate. 0.12% of frames ran over 17.5 ms, and the worst was 22.8 ms. This was on the lab machine's GeForce GT 1030.
- **Input smoke test.** 14 of 14 checks passed. Walking, the backpack, the map, the item keys, F1, doors, the sleep question, saving and walking out all respond.

In the playthrough, the ranger reached the cabin at 9:50 am using 23 energy. The rain arrived during the repairs, which were done by 2:10 pm at 148 energy and 72 warmth. The ranger slept there and was home by 9:50 the next morning, having traced 1,823 tiles.

## Art cleanup report, short form

86 passed and 1 failed. The full report is in `art/cleanup_report.md`.

- **Failed: `obj_campfire`.** The flames come out as four separate pieces. Please redo it with the fire touching the stones.
- **Skipped:** "ChatGPT Image Nov 15, 2026, 07_05_23 AM.png" is a byte-identical copy of "Forest park object sprite sheet.png".
- **Still placeholder, no raw art yet:** hot soup, planks, nails, roofing, window glass, the unlit stove (the raw stove looks lit, so it became the lit one), and the park gate.
- **Extras cut for later phases:** axe, saw, shovel, binoculars, camera, matches, canteen, backpack, bedroll, table, chair, rug, map desk, woodpile, berry bush, stump, branch, fern, arrow sign, fire pit, mushrooms, flowers, glowing mushrooms, and three more grass, forest-floor and trail variants.

## Where this differs from the spec, and why

1. **Commits and emails.** The nine build steps landed in four commits (step 1, step 2, steps 3 to 7, steps 8 and 9), and you are getting one status email at the end instead of nine. You asked for one email when done.
2. **Engine.** Godot 4.7.2 stable is used, as installed at `C:\Godot`. The spec allows 4.6 or newer.
3. **Walking energy** is charged only in ten-minute steps when the ranger actually moved. Standing still outdoors costs nothing.
4. **Chill** doubles the walking drain. It does not double the fixed costs of repairing, surveying and mapping.
5. **Repair.** A step's materials are used up on its first hammer action. The hammer works on a step already started, or else the first unfinished step whose materials you are carrying.
6. **Time-taking actions.** Repairing and mapping a location move the clock forward at once, and warmth still changes for each ten minutes that pass. Surveying is a real wait: you stand still for 30 game minutes, about 21 seconds.
7. **Lantern.** It is lit whenever it is the held item. There is no on/off switch.
8. **Stove.** The stove goes out overnight.
9. **Solid bushes.** Bushes are solid, as in Stardew. The spec lists trees, boulders, buildings and trunks.
10. **Reveal radius in two places.** It is stored both in the landmarks table and in tuning. The landmark row wins, and both say 8. See question 5.
11. **Weather leaning.** A block only keeps the previous block's weather if that weather can happen in the current season, so rain never carries into winter. A wrong forecast always names weather that is possible in that season.
12. **Tomorrow's outlook** on the radio names tomorrow's most common block weather, and it is right 85% of the time.
13. **Edge of the map.** The map's edge is three tiles of rock plus four of dense trees. The gate stands in a gap in the west edge, near the station.
14. **Placeholder font.** The text uses Godot's built-in font at 8 px. It is a placeholder until a pixel font is chosen, and choosing one is an add-on question.
15. **File housekeeping.** Your `ref/` folder is left untouched and is ignored by git. The docs were copied into `docs/` and the raw images into `art/raw/`. Godot's `.gdignore` marker files were added to `art/raw/`, `docs/`, `tools/` and `ref/` so that Godot never writes import files there; no image was changed.

## Questions for you

1. **Who finds the ranger after a collapse?** The placeholder text says "A hiker found you and helped you back to the station." *Suggested answer:* keep a nameless kind stranger until phase 3, then maybe a note from the Chief.
2. **The palette.** The style guide's palette isn't in the repository, so the cleanup tool made a stand-in of 62 colors from your raw art (`art/palette.json`). *Suggested answer:* send the style-guide palette, and the lab will re-run the cleanup.
3. **The art manifest.** The style guide's file table isn't in the repository either, so the lab wrote `tools/art_manifest.json` from the images themselves. *Suggested answer:* confirm the sizes the lab chose: trees 32×48, cabin 64×64, station 96×80, bed 32×32 and items 16×16.
4. **The shortcut is very short.** Cross-country from the outlook to the cabin takes about 35 game minutes, against roughly 3 hours by trail via the fork. *Suggested answer:* play-test it first. If it feels like cheating, the lab can add a ridge with one gap so it takes about 1.5 hours.
5. **Location reveal radius in two places.** *Suggested answer:* keep the tuning value as the default, and let a landmark's row override it only when it needs a different size.
6. **Standing still outdoors costs no energy.** *Suggested answer:* keep it that way.
7. **Missing art.** *Suggested answer:* add hot soup, planks, nails, roofing, window glass, an unlit stove, the park gate, and a redone campfire to the next art batch.

## What comes next

- You play the phase one checklist in `docs/Phase One Spec.md` and note every number that felt wrong.
- Tuning changes and sign-off.
- Then the phase two spec.

## How to run the current build

- **Play:** open `project.godot` in Godot 4.7.2 and press F5, or run `C:\Godot\Godot_v4.7.2-stable_win64.exe --path .` in the repository folder. On the title screen choose New game.
- **Keys:** W A S D to walk. Right-click or X to interact. Left-click or C to use the held item. 1 to 0, - and = to choose an item. E for the backpack, M for the map, Y or N to answer, F1 for the debug panel.
- **Tests:** `python tools/run_tests.py`.
