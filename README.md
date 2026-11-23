# Strange Ranger

A cozy top-down pixel game about a park ranger in a vast, quietly magical
wilderness. This repository holds phases one, 2a, 2b and 3. See `docs/` for the
game bible, roadmap, phase specs and working rules.

**Current version: 0.7.7** (see [Version history](#version-history)). The
version shows on the title screen and in the debug panel, and V shows it in
play.

## The tracker

A small web page for bugs, feature requests and the latest build, served
from this computer to the home network. Start it with
`tools\tracker\start_tracker.bat` (or `python tools/tracker/server.py`) and
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
| Right-click or X | Interact: doors, bed, radio, shelf, chest, stove, workbench, landmarks; pick forage, berries and rose hips from bushes, resin from pines; a lit stove or camp fire opens cooking. In town: talk to someone, the notice board, a shop's door (in during its hours), a shop's counter (talk, buy, sell), the library's shelves. In the park: the catalog desk and staff board in the station, the kiosk's gift shelf and the suggestion box at the gate, cleaning a bathroom, emptying a trash can, picking up litter, shooing a troll badger, finding a lost party, the rent sign by the old cabin's door |
| Left-click or C | Use the held item: hammer (repairs; builds a kit at its pad; takes down a facility or picks up a bench, trash can, picnic table or fire ring), map (survey), food, firewood (also lights a fire ring), shovel (dig; fills a badger's hole), signs, markers, cairns, boardwalk, workbench kit, and puts down a bench, trash can, picnic table or fire ring |
| 1 to 9, 0 or mouse wheel | Choose the held item from the item bar (the first 10 backpack slots, numbered) |
| E | Backpack (and closes screens) |
| Escape | Closes the open screen; with none open, the pause menu (resume, quit to title, quit game) |
| M | Map |
| J | The clipboard (Jobs page): Q/E change tab, W/S move through the jobs, P pins one to the screen, M shows it on the map, X follows a step's link, Escape closes |
| B | The book: the park today, the ledger, suggestion cards, the Chief's letters, the notebook, badges |
| K | Crafting page: things made anywhere |
| L | Skills page (and choose a waiting specialty) |
| Y or Enter / N | Answer a question (sleep) |
| V | Show the version number |
| O | People page and calendar (Q / E to turn) |
| F11 | Full screen or a window (the game starts full screen) |
| F12 | Screenshot, saved to your Downloads folder as "Strange Ranger" and the date and time |
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

### 0.7.7 (23 November 2026): Mark's portraits

- **Portraits in the talk box.** Mark's optional portraits (`art/raw/raw_portraits_*.png`), cut to 64 x 64 in four moods each: neutral, happy, sad, surprised (`portrait_<id>_<mood>`). The talk box shows the speaker's portrait on the left, in the mood the line calls for (`Town.mood_of`: happy at a first meeting and in friendship lines, surprised at news from the park), and the asker's when a favor is asked. Without a portrait it shows a big crop of the person's sprite head.
- **Wren's portrait waits.** Mark's sheet for Wren is "a provisional ranger design" (his note), not Wren's look, so it is kept in `art/raw/` but not used; the talk box shows her sprite's face until it's redrawn.
- Tests: `tests/test_portraits.gd`; screenshots: `docs/status/077_shots/` (`tests/support/screenshots_077.gd`).

### 0.7.6 (23 November 2026): Townsfolk Favors

Phase 4, 4a step 7: Townsfolk Favors are the jobs system's fifth live type (`data/content/town_favors.json`, `scripts/town/favors.gd`). Status note: `docs/status/076_status.md`; screenshots: `docs/status/076_shots/` (`tests/support/screenshots_076.gd`); tests: `tests/test_favors.gd`.

- **24 hand-written favors,** two for each townsperson, and **five templates** (a forage wish, something hot, a parcel, a lost thing, a hand at a shop). Every favor gives friendship with whoever asked, as well as its other rewards.
- **Three ways in:** notes pinned on the town notice board (read it to take them all; the board is kept at three template favors each morning), asked in person (after someone's line, Y "I'll see what I can do" or N "Not now", which leaves it on offer for a week), and letters in the station's new mailbox beside the door (its red flag is up when a letter waits).
- **New step kinds:** hand something to a townsperson (with C, as a gift is given; not counted as a gift, and something only shown is handed back), talk to someone, collect a parcel at the post office, an hour helping at a shop during its hours, and find a lost thing put out on a trail near a mark on the map. A favor's steps count in order. A survey step can want a clear day or to be done before dusk. New conditions: `met:`, `hearts:person:n`, `town_open`. New rewards: friendship and a recipe.

### 0.7.5 (23 November 2026): the houses' insides

- **The eight houses** have insides (`data/content/town_interiors.json`), dressed with Art Request 21's home set and each household's own pieces: the Pelletiers' gear wall, Bev's curio cabinet and snow globes, Agnes's books, typewriter and cat, the mayor's portrait and trophies, Pip's cryptid posters and toy chest, the Mendozas' family table and chillies, Gus's log bed and tool wall, Sol's easel and window seat. Three new walls and floors from B8 are used too.
- **Knocking:** X at a house's door lets the ranger in when someone who lives there is home, between 8:00 and 21:00 (tuning `town.visit_from`, `visit_until`); they stand inside, to talk to and give gifts as anywhere. When it gets late, or the last of them goes out, they see the ranger to the door. Otherwise the door says nobody's home, or that it's too early or late to knock. Tests: `tests/test_houses.gd`; screenshots: `docs/status/075_shots/` (`tests/support/screenshots_075.gd`).

### 0.7.4 (23 November 2026): Art Request 21 in, the townsfolk, clothing, and the People page

Mark sent every sheet of Art Request 21 (`art/raw/raw_ar21_*.png`). Status note: `docs/status/074_status.md`; screenshots: `docs/status/074_shots/` (`tests/support/screenshots_074.gd`).

- **All of Art Request 21 is cut** (224 pieces by `tools/art_cleanup.py`, the rest by `tools/cut_ar21_people.py`): the home set and each household's pieces, the Social page, calendar, mailbox and favor pieces, emotes, romance, Esme's cards, all four festivals' pieces, the station's upgrades and 30 decorating pieces with three walls and floors, and the garden with nine crops and their seeds. New in the cleanup: a "scale" so a sheet's pieces (a crop's stages, a fire's frames) keep one size; light backgrounds cleared from inside drawn cards ("bg_seeds"); and a sheet's own colours kept on pixel and final-say sheets. One stand-in: Mark drew no picked pumpkin, so `item_pumpkin` is cut from the grown plant.
- **The townsfolk in their own sprites.** All eleven besides Wren, and the Big Foot costume, cut by `tools/cut_ar21_people.py`: every frame of a person at one scale, feet on one row, heads lined up, so the walk holds still.
- **Clothing** (Phase 4, 4a step 6; `scripts/game/wardrobe.gd`, `data/content/clothing.json`). The ranger wears a hat, a coat and boots; the starting three give the old +1 warmth. The outfitters sells the wool toque, rain shell (half the rain's chill), wool coat, down parka (+3, 5% slower), waterproof boots (no slowdown in shallows and bog) and insulated boots, and the big bedroll (5% more rest at camp). Put clothes on by using them, or by dragging them onto Put on in the backpack, which also says what's worn. Mark's garments are fitted over the ranger's own frames, and a new hat takes the ranger's hat off. Tests: `tests/test_clothing.gd`.
- **The People page and the calendar** (Phase 4, 4a step 4), on O; Q and E turn between them (`scripts/ui/social_screen.gd`). Everyone met, with face, hearts (locked past a romance's cap), birthday, talked today and gifts this week; and the season's calendar with today, every birthday and the festival day (`data/content/festivals.json`). Tests: `tests/test_social_calendar.gd`.
- **The playtest start** no longer opens on a stack of old "done" cards, and its map shows what was seen along the trails.

### 0.7.3 (23 November 2026): a playtest start

- **Playtest start** on the title screen of playtest (debug) builds: a new game in which Get the Station Shipshape is done and the old cabin, the scenic outlook, Kettle Pond and the static tower are open. It is all done in the world as a ranger would: the trail dug out to each site (Reopen the Pond Trail and both halves of the Stake Trail with it), the cabin and the tower repaired, a sign at each, each site found, mapped and opened. It starts the next morning with the road to town open (`GameSession.debug_sites_open_start`). Test: `tests/test_playtest_start.gd`.
- `ParkHelpers.open_route` moved into the game as `GameSession.debug_open_route`, so the playtest start and the tests dig trail the same way.

### 0.7.2 (23 November 2026): Art Request 21, the rest of Phase 4

- **Art Request 21** (`docs/art/art_request_21_rest_of_phase_4.md`): every picture the rest of Phase 4 needs. Part A (4a, wanted first) asks for the eleven townsfolk walk sheets, six clothing overlays for the ranger with their icons, the eight houses' insides, and the Social page, calendar, mailbox and favor pieces. Part B (4b) asks for emote bubbles, romance items, the fortune teller's cards, the four festivals' pieces, the station's upgrades with 30 decorating pieces and three walls and floors, and the garden's plot, nine crops and seeds. Portraits are an optional last section. No game changes.

### 0.7.1 (23 November 2026): Mark's Art Request 20

Mark's touch-ups for tracker #36. Tests in `tests/test_art_request_20.gd`; pictures from `tests/support/screenshots_071.gd`.

- **The pads are roped off.** A staked-out pad now has one of Mark's flagged stakes at each corner, with his red-and-white flagging tape between them, a piece per tile along each edge (`ParkView._rope_pad`). The tape is cut from the straight middle of each run Mark drew, so it repeats. The tower's lookout keeps its single stake by the door.
- **Calmer floors.** Mark's plank floor in the station, the cabin and the tower, and his warm boards with their two variants in the shops. `tools/cut_ar20_floors.py` cuts the big tiles to 16 x 16 and keeps each seam a single pixel wide, which a plain shrink would lose. The lab's stand-in calm copies from 0.7.0 are gone.
- **The catalog desk** is Mark's new one: an open catalog, a telephone, an order pad and a plant.
- The art cleanup now keeps a sheet's own colours ("keep_colors") on pixel sheets and on sheets that have the final say, so the tape stays red and the flag orange.

### 0.7.0 (22 November 2026): Mark's tracker reports on 0.6.8

Fixes for tracker #28 to #41. Tests in `tests/test_tracker_070.gd`; pictures from `tests/support/screenshots_070.gd`.

- **#37, full screen.** The game starts full screen, drawn at 4 times on a 1920 x 1080 screen. Before, its 1920 x 1080 window didn't fit with a title bar, so it dropped to 3 times with black borders. F11 or Options switches to a window, sized to the biggest whole scale that fits (`Settings.apply_window`).
- **#28, the title sky** is one clear blue, without the bands.
- **#29, The Sign in the Ford.** A sign counts from its tile's middle, with half a tile to spare, and anywhere within 8 tiles of the ford (was 6).
- **#34, the tower's trail.** The tower's "join it to the station" step needs trail all the way from the station. It now names the first job still to do on that way (Stake Trail East, then West, then the pond trail), not a finished one. With all of them done, the gap still to dig is marked on the map.
- **#30, the Percolator's hours.** It shuts on Wednesdays. Its door now says so ("closed Wed"), and on a Wednesday it says "closed all day".
- **#31, burnt trees** in the burn can be chopped, for one more firewood than a green tree (`axe.firewood_extra`).
- **#32, hot soup** warms by 35 (was 15). Eating anything now says what it gave, for example "(+35 warmth, +70 energy)".
- **#33, spring snow** is rare: 15% of first-week rain (was half). Autumn's last week is unchanged.
- **#38, the finishing card** is larger, stretched as a nine-patch so Mark's corners, bolts and leaves stay as drawn. Every word sits on the paper, clear of the leaves, the bolts and the DONE stamp.
- **#39, hover tags and toasts.** A tag's words start past its string hole. Toasts lose the coloured stripe at their start, are as long as their words, and clip anything longer.
- **#40, the purple square** was the "new job" reward's missing icon. It now uses the clipboard note, and a test checks every reward icon.
- **#41, the map in town** shows a plan of Humdrum: its streets, the creek, every building named, and where you are.
- **#36, graphics.** The interior floors are calmer copies at half contrast, without the nail heads (`tools/calm_floors.gd`, `*_calm.png`). Art Request 20 (`docs/art/art_request_20_touch_ups.md`) asks Mark for the pad flags, the floors and the catalog desk.

### 0.6.9 (22 November 2026): town fixes

- **The creek's bends.** Inner corners are now made from the two side tiles that meet there (`tools/cut_town_ground.gd`): the lawn is a small nub in the corner with the sand rim running round it, so where Dusk Creek steps up or down the shore turns a corner instead of showing a square of grass. The cobbles' and gravel's inner corners are made the same way.
- **The Percolator's windows glow at night,** and Casa Luna's glass glows rather than its turquoise frames. Their glass is darker than Art Request 19's pale blue, so `town_look.window_glass.pictures` gives each its window boxes and light range.
- **Bigger yard fences.** The picket fence, hedge, stone wall and their ends are cut half as big again (the picket 36 x 27), so they lose the speckle and stand taller. The runs are spaced by the new widths, the hedge and wall overlapping by 2 pixels so they have no gaps.
- New tests in `tests/test_town_fixes_069.gd`; screenshots from `tests/support/screenshots_069.gd`.

### 0.6.8 (22 November 2026): Mark's new music

- Mark's three new pieces replace the old ones: **Ranger Station Morning** (title screen and indoors), **Trail Through the Pines** (outdoors by day) and **Snowbound Ridge** (winter, and outdoors at night). The MP3s are in `audio/music/`, named in `data/content/music.json`; the MIDI copies he sent are not used. Hearthlight, Pine Path and Lanterns in Snow are gone.

### 0.6.7 (22 November 2026): Mark's town, and the road opens later

- **Mark's Art Request 19 in Humdrum.** Every building but the Percolator and Casa Luna is Mark's: the four Main Street shops, Town Hall, the bandstand, Esme's caravan and the eight houses. Cut by `tools/art_cleanup.py` (manifest entries for `raw_ar19_*.png`); the ground sheet by `tools/cut_town_ground.gd`, which also makes the inner corners Mark's sheet lacked, flipped middles, and the lawn in Mark's grass colours (`town_grass_*`).
- **Grounds meet with edges** (`town_look.edges` in tuning): cobbles, gravel, flower beds, the square's paving and the creek's banks take a side, corner or inner corner where they meet another ground.
- **The town re-laid** (`tools/bake_town.py`): the square's paved half with the compass mosaic, a wandering creek with shallows, reeds, stones and lily pads, backyards with fence, hedge or wall behind the north houses, mailboxes, bushes in clumps, tufts and wildflowers, the willow by the caravan, a two-deep forest edge, and Main Street's signpost, chalk board, planters and crates. No building or door moved; the bandstand is six tiles wide to fit its picture.
- **Night and seasons:** window glass glows warm at night, drawn above the night's tint (`town_look.window_glass`); streetlamps and winter string lights swap to their lit pictures; crabapple blossom and petals in spring, bunting in summer, leaves and pumpkins in autumn, lights in winter.
- **The road to town opens later.** A new game starts with it closed ("ROAD CLOSED FOR REPAIRS"); it opens the morning after Get the Station Shipshape is done, or on day 4, with a letter from the chief (`town.opens_when`, new condition `day_at_least`). Old saves have it open; the debug panel still goes to town.
- Tests: `tests/test_town_gate_067.gd`, `tests/test_town_art_067.gd`. Screenshots: `docs/status/067_shots/` (`tests/support/screenshots_067.gd`). Status note: `docs/status/067_status.md`.

### 0.6.6 (22 November 2026): Art Request 19, the town

- **Art Request 19** (`docs/art/art_request_19_town.md`), written from Mark's three Stardew town pictures (in `ref/stardew_town/`, not in git): eight sheets covering the fifteen stand-in buildings, ground edges, street furniture, greenery, yards and seasonal touches. Pictures of the town as it looks now are in `docs/art/ar19_town_today/`, taken with `tests/support/screenshots_town_today.gd`. No game changes.

### 0.6.5 (22 November 2026): F12 screenshots

- **F12** saves what's on screen to the Downloads folder, named with the game and the date and time ("Strange Ranger 2026-11-22 10-05-56.png"); two in one second get " (2)". It works anywhere, the title screen included, and says where it went. Without a Downloads folder it saves to the game's user folder. Code: `scripts/core/screenshot.gd`; test: `tests/test_screenshot_065.gd`.

### 0.6.4 (22 November 2026): Mark's fixed interior pieces

- Mark's second version of Art Request 18's counters and shop-pieces sheets, and a new wall piece, `raw_ar18_post_pigeonholes.png`.
- **The Town Hall** has the post office counter again, now just its brass grille (48 x 32), with the pigeonholes on the wall behind: the mayor shows behind his counter.
- **The Outfitters** has the new coat display; the shop-pieces sheet now comes on a transparent background, so it cuts cleanly.
- **The Percolator's menu board** shows its chalk cup, drawn bolder.
- Screenshots: `docs/status/064_shots/`. Still waiting on code: the room's edge piece and the window light shaft.

### 0.6.3 (22 November 2026): Mark's Art Request 18 in the shops

- **Art Request 18:** Mark's four interior sheets (`art/raw/raw_ar18_*.png`) cut into 40 pieces: warm floorboards and a checker floor, plank, brick and wallpaper walls, windows by day and night, a doormat, four counters, the bookcase and goods shelf, each shop's own pieces, rugs, plants, an armchair and wall pictures. They keep their own colours (`keep_colors`), since the palette turned the honey floor salmon.
- **The seven shops re-dressed** with them: a wall and floor for each shop, windows, plants in the corners, rugs marking each area, a doormat at every door. Screenshots: `docs/status/063_shots/`.
- `InteriorView` draws a wall picture as tall as the whole wall as one strip a column, and mixes a room's `floor_alts` so the boards don't repeat.
- Not used yet: the room's edge piece and the light shaft (sheet 1), the coat display (white left inside the rack), and the post office counter, whose pigeonholes hide the mayor behind it. The Town Hall uses the plain counter until then.

### 0.6.2 (22 November 2026): Phase 4, the shops

From `docs/Phase 4 Spec.md`, 4a step 5 (notes for Mark: `docs/status/062_status.md`).

- **Shop insides:** X at an open shop's door goes in; at closing time the keeper sees the ranger out. Seven rooms in `data/content/town_interiors.json`, laid out to the Interior Art Guide and Mark's Stardew pictures, drawn by the same `InteriorView` as the park's buildings. Keepers stand behind their counters; townsfolk visiting a shop are inside at its guest spots, and can be talked to and given gifts.
- **Buying and selling:** X at the counter: talk, buy, sell (Gifts & Notions), or the catalog (post office). `data/content/shops.json` holds what each sells and buys; tuning `shops`. Café and restaurant dishes are eaten here or taken away. Coffee walks 10% faster for two hours. While a keeper is out, an honour jar still takes money.
- **The library:** ten books (`data/content/books.json`); four teach a recipe.
- **Art Request 18** (`docs/art/art_request_18_interiors.md`): the interior sheets, from Mark's Stardew reference pictures. Stand-ins for the counter, goods shelf, bookcase and eight menu items.
- Code: `scripts/town/shops.gd`; the session's `town_inside`. Tests: `tests/test_shops_062.gd` (rooms laid out well, hours, buying and selling exactly, coffee, books, saves).

### 0.6.1 (22 November 2026): tracker #26 and #27

- **#26, the pond could never be found:** its landmark is mid-water, more than the find radius from any shore. A site is now found near its landmark or its door. Test: every site is found from its door.
- **#26, the burn's brush:** what an active job still wants cleared (brush, trunks, branches) gets a small bobbing gold arrow over it (`Jobs.clear_marks()`, tuning `look.job_marks`), since the gap brush looked like the scenery bushes.
- **#27, crowded insides:** the station and the tower are laid out like the old cabin, using Mark's new bed, chest, workbench and supply shelf in the station. Zones, a clear way from the door, nothing on the rug, a free tile in front of each piece. The station's coat rack became a wall hook, and the tower's wardrobe went. Test: no overlaps, everything reachable. New interior art waits for Mark's reference pictures.

### 0.6.0 (21 November 2026): Phase 4, first pass: Humdrum

From `docs/Phase 4 Spec.md`, 4a steps 1 to 4 (notes for Mark: `docs/status/060_status.md`).

- **Humdrum** (`scripts/town/`, `tools/bake_town.py`, `data/world/town.json`): X at the park gate leads into town, walking east along the road leads back. While in town the park keeps the ranger at its gate, so weather, warmth and the clock carry on. Main Street, the square with its bandstand and notice board, two lanes, Dusk Creek and its footbridge, eight houses, the shops, the library, Town Hall and the caravan. Streetlamps glow at night. Mark's Percolator, Casa Luna, town ground and Wren; lab stand-ins for the rest.
- **Named days:** day 1 of each season is a Monday; the clock shows the day; the Chief's report falls on Sundays.
- **Twelve townsfolk** (`townsfolk`, `routines`, `town_places`): homes, birthdays, a routine per day with rain and weekday exceptions, walking between places along paths; keepers at their open shops' doors, everyone inside at home.
- **Talking and friendship** (`dialogue`, `spoiler_dialogue`, tuning `friendship`): one line a day, none repeated within a week, lines about what was done in the park, heart lines; 20 points for talking once a day; hearts never go down; romance candidates stop at 8 hearts until dating.
- **Gifts** (`gift_tastes`): loved, liked, neutral, disliked and hated, two a week plus a birthday gift worth eight times.
- Debug panel: Town, and +1 heart all.

### 0.5.4 (21 November 2026): the graphics refresh, first pass

From Mark's Graphics Polish request and Interior Art Guide (`docs/art/`).

- **The old cabin** is laid out to the guide's plan, with Mark's new bed, stove (cold and lit), and chest (`art/raw/raw_int_furniture_big_01.png`; his workbench, desk and supply shelf are cut too, ready for the station and tower). The piece the ranger faces indoors shows its name: "Wood stove", "Chest".
- **Hits:** when the axe, saw, shovel or hammer lands, the ranger holds still a few frames, chips of wood, leaves, dirt or stone burst out, and brush and trunks jolt a pixel. A felled tree tips away in pixel steps and fades.
- **Signs of life:** standing still, the ranger breathes, rising a pixel and settling.
- **Depth:** buildings fade while the ranger walks behind them.
- **Fog and snow** drift over the world as pale patches, two layers at different speeds.
- **Options** has Motion and Weather effects switches.
- **The art audit** (`tools/art_audit.py`, `docs/art/art_audit.md`): every finished picture measured and ranked, with ready-to-paste prompts for the ten most worth redoing.
- `tools/art_cleanup.py`: `bg` clears a painted checkerboard or a glow; `keep_colors` keeps a sheet's own colours where the palette has no near match (people, cobbles). Phase 4's first art is cut: The Percolator, Casa Luna, Wren and the town ground.
- `tools/make_placeholders.py` runs again (it stopped on the plain ground tiles from 0.5.1).

### 0.5.3 (21 November 2026): the station's furniture, and water that moves

- **The station's furniture** (Art Request 17, sheet 5): Mark sent it again on a plain background (`art/raw/ar17_station_plain.png`). The bed, stove (cold and lit), workbench, catalog desk, radio, shelf, staff board, note board, chest, logbook desk and door are all his now. The wooden pieces take the game's wood browns, and the staff board's cork its tan.
- **Water:** open water sways its ripple marks and catches a small glint, and where water meets land a wet-sand rim and a foam line run along the shore, lapping in and out. Made in the game from its own palette (`look.water` in tuning), after the feel of the picture Mark sent. Not where water meets boards.
- `tools/art_cleanup.py`: boxes can be cleared from a cell before the cut (`erase`: the bed's cell also holds a wall picture and a hat hook), and recolouring touches only pictures cut in the same run, so re-cutting one sheet no longer darkens another's.

### 0.5.2 (21 November 2026): Art Request 17, the flat pieces redrawn

- **Art Request 17** (`docs/art/art_request_17_park_things.md`): Mark's redrawn park facilities (the gate's kiosk, suggestion box and bathroom, the bathroom with a badger inside, the picnic area, the outlook sign, the pad stakes and kit crates), the campground and the fishing dock, the small park things (bench, picnic table, trash cans, fire rings, litter, the rent sign, the trail marker, the camp bedroll, the job flag), the backpack icons for things put down plus the radio valve, painted stone and window glass, and four versions of dug earth.
- The station furniture sheet came back drawn against a log wall, which can't be cut away from the pieces, so the station keeps its furniture until it's redrawn on a plain background.
- `tools/art_cleanup.py`: a newer sheet can have the final say over an older pixel-for-pixel one of the same name (`final_say`), and the bathroom and crates take the game's wood browns (`recolor_map`).
- The tracker page shows a fixed item's version, what was changed and how to check it (`fix` and `check` fields).

### 0.5.1 (21 November 2026): Mark's art and music, and the tracker's jobs fixes

Art Request 16 and the first music are in, and every 0.5.0 tracker report the lab could reach is fixed.

- **Art Request 16** (`docs/art/art_request_16_rooms_trees_water.md`), cut from Mark's eight sheets by `tools/art_cleanup.py` (now able to clear the background cell by cell inside drawn grid lines, cut hand-placed cells, and recolor a piece to the game's own colours): the 26 item icons that were stand-ins; furniture for the rooms (a trunk, cupboards, a wardrobe, pantry shelves, a bunk bed, a cabin bed, a map table, a table and chairs, a coat rack, a lamp unlit and lit, a window with curtains by day and night); five new trees (birch, spruce, maple, aspen, old cedar) and an old and a young version of each of today's four; plain ground tiles in today's colours, shown on about three tiles in four, with the scattered details a third as common; a wooden frame and six tab icons. The bog tile came out broken and is left out. The water waits on Mark's picture.
- **Rooms one tile bigger** each way (tracker #21) and furnished: the cabin and the tower each get their own bed and a trunk, and the furniture to make them lived in. Decor is passed by when X looks for the bed or chest beside it.
- **Light at night:** an open building's windows glow warm from outside; inside, the room dims and lamps and a lit stove light it; the curtains show a night sky.
- **Music:** Mark's Ranger Station Morning (title and indoors), Trail Through the Pines (outdoors by day) and Snowbound Ridge (winter, and outdoors at night), crossfading as you go (`scripts/audio/music.gd`, `data/content/music.json`). Options: Music Off, Quiet, Medium or Loud.
- **The jobs look in other screens:** the backpack, the book, the workbench and cooking lists, the pause menu, Options and dialogs sit in the wooden frame, with tab pictures.
- **Tracker fixes:** template jobs now fill a blank inside a place ("place:{site_id}"), so trash cans and benches count at the outlook and the cabin (#16, #24); the pond trail's brush is part of its clearing step, and old paths join the cabin to the pond trail, the pond to the stakes and the steps to the tower door, so the pond and tower trail jobs finish (#19, #23); a site counts as joined within 4 tiles of its spot; X at a landmark still to map comes before forage beside it, so the pond's cairn maps (#25); a step always walks out of something put down on the ranger (#12, #14); the hammer packs up a camp (#20) and its taking-down is in the hints and messages (#18); signs and things try the tiles beside the faced one (#17); Show on map rings the step and names it, and goes to the rumor for a place not found yet (#22). The book's hint says B.
- New tests: `tests/test_tracker_051.gd`, `tests/test_audio_and_art16.gd`; screenshots: `tests/support/screenshots_051.gd`; lab probes `tests/support/probe_tracker.gd` and `probe_trails.gd`.

### 0.5.0 (19 November 2026): the jobs rebuild

The jobs system is rebuilt to the designer's Jobs Spec (`docs/jobs_spec.md`), with Mark's jobs art.

- **One jobs module** (`scripts/game/jobs.gd`) decides what a job is. Jobs are data: hand-written jobs (`jobs.json`), template jobs filled from the park (`job_templates.json`), five job types with givers, colors and icons (`job_types.json`, `givers.json`), typed steps (`job_steps.json`) and reward kinds (`rewards.json`). Steps are worked out from the world; a step that stays done is recorded once; a job finishes the moment its last step is done and stays finished. Five signals: job added, step done, step undone, job done, job retired. This is tracker #10, brought forward from Phase 4.
- **A new opening.** A new game offers only Get the Station Shipshape: tidy three spots in the station, clear a branch on the trail, set the trash can out by the gate. Finishing it gives rumors of the cabin, the outlook and the pond, the supply catalog, and two jobs nearer home: five jobs of three kinds to choose from.
- **Rewards for every job**, shown before starting and given on a finishing card: rumors, trail travel, map sketches, catalog unlocks, follow-on jobs, journal pages, supplies, gold and experience. Something already had is swapped for gold.
- **Trail travel is a reward** for opening a joined site (tracker #15). The "arrive twice" rule is gone, and travel counts trail within 3 tiles of a door.
- **Short trail jobs.** The pond trail, the last ranger's old path beside the stakes across the burn, and the old road are now old trail with gaps of no more than a screen (30 tiles), so the tower is a day's work, not a week's.
- **The clipboard** (J): Current, Noticed and Done tabs, the list grouped under a ribbon per type, and the chosen job in full: from, note, what you'll need (with where to get it), steps (the next one highlighted, counts, links), rewards. Nothing runs off the paper; long lists scroll.
- **The pinned note** in the top left shows the pinned job (or the one last worked on) and its next step; click it to open the clipboard. **Toasts** for new jobs, steps done or broken, and counts at each quarter. **Finishing cards** with a DONE stamp, then the map opens on what changed. A season's card on the first morning of a season.
- **Map markers:** the pinned job's next step gets a flag in its type's color, other jobs a dot; hover one for its name and step. Show on map (M) from the clipboard.
- **Seasons:** untouched template jobs and the ended season's jobs retire at the turn; started jobs stay. Template jobs keep each type topped up each morning. A template job someone else does finishes on its own at half pay.
- **The suggestion box:** a card that asks for something offers "Take this on", which adds it as a Visitor Request (replacing pinning). The radio's lost party is a Visitor Request.
- **Older saves** are converted: every job is worked out from the world, those already done are finished and paid, and one "While you were away..." card lists them. Opened, joined sites get trail travel.
- Options: Show pinned job, and Show unlocks on the map. B opens the book; its Jobs page is replaced by the clipboard.
- Debug panel: list jobs, finish or reset one, draw a template, notice everything (spoilers only), turn the season.
- New tests: `tests/test_jobs_system.gd`; screenshots: `tests/support/screenshots_jobs.gd`.

### 0.4.10 (18 November 2026): the outlook and pond can open

- The scenic outlook and the kettle pond, which have no building, can now be declared open: once every step is done, X at the outlook's post or the pond's cairn asks to open it, and the hover hint says so. Before, X there only ever said the place's name.
- A site with no building counts as joined to the station's trail when that trail comes within 3 tiles of its spot (`sites.spot_reach_tiles`). The outlook's spot sat 3 tiles from the end of its trail, so it never counted as joined and its two flags sat by the post whatever was dug. Its trail already reaches it in a new game.
- When a site's trail joins the station's, the game says so ("The Kettle Pond is joined to the station's trail! Its flags are off the map."), and says so again if it comes apart. The job step now says trail tiles must touch side by side, not just at the corners.
- The steps for a site with no building say to press X at its marker (a post or a cairn).

### 0.4.9 (18 November 2026): jobs that follow you

- The Jobs page works on the site the ranger last found, mapped or reached, and remembers it in the save. Before, it always showed the first site in the list, so at the scenic outlook it said the tower.
- Every thing to bring, and every "handy to have", says where to get it: "(in the Ranger Station's chest)", "(on the Ranger Station's supply shelf)", "(make it at a workbench)", "(order it from the catalog at the station)" or "(gather it outdoors)". It never points into a building still locked. The bedroll, axe and shovel start in the station's chest, as the Phase 2 spec has it; only the saw is at the cabin.

### 0.4.8 (18 November 2026): Mark's new start screen and cursors

- A new start screen from Mark (Art Request 11, redrawn): detailed mountains, a pine ridge, the Dusk River meadow framed by trees, a carved "Welcome to Dusk River Park" sign that carries the park's emblem, and a script "Strange Ranger" logo. The menu's words are cream with a dark edge, to read over the plank's grain.
- Mark's cursors (Art Request 15): the pointer, and the pointer with a green plus over forage in reach. He drew them large; `tools/art_cleanup.py` shrinks them to 24 x 24 with the point in the top-left pixel (new `anchor: "top_left"` and `edge_ok` cell options in `tools/art_manifest.json`).

### 0.4.7 (18 November 2026): the tracker's first list

- **Jobs as steps** (tracker #2, #3). Every site found, or offered on the note board, is one job with its steps in order: gather what to bring (counted for every step still to do: materials, hammer, shovel, a sign), find, map, join to the trail, repair part by part, sign, open. The book's Jobs page shows the job being worked on in full, the others in a line each with their next step, and what's done.
- **Dig flags on the map** (#2). Where a site's trail still has to be joined to the station's, a red flag marks each end of the gap, with dashes between.
- **The workshop** (#4). Each recipe says what it is for; recipes not learned yet are hidden again, and learning one pops up "You can make something new!"; each workbench has its own 10-slot box (`storage.bench_slots`): what's in it counts for making, and made things go in it when the backpack is full.
- **Waking in the tower** (#5). The ranger woke half inside the radio and couldn't take a step; now every bed wakes the ranger on the nearest clear spot.
- **Why you passed out** (#6). The wake-up note says whether it was cold, hunger or staying out too late, and what to do next time.
- **Options screen** (#7). Esc, then Options. Hover tips can show for the first week of a game (the default, `ui.hover_tip_days`), always, or never; kept on this computer for every game.
- **Forage with the mouse** (#8). A stand-in cursor (`tools/cursor_placeholders.py`) shows a plus over forage in reach; either click picks it, by the same rules as X.

### 0.4.6 (17 November 2026): Art Requests 11 to 14 are in

- Mark's park look art replaces the stand-ins: the title screen's four drifting layers, entrance sign, emblem, logo, lantern, fireflies and hanging menu planks; the ranger's kit (paper panels, plank buttons, red and blue book tabs, paper tags, the clock sign, the wallet patch and the item-bar pegs); the map's compass, star, site pictograms, legend frame, parchment for unexplored land and lettering; and every badge.
- Cut by `tools/art_cleanup.py` from Mark's exact coordinates (`box` cells in `tools/art_manifest.json`); the raw sheets are in `art/raw/ar11_*` to `ar14_*`.
- Where a sheet left a gap, the game fills it: disabled buttons fade the normal plank (the fourth plank state sits under the wallet patch on the sheet), skill patches get gold pips for their level (the three levels are drawn alike), and the legend uses only its frame's border.
- Every piece falls back to the drawn stand-in if its picture is missing.

### 0.4.5 (17 November 2026): the park look

- The title screen is the entrance to Dusk River Park at dusk: a banded sky, mountains and pines drifting slowly, the Dusk River, fog and fireflies, "STRANGE RANGER" in poster letters, and a routed-wood sign with the compass-and-eye emblem and a lantern, the menu hanging under it on planks.
- Every screen wears the ranger's kit: field-book paper panels, plank buttons, the clock on a wooden sign, the wallet as a green patch, wooden pegs for the item bar and paper tags for hover hints (`scripts/ui/kit_style.gd`).
- The map is a park poster: flat bright land colours, red stars at mapped landmarks, a compass rose, a legend and the park's name. The map now always paints in full the first time it opens.
- A Badges page in the book: skill patches, specialty shields, and strange badges that never say what earns them.
- All drawn in code as stand-ins until Art Requests 11 to 14 (`docs/art/art_requests_11_to_14_park_look.md`). The world keeps its bright colours.

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
