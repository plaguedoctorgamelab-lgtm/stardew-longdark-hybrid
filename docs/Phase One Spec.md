# Strange Ranger: Phase One Build Spec

Phase one builds the bedrock: one ranger, a clock, weather, energy and warmth, a cabin to repair and sleep in, and a map that fills in as you explore. This is the document the lab builds from.

## Goal and scope

Phase one must prove one thing: that walking out into a big, weather-ruled wilderness and coming home again feels good, with nothing else in the game to lean on.

The scene that proves it: the ranger leaves the station in the morning, follows a trail into the forest, is caught by a change in the weather, reaches a run-down cabin, repairs it, warms up, sleeps there, and walks home the next day with a map that has begun to fill in.

**In phase one:**

- One ranger, walking in four directions, with a fixed appearance.
- A clock, a calendar of four seasons, and day and night lighting.
- Weather that changes, affects the ranger, and is partly forecast by a radio.
- Energy and warmth, with collapse and rescue.
- A backpack with a handful of items: food, repair materials and tools.
- The ranger station, with a bed and a radio.
- One backcountry cabin that is repaired in steps, then used to rest, warm up, sleep and save.
- One scenic outlook.
- The map: trace, survey, location mapping, outlook survey, and the position marker rules.
- A small test area, built so the world can grow to full size later.
- Saving and loading.
- Debug tools.

**Not in phase one:** visitors, money, the town, townsfolk, creatures, animals, magic, crafting, skills, badges, trail building, signs, fire towers, pets, character creation, decorating, the Chief, mysteries, music, and final art. Anything on this list waits for its phase even if it would be easy to add.

## Technical standards

These decisions are fixed for the whole project, so the lab does not make them case by case.

| Matter | Standard |
| --- | --- |
| Engine | Godot 4.6 or a newer stable 4.x release ([release list](https://godotengine.org/blog/release)). The lab records the exact version it installs and does not change it during a phase. |
| Language | GDScript with static typing throughout |
| Screen | The game draws at 480 by 270 and is scaled up by whole numbers only: 4 times on a 1920 by 1080 screen. This shows about 30 tiles across, as Stardew does. |
| Pixels | Nearest-neighbor filtering everywhere. No smoothing. Sprites sit on whole pixels. |
| Sizes | Tiles 16 by 16. Ranger 16 by 32. |
| Controls | Keyboard and mouse. Every control goes through Godot's input map by action name, so a controller can be added later without rework. |
| Default keys | W A S D to move, right-click or X to interact, left-click or C to use the held item, E or Escape for the backpack, M for the map, number keys for the item bar |
| Tests | Automated tests that run with no window, from one command, and exit with pass or fail |
| Python | Used only for tools outside the game: art cleanup, map baking and data checks |

**Repository layout.** The Godot project file sits at the top of the repository.

```text
project.godot
scenes/            Godot scenes
scripts/           GDScript, grouped by system
art/raw/           images exactly as downloaded; never edited
art/placeholder/   stand-in images made by the lab
art/final/         cleaned, sliced art made by the cleanup tool
data/content/      content tables
data/tuning/       tuning values
data/world/        baked map chunks
tests/             automated tests
tools/             Python tools (hidden from Godot)
docs/              bible, roadmap, specs, rules, art guide (hidden from Godot)
```

**Naming.** Files and folders use lowercase words joined by underscores. Every content row has a permanent id in the same form, such as `tin_of_beans`. Ids never change once used in a save.

**Structure rules.**

- Each system (clock, weather, needs, map, saving, content, tuning) is its own module with one clear job.
- Systems talk to each other through signals, not by reaching into each other.
- No number that affects play is written in code. It lives in the tuning file.
- No item, place or piece of text is written in code. It lives in content data.
- All text shown to the player comes from one text table, so it can be edited and translated later.

## Content data and save files

The game has a content database, kept as one plain text table per kind of thing, and loaded into memory when the game starts.

**Why text tables.** Text files show their changes clearly in git, need no add-on, and can be checked by a Python tool. The game reaches content only through one content module with lookup functions. If the data ever outgrows text files, it can move to SQLite behind that same module with no change to the rest of the game. The designer has confirmed this choice.

**Format.** One JSON file per table in `data/content/`. Every row has a unique `id`. Rows refer to each other by id.

**Phase one tables:**

| Table | Holds | Phase one rows |
| --- | --- | --- |
| `items` | Everything that fits in the backpack: name, kind, stack size, icon | Food, firewood, planks, nails, roofing, window glass, map, compass, pencil, hammer, lantern |
| `foods` | Energy and warmth restored by each food item | Tin of beans, apple, sandwich, hot soup |
| `weather_types` | Each kind of weather: light, visibility, warmth effect, walking effect | Clear, overcast, rain, fog, storm, snow, blizzard |
| `weather_odds` | How likely each weather is in each season | Four seasons |
| `structures` | Buildings: kind, repair steps and what each step needs | Ranger station, the test cabin |
| `landmarks` | Mappable places: name, kind, reveal size | The cabin, the outlook |
| `text` | Every line shown to the player | All phase one text |

**Data checks.** A Python tool confirms that every table loads, every id is unique, and every reference points at a real row. It runs with the tests.

**Save files.** Saves are separate from content. Each save slot is one JSON file in the player's data folder, with a version number. A save holds:

- The date, time and season.
- Today's weather and tomorrow's.
- The ranger's position, energy, warmth and backpack.
- Each structure's repair progress and stored items.
- The map: what is traced, surveyed and mapped.
- The save's random seed.

**Saving happens only on sleeping**, as in Stardew. Loading an older save version must either work or fail with a clear message, never corrupt.

## Systems: time, movement and the world

These three systems are the ground everything else stands on. All numbers below are starting values held in the tuning file.

### Time and calendar

- A day runs from 6:00 in the morning to 2:00 the next morning.
- Ten game minutes pass every 7 real seconds, so a full day is 14 real minutes.
- The clock shows time in ten-minute steps and stops while a menu is open.
- A year is four seasons of 28 days: spring, summer, autumn, winter. The game starts on spring 1 of year 1.
- Other systems learn of each new ten minutes, hour, day and season through signals.

### Day and night light

- The whole screen is tinted according to the time of day: warm at sunrise and sunset, plain at midday, deep blue at night.
- Sunrise and sunset times shift with the season. Summer days are long and winter days short.
- Weather adds its own tint and dimming on top.
- Outdoors at night the screen is dark enough that the trail is hard to follow. Holding a lit lantern clears a circle of light around the ranger. Indoors is always lit.

### Movement

- The ranger moves in eight directions and faces one of four, as in Stardew.
- Walking speed depends on the ground: fastest on trail, slower on grass and forest floor, slowest in tall grass and shallows. Deep water and rock walls block the way.
- Bad weather slows walking further.
- Trees, boulders, buildings and fallen trunks are solid.
- The camera follows the ranger and stops at the edge of the world.
- Buildings are entered through their door, which loads a separate small interior, as in Stardew.

### The world

- The outdoor world is one continuous area divided into chunks of 32 by 32 tiles. Only chunks near the ranger are loaded. The test area is small, but this must work for a world hundreds of chunks wide.
- The land is never made while the game runs. A Python tool bakes it once from a layout file and a fixed seed, and the baked chunks are stored in the repository. Baking twice gives the same result.
- Hand-placed things, such as the station, cabin, outlook and trail, are listed in the layout file and always win over generated terrain.
- The edges between ground types are made by the lab from the plain ground tiles.
- What varies per save is drawn from the save's own seed. In phase one that is only the supplies found in the cabin.

## Systems: energy, warmth, weather and collapse

These systems make the weather matter. All numbers are starting values in the tuning file.

### Energy

- Energy runs from 0 to 270.
- Walking outdoors costs a little each ten minutes. Rough ground and bad weather cost more.
- Each repair action and each survey costs a set amount.
- Eating restores energy by the amount in the food table. Sleeping in a bed restores it fully.
- Below 20, the ranger is exhausted and walks slowly. At 0, the ranger collapses.

### Warmth

- Warmth runs from 0 to 100.
- Every ten minutes outdoors, warmth changes by the sum of three things: the weather, the season, and whether it is night.
- Mild, clear daytime weather lets warmth recover slowly. Rain, wind, snow and night drain it. A blizzard drains it fast.
- Phase one has no clothing system. One tuning value stands in for the ranger's clothes.
- Inside the station or the repaired cabin, warmth rises. With the cabin's stove lit it rises quickly. The stove burns firewood from the backpack and stays lit for a few hours.
- Hot food gives a small boost.
- Below 25, the ranger is chilled and energy drains twice as fast. At 0, the ranger collapses.

### Weather

- Each day is divided into three blocks: morning, afternoon, and evening into night. Each block has one kind of weather, chosen from the season's odds, with a leaning toward staying the same as the block before.
- The seven kinds are clear, overcast, rain, fog, storm, snow and blizzard. Snow and blizzard occur in winter and rarely in late autumn and early spring.
- Each kind sets five things: the screen tint, how far the ranger can see, the change in warmth, the walking speed, and whether surveying is possible.
- Fog and blizzard shrink the visible area to a small circle around the ranger.
- **Signs before a change.** For the hour before the weather turns, the light shifts and wind streaks cross the screen, so a watchful player gets warning.
- **The radio.** Using the station radio gives the forecast for today's three blocks and a one-line outlook for tomorrow. Each forecast block is right about 85% of the time. The radio works only at the station in phase one.
- Rain, snow and fog are drawn by the game as moving effects, not as art.

### Collapse and rescue

- The ranger collapses when energy or warmth reaches 0, or when the clock reaches 2:00.
- The screen fades. The ranger wakes at 10:00 the next morning in the station bed, or in the repaired cabin if that is nearer.
- They wake with half energy and full warmth, and a short message says who found them.
- The game saves on waking. Nothing else is lost in phase one. A money cost is added when money exists.

## Systems: backpack, cabin, sleeping and the map

These are the things the ranger does. All numbers are starting values in the tuning file.

### Backpack and supplies

- The backpack has 12 slots, all shown as an item bar along the bottom of the screen. Like items stack.
- The ranger starts with a hammer, lantern, map, compass and pencil.
- A supply shelf in the station restocks every morning with food, firewood, planks, nails, roofing and window glass. Supplies are free and plentiful in phase one.
- The station and the repaired cabin each have a storage chest of 12 slots.
- Packing is a small puzzle on purpose. Five tools, the cabin's repair materials, food and firewood only just fit.

### The cabin

The cabin starts run-down and cannot be entered. It is repaired in four steps, in any order.

| Step | Materials |
| --- | --- |
| Door | 2 planks, 4 nails |
| Walls | 4 planks, 8 nails |
| Roof | 4 roofing, 8 nails |
| Window | 1 window glass, 2 planks |

- Each step needs the hammer and its materials in the backpack, and takes three hammer actions. Each action takes 20 game minutes and costs energy.
- Progress is kept between visits, so the job can be spread over several trips.
- When all four steps are done, the cabin's picture changes to its repaired form and the door opens.
- Inside are a bed, a wood stove and a storage chest.

### Sleeping and saving

- Using a bed in the station or the repaired cabin asks for confirmation, then ends the day.
- The ranger wakes at 6:00 the next morning with full energy and warmth, and the game saves.
- This is the only way to save, apart from a collapse.

### The map

The M key opens the map: a blank sheet covering the test area that fills in four ways.

| Action | How | Reveals |
| --- | --- | --- |
| Trace | Automatic while walking | A thin dotted line along the ranger's path |
| Survey | Use the map with compass and pencil in the backpack. Stand still for 30 game minutes. | The ground within 12 tiles |
| Map a location | Interact with a newly found landmark. Takes 20 game minutes. | The landmark, its name and the ground within 8 tiles |
| Outlook survey | Survey while standing on the outlook | The ground within 40 tiles |

- Surveying works only in daylight, in clear or overcast weather. Moving cancels it.
- Mapping a location works in any conditions.
- The map shows what share of the area has been revealed. The 80% completion rule is not active in phase one.

**The position marker.** The ranger's marker is shown on the map only when all three of these are true:

1. The ranger is standing on revealed ground. A trace alone does not count.
2. The weather is not fog, storm or blizzard.
3. It is daytime, or the ranger is on a trail.

When the marker is hidden, the map says the ranger is not sure where they are. The trace walked while lost is recorded but is only drawn once the marker returns, so the trace cannot be used to cheat.

### On-screen display

The screen shows the date, the time, a weather symbol, an energy bar, a warmth bar and the item bar. The lab draws these plainly for now.

## The test map

Phase one uses a small test area of about 384 by 256 tiles (12 by 8 chunks), laid out so the cabin is too far for a comfortable day trip. It is a proving ground, not the final forest.

**Layout, from southwest to northeast:**

1. **The entrance clearing**, in the southwest corner. A park gate stands at the map's edge with nothing beyond it yet. The ranger station sits in open grass. The trail begins at its door.
2. **The meadow.** The trail winds east through grass and patches of tall grass, with scattered bushes and boulders.
3. **The forest edge.** About a quarter of the way across, the trees begin. From here the ground is forest floor and the trees are dense enough to hide what is ahead.
4. **The stream.** A stream crosses the map from north to south. The trail meets it at a shallow ford that slows the ranger. North of the ford it widens into a deep pool that cannot be crossed.
5. **The fork.** Just past the ford, beside a dead tree that serves as a landmark, the trail splits.
6. **The outlook.** The north branch climbs a rocky rise to the scenic outlook.
7. **The cabin.** The east branch runs on through thick forest to a small clearing in the far northeast, where the run-down cabin stands.
8. **The shortcut.** Between the outlook and the cabin there is no trail, only thick forest with a few fallen trunks to steer by. It is shorter and easy to get lost in.

The map's edges are closed off by rock and trees too dense to pass.

**Walking times.** The lab adjusts the trail's length and bends, and the map's size if needed, to meet these times at trail speed in clear weather:

| From the station to | Game time | Real time |
| --- | --- | --- |
| The forest edge | 1 hour | 42 seconds |
| The fork | 2 hours 30 minutes | 1 minute 45 seconds |
| The outlook | 3 hours 30 minutes | 2 minutes 27 seconds |
| The cabin | 4 hours | 2 minutes 48 seconds |

With four hours each way and four hours of repair work, doing everything in one day is possible but tight, and bad weather or failing light will often make sleeping at the cabin the better choice. That choice is what phase one is testing.

## Tuning values

Every number that shapes the feel of play lives in one file, `data/tuning/tuning.json`, and can be reloaded while the game runs. These are starting guesses, meant to be changed after playing.

| Group | Value | Start |
| --- | --- | --- |
| Time | Real seconds per ten game minutes | 7 |
| Time | Day starts / day ends | 6:00 / 2:00 |
| Time | Days per season | 28 |
| Light | Sunrise / sunset, spring | 6:30 / 19:00 |
| Light | Sunrise / sunset, summer | 5:30 / 20:30 |
| Light | Sunrise / sunset, autumn | 6:30 / 18:30 |
| Light | Sunrise / sunset, winter | 7:30 / 17:00 |
| Light | Length of dawn and dusk | 60 game minutes |
| Light | Lantern light radius | 5 tiles |
| Movement | Speed on trail | 4.5 tiles per second |
| Movement | Speed on grass / forest floor / tall grass / shallows | 90% / 80% / 65% / 50% of trail speed |
| Movement | Speed in rain / storm / snow / blizzard | 95% / 85% / 85% / 60% |
| Movement | Speed when exhausted | 60% |
| Energy | Maximum | 270 |
| Energy | Walking, per ten minutes outdoors | 1 |
| Energy | Extra cost on tall grass or shallows, and in storm, snow or blizzard | 1.5 times each |
| Energy | Repair action / survey / mapping a location | 8 / 4 / 2 |
| Energy | Exhausted below | 20 |
| Energy | Restored by beans / apple / sandwich / hot soup | 60 / 25 / 50 / 70 |
| Energy | Energy on waking after a collapse | 50% |
| Warmth | Maximum | 100 |
| Warmth | Per ten minutes: clear / overcast / fog / rain / snow / storm / blizzard | +2 / 0 / -1 / -2 / -3 / -4 / -7 |
| Warmth | Per ten minutes: spring / summer / autumn / winter | -1 / +1 / -1 / -3 |
| Warmth | Per ten minutes at night | -2 |
| Warmth | Per ten minutes from clothing (stand-in) | +1 |
| Warmth | Per ten minutes indoors / indoors with stove lit | +10 / +25 |
| Warmth | Stove burn time per firewood | 3 game hours |
| Warmth | Boost from hot soup | +15 |
| Warmth | Chilled below, and its effect | 25; energy drains 2 times as fast |
| Weather | Chance a block keeps the last block's weather | 50% |
| Weather | Forecast accuracy per block | 85% |
| Weather | Warning before a change | 60 game minutes |
| Weather | Visible radius in fog / blizzard | 6 tiles / 4 tiles |
| Map | Survey radius / time | 12 tiles / 30 game minutes |
| Map | Location radius / time | 8 tiles / 20 game minutes |
| Map | Outlook survey radius | 40 tiles |
| Repair | Actions per step / time per action | 3 / 20 game minutes |
| Storage | Backpack slots / chest slots | 12 / 12 |
| World | Chunk size | 32 by 32 tiles |

**Weather odds per block, by season.** These live in the `weather_odds` content table.

| Season | Clear | Overcast | Rain | Fog | Storm | Snow | Blizzard |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Spring | 40% | 25% | 20% | 10% | 5% | 0% | 0% |
| Summer | 55% | 20% | 10% | 5% | 10% | 0% | 0% |
| Autumn | 30% | 30% | 20% | 15% | 5% | 0% | 0% |
| Winter | 25% | 25% | 0% | 5% | 0% | 30% | 15% |

In the last week of autumn and the first week of spring, half of all rain falls as snow.

As a check on these numbers: the round trip to the cabin costs about 48 energy and the full repair 96, which leaves room to spare from 270. A winter blizzard drains full warmth in under two game hours, which is about 77 real seconds.

## Debug tools and placeholder art

The designer must be able to test any moment of the game in seconds, and the game must be fully playable before any real art exists.

### Debug panel

Pressing F1 opens a panel, available in test builds only. It can:

- Set the time, or skip to the next weather block, day or season.
- Run the clock at 10 times speed.
- Force any weather now, and set the next block's weather.
- Set energy and warmth to any value, and switch their drain off.
- Move the ranger to the station, fork, outlook or cabin.
- Add any item to the backpack.
- Complete or undo any cabin repair step.
- Reveal or wipe the map.
- Reload the tuning file without restarting.
- Show the ranger's tile position, the current chunk and the chunk borders.

Every debug action is also callable from the automated tests.

### Placeholder art

- The lab makes a plain stand-in image for every picture the game needs: flat palette colors, correct size, simple shapes.
- Stand-ins live in `art/placeholder/`. Finished art lives in `art/final/` under the same file names.
- When loading a picture, the game uses the finished version if it exists and the stand-in if not. Dropping in real art needs no change to code or data.

### Art cleanup tool

A Python tool turns the designer's raw images into finished art. It never alters anything in `art/raw/`.

1. Read each raw image and its entry in the art manifest, which gives its grid layout and the target size of each item. The manifest follows the file table in the art style guide.
2. Remove the background if it is not already transparent.
3. Shrink each cell to its target size in game pixels, taking the most common color in each block so edges stay hard.
4. Snap every color to the nearest palette color.
5. Cut the sheet into separate named images and save them to `art/final/`.
6. Write a short report listing each image, whether it passed, and why any failed, such as an item crossing its cell or the wrong number of items.

The report goes in the lab's status email, so the designer knows which images to redo.

## Build order and acceptance tests

Phase one is built in nine small steps, each ending with passing tests and a status email, and it is done when every test below passes and the designer has played the checklist.

### Build order

1. **Foundations.** The project, folder layout, test runner, tuning file, content tables, data checks and placeholder images.
2. **World and movement.** The baking tool, the test map, chunk loading, the ranger walking with ground speeds and collisions, the camera, and the debug panel's first tools.
3. **Time and light.** Clock, calendar, seasons, day and night tint, the lantern, and the clock display.
4. **Weather.** Blocks, odds, effects on light, sight and speed, warning signs, and the radio forecast.
5. **Energy and warmth.** Both needs, their bars, food, exhaustion, chill, collapse and rescue.
6. **Backpack and buildings.** Items, the item bar, the supply shelf, chests, interiors, cabin repair, the stove, sleeping and saving.
7. **The map.** Trace, survey, location mapping, the outlook, the map screen and the position marker rules.
8. **Art cleanup tool.** Run against whatever raw images exist by then.
9. **Full pass.** All tests, a complete played run, and a final report.

The debug panel grows with each step, so every new system can be tested the day it is built.

### Automated tests

The lab writes and runs tests proving each of these:

| Area | Must be true |
| --- | --- |
| Data | Every content table and the tuning file load; ids are unique; references resolve |
| Time | A day lasts 120 ten-minute steps; day 28 of winter is followed by spring 1 of the next year |
| Movement | Speed on each ground type matches tuning; solid objects and map edges block |
| World | Baking twice gives identical chunks; chunks load and unload as the ranger moves; walking times to the four landmarks are within 10% of target |
| Weather | Over 10,000 simulated blocks per season, each weather's share is within 3 points of its odds; winter has no rain or storm; forecasts are right 85% of the time, within 3 points |
| Warmth | Each weather, season and night value changes warmth as tuned; indoors and stove values apply; chill doubles energy drain |
| Energy | Each action costs its tuned amount; each food restores its amount; exhaustion slows walking |
| Collapse | Zero energy, zero warmth and 2:00 each cause a collapse; the ranger wakes at 10:00 in the nearer valid bed with half energy; the game saves |
| Backpack | Stacking and slot limits hold; the shelf restocks each morning |
| Cabin | Each step needs its materials and the hammer; progress persists; the cabin opens only after all four steps |
| Sleep and save | Sleeping advances to 6:00 and saves; loading restores every saved value exactly |
| Map | Each of the four actions reveals its tuned area; survey is refused at night and in fog, rain, storm, snow and blizzard; the marker shows only under its three conditions; the hidden trace appears when the marker returns |
| Tuning | Changing a value in the file and reloading changes behavior without a restart |
| Performance | The game holds 60 frames per second while walking across the whole map |

### Play checklist

The designer plays these and ticks them off. They test feel, which no automated test can.

- [ ] Start a new game, hear the forecast, pack the backpack, and walk to the cabin by the trail.
- [ ] Feel that the cabin is properly far away, and that the meadow, forest and ford each feel different underfoot.
- [ ] Be caught by a change in the weather, having noticed the warning signs or missed them.
- [ ] Repair the cabin over one or two trips, light the stove, warm up and sleep there.
- [ ] Walk home at dusk with a lantern and feel the dark close in.
- [ ] Survey from the outlook and enjoy watching the map fill in.
- [ ] Take the shortcut in fog, lose the marker, and find the way out or be rescued.
- [ ] Force a winter blizzard at the station door and decide to stay in.
- [ ] Collapse on purpose and judge whether the rescue feels gentle.
- [ ] Quit, reload, and find everything as it was left.
- [ ] Write down every number that felt wrong, for the tuning list.
