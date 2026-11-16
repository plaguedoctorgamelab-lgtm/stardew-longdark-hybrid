# Strange Ranger: Phase 2b Status

16 November 2026 · from the lab

## Summary

Phase 2b, as written in your Phase 2b Build Spec, is built. All automated tests pass: **173 passed, 0 failed.** The lab built all seven steps in one go, as asked, so this one report covers them all.

On a walk the ranger now gathers forage that changes with the season, the weather and the hour. The first time they pick something up they may have an idea. They can cook at a fire, make things anywhere or at a workbench, and refit three tools with magic they found. Four skills rise by doing, with a specialty to choose at level 5.

The Art Request 05 art is in the game too: ground, soft edges, walls, floor, windows, rug, picture and furniture.

Like the hidden things, this report gives only counts for the magical ingredients, so where they are stays a surprise.

## What was built

1. **Foraging.**
   - 11 ordinary kinds:
     - On the ground: sticks, stones, reeds, wild onions, fiddleheads, wildflowers, hazelnuts and mushrooms.
     - From bushes: berries and rose hips.
     - From pines: pine resin.
   - Each kind keeps to its own ground, seasons and limits from your table:
     - Sticks are fewer in winter.
     - Mushrooms also come up the day after rain.
     - Berries come in summer and the first half of autumn.
     - A bush fruits again after 4 days; a pine gives resin once a week.
   - Where forage can appear is fixed when the land is baked: 11,001 ground spots across the whole built world. Each season a save's own seed wakes a share of them.
   - New forage appears each morning. What is not picked lasts 3 days.
   - Walk up and press X to pick. Picking takes no time.
   - Raw forage can be eaten for 5 to 10 energy. Wildflowers are kept for later.
2. **A casual walk.** The lab walked every hour-long stretch of the longest trail in three different saves, picking up anything within three tiles, with no searching. On average an hour's walk filled:
   - spring: 2.8 slots
   - summer: 2.5 slots
   - autumn: 2.8 slots
   - winter: 2.2 slots

   All are inside your target of two or three. A test checks this every run.
3. **Magical ingredients.**
   - 3 ingredients, 30 possible places in all (10 each), 5 of each used per save.
   - Each shows only under its own conditions from your table:
     - Glowcap: only at night; back a week after it is picked.
     - Ember moss: only in snowy weather.
     - Lodestone sliver: buried; the compass trembles near it, the shovel digs it up, and it never comes back.
   - The first of each picked up is logged as a find with a short note, and gives an idea.
4. **Crafting.**
   - The Crafting page (K) has the things made anywhere.
   - A workbench has everything except cooking. The station has one from the start.
   - A lit stove or camp fire cooks. Adding firewood is the first line of the cooking list.
   - At a workbench or stove, the building's chest counts as well as the backpack.
   - Making anything takes 10 game minutes and no energy.
   - A recipe the ranger has not learned is not shown at all.
   - All 17 recipes are in, with your amounts: 4 made anywhere, 5 at a workbench, 5 cooked at a fire and 3 refits.
5. **Ideas.**
   - Picking something up for the first time can teach a recipe, told in one line, such as "These reeds would twist into rope."
   - There are 9 ideas: reeds, hazelnuts, rope, mushrooms, fiddleheads, rose hips, and one for each magical ingredient.
6. **The magic slot and refits.**
   - The slot stays invisible until the ingredient's idea. From then on, an empty slot marked [?] shows on the refit.
   - The game never says what a refit will do.
   - A refit gives the changed tool back in the same backpack slot. Refitting again replaces the old magic.
   - The three refits do what your table says:
     - Glowcap lantern: light reaches 8 tiles, and any find not yet logged sparkles inside it.
     - Ember bedroll: camp is made with no firewood, stays warm with no fire, and restores 90%.
     - True compass: the position marker stays at night and in fog, even off the trail. Storms and blizzards still hide it.
   - Which recipe takes which ingredient is a content table (magic_variants), so later regions can add more without new code.
7. **Things to place.**
   - A cairn stands on open ground and shows on the map once that ground is revealed.
   - Boardwalk is laid on boggy ground or shallows and counts as trail.
   - A workbench kit is set up inside a repaired cabin or tower.
   - The pack frame is made once and grows the backpack from 12 slots to 18, keeping every item.
8. **Skills.**
   - Trailcraft, Surveying, Woodcraft and Foraging. Levels come at Stardew's totals, 100 to 15,000.
   - Every level cuts that skill's energy by 3%.
   - Levels 2 to 4 bring your perks and recipes.
   - At level 5 the ranger picks one of the two specialties from your table, for good.
   - Level-ups are told on waking, one line each, with the perk a level brings. A level 5 wake-up offers the specialty choice once.
   - L shows the Skills page.
   - Experience earned before this phase does not count: everyone starts at level 0.
9. **Saves.** A phase 2a save loads, starting at level 0 with the starting recipes. Everything new saves and loads exactly.
10. **Debug tools (F1).**
    - Put any forage in front of you, regrow all forage, and unlock every recipe and idea.
    - Set any skill's level, or give any specialty.
    - A "Show spoilers" tick. Without it, the magic information gives counts only.
11. **Art Request 05.**
    - All 5 sheets are in and cut pixel for pixel.
    - Your edge sheet drew its cells in a different order from the guide, and one shape (ground on the top, left and right) was missing. The lab put the cells in the right order and built the missing one from your top, left and right cells. It joins up cleanly.
    - The new desk is in the tower, and the framed picture hangs in all three rooms.
12. **Full pass.** Every test, the windowed performance run, the input smoke test, and screenshots of each new feature (attached).

## The play checklist

These are the lines from your spec for you to play. The lab's tests cover each one, but only you can judge how they feel.

- Come home from an ordinary walk with a few things you did not set out to gather.
- Have an idea, and make the thing it suggested.
- Cook a meal at a campfire and at a stove.
- Make planks at a workbench you set up in the cabin or tower, and use them there.
- Lay boardwalk across wet ground.
- Make the pack frame and feel the difference on the next trip.
- Find one magical ingredient without being told where it is.
- Refit a tool, and work out for yourself what changed.
- Reach level 2 or 3 in a skill and notice the work getting easier.
- Judge whether foraging feels like a pleasure of walking or a chore.
- Judge whether any refit makes the game too easy.
- Write down what felt wrong, and what you wanted to make and could not.

## Test results

`python tools/run_tests.py`: **173 passed, 0 failed.** The run also does three checks:

- **Data check:** passed (21 tables, 513 rows).
- **Bake check:** two bakes are identical, and all 810 chunks and the forage spots match the repository.
- **Ring one check:** ring one is unchanged apart from the 42 tiles listed in the bake.

The 41 phase 2b tests cover every line of your test table: forage, yield, magical ingredients, crafting, ideas, the magic slot, refit effects, placeables, backpack, skills, saves and secrecy. One more plays your proving scene: berries and reeds on a walk, a glowcap at night, the refit at the workbench, and the next night a sparkle on a find that was walked past.

Checks run with a window:

- **Windowed performance:** the trails from the station through ring one and ring two were walked at three times speed. The run averaged 59.9 fps; 2 of 7,655 frames went over 17.5 ms (0.03%), and the worst was 19.1 ms. This was on the lab machine's GeForce GT 1030.
- **Input smoke test:** 14 of 14 checks passed.

## Where this differs from the spec, and why

1. **Built in one go.** You asked for the whole phase, so there is one report, not seven.
2. **The Crafting page is on its own key (K)**, not a page inside the backpack screen. It lists the same recipes.
3. **Phase 2a recipes are kept.**
   - Trail markers and repair kits are still made at the workbench.
   - Your "blank sign" is the 2a trail sign, now made anywhere for 2 planks and 1 nail.
   - So 19 recipes are listed in all: your 17 plus these two.
4. **Things the spec does not settle, and what the lab chose:**
   - Rose hips come back on the same 4-day cycle as berries.
   - Ember moss comes back a week after it is picked, like glowcap.
   - "After rain" means the day after any rain or storm.
   - Picking takes no time and no energy, as in Stardew.
   - Camp hand's "10 points more" is 10 more energy and 10 more warmth.
   - Laying boardwalk takes 10 minutes and 2 energy.
   - A workbench kit stands in one set spot in each room.
   - The casual-walk yield counts ground forage and fruit on bushes. It does not count pine resin, which needs a deliberate stop at a tree.
5. **Levels work at once, and are told on waking.** If the specialty choice is closed, it can still be made from the Skills page.
6. **Raw forage energy** sits in the foods table with the other food values, as your "New data" section asks, rather than in the tuning file.

## Questions for you

1. **Digging two tiles.** Phase 2a already digs 2 tiles at a time, so "Each dig lays two tiles" at Trailcraft 2 would change nothing.
   - *Suggested answer:* keep 2a's 2 tiles; Trailcraft 2 adds one (3 tiles) and Trail builder another (4).
   - The other way is to go back to 1 tile at the start.
2. **The numbers.** Forage densities, the 3-day life, refruit days, the skill perks and the refit sizes are all first values in the tuning file and content tables. *Suggested answer:* play with them as they are and note what feels wrong.
3. **Art.** Everything new uses stand-ins. *Suggested answer:* Art Request 06 (attached: 3 sheets, prompts inside) covers the gathered icons, the made icons and the small things on the ground.
4. **Next.** *Suggested answer:* you play the checklist above, and the lab revises 2b from your notes before planning phase three.

## How to run the current build

- **Play:** run `C:\Godot\Godot_v4.7.2-stable_win64.exe --path .` in the repository folder, or open `project.godot` in Godot and press F5.
- **New keys:**
  - X picks forage, berries, rose hips and pine resin, and opens cooking at a lit stove or camp fire.
  - K opens crafting.
  - L shows skills.
  - Use (C) lays boardwalk, sets cairns and sets up a workbench kit; with the shovel it also digs.
- **Tests:** `python tools/run_tests.py`.
