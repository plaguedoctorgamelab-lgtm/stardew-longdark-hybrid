# Strange Ranger 0.5.1: your art and music, and the tracker fixes

From the lab, 21 November 2026.

## What's in

**Your Art Request 16 sheets:**

- **Item icons:** all 26 that were stand-ins.
- **Furniture:** a trunk, two cupboards, a wardrobe, the pantry, a bunk bed, the cabin bed, the map table, a table and chairs, the coat rack, the lamp (unlit and lit), and the curtained window by day and night.
- **Trees:** the five new trees, and an old and a young version of the pine, fir, oak and dead tree.
- **Plain ground:** recolored to the game's own greens, browns and blues so it sits among the old tiles. It now covers about three tiles in four, and the scattered details are a third as common.
- **UI pieces:** the wooden frame and the six tab icons. The frame's wood was turned brown to match the clipboard.

Two things from the sheets are not in:

- **The bog tile** came out as a white blob, so it's left out. Send it again any time.
- **The water:** your picture still hasn't come through, so the water is unchanged.

Two other notes on the sheets:

- The two room sheets were swapped (the small things came under the big sheet's name). No harm done.
- A few pieces were cut by hand where a row had extra cells: the coat rack and the two windows.

**Rooms** are one tile bigger each way (tracker #21) and furnished:

- **The cabin:** its own bed, a trunk, cupboard, pantry, washstand, wood box and lamp.
- **The tower:** the bunk bed, map table, wardrobe, trunk and lamp.
- **The station:** a table and chairs, the coat rack, a lamp and the curtains.

**Light at night:**

- From outside, an open building's windows glow warm and light the step.
- Inside, the room dims, and the lamps (and the stove, when lit) light it.
- The curtained windows show a night sky.

**Music**, which changes with where you are and crossfades:

- **Hearthlight:** the title screen and indoors.
- **Pine Path:** outdoors by day.
- **Lanterns in Snow:** all winter, and outdoors at night.

Options has a new **Music** setting: Off, Quiet, Medium or Loud.

**The jobs look in other screens:** the backpack, the book, the workbench and cooking lists, the pause menu, Options and dialogs now sit in your wooden frame, with tab pictures.

## The tracker

Every open item is marked fixed, each with a note saying what was wrong. Reopen any that still feel wrong. The real bugs behind your reports:

- **Cans and benches not counting (#16, #24):** template jobs never filled in their place, so they looked nowhere.
- **The pond trail (#19):**
  - Some brush on it was never named in a step.
  - There was no trail from the cabin to where the pond trail starts.
  - The trail stopped just over 3 tiles from the pond's spot.
- **The stake trail (#23):**
  - Getting from the pond to the first stake meant a long wade.
  - The trail stopped 5 tiles short of the tower door.
- **The pond cairn (#25):** pressing X picked the reeds beside it first.
- **Getting stuck (#12, #14):** you can always walk out now.
- **Camps (#20):** the hammer packs one up.
- **Taking things down (#18):** the hammer always did this; the hints now say so.
- **Placing (#17):** signs and things try the tiles beside the one you face.
- **Show on map (#22):** it now rings the step and names it.

## Things to test

- [ ] **Music:** hear Hearthlight on the title screen, Pine Path outdoors, Hearthlight indoors, and Lanterns in Snow after dark or in winter (F1, then "+season" three times). Try each Music setting in Options.
- [ ] **Night:** at night, walk by the open station or cabin. Do the windows glow? Go in. Is the room dim with the lamp lit, and do the curtains show night?
- [ ] **Rooms:** walk round the station, the cabin and the tower. Is there room to move? Do the bed, chest, stove and radio still answer X with the new furniture beside them?
- [ ] **Ground and trees:** is the ground calm enough now? Do the new trees sit well among the old ones?
- [ ] **Item icons:** open the backpack and the workbench. Do the new icons read at size?
- [ ] **Frames:** the backpack, the book (B), the workbench, the pause menu and Options. Does the jobs look carry over?
- [ ] **#16, #24:** take on a cans or bench job at the outlook or cabin, put the things down there, and see the job finish.
- [ ] **#19:** do Reopen the Pond Trail (saw the trunks, clear the brush, dig both gaps). Does "Walk the trail: cabin to pond" tick, and does Open Kettle Pond's join tick?
- [ ] **#23:** do both Stake Trail jobs. Do they finish, and does Open the Static Tower's join tick? Then try trail travel to the tower.
- [ ] **#25:** press X at the pond's cairn.
- [ ] **#12, #14, #20, #17, #18:** put a can down where you stand and walk off it. Make a camp, then pack it up with the hammer. Put a sign down facing a bad tile. Take a sign down with the hammer.
- [ ] **#22:** pick a job on the clipboard and press Show on map.
- [ ] Your old save: does it load with the bigger rooms? Your position inside is moved to the entry if needed.
