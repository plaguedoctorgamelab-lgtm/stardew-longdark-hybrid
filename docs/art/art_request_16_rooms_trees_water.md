# Strange Ranger: Art Request 16, Stand-ins, Rooms, Trees and Water

From the lab, 21 November 2026. This covers every picture the game still shows as a lab stand-in, the furniture for the cabins and the tower, more trees, calmer ground, the water, and two changes to how things are shown (the map and the lights at night). It ends with the jobs-page look carried into the other screens.

Each section says what you draw and what the lab does. Some items are lab work only and need no art.

Same rules as Art Requests 11 to 15: true pixel art at exactly game size, the bright palette of Art Request 06 (`docs/art/palette_bright.json`), a one-pixel dark outline, and light from the top left.

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

## The sheets at a glance

| # | File | Size | What | Priority |
| --- | --- | --- | --- | --- |
| 1 | `ar16_gathered.png` | 128 × 128 | 14 gathered item icons (4 × 4 grid of 32 × 32) | High |
| 2 | `ar16_made.png` | 128 × 96 | 12 made item icons (4 × 3 grid of 32 × 32) | High |
| 3 | `ar16_room_small.png` | 192 × 96 | Small room things (4 × 2 grid of 48 × 48) | High |
| 4 | `ar16_room_big.png` | 192 × 128 | Big room things (4 × 2 grid of 48 × 64) | High |
| 5 | `ar16_trees_new.png` | 160 × 96 | 5 new trees (5 × 2 grid of 32 × 48) | High |
| 6 | `ar16_trees_more.png` | 128 × 96 | 2 more versions of each of today's 4 trees (4 × 2 grid of 32 × 48) | Medium |
| 7 | `ar16_ground_plain.png` | 64 × 32 | 8 plain ground tiles (4 × 2 grid of 16 × 16) | High |
| 8 | `ar16_water.png` | see section 5 | Water and shore pieces | High, waiting on your picture |
| 9 | `ar16_night.png` | see section 7 | Lit windows and a lamp glow | Medium |
| 10 | `ar16_ui.png` | see section 8 | A few pieces to carry the jobs look into other screens | Medium |

---

## 1. Every stand-in in the game today

These are all the pictures the game still draws from `art/placeholder/` (lab stand-ins). Everything else is your art.

**Gathered items (14):** sticks, stones, reeds, wild onion, fiddleheads, wildflowers, berries, hazelnuts, mushrooms, rose hips, pine resin, glowcap, ember moss, lodestone sliver.

**Made items (12):** cairn, rope, boardwalk, workbench kit, trail mix, berry preserve, fiddlehead fry, roast hazelnuts, rose hip tea, glowcap lantern, ember bedroll, true compass.

**On the ground (1):** berries on a bush (`obj_forage_berries`).

**Room trim (1):** `interior_trim`, the thin dark line along the walls. It's 4 × 4 and the lab can make it from your wall colours, so it needs no art.

**Soft edges (2):** `edge_grass` and `edge_forest_floor`. The lab made these from your ground tiles. They're fine unless you want to redraw them.

### Sheet 1: Gathered (4 × 4 grid of 32 × 32 icons; the last two cells empty)

This is Art Request 06's Sheet 1. It never came back, so here it is again.

Row by row: sticks, stones, reeds, wild onion; fiddleheads, wildflowers, berries, hazelnuts; mushrooms, rose hips, pine resin, glowcap; ember moss, lodestone sliver.

> [Style line]. A 4 by 4 grid of 32 by 32 pixel art inventory icons for a top-down forest game, transparent background, each one item centred in its cell with a one-pixel dark outline. Row 1: a small bundle of sticks; three smooth stones; a bundle of reeds; a wild onion with its green top. Row 2: two curled fiddlehead ferns; a small posy of wildflowers; a sprig of dark berries; three hazelnuts. Row 3: two brown forest mushrooms; red rose hips on a twig; a golden drop of pine resin; a small violet mushroom glowing softly. Row 4: orange moss on a scrap of dead wood, faintly glowing; a dark splinter of stone with a dull shine; the last two cells empty.

### Sheet 2: Made (4 × 3 grid of 32 × 32 icons)

Art Request 06's Sheet 2, again.

Row by row: cairn, rope, boardwalk, workbench kit; trail mix, berry preserve, fiddlehead fry, roast hazelnuts; rose hip tea, glowcap lantern, ember bedroll, true compass.

> [Style line]. A 4 by 3 grid of 32 by 32 pixel art inventory icons for a top-down forest game, transparent background, each one item centred in its cell with a one-pixel dark outline. Row 1: a small stack of stones (a cairn); a coil of rope; a short length of wooden boardwalk planks; a flat-packed wooden workbench kit with a few nails. Row 2: a paper twist of trail mix; a jar of berry preserve with a cloth lid; fiddleheads frying in a small pan; roasted hazelnuts in a paper cone. Row 3: a mug of red rose hip tea; a camp lantern glowing violet inside; a rolled bedroll with a warm orange glow along it; a brass compass with a dark needle and a faint shimmer.

The berries-on-a-bush piece is the one cell of Art Request 06's Sheet 3 still missing. Add it to Sheet 3 below as its last cell, or send it on its own at 16 × 16: only the dark berry clusters, placed to sit on the round bush, with everything else transparent.

---

## 2. Things in the cabins and the tower

**Today:**
- The **ranger station** (12 × 10 tiles) has a bed, a note board, a radio, a shelf, a chest, a workbench, the catalog desk and the staff board.
- The **old cabin** (9 × 9) has only a bed, a stove and a chest.
- The **static tower** (9 × 9) has a bed, a stove, a radio, a chest, a note board and a desk.

The cabin and the tower feel empty, and the same bed and chest are in every room.

**What changes (lab):**
- Each room gets its own furniture from the list below.
- The rooms get one tile bigger each way (tracker #21): the station becomes 13 × 11 and the cabin and tower 10 × 10.
- Most new pieces are things to look at. A few do something, noted as they come.

The rules from Art Request 05 still hold:
- Furniture is big and stands on the bottom of its cell.
- Its back edge is against the wall, with a one-pixel dark outline.
- Use the same woods and the same walnut trim as today's bed and workbench.

### Sheet 3: Small room things (4 × 2 grid of 48 × 48 cells)

Row 1:
1. **Trunk:** an old domed travel trunk with brass corners and a leather strap, closed. It is different from today's flat chest and is the cabin's store.
2. **Cupboard, low:** a two-door kitchen cupboard with a worktop, a tin mug and a jar on top.
3. **Washstand:** a small stand with an enamel basin and jug, and a towel on the rail.
4. **Wood box:** an open box of split firewood beside a stove, with a hatchet leaning on it.

Row 2:
5. **Table and two chairs:** a small square table with a checked cloth and two plain chairs, seen from above at the game's angle.
6. **Oil lamp, unlit:** a brass oil lamp on a small round side table.
7. **Oil lamp, lit:** the same lamp, its glass glowing warm yellow and its flame showing. The game swaps the two at night.
8. **Berries (on a bush):** see the end of section 1, or leave it empty.

### Sheet 4: Big room things (4 × 2 grid of 48 × 64 cells)

Row 1:
1. **Bunk bed:** two plain bunks with wool blankets, one red check and one green, and a small ladder. For the tower.
2. **Cabin bed:** a log-frame bed with a patchwork quilt, different from the station's bed.
3. **Tall cupboard (wardrobe):** a plank wardrobe with one door ajar and a coat showing.
4. **Pantry shelves:** open shelves with jars, tins, a sack of flour and strings of dried onions.

Row 2:
5. **Cabin workbench:** a rough workbench with a vise, a saw on the wall above it, and shavings on the floor. Smaller and older than the station's.
6. **Map table:** a slanted table with a pinned map, a ruler and a lamp. For the tower.
7. **Coat rack and boots:** a standing rack with a ranger jacket and a hat, and boots beneath.
8. **Window with curtains:** a wall window with gingham curtains tied back, for the back wall. Draw it twice side by side in the one cell, 24 × 64 each: by day showing sky, and at night with a dark blue pane. The lab can light the night one from code.

**Prompt (Sheet 3).**

> [Style line]. A 4 by 2 grid of 48 by 48 pixel art furniture pieces for the inside of a cozy log cabin in a top-down forest game, three-quarter view from above, transparent background, each piece standing on the bottom of its cell with its back to the wall, a one-pixel dark walnut outline, warm honey and walnut woods. Row 1: a domed travel trunk with brass corners and a leather strap; a low two-door kitchen cupboard with a tin mug and a jar on top; a washstand with an enamel basin and jug and a towel; an open box of split firewood with a hatchet leaning on it. Row 2: a small square table with a red checked cloth and two plain chairs; a brass oil lamp, unlit, on a small round side table; the same oil lamp lit, its glass glowing warm yellow; an empty cell.

**Prompt (Sheet 4).**

> [Style line]. A 4 by 2 grid of 48 by 64 pixel art furniture pieces for the inside of a cozy log cabin in a top-down forest game, three-quarter view from above, transparent background, each piece standing on the bottom of its cell with its back to the wall, a one-pixel dark walnut outline, warm honey and walnut woods. Row 1: a plank bunk bed with a red check blanket on top and a green one below and a small ladder; a log-frame bed with a patchwork quilt; a plank wardrobe with one door ajar showing a coat; open pantry shelves with jars, tins, a flour sack and strings of dried onions. Row 2: a rough old workbench with a vise and a saw hanging above it and shavings on the floor; a slanted map table with a pinned map, a ruler and a small lamp; a standing coat rack with a green ranger jacket and a wide-brimmed hat and boots beneath; a wall window with gingham curtains tied back, drawn twice side by side, once with a daytime sky and once with a dark blue night pane.

### Which room gets what (lab)

| Room | Keeps | Adds |
| --- | --- | --- |
| Ranger station | everything it has | table and chairs, coat rack, lamp, window with curtains |
| Old cabin | stove | cabin bed, trunk (in place of the chest), low cupboard, wood box, washstand, pantry shelves, cabin workbench, lamp |
| Static tower | stove, radio, note board, desk | bunk bed (in place of the bed), map table, tall cupboard, trunk, lamp |

---

## 3. Trees

**Today:** four trees (pine, fir, oak and dead), each with one other version, at 32 × 48. The forest repeats a lot.

### Sheet 5: New trees (5 × 2 grid of 32 × 48)

Five new kinds, each drawn twice: the first row as the main picture, the second row as a slightly different second version (a branch moved, a little shorter or leaning).

1. **Birch:** a white trunk with dark marks and a light, airy yellow-green crown.
2. **Spruce:** tall, narrow and dark blue-green, with drooping tiers. It must read differently from today's fir.
3. **Maple:** a round, full crown in a warmer green than the oak, with a hint of red at the edges.
4. **Aspen:** a slim pale trunk with a small, rounded, bright green crown. Good in clumps by water.
5. **Old cedar:** short and wide, with a thick reddish trunk and a heavy, shaggy crown. Rare, near the old trail.

> [Style line]. A 5 by 2 grid of 32 by 48 pixel art trees for a top-down forest game, three-quarter view from above, transparent background, each tree's trunk standing on the bottom middle of its cell, a one-pixel dark outline. Columns: a birch with a white trunk with dark marks and a light airy yellow-green crown; a tall narrow dark blue-green spruce with drooping tiers; a maple with a round full warm-green crown touched with red at its edges; a slim pale aspen with a small rounded bright green crown; a short wide old cedar with a thick reddish trunk and a heavy shaggy crown. Row 2 is a second version of each tree above it, slightly different in shape.

### Sheet 6: More of today's trees (4 × 2 grid of 32 × 48)

Two more versions of each tree the game has, so each has four. The columns are pine, fir, oak and dead tree. In each column:
- Row 1 is **bigger**, an old tree.
- Row 2 is **smaller**, a young tree about two-thirds the height, standing on the same spot.

Match today's pictures (`art/final/obj_tree_pine.png` and the others) in colour and outline.

> [Style line]. A 4 by 2 grid of 32 by 48 pixel art trees for a top-down forest game, matching the existing pine, fir, oak and dead tree sprites, transparent background, each trunk on the bottom middle of its cell. Columns: pine, fir, round oak, bare dead tree. Row 1: a bigger, older version of each, filling its cell. Row 2: a young version about two-thirds the height.

**What the lab will do:**
- Mix the new trees into the forest: birch and aspen near water and meadows, spruce in the deep forest, maple with the oaks, and cedar rare.
- Let each tree pick from its versions, so no two stands look the same.

---

## 4. Calmer ground

**Today:**
- The ground was made quieter on 17 November: about half of each tile's marks were painted out, and the calmest version is used most.
- Small details (daisies, clover, leaves and so on) are scattered on about 1 in 100 tiles.

It still reads busy.

**What the lab does now, with no new art:**
- **Fewer marks:** today's tiles are quietened further. Grass and forest floor keep about a quarter of their marks, down from half.
- **Calmest tile most of the time:** the calmest version is used on nearly every tile, and the other three only now and then.
- **Fewer details:** the scattered details drop to about a third of today's.

### Sheet 7: Plain ground (4 × 2 grid of 16 × 16)

One plain version of each main ground, for the lab to use on most tiles:
- **Row 1:** grass, tall grass, forest floor, trail.
- **Row 2:** rock, bog, shallows, deep water.

**Plain means:**
- the base colour, with only **three to five** small, soft marks per tile;
- each mark one shade off the base;
- no mark touching the tile's edge.

Today's busier tiles stay, kept for now and then.

> [Style line]. A 4 by 2 grid of 16 by 16 seamless pixel art ground tiles for a top-down forest game, very calm and plain: each tile is mostly one flat base colour with only three to five tiny soft marks one shade off the base, no marks near the tile edges, no outlines, no near-black or white. Row 1: meadow grass; tall grass; brown forest floor; packed dirt trail. Row 2: grey rock; dark green bog; light blue shallow water; deep blue water.

---

## 5. Water

**Your picture didn't come through.** The note says to use the water tiles "like in this image", but no image was attached. Please send it, and the lab will match it.

**Today:** water is two plain square tiles, shallows and deep water, with four versions each. Where water meets land it's a hard square edge, and nothing moves.

**What the lab expects to need, to be fitted to your picture once it comes:**
- **Shore edges:** a set of edge pieces where shallows meet grass, and again where deep water meets shallows. That's the 4 sides, the 4 outer corners and the 4 inner corners, 12 pieces each at 16 × 16, laid out as in the edge guide from Art Request 05 (`docs/art/art_request_05_edge_guide.png`). A soft sand or pebble line works well on the land side.
- **Movement:** two or three frames of the open water tiles, with ripples or glints that shift a little. The game cycles them slowly.
- **Small extras:** lily pads, a reed clump at the edge and a few ripples, each 16 × 16. The game scatters them sparingly.

The lab will send the exact sheet layout once your picture arrives.

---

## 6. The map: no more walked lines (lab only, no art)

**Today:** the map draws a line on every tile you've stepped on, so after a few days it's a tangle of lines.

**Change:** walking no longer draws lines. The ground around you fills in as you walk, in a circle a few tiles wide, so the map simply opens up where you've been.
- Trails you've dug or found still show as trails.
- Marked places and job flags stay as they are.
- In an older save, the walked lines are turned into revealed ground.

---

## 7. Light in the buildings at night

**Change (lab):**
- At night, any building that is open shows a warm glow in its windows from outside, with a soft pool of light on the ground by the door.
- Inside, the room lifts out of the night tint around a lit lamp or a lit stove.
- A building that isn't open yet stays dark.
- The station is always lit, since it's home.

The lab can do this much in code: a warm glow drawn over each window and a soft round light around lamps and stoves. Lit window pictures would make it look much better.

### Sheet 9: Night (draw at each building's own size, one per cell)

The lit version of each open building, the same as today's picture but with its windows glowing warm yellow and a little light spilling out of the doorway:

| Cell | Building | Size |
| --- | --- | --- |
| 1 | Ranger station | 125 × 92 |
| 2 | Old cabin (repaired) | 79 × 79 |
| 3 | Static tower (repaired) | same as `building_tower_repaired.png` |

Send each as its own picture, or side by side on one sheet with a gap between.

> [Style line]. The same [building] as the attached picture, drawn at night: identical in shape and outline, its windows glowing warm yellow and orange, a little warm light spilling from the doorway onto the step, the rest of the building unchanged.

---

## 8. The jobs-page look in the other screens

The jobs page (the clipboard) reads well, so the lab will carry its look into the other screens. It's built from:
- the wooden frame;
- the cream paper;
- tabs along the top;
- ribbons over each group;
- cards with a pin mark;
- the yellow band for what matters next.

**Lab, with today's art:**

| Screen | Becomes |
| --- | --- |
| Backpack | paper on the frame, with tabs for Backpack, Chest and Shelf |
| Workbench and cooking | paper on the frame; a list of cards on the left and the chosen recipe on the right, like a job's detail |
| The book (B) | the same frame and tabs: Park, Ledger, Cards, Letters, Notebook, Badges |
| Catalog | cards with a price tag, under a ribbon for each kind |
| Options and pause | a smaller paper on the frame |
| Map | its legend and travel list on a paper card at the side |

### Sheet 10: A few UI pieces (optional; the lab can stretch today's)

1. **A plain wooden frame without the clipboard clip**, 480 × 270, the same wood as the clipboard. For screens that aren't jobs (the backpack, the book). A 9-slice version is even better: four 16 × 16 corners and four edge strips.
2. **Six small tab icons**, 12 × 12 each: backpack, chest, shelf, book, coin (ledger) and gear (options).
3. **A recipe card**, the same size as the job list card (`ui_jcard`), with a small fire or hammer corner mark to tell cooking from crafting.

> [Style line]. Pixel art UI pieces for a cozy forest game, transparent background, one-pixel dark walnut outline: a 480 by 270 wooden board frame in honey wood with darker walnut edges and small nail heads at the corners, empty in the middle; six 12 by 12 tab icons in a row: a green backpack, a wooden chest, a shelf, a closed book, a gold coin, a grey gear.

---

## What the lab does when the sheets come back

1. Cut each sheet into the game's pictures. They'll drop in where the stand-ins are, and the art cleanup report will list every one.
2. Fill the rooms, mix in the trees, and switch the ground to the plain tiles on most tiles.
3. Build the shore edges and the water's movement to match your picture.
4. Show you screenshots of each change before the next build.

The lab-only changes (the map, the lights in code, the calmer ground and the screens restyled from today's art) can go ahead before any sheets come back.

## When you send it back

- One PNG per sheet, named as in the table at the top, on a transparent background.
- Exact size, at the game's pixel size: not scaled up.
- If a cell isn't ready, leave it empty and send the rest.
