# Strange Ranger

A cozy top-down pixel game about a park ranger in a vast, quietly magical
wilderness. This repository holds **phase one: Bedrock**. See `docs/` for the
game bible, roadmap, phase spec and working rules.

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
| 1 to 9, 0, -, = or mouse wheel | Choose the held item |
| E or Escape | Backpack (and closes screens) |
| M | Map |
| J | Jobs and sites |
| K | Crafting page: things made anywhere |
| L | Skills page (and choose a waiting specialty) |
| Y or Enter / N | Answer a question (sleep) |
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
