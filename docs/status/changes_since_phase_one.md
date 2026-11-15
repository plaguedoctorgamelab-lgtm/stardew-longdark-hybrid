# Strange Ranger: Changes Since the Phase One Build

15 November 2026 · from the lab

Phase one was delivered in four commits, steps 1 to 9. Since then, five more commits have landed on `main` from the designer's first play. All automated tests pass: **88 passed, 0 failed**, up from 75.

## 1. Easier to read, easier to start

*Commit 911eb37: sharp text, a clear first day and a mapped home area*

- **Sharp text.** The world still draws at 480 × 270, pixel-perfect and scaled up by whole numbers. Text, menus and the HUD now draw at the screen's full resolution, so they are crisp instead of blocky and blurred.
- **Day one is always clear.** Fog or rain on the first morning got the designer lost straight away. The first day's three weather blocks are now forced to clear. The setting is `weather.first_day` in tuning.
- **The home area starts mapped.** The ground within 20 tiles of the station door is already filled in on a new game, so the map is useful from the first minute. The setting is `map.home_reveal_radius`.

## 2. Something to head for, and a way to stay out overnight

*Commit 564ac56: cabin hint, camping, chopping trees and the cabin job*

- **Cabin hint on the map.** A rough dashed circle labelled "Old cabin?" shows roughly where the cabin is. It is placed off-centre on purpose, so it is a direction, not a pin. It disappears once the cabin is mapped.
- **The job.** A note board in the station holds a note from the last ranger asking for the old cabin to be fixed up. Reading it adds **Fix up the old cabin** to the job list.
  - Press **J** for the job list.
  - The list shows what to bring, with counts from the backpack, and which of the four repairs are done.
  - The wording is an invitation, not an order, as the bible asks.
- **Camp.** The station chest now starts with an **axe** and a **bedroll**.
  - A bedroll plus one firewood makes camp anywhere outdoors: the bedroll where you stand and a small fire in front.
  - The fire warms you by +8 per ten minutes within 2.5 tiles, lights the dark around it, and burns 3 hours per firewood. You can feed it more wood.
  - Sleeping at camp wakes you at 6:00 with 75% energy and warmth, and saves the game.
  - Only one camp can stand at a time.
- **Chopping trees.** Use the axe on a pine, fir or oak.
  - Each chop gives 2 firewood and costs 6 energy and 20 minutes.
  - The tree leaves a stump that grows back after 7 days.
  - The dead tree at the fork can't be chopped, because it is a landmark.

These pull gathering (phase 2) and a first job (phase 4) forward, on the designer's instruction. Every number is in `tuning.json` and every word is in the content tables.

## 3. Light spring mornings and a kinder rescue

*Commit 1e690f8*

- **Spring sunrise moves to 5:30**, so it is already light when the day starts at 6:00 and you can survey straight away.
- **Rescue message.** After a collapse it now reads "Someone found you and brought you back to the station. They were gone before you woke." There is a matching line for the cabin.
- Kept as they were, as agreed: backpack size, the outlook-to-cabin shortcut, and rescue to the nearer bed.

## 4. Art Request 01

*Commit 75d39ee*

`docs/art/art_request_01.md` lists every picture the game was still missing, with grids, game sizes, descriptions and prompts. It covers three sheets: items, the fire, stove and gate, and the weather symbols. It also asked two questions, about the palette and the game sizes. It was emailed to typewritermark@gmail.com.

## 5. The art came back

*Commit cfe71eb: Art Request 01 and the forest palette*

- **All three sheets are in the game:**
  - hot soup, planks, nails, roofing and window glass;
  - the camp bedroll and the note board;
  - the redrawn campfire, the unlit stove and the park gate;
  - all seven weather symbols.
- **The forest palette.** The 25-colour palette sheet replaces the lab's 62-colour stand-in. Every picture in the game was re-cleaned against it, so the whole game now uses only those 25 colours.
- **Cleanup report:** 103 images passed.
  - The one failure on the list is the *old* campfire from the first batch. It is kept as `obj_campfire_v1` for the record and is not used; the new campfire passes.
  - The palette sheet itself is marked as a reference, not a picture.
- **No stand-ins remain.** Every picture the game uses is finished art.
- The cleanup tool now leaves out any image that fails its checks, so a broken picture can never replace a working one.

## Smaller fixes along the way

- Dialog boxes size themselves to their text, so the radio forecast no longer overflows.
- The note board was moved away from the bed so that pressing interact by the bed doesn't read the note.
- The map's labels are kept at the right size.
- The trail now starts at the station's door, and the cabin door is reachable from the end of the trail.

## Still open, for the designer

1. **Unlit and lit stove don't quite match.** The new unlit stove is drawn a little differently from the lit one in the first batch. *Suggested answer:* redraw the lit stove from the new unlit one, with a glow added.
2. **Clear nights show a sun.** *Suggested answer:* add a moon symbol for clear weather after dark in the next art batch.
3. **Game sizes.** The size table in Art Request 01 hasn't been confirmed yet. *Suggested answer:* keep the current sizes unless something looks wrong in play.
4. **The shortcut.** Going cross-country from the outlook to the cabin is still about 35 game minutes, against roughly 3 hours by trail. *Suggested answer:* judge it in play. If it feels like cheating, add a ridge with one gap.

## How to run

- **Play:** run `C:\Godot\Godot_v4.7.2-stable_win64.exe --path .` in the repository folder, or open `project.godot` in Godot and press F5.
- **Keys:**
  - W A S D to walk.
  - X or right-click to interact; C or left-click to use the held item.
  - 1 to 0, - and = to choose an item.
  - E for the backpack, M for the map, J for jobs.
  - Y or N to answer; F1 for the debug panel.
- **Tests:** `python tools/run_tests.py`.
