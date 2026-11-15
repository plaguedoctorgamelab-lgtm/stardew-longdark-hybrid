# Strange Ranger: Phase Two Build Spec (lab draft)

**Draft for the designer to review.** The lab wrote this from the bible, the roadmap and what phase one's play taught. Nothing here is built yet. Change anything, then sign it off, and the lab builds from the signed version. The lab's questions are at the end.

Phase two, Trail work, gives the ranger the tools and skills to turn a found place into an open one. A new stretch of forest beyond the old cabin gives them somewhere worth doing it.

## Goal and scope

Phase two must prove that **opening the park is satisfying work**: finding a place, mapping it, cutting a way to it, fixing it up and signposting it, over several trips, by choice.

The scene that proves it:

1. A note from the last ranger hints at a fire tower further out.
2. The ranger heads beyond the cabin into new forest, steering by what they can see, and finds the tower run-down.
3. They map it, then over the next trips clear the fallen trees between it and the nearest trail and dig the missing stretches.
4. They repair the tower, sleep in it, and survey from the top while the map floods with ground.
5. They craft a sign at the station, carry it out and put it up at the junction.
6. Then they declare the tower open.

Along the way they gather, cook, craft a better tool, and feel their skills grow.

### Split in two

The roadmap allows a phase to be split, and this one is large, so the lab proposes two halves. Each half is playable and tested before the next begins.

| Half | Name | Adds | Done when |
| --- | --- | --- | --- |
| 2a | The way out | The second ring of the forest, the shovel and saw, clearing and building trail, a workbench with park-work recipes, signs, the site-opening steps, fire towers, more outlooks, rumors on the map, hidden things | A player can take the fire tower from found to open |
| 2b | Living out there | Gathering, cooking, personal crafting and the magic slot, the skills Trailcraft, Surveying, Woodcraft and Foraging with their specialties | A player can make a magic-slot item from things they found and feel a skill choice change how they play |

**In phase two:** everything in the table above.

**Not in phase two:** money, shops, visitors, fees, tours, permits, staff, the town, townsfolk, the Chief, creatures and animals, settling magic, the Lore skill, the camera, the field guide, badges, clothing, decorating, pets, the canoe and cart, crossing into the forest beyond ring two, the 80% map-completion rule, music and sound. Anything on this list waits for its phase, even if it would be easy.

Several things were pulled forward from phase two during phase one's play: the axe, chopping trees, camping, the note board and the job list. Phase two keeps them and builds on them.

## What phase one taught

These came out of the designer's first play. The lab proposes adding them to the lessons-learned list when phase one is signed off.

- **Readable text matters as much as the pixel look.** The world stays pixel-perfect; text and menus draw at full resolution.
- **The first hour must not get the player lost.** Day one is clear and the home area starts mapped.
- **A place you can't see needs a hint.** A rough circle on the map works without becoming a quest marker.
- **Far trips need a fallback for the night.** The bedroll camp made distance feel like planning, not punishment.
- **An invitation helps.** The note board and job list gave the cabin trip a reason without ordering it.

## Technical standards

Phase one's standards hold unchanged: engine, language, screen, pixels, input, tests, Python tools and folder layout. Additions:

- **Changes to the land are kept in the save, not the baked chunks.** Cleared trunks, dug trail, placed signs and chopped trees are stored per save as changes on top of the frozen land. The baked world stays identical for every player.
- **Save version 2.** It adds the new keys. Phase one saves load and gain the new keys with starting values; they never fail.
- **The world grows to the forest's full planned size.** Only ring one and ring two are filled in. Chunks that hold nothing yet are not baked or loaded.
- **Hidden things live apart.** Their rows go in their own content tables, marked as spoilers. Their notes stay in `docs/spoilers/`, which is kept out of git. Their tests sit in a separate test file. See question 7.

## The world: ring two

The forest is built outward in rings, and each ring is final once built. Ring one is phase one's test area, and it stays exactly as built. Phase 2a adds ring two around and beyond it.

- **Where it is.** Ring two is laid out by the lab from its private region plan, so the designer can discover it. This spec doesn't describe what is in it.
- **What it holds, in counts.** One fire tower to repair and open. At least one new outlook. Several new landmarks to map. A set of hidden things.
- **Edges.** Ring two is closed off by natural features the player can see. There are no invisible walls and no temporary barriers.
- **Distance.** The fire tower is a long day's walk from the station by trail, and shelter is never more than about four hours apart. The lab meets the travel times in its plan to within 10%.
- **Ring one is untouched.** Its baked chunks must come out the same byte for byte after ring two is baked, apart from at most a few hand-placed additions, which the lab reports by count.
- **Per save.** Supplies found in ring two's buildings, and the spots where forage grows, vary with the save's seed. Everything else is fixed.

### Rumors

The cabin hint becomes a general rule. A note from the last ranger, found on a note board or in a building, can add one or more rough circles to the map, placed off-centre. A circle disappears once its place is mapped. Rumors are how the player hears of ring two's places without being told where they are. Ring two needs at least two rumor notes.

## 2a systems: tools, clearing and trail

### The tool kit

Phase two's kit completes the bible's list, except the camera and binoculars, which wait for the field guide in phase five (see question 2).

| Tool | Use in phase two | Starts |
| --- | --- | --- |
| Axe | Chop trees for firewood (as now) and clear brush | In the station chest (as now) |
| Saw | Cut through fallen trunks across a trail | Found at the old cabin once repaired |
| Shovel | Dig new trail, one tile at a time | In the station chest |
| Hammer | Repairs, and putting up signs | Carried (as now) |
| Lantern | Light | Carried (as now) |
| Map, compass and pencil | Surveying | Carried (as now) |

Tools are used from the item bar on the tile the ranger faces, as with the axe now.

### Clearing

- **Brush** is a new small obstacle that blocks trail. One axe action clears it.
- **Fallen trunks** across a trail take several saw actions. Each saw action takes game time and energy. Cut trunks are gone for good in that save.
- Cleared things stay cleared. Nothing grows back except chopped trees, as now.

### Building trail

- The shovel turns the faced tile of grass, tall grass or forest floor into trail. It can't dig on rock, water or under solid things.
- Dug trail is real trail: it has trail speed, and it counts as trail for the map marker's night rule.
- Digging next to existing trail joins up with it, so a player can link two trails or close a gap.
- Trail can't cross deep water in phase two. Bridges are later.

### The workbench and park-work recipes

- A workbench stands in the station. Using it shows the recipes the ranger can make, with what each needs and what is in the backpack.
- **Park-work recipes in 2a:** trail sign, trail marker (a small post that shows on the map and counts as trail for the marker's night rule) and repair kit (a bundle of planks and nails that stands in for one step's loose materials, to save backpack slots).
- Materials come free from the supply shelf, as in phase one, until money arrives in phase three.

### Signs

- A trail sign is crafted, carried, and put up with the hammer on any trail tile.
- When putting it up, the player picks a destination from the places they have mapped. The sign shows that name and points the way.
- Signs appear on the map. Reading one names the place and its direction.
- A sign can be taken down and carried again.

## 2a systems: sites and fire towers

### Opening a site

Each site has six steps, shown in the job list (J), which now has a Sites page:

| Step | Done when |
| --- | --- |
| Find | The ranger first sees the site |
| Map | The ranger maps it as a location, as now |
| Reach | Unbroken trail, cleared of obstacles, joins the site's door to the station's trail network |
| Repair | Its structure's repair steps are all done |
| Sign | A sign naming the site stands on the trail within a set distance of it |
| Settle | Any magic there is settled. No site in phase two has any, so this shows as "nothing strange here" and counts as done |

When the first five are done, interacting with the site offers to **declare it open**. An open site is marked on the map, and the job list shows it as open. In phase two, opening changes nothing else; visitors and income come in phase three. Steps can be done in any order, and progress is never lost.

The fire tower is phase two's site. The old cabin stays a shelter, not a site.

### Fire towers

- A fire tower is repaired like the cabin, in steps, with materials. It has its own steps and its own picture for each state.
- Repaired, it is a full shelter: bed, stove, chest, sleeping and saving.
- **The tower radio** gives the forecast, as the station radio does.
- **The tower survey.** Surveying from the cab at the top reveals a much larger patch than an outlook.
- Like the station, it can hold a note from the last ranger.

### Collapse and rescue

The ranger wakes in the nearest repaired shelter (station, cabin or tower) after a collapse. A camp doesn't count. This answers the open question "Where does the ranger wake after staying up too late in the backcountry?" (see question 4).

### Hidden things

Phase 2a is the phase where hidden things begin, as the Working Rules describe. The lab places a set of them in ring two and adds one small addition to ring one. Each obeys the standing rules, needs nothing and blocks nothing, and has its own test. Status emails give only the count.

## 2b systems: gathering, cooking, crafting and skills

### Gathering

- **Forage** grows at spots drawn from the save's seed, by season, and regrows after a set number of days. Interacting picks it.
- **Starting forage:** berries (summer to autumn), mushrooms (autumn), wild greens (spring), pine resin (all year). It is used for food and recipes.
- **Found magical ingredients:** a short list of odd things that occur only in particular places, such as glowing mushrooms. Each is used only in the magic slot.

### Cooking

- Cooking happens at a lit stove, at the station, cabin or tower, or at a lit campfire. It uses recipes like the workbench.
- **Starting recipes:** berry jam on bread, mushroom stew, and trail mix. Each restores the energy and warmth set in the food table. Hot meals give the warmth boost.

### Personal crafting and the magic slot

- Every recipe has a basic version, plus an optional magic slot that takes one found magical ingredient.
- The ingredient changes the result in a way the recipe row describes. In phase two, these changes are only to numbers, never new abilities.
- **Starting recipes with magic slots:**
  - glow lantern: wider light;
  - resin torch: a camp fire that burns longer;
  - stout boots: tall grass and shallows slow you less;
  - warm flask: hot drink, longer warmth boost.
- The best versions are only possible with found ingredients, as the bible asks.

### Skills

Four skills rise by doing, as in Stardew. Each has 10 levels. Every level gives a small boost, and at levels 5 and 10 the player picks one of two specialties.

| Skill | Grows by | Each level | Example specialties |
| --- | --- | --- | --- |
| Trailcraft | Clearing, digging trail, putting up signs and markers | Trail work costs less energy | Pathfinder (dug trail is faster) or Sawyer (trunks take fewer actions) |
| Surveying | Surveying, mapping locations, walking new ground, reaching the tower top | Surveys reveal a little more | Steady hand (surveys take less time) or Wayfinder (the marker holds longer in fog) |
| Woodcraft | Repairs, crafting, cooking, chopping, making camp | Repairs and chopping cost less energy | Fire-keeper (fires and stoves burn longer) or Joiner (repair steps need fewer actions) |
| Foraging | Picking forage, finding magical ingredients | Better chance of picking extra | Gatherer (forage regrows sooner) or Seeker (magical ingredients show from further off) |

- Every number above is in the tuning file.
- The skill screen shows each skill's level, its progress and the chosen specialties.
- A level-up shows a short message.
- Lore waits for phase five.

## Content tables

New tables, each with a data check:

| Table | Holds |
| --- | --- |
| `sites` | Each site: its structure, its door, its sign distance, and whether it has magic to settle |
| `recipes` | Workbench and cooking recipes: inputs, the optional magic slot, its allowed ingredients, the result and what changes |
| `forage` | Each forage kind: item, seasons, regrow days, how many spots and where they may appear |
| `skills` | Each skill: what grows it, XP per level, each level's boost, specialties |
| `obstacles` | Brush and fallen trunks: tool, actions, time, energy |
| `notes` | Notes from the last ranger: text, where they appear, what they unlock, which rumors they add |
| Spoiler tables | Hidden things, kept apart |

Existing tables grow: items (new tools, sign, marker, forage, food, magical ingredients), structures (the fire tower), landmarks (ring two's places), jobs (folded into the Sites page) and text.

## Tuning values (starting guesses)

| Group | Value | Start |
| --- | --- | --- |
| Clearing | Brush: axe actions / minutes / energy | 1 / 10 / 3 |
| Clearing | Fallen trunk: saw actions / minutes each / energy each | 3 / 20 / 6 |
| Trail | Tiles dug per shovel action / minutes / energy | 1 / 5 / 2 |
| Signs | Minutes and energy to put up / take down | 10 and 2 / 5 and 0 |
| Sites | Sign distance from the site | 30 tiles |
| Towers | Repair steps; tower survey radius | 4 steps; 90 tiles |
| Forage | Regrow days; spots per kind in ring one / ring two | 3; 6 / 18 |
| Skills | XP to reach level 1, growing by | 100, ×1.4 a level |
| Skills | Boost per level | 3% |
| Collapse | Wake in the nearest repaired shelter | on |

Each skill's XP for each action is in the skills table. The magic-slot changes are in the recipes table.

## Debug tools

The F1 panel gains these tools, each callable from tests:

- Move to any ring two landmark.
- Place or clear any obstacle.
- Dig or undo trail on the faced tile.
- Put up a sign anywhere.
- Complete or undo any site step.
- Declare a site open.
- Set any skill's level and specialties.
- Spawn or regrow forage.
- Unlock every recipe.
- Show the trail network and site reach.

A separate spoiler panel, opened from the debug panel, lists hidden things by id only.

## Build order and acceptance tests

### 2a build order

1. Save version 2, the world grown to full size, and changes to the land kept in the save.
2. Ring two baked, with ring one unchanged and travel times met.
3. Shovel, saw, brush, trunks and digging trail.
4. The workbench, signs and markers.
5. Sites, the Sites page, reach checking and opening.
6. The fire tower, its radio and the tower survey. Rumors and notes.
7. Hidden things.
8. Full pass, play, and a status email.

### 2b build order

1. Forage and magical ingredients.
2. Cooking.
3. Personal crafting and the magic slot.
4. Skills, specialties and the skill screen.
5. Full pass, play, and a status email.

### Automated tests

| Area | Must be true |
| --- | --- |
| Saves | Phase one saves load into version 2; every new value saves and loads exactly |
| World | Ring one's chunks are unchanged; baking twice matches; travel times to ring two's places are within 10% of the plan; ring two's edges can't be crossed anywhere |
| Clearing and trail | Each obstacle needs its tool, actions, time and energy; cleared things stay cleared after a reload; dug trail has trail speed and counts for the marker |
| Signs | A sign can be crafted, put up, read, shown on the map, taken down and put up again |
| Sites | Each step completes only on its condition; reach needs unbroken trail; the site can be opened only when steps are done; opening survives a reload |
| Tower | Repair works; bed, stove, radio and tower survey each work; collapse wakes in the nearest repaired shelter |
| Rumors | Each note adds its circles; circles vanish when mapped |
| Hidden things | Each can be found and works (separate file) |
| Forage | Spots differ between seeds and are the same for one seed; seasons and regrowth hold |
| Crafting | Each recipe needs its inputs; the magic slot changes exactly what its row says |
| Skills | Each action gives its XP; levels and specialties apply their boosts |
| Performance | 60 frames per second walking the trails of rings one and two |

### Play checklist

- [ ] Find a note, and set out for a place you have only heard of.
- [ ] Cross new forest with no trail and feel how big it is. Get lost once.
- [ ] Find the tower, sleep there, and survey from the top.
- [ ] Clear and dig your way so the tower joins the trail, and feel your trail get faster to walk.
- [ ] Put up a sign, then open the tower.
- [ ] (2b) Forage, cook a meal at camp, and craft a magic-slot item from something you found.
- [ ] (2b) Choose a specialty and notice the difference.
- [ ] Stumble on at least one thing you didn't expect.
- [ ] Write down every number that felt wrong.

## Designer's answers (15 November 2026)

1. **Split phase two into 2a and 2b:** yes, as drafted.
2. **Camera and binoculars:** they wait for phase five.
3. **Phase two's site:** the fire tower. The old cabin stays a shelter.
4. **Waking after a backcountry collapse:** the nearest repaired shelter (station, cabin or fire tower), never a camp.
5. **Supplies:** the station shelf stays free until money exists in phase three.
6. **Art for hidden things:** mixed into ordinary art batches under plain names, with stand-ins until then.
7. **The repository stays public.** The lab's spoiler notes stay out of git. The hidden things' content rows are in the repository and can be found by anyone who looks.
8. **Phase one is signed off** with the changes made after play. Its lessons are in the open questions list, and the rest of the phase-one checklist is played alongside 2a.
