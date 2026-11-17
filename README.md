# Strange Ranger

A cozy top-down pixel game about a park ranger in a vast, quietly magical
wilderness. This repository holds phases one, 2a, 2b and 3. See `docs/` for the
game bible, roadmap, phase specs and working rules.

**Current version: 0.4.4** (see [Version history](#version-history)). The
version shows on the title screen and in the debug panel, and V shows it in
play.

## The tracker

A small web page for bugs, feature requests and the latest build, served
from this computer to the home network. Start it with
`tools	racker\start_tracker.bat` (or `python tools/tracker/server.py`) and
open the address it prints from any device on the network, port 8080. Each
entry has a type, priority, status, the version it was found in and the one
it was fixed in. The **Download zip** button gives the latest playtest build,
named with its version from `export/build_info.json`. The list itself is kept
in `tracker_data/items.json`, on this computer only, not in git.

## Running the game

Needs Godot 4.7.2 stable (the lab's build uses
`C:\Godot\Godot_v4.7.2-stable_win64.exe`).

- Open `project.godot` in Godot and press F5, or run
  `C:\Godot\Godot_v4.7.2-stable_win64.exe --path .` from this folder.
- On the title screen choose **New game**. **Continue** loads the save.

| Key | Action |
| --- | --- |
| W A S D | Walk (eight directions) |
| Right-click or X | Interact: doors, bed, radio, shelf, chest, stove, workbench, landmarks; pick forage, berries and rose hips from bushes, resin from pines; a lit stove or camp fire opens cooking. In the park: the catalog desk and staff board in the station, the kiosk's gift shelf and the suggestion box at the gate, cleaning a bathroom, emptying a trash can, picking up litter, shooing a troll badger, finding a lost party, the rent sign by the old cabin's door |
| Left-click or C | Use the held item: hammer (repairs; builds a kit at its pad; takes down a facility or picks up a bench, trash can, picnic table or fire ring), map (survey), food, firewood (also lights a fire ring), shovel (dig; fills a badger's hole), signs, markers, cairns, boardwalk, workbench kit, and puts down a bench, trash can, picnic table or fire ring |
| 1 to 9, 0 or mouse wheel | Choose the held item from the item bar (the first 10 backpack slots, numbered) |
| E | Backpack (and closes screens) |
| Escape | Closes the open screen; with none open, the pause menu (resume, quit to title, quit game) |
| M | Map |
| J | The book: jobs and sites, the park today, the ledger, suggestion cards, the Chief's letters, the notebook |
| K | Crafting page: things made anywhere |
| L | Skills page (and choose a waiting specialty) |
| Y or Enter / N | Answer a question (sleep) |
| V | Show the version number |
| F1 | Debug panel (test builds only) |

The lantern lights the dark while it is the held item. Saving happens only
when you sleep, or after a collapse.

## Running the tests

```
python tools/run_tests.py
```

Runs the data check, the bake check (baking twice gives identical chunks that
match the repository) and every Godot test headless, and exits 0 on pass.
Set `GODOT` or pass `--godot PATH` if Godot is elsewhere.

Two extra checks need a window:

- `godot --path . -s tests/support/perf_window.gd`: walks the whole trail with
  drawing on and reports frame times.
- `godot --path . -s tests/support/perf_visitors.gd`: 80 visitors in the
  park, 30 on screen, and reports frame times.
- `godot --path . -s tests/support/screenshots.gd` (and `screenshots_p3.gd`
  for the park): saves pictures of key moments to the user data folder.

## Tools (Python, standard library only)

| Tool | Does |
| --- | --- |
| `tools/bake_world.py` | Bakes `data/world/layout.json` into chunks, and where forage can appear (`data/world/forage.json`, by `tools/bake_forage.py`). Same input, same bytes. |
| `tools/preview_map.py` | Draws the baked world as an overview picture. |
| `tools/check_data.py` | Checks content tables: loads, unique ids, references. |
| `tools/make_placeholders.py` | Makes the stand-in pictures in `art/placeholder/` (the park's are in `tools/park_placeholders.py`). |
| `tools/place_pads.py` | Places the facility pads on open ground near the trail, from `tools/pad_requests.json`, into `data/content/pads.json`. |
| `tools/art_cleanup.py` | Turns `art/raw/` into `art/final/` using `tools/art_manifest.json`; writes `art/cleanup_report.md`. Never touches `art/raw/`. |
| `tools/run_tests.py` | Runs every test. |

## Layout

```
project.godot
scenes/            Godot scenes
scripts/           GDScript, by system: core, time, weather, needs, items,
                   buildings, map, save, world, game, ui, debug, living, park
art/raw/           images exactly as delivered; never edited
art/placeholder/   stand-ins made by the lab
art/final/         cleaned, sliced art made by the cleanup tool
data/content/      content tables (JSON, one per table)
data/tuning/       tuning.json: every number that shapes play
data/world/        layout.json and the baked chunks
tests/             automated tests
tools/             Python tools (hidden from Godot)
docs/              bible, roadmap, specs, rules, status reports (hidden from Godot)
```

## Version history

The version lives in `project.godot` (`application/config/version`). Every
commit of the build raises it and adds a line here.

### 0.4.4 (17 November 2026)

- The X and C hints show on hover instead of always: point the mouse at a thing (a building, the note board, a pad, forage) and a small tooltip says what X does there; point at an item-bar slot and it names the item and says what C does with it here. Clicking a slot holds that item. The green and red square for placing things stays.

### 0.4.3 (17 November 2026)

- Smooth walking again. In 0.4.2 the new hint line and "?" marks asked several times a second whether each site was joined to the station by trail, and each answer walked the whole trail: once sites were mapped, the game stalled about half a second at a time. One search from the station now answers for every site, and is kept until the land changes (a dig, boardwalk, clearing, a chopped tree or a badger's hole).

### 0.4.2 (17 November 2026): the Phase 2b feedback

- A hint line over the item bar always says what X and C do where you stand, or why C won't work there. A square on the faced tile shows where boardwalk, signs, markers, park things and the shovel can go: green yes, red no.
- A "?" floats over anything with something new: the note board (and the station door), a delivery on the supply shelf, new suggestion cards, a site ready to open, a kit waiting at its pad.
- The book's Jobs page starts with **Next:**, the one next thing to do at each site found.
- Money is in gold coins, not dollars.
- The map opens by itself when a survey finishes.
- The crafting page (K) lists every recipe known, greyed with where it is made, and the ones not learned yet with how to learn them. Cooking lists its recipes the same way.
- Signs go on or beside a trail (`signs.beside_trail_tiles`), can name any site found, and say whether they count for it.
- X gathers every forage spot close by at once (`forage.pick_radius_tiles`).
- Stacks are about three times bigger. In the backpack, drag stacks between slots, chests and shelves; drag onto Drop to put them on the ground (X picks them up) or onto Trash to throw them away. Tools can't be trashed.
- Trail travel: once you have arrived at a place twice and a trail joins it, the map lists it; click to walk there in one go. The time passes and it tires you as walking does (`travel` in the tuning file).
- The gift shelf and the suggestion box say how they work when opened.
- Art Request 10 asks for a "?" mark, a dropped bundle and a gold coin.

### 0.4.1 (17 November 2026)

- Art Requests 08 and 09 are in: Mark's visitors (a body and nine layers the game colours), the troll badger, the kiosk, bathroom, picnic area, campground, fishing dock, suggestion box, lookout sign, pad stakes and kit crates, benches, trash cans, picnic tables, fire rings, litter, dug earth, ten icons including the gift goods, and the station's catalog desk and staff board.
- Visitors' hair and hats sit a pixel higher than drawn so they clear the eyes (`look.visitor_layer_lift` in the tuning file).

### 0.4.0 (17 November 2026): Phase 3, the park runs

- Money: a wallet beside the clock, starting at $500, with $250 from the Chief every seventh day. A supply catalog on the station desk replaces the free shelf: orders arrive at 6:00 the next morning. A rescue costs 10% of the wallet, up to $250.
- Visitors: six kinds (day hikers, families, campers, anglers, tour groups and scout troops) arrive at the gate, walk only on trail to sites that are ready, and go home. How many come depends on the sites, their facilities and mess, the season, the day of the week, the weather and last week's mood. At most 80 at once.
- The old cabin and the outlook are now sites, and so is one more place further out, so visitors have somewhere to go.
- Facilities at set pads: bathrooms, picnic areas, campgrounds, a fishing dock and a tower lookout. Order a kit, build it with the hammer, take it down for half back. The kiosk and suggestion box stand at the gate.
- Benches, trash cans, picnic tables and fire rings can be put down near a trail.
- The old cabin can be rented out with the sign by its door.
- Income from entrance fees, camping, tours, fishing permits, gear rental, park maps, cabin rent and a gift shelf with five new gift goods.
- Upkeep: bathrooms get dirty, trash cans fill, litter gets dropped. Mess draws troll badgers, who tip cans, nap in bathrooms, raid picnics and dig holes in the trail.
- Staff: custodians and trail crew, hired at the staff board in the station.
- A suggestion box of visitors' cards, lost parties to find in fog, and letters from the Chief: a weekly report, praise and the odd grumble.
- J opens the ranger's book: jobs, the park today, the ledger, cards, letters and a notebook.
- The debug panel has the park's tools.

### 0.3.2 (17 November 2026)

- Art Request 07 is in: the forage on the ground is Mark's new art, 24 x 24 with outlines and soft shadows, so it stands out from the grass and forest floor. Bigger berries and rose hips on bushes, and a new sparkle.
- The art cleanup tool can keep a drawn shadow's see-through pixels (`soft`) or leave them out (`drop_soft`).

### 0.3.1 (17 November 2026)

- The version number is on the title screen and in the debug panel; V shows it in play.
- Escape opens a pause menu (resume, quit to title, quit game) instead of the backpack. E still opens the backpack; Escape still closes any open screen.
- The backpack has 1.5 times the slots: 18, and 27 with the pack frame.
- The item bar along the bottom shows only the first 10 slots, each marked with its number key (1 to 9, then 0). The backpack screen lays out 10 to a row, so its top row is the item bar.
- Waking at camp packs up the bedroll and puts out the fire.
- Calmer ground: the grass, forest floor and tall grass tiles have fewer small marks, and ground details that look like forage are gone.
- Art Request 07: a spec for bigger, brighter forage on the ground.

### 0.3.0 (16 November 2026): Phase 2b, living out there

- Foraging: 11 kinds of ordinary forage by season, weather and hour, plus 3 magical ingredients.
- Crafting anywhere, at a workbench or at a fire, with ideas that teach recipes, and three magic refits.
- Things to place: cairns, boardwalk, a workbench kit, the pack frame.
- Four skills with perks and a specialty at level 5.
- Art Request 05: new ground, soft edges, walls, floors and furniture.

### 0.2.1 (15 November 2026): Art and fixes after phase 2a

- Art Requests 02 and 03 are in, with a brighter palette.
- Debug panel: repair or undo every step of the fire tower at once.

### 0.2.0 (15 November 2026): Phase 2a, the forest region

- The whole forest region, with ring two baked around ring one (save version 2).
- Shovel, saw, clearing and digging trail; the workbench, signs and trail markers.
- Sites to open, the fire tower and its radio, the tower survey, rumors and hidden things.

### 0.1.1 (15 November 2026): After the first play

- Sharp text, a clear first day and a mapped home area.
- Camping, chopping trees, the cabin job and a cabin hint.
- Lighter spring mornings and a kinder rescue note.
- Art Request 01 and the forest palette.

### 0.1.0 (15 November 2026): Phase one, bedrock

- The game scene, world and movement.
- Time, light, weather, energy and warmth.
- Buildings, saving and the map.
- The art cleanup tool and the playthrough tests.
