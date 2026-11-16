# Strange Ranger: Phase 2b Build Spec

Phase 2b lets the ranger make things from what the forest provides, improve tools with found magic, and get better at the work by doing it. It was written before the designer's play test of phase 2a and should be revised against that play test before the lab starts.

## Goal and scope

Phase 2b must prove the bible's rule that exploring is the upgrade path: that the best things the ranger owns are made from what they found, not handed out.

The scene that proves it: on a walk, the ranger gathers berries and reeds, and one night spots something glowing on the forest floor. Back at a workbench, an idea appears beside the lantern recipe. They refit the lantern with what they found, and the next night it shows them something they had walked past a dozen times.

**In phase 2b:**

- Foraging: ordinary things to gather that change with season, weather and time of day.
- Three magical ingredients, each rare and each found only under its own conditions.
- Crafting, in two tiers: simple things made anywhere, and proper work at a workbench.
- Cooking at a lit stove or campfire.
- The magic slot: an optional ingredient that changes what a recipe makes.
- Three refitted tools that each change how the game is played.
- A larger backpack, made, not bought.
- Four skills that rise by doing: Trailcraft, Surveying, Woodcraft and Foraging.
- A specialty choice at level 5 in each skill.

**Not in phase 2b:** money, selling, goods for the gift shop, clothing, visitors, the town, creatures, the Lore skill, badges, level 10 specialties. Gift shop goods and clothing arrive with money and the outfitter in phases 3 and 4.

**Carried over.** Everything in the phase 2a spec's "What carries over" section still holds, above all the secrecy rules: the lab does not tell the designer where anything is.

## Foraging

The forest now offers things to pick up, and what it offers depends on the season, the weather and the hour, so the same walk is different in May and October.

**How it works.**

- Forage appears as small objects in the world and is picked up by interacting. It goes into the backpack and stacks.
- A casual walk should fill two or three backpack slots without any searching. Nobody should need to grind.
- Each morning new forage appears. What is not picked lasts three days.
- Where forage can appear is fixed when the land is baked. Which of those spots are active is drawn from the save's own seed each season, so spots shift between saves, as the bible asks.
- Forage is tracked for the whole built world, not only the chunks near the ranger.

**Ordinary forage:**

| Item | Found | When |
| --- | --- | --- |
| Sticks | Forest floor; also from clearing brush | All year, fewer in winter |
| Stones | Rocky ground and stream banks | All year |
| Reeds | Shallows at the water's edge | Spring to autumn |
| Pine resin | From a pine, by interacting; each tree gives once a week | All year |
| Wild onions | Meadow and open grass | Spring |
| Fiddleheads | Forest floor near water | Spring |
| Wildflowers | Meadow and open ground | Spring and summer |
| Berries | Berry bushes; a bush fruits again after four days | Summer and early autumn |
| Hazelnuts | The forest's edge | Autumn |
| Mushrooms | Forest floor | Autumn, and any day after rain |
| Rose hips | Bare bushes | Winter |

**Magical ingredients.** There are three. Each is rare, each appears only under its own conditions, and none is ever sold.

| Ingredient | What it is | How it is found |
| --- | --- | --- |
| Glowcap | A small violet mushroom that gives off light | Seen and picked only at night. Regrows after a week. |
| Ember moss | An orange moss on dead wood, warm to the touch | Appears only in weather cold enough to snow |
| Lodestone sliver | A splinter of dark stone that pulls at iron | Buried in rocky ground. The compass needle trembles when the ranger carries it nearby; the shovel digs it up. Does not come back. |

- Each has about ten possible places in the built world, of which a save uses five. The lab chooses the places to suit the region plan and records them in `docs/spoilers/`, not in anything the designer reads.
- The first time each is picked up, it is logged in the notebook as a find, and it gives the ranger an idea, as described under Crafting.

## Crafting

Crafting follows Stardew's lead, a page of known recipes that shows what each needs, with one addition of its own: the magic slot.

**Where things are made.**

| Place | What can be made there |
| --- | --- |
| Anywhere | Simple things, from a Crafting page in the backpack screen |
| A workbench | Everything, including building materials and tool refits |
| A lit stove or campfire | Cooked food |

- The station has a workbench from the start.
- A workbench kit can be made and set up inside any repaired cabin or tower, so the ranger can work wood far from home.
- At a workbench or stove, items in that building's chest count as well as those in the backpack.
- Making anything takes 10 game minutes and no energy.

**How recipes are learned.** A recipe the ranger has not learned is not shown at all.

- A small set is known from the start.
- Others come with skill levels.
- Others come as **ideas**: picking up a certain thing for the first time teaches what might be done with it. The game says so in one line, such as "These reeds would twist into rope."

**The magic slot.**

- Any recipe can accept one optional magical ingredient that turns its result into a named variant with a different ability.
- The slot is invisible until the ranger has the idea for it. Picking up a magical ingredient for the first time gives the idea, and from then an empty slot marked with a question mark shows on every recipe that can take that ingredient.
- The game never says what the variant will do. The ranger makes it and finds out.
- A **refit** is a recipe that takes a tool the ranger already owns plus a magical ingredient, and returns the changed tool. The ingredient is used up.
- A tool holds one magic at a time. Refitting it again replaces the old one.
- Which recipes accept which ingredients, and what results, is content data. Phase 2b ships three combinations. Later regions add more without new code.

## The recipes

Phase 2b has seventeen recipes: enough to make foraging worthwhile and the backcountry more self-sufficient, and few enough to learn by heart. All amounts are starting values in content data.

### Made anywhere

| Recipe | Needs | Gives | Learned |
| --- | --- | --- | --- |
| Cairn | 3 stones | A small stone marker to set on the ground. It shows on the map once that ground is revealed, so the ranger can mark their own routes. | From the start |
| Blank sign | 2 planks, 1 nail | 1 blank sign | From the start |
| Rope | 3 reeds | 1 rope | Idea, from the first reeds |
| Trail mix | 2 berries, 2 hazelnuts | Food: 45 energy | Idea, from the first hazelnuts |

### Made at a workbench

| Recipe | Needs | Gives | Learned |
| --- | --- | --- | --- |
| Planks | 2 firewood, with the saw | 1 plank | From the start |
| Roofing | 2 firewood, with the axe | 1 roofing | Woodcraft 2 |
| Workbench kit | 4 planks, 8 nails | A workbench to set up in a repaired building | Woodcraft 3 |
| Boardwalk | 2 planks, 2 nails | One tile of boardwalk. Laid on boggy ground or shallows, it counts as trail. | Trailcraft 3 |
| Pack frame | 4 sticks, 2 rope, 1 pine resin | The backpack grows from 12 slots to 18. Made once. | Idea, from the first rope |

Nails, window glass and the radio valve still come only from the supply shelf.

### Cooked at a fire

| Recipe | Needs | Gives | Learned |
| --- | --- | --- | --- |
| Hot soup | 2 mushrooms, 1 wild onion | 70 energy, 15 warmth | Idea, from the first mushrooms |
| Fiddlehead fry | 2 fiddleheads, 1 wild onion | 55 energy | Idea, from the first fiddleheads |
| Berry preserve | 3 berries | 40 energy | Foraging 2 |
| Roast hazelnuts | 3 hazelnuts | 30 energy, 5 warmth | Foraging 3 |
| Rose hip tea | 2 rose hips | 10 energy, 25 warmth | Idea, from the first rose hips |

Berries, hazelnuts, mushrooms, wild onions, fiddleheads and rose hips can also be eaten raw for 5 to 10 energy each. Wildflowers have no use yet; they are kept for gifts in phase 4.

### Refits, at a workbench

These are the three magic slot combinations. Each changes how the game is played, and each is found by trying it.

| Refit | Needs | What changes |
| --- | --- | --- |
| Glowcap lantern | The lantern, 1 glowcap | Its light reaches 8 tiles in place of 5. Any find not yet logged gives off a faint sparkle while inside that light. |
| Ember bedroll | The bedroll, 1 ember moss | Camp can be made without firewood and stays warm with no fire. Sleeping at camp restores 90% in place of 75%. |
| True compass | The compass, 1 lodestone sliver | The position marker stays on the map at night and in fog, even off the trail. Storms and blizzards still hide it. |

A cabin or tower still beats a camp with an ember bedroll: full recovery, storage, a stove and a radio.

## Skills

Four skills rise as the ranger does the work, in Stardew's manner: ten levels, experience earned by doing, level-ups announced on waking, and a choice of specialty at level 5.

**The basics.**

- Each skill has levels 0 to 10. Levels need 100, 380, 770, 1,300, 2,150, 3,300, 4,800, 6,900, 10,000 and 15,000 experience, as in Stardew.
- Every level makes that skill's actions cost 3% less energy.
- Some levels also give a perk or a recipe, listed below.
- A new Skills page in the menu shows each skill's level and progress.
- Level-ups are told on waking, one line each. A level 5 wake-up offers the specialty choice.
- Levels 6 to 9 give the energy saving only. Level 10 specialties come in a later phase.

**What earns experience:**

| Skill | Earned by | Experience |
| --- | --- | --- |
| Trailcraft | Clearing or digging a trail tile / laying boardwalk / clearing brush or a stump / each chop at a fallen trunk / setting a sign | 2 / 4 / 5 / 4 / 10 |
| Surveying | A survey / a survey from an outlook or tower / mapping a location | 40 / 100 / 150 |
| Woodcraft | A repair action / each chop at a standing tree / making something at a workbench / cooking / making camp | 8 / 6 / 10 / 6 / 10 |
| Foraging | Picking ordinary forage / picking a magical ingredient | 5 / 50 |

**Perks by level:**

| Level | Trailcraft | Surveying | Woodcraft | Foraging |
| --- | --- | --- | --- | --- |
| 2 | Each dig lays two tiles in a row | Surveys take 20 minutes, not 30 | Roofing recipe | Berry preserve recipe |
| 3 | Boardwalk recipe | Survey radius +2 tiles | Workbench kit recipe | Roast hazelnuts recipe |
| 4 | Clearing brush takes no time | Surveys work at dawn and dusk | Fires burn 4 hours per firewood, not 3 | 10% chance of a double pick |
| 5 | Specialty | Specialty | Specialty | Specialty |

**Specialties.** At level 5 the ranger picks one of two. The choice is permanent for now.

| Skill | First choice | Second choice |
| --- | --- | --- |
| Trailcraft | **Trail builder.** Each dig lays three tiles and costs half the energy. | **Sawyer.** Fallen trunks fall to one chop, and all chopping gives double firewood. |
| Surveying | **Cartographer.** Survey radius is half as large again, and surveys work in rain. | **Wayfinder.** The ranger walks 15% faster off the trail and is no longer slowed by tall grass. |
| Woodcraft | **Carpenter.** Repair steps take two actions, not three, and use a quarter fewer planks. | **Camp hand.** Camp restores 10 points more, and cooked food gives a quarter more. |
| Foraging | **Gatherer.** A 25% chance of a double pick, and berry bushes fruit again in two days. | **Seeker.** The ranger senses a magical ingredient within 10 tiles, and they come back twice as fast. |

**Fairness to existing saves.** Experience is not awarded for work done before this phase. Everyone starts at level 0.

## New data and tuning values

Every forage item, recipe, idea, perk and specialty is a row of content data, so later regions add their own without new code.

**New content tables:**

| Table | Holds |
| --- | --- |
| `forage` | Each forage item: the ground it grows on, its seasons, any weather or time-of-day limits, how often it appears, how long it lasts |
| `recipes` | Each recipe: where it is made, what it needs, any tool required, what it gives, how it is learned |
| `magic_variants` | Each magic slot combination: the recipe, the ingredient, the result and what the result changes |
| `ideas` | Each idea: the item that triggers it, the recipes or slot it reveals, its one line of text |
| `skills` | Each skill: what earns experience, the perk at each level |
| `specialties` | Each specialty: its skill, its name, what it changes |

The `items`, `foods` and `text` tables gain rows for everything new.

**New tuning values:**

| Group | Value | Start |
| --- | --- | --- |
| Forage | Days uncollected forage lasts | 3 |
| Forage | Target yield of a casual hour's walk | 2 to 3 backpack slots |
| Forage | Days for a berry bush to fruit again | 4 |
| Forage | Days between resin from one pine | 7 |
| Forage | Energy from raw forage | 5 to 10 each |
| Magic | Possible places per ingredient / places used per save | 10 / 5 |
| Magic | Days for glowcap to regrow | 7 |
| Magic | Distance at which the compass trembles near a lodestone sliver | 10 tiles |
| Crafting | Time to make anything | 10 game minutes |
| Crafting | Backpack slots with the pack frame | 18 |
| Refits | Glowcap lantern light radius | 8 tiles |
| Refits | Ember bedroll camp recovery | 90% |
| Skills | Energy saved per level | 3% |
| Skills | Experience needed per level | As listed under Skills |
| Skills | Experience per action | As listed under Skills |

Recipe amounts, food values, perk sizes and specialty sizes sit in their content tables, not in the tuning file, because they belong to individual rows.

## Build order, art and tests

Phase 2b is built in seven steps, each ending with passing tests and a spoiler-free status email, and it is done when every test passes and the designer has played the checklist.

### Build order

1. **Foraging.** The forage table, daily appearance across the whole built world, per-save spots, picking up, and raw food.
2. **Crafting anywhere.** The Crafting page, known recipes, ideas, and the four simple recipes, including placing cairns.
3. **Workbench and cooking.** The station workbench, the workbench kit, chest items counting, the workbench recipes, boardwalk, the pack frame, and cooking at fires.
4. **Magical ingredients.** The three ingredients, their conditions and places, and their notebook entries.
5. **The magic slot and refits.** The hidden slot, the three refits and their effects.
6. **Skills.** Experience, levels, perks, the Skills page, wake-up messages and specialties.
7. **Full pass.** All tests, a complete played run by the lab, and a final report.

### Art

The lab writes Art Request 03 after step 1 and builds with stand-ins meanwhile. It will need icons for every new item, the forage as it appears in the world, the workbench, the cairn, boardwalk tiles, and the three refitted tools. The glowing violet mushrooms already in the game's art serve as the glowcap.

### Automated tests

| Area | Must be true |
| --- | --- |
| Forage | Each item appears only on its ground, in its seasons and under its limits; uncollected forage expires on time; two saves with different seeds have different active spots; the same seed gives the same spots |
| Yield | A simulated hour's walk on trail in each season yields forage within the tuned range |
| Magical ingredients | Each appears only under its conditions; each save uses the tuned number of places; glowcap regrows; a dug lodestone sliver does not return; the compass trembles only within range |
| Crafting | A recipe is hidden until learned; each recipe consumes and gives exactly what its row says; workbench and fire recipes cannot be made elsewhere; chest items count only in that building |
| Ideas | Each idea fires once, on first pickup, and reveals what its row says |
| Magic slot | The slot is hidden before its idea and shown after; each refit consumes its ingredient and returns the changed tool; a second refit replaces the first |
| Refit effects | The glowcap lantern lights its radius and marks unlogged finds only; the ember bedroll makes camp without firewood and restores its tuned amount; the true compass keeps the marker at night and in fog and loses it in storm and blizzard |
| Placeables | Cairns show on the map only on revealed ground; boardwalk counts as trail for a site's trail step; a workbench kit can be set only inside a repaired building |
| Backpack | The pack frame can be made once and raises the slots to its tuned number; no item is lost when the backpack grows |
| Skills | Each action gives its experience; levels arrive at the listed totals; each level cuts energy by the tuned share; each perk and specialty does what its row says; a specialty is offered once |
| Saves | A phase 2a save loads; all new state saves and loads exactly |
| Secrecy | No status email, commit message or debug screen names where a magical ingredient grows unless "show spoilers" is ticked |

### Play checklist

- [ ] Come home from an ordinary walk with a few things you did not set out to gather.
- [ ] Have an idea, and make the thing it suggested.
- [ ] Cook a meal at a campfire and at a stove.
- [ ] Make planks at a workbench you set up in the cabin or tower, and use them there.
- [ ] Lay boardwalk across wet ground.
- [ ] Make the pack frame and feel the difference on the next trip.
- [ ] Find one magical ingredient without being told where it is.
- [ ] Refit a tool, and work out for yourself what changed.
- [ ] Reach level 2 or 3 in a skill and notice the work getting easier.
- [ ] Judge whether foraging feels like a pleasure of walking or a chore.
- [ ] Judge whether any refit makes the game too easy.
- [ ] Write down what felt wrong, and what you wanted to make and could not.
