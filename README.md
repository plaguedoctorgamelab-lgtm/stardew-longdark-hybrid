# Strange Ranger

A cozy top-down pixel game about a park ranger in a vast, quietly magical
wilderness. This repository holds phases one, 2a and 2b. See `docs/` for the
game bible, roadmap, phase specs and working rules.

**Current version: 0.3.2** (see [Version history](#version-history)). The
version shows on the title screen and in the debug panel, and V shows it in
play.

## Running the game

Needs Godot 4.7.2 stable (the lab's build uses
`C:\Godot\Godot_v4.7.2-stable_win64.exe`).

- Open `project.godot` in Godot and press F5, or run
  `C:\Godot\Godot_v4.7.2-stable_win64.exe --path .` from this folder.
- On the title screen choose **New game**. **Continue** loads the save.

| Key | Action |
| --- | --- |
| W A S D | Walk (eight directions) |
| Right-click or X | Interact: doors, bed, radio, shelf, chest, stove, workbench, landmarks; pick forage, berries and rose hips from bushes, resin from pines; a lit stove or camp fire opens cooking |
| Left-click or C | Use the held item: hammer, map (survey), food, firewood, shovel (dig), signs, markers, cairns, boardwalk, workbench kit |
| 1 to 9, 0 or mouse wheel | Choose the held item from the item bar (the first 10 backpack slots, numbered) |
| E | Backpack (and closes screens) |
| Escape | Closes the open screen; with none open, the pause menu (resume, quit to title, quit game) |
| M | Map |
| J | Jobs and sites |
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
- `godot --path . -s tests/support/screenshots.gd`: saves pictures of key
  moments to the user data folder.

## Tools (Python, standard library only)

| Tool | Does |
| --- | --- |
| `tools/bake_world.py` | Bakes `data/world/layout.json` into chunks, and where forage can appear (`data/world/forage.json`, by `tools/bake_forage.py`). Same input, same bytes. |
| `tools/preview_map.py` | Draws the baked world as an overview picture. |
| `tools/check_data.py` | Checks content tables: loads, unique ids, references. |
| `tools/make_placeholders.py` | Makes the stand-in pictures in `art/placeholder/`. |
| `tools/art_cleanup.py` | Turns `art/raw/` into `art/final/` using `tools/art_manifest.json`; writes `art/cleanup_report.md`. Never touches `art/raw/`. |
| `tools/run_tests.py` | Runs every test. |

## Layout

```
project.godot
scenes/            Godot scenes
scripts/           GDScript, by system: core, time, weather, needs, items,
                   buildings, map, save, world, game, ui, debug
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
