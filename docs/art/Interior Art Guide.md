# Interior Art Guide

Special rules for the insides of buildings: the station, the cabins and the fire tower. They fix three problems with the first interior art: rooms look flat, small items are too busy to recognize, and furniture is crammed together. Where these rules and the main style guide disagree about interiors, these win.

The guide has four parts: rules for drawing interior pieces, rules for laying out rooms, the code the lab adds, and ready-to-paste prompts to redraw the interior set.

## Part one: drawing interior pieces

### 1. Every piece shows two faces

The view is the same top-down three-quarter view as outdoors. Every piece of furniture shows **its top and its front**: a table's top and its front edge and legs; a bed's blanket and its footboard; a chest's lid and its front panel; a stove's top and its door. A piece that shows only its top looks flat and is redone.

### 2. Furniture gets room to breathe: multi-tile sizes

Nothing larger than a mug is squeezed into one 16 by 16 tile. These are the sizes for the interior set, in game pixels and in tiles. **Picture** is the whole drawing. **Blocks** is the part of the floor the ranger cannot walk through, always at the picture's bottom.

| Piece | Picture | Tiles | Blocks |
| --- | --- | --- | --- |
| Bed | 32 by 48 | 2 by 3 | 2 by 2 |
| Wood stove | 32 by 32 | 2 by 2 | 2 by 1 |
| Small stove (tower) | 16 by 32 | 1 by 2 | 1 by 1 |
| Workbench | 48 by 32 | 3 by 2 | 3 by 1 |
| Desk | 48 by 32 | 3 by 2 | 3 by 1 |
| Table | 32 by 32 | 2 by 2 | 2 by 1 |
| Chair | 16 by 32 | 1 by 2 | 1 by 1 |
| Chest | 32 by 32 | 2 by 2 | 2 by 1 |
| Map table (tower) | 32 by 32 | 2 by 2 | 2 by 1 |
| Supply shelf | 32 by 48 | 2 by 3 | 2 by 1 |
| Firewood stack | 32 by 32 | 2 by 2 | 2 by 1 |
| Trash can | 16 by 32 | 1 by 2 | 1 by 1 |
| Rug | 48 by 32 | 3 by 2 | None |
| Window, on the back wall | 32 by 32 | 2 by 2 | None |
| Wall shelf, note board, staff board, coat pegs | 32 by 32 | 2 by 2 | None |
| Small props, on surfaces | 16 by 16 | 1 by 1 | None |

### 3. Light, shadow and edges

- **Light from the top left,** as everywhere else.
- **A contact shadow** under every piece that stands on the floor: one to two pixels of the darkest palette color, `#1a1620`, along the floor just below its base, and under any overhang such as a table top or bed frame.
- **A highlight** along the top front edge of every flat top: tables, desks, shelves, chests, the stove. One pixel of the material's lightest tone, or cream `#f6ecd0` for pale wood.
- **Two or three tones per material,** never one flat color and never a staircase of many.
- **Outlines** one pixel wide, in a dark shade of the piece's own color, so it separates from the floor.

### 4. Small things are simple

- Small props are drawn like icons: one bold shape, two or three colors, nothing finer than a single game pixel.
- **The one-second test:** at game size, can you name it in one second? If not, it is redone simpler.
- **The silhouette test:** filled with one dark color, is it still recognizable? A mug, a lantern, a radio and a book should each have a shape of their own.

### 5. Floors and walls stay quiet

Floors and walls are the background. They must never compete with what stands on them.

- **Floors** use two close mid tones: boards in `#9a6b42` with seams in `#6b4a32`, never the darkest brown. Board seams are broken and irregular, not a hard grid. Three or four floor variants are mixed at random so no pattern repeats.
- **The back wall** is three tiles tall (48 pixels), drawn as a wall face with a trim along its top. Walls are a touch lighter than the floor, so the room reads as a box.
- **Side walls** are a one-tile strip seen from above along the room's left and right edges.
- **Furniture is lighter and higher in contrast** than the floor beneath it, so every piece stands out.

## Part two: laying out rooms

### Rules

1. **Leave breathing room.** At least one clear tile between groups of furniture, and between furniture and the side walls where possible.
2. **Keep the way clear.** A clear path at least two tiles wide from the door to the bed, and one tile wide to every piece the ranger uses.
3. **Group by purpose.** A sleeping corner, a warm corner by the stove, a work corner. Each group reads as one idea.
4. **Small things sit on big things.** Lanterns, radios, mugs, books and jars go on a table, desk or shelf, never loose on the floor. The only things on the floor are furniture, rugs, the trash can and a pair of boots.
5. **Don't fill the floor.** Furniture covers no more than about 40% of the floor.
6. **The back wall carries decoration.** Windows, boards, shelves and pegs go on the back wall, spaced with plain wall between them.
7. **The room sits in the dark.** A room smaller than the screen is centered, with darkness around it. The camera does not move in a room that fits the screen.
8. **The way out is plain.** The exit is a doormat at the front edge of the floor. Walking off it leaves.

### The three rooms

These plans are guides. The lab may move a piece by a tile to suit the art, but must keep the rules. Each square is one floor tile; the back wall runs above the first row.

**Key:** B bed · S stove · s small stove · K workbench · E desk · T table · c chair · C chest · M map table · P supply shelf · F firewood · R rug · t trash can · b boots · H hatch · D doormat · . clear floor

**The old cabin.** Floor 8 by 6. Back wall, left to right: wall shelf, window, coat pegs with a lantern.

```text
     0 1 2 3 4 5 6 7
  0  B B . . . . S S
  1  B B . . . . S S
  2  B B . R R R . .
  3  . . . R R R . F
  4  C C . . . T T F
  5  . . . D . T T c
```

A workbench kit, when placed, goes against the back wall at x 2 to 4, under the window.

**The fire tower room.** Floor 7 by 7. Back wall: a window at each end, plain wall between. Its way out is a hatch in the floor, not a doormat.

```text
     0 1 2 3 4 5 6
  0  B B . . . . s
  1  B B . M M . s
  2  B B . M M . .
  3  . . . . . . .
  4  C C . R R . F
  5  . . . R R . F
  6  . . . H . . .
```

The radio stands on the map table.

**The ranger station.** Floor 12 by 8. Back wall, left to right: window, note board, window, staff board. The radio, the catalog and the job papers sit on the desk.

```text
     0 1 2 3 4 5 6 7 8 9 10 11
  0  B B . . K K K . . S S  .
  1  B B . . K K K . . S S  .
  2  B B . . . . . . . . .  P
  3  . . . R R R . . . . .  P
  4  C C . R R R . T T c .  P
  5  . . . . . . . T T . .  .
  6  E E E . . . . . . . .  .
  7  E E E . . b D t . . F  F
```

The station's untidy spots for Get the Station Shipshape are the desk, the wall shelf by the window and the boots by the door. The trash can for that job stands just right of the doormat.

## Part three: what the lab adds in code

1. **Depth sorting indoors,** as outdoors: every piece and character is drawn in order of its base, so the ranger passes behind the bed's headboard and in front of its footboard.
2. **Contact shadows as a fallback.** If a piece's art lacks its contact shadow, the game draws a one-pixel `#1a1620` strip under its base, so every piece looks planted while art is redone.
3. **What am I looking at?** The piece the ranger is facing and can use gets a one-pixel cream outline, and its name appears in small text above it: "Wood stove", "Chest". This alone fixes most of "I can't tell what it is."
4. **Light at night.** Windows go dark blue after dusk; a lit stove casts a warm, flickering glow on the floor around it; a lantern on a table lights a small circle. These use the existing tint and overlays, as in the Graphics Polish request.
5. **Room framing.** Rooms are centered with darkness around them; the camera stays still in a room that fits the screen.
6. **Layout data.** Each room's layout is content data, one row per piece with its position, so rooms can be adjusted without code and the furnishing of cabins can come later.

## Part four: prompts to redraw the interior set

Make these as before: one ChatGPT conversation; paste the main **style block**, then the **interior line** below, then the prompt. Attach the accepted ground tile sheet as the style reference, and add "Match the pixel size, colors and shading of the attached image." Save each in `art/raw/` under its name.

These replace the first batch's cabin interior sheet, `raw_interior_01.png`, and prompt 9 of the Jobs Art Request.

**The interior line:**

```text
THIS IS INTERIOR FURNITURE for a top-down game, seen from above and slightly in front, so every piece shows BOTH its top surface AND its front face (legs, drawers, side thickness). Light from the top left. A thin dark contact shadow on the floor directly under each piece's base. A one-pixel light highlight along the top front edge of every flat surface. Two or three tones per material. Simple, bold shapes that read clearly at a small size. No room, no floor and no walls around the pieces unless asked for.
```

| Prompt | Save as | Layout | Contents |
| --- | --- | --- | --- |
| 1 | `raw_int_floors_01.png` | 4 by 4 | Floor tiles |
| 2 | `raw_int_walls_01.png` | 6 across | Back wall sections |
| 3 | `raw_int_furniture_big_01.png` | 3 by 2 | Large furniture |
| 4 | `raw_int_furniture_01.png` | 4 by 3 | Smaller furniture and wall pieces |
| 5 | `raw_int_tidy_01.png` | 2 by 3 | Untidy and tidy station pieces |
| 6 | `raw_int_props_01.png` | 4 by 4 | Small props for surfaces |

**Prompt 1. Save as `raw_int_floors_01.png`**

```text
Create a square 1024 by 1024 image: a sheet of 16 indoor floor tiles for a top-down game, in a 4 by 4 grid with no gaps and no lines between them. Each tile is 256 by 256 and fills its cell edge to edge, seen from directly above. Draw it as if the sheet were a 64 by 64 pixel canvas enlarged 16 times, so each tile is 16 by 16 big square pixels.

Every tile must repeat seamlessly. Keep them QUIET: low contrast, two close tones of brown, few details, so things placed on them stand out.

Row 1: four variations of a cabin floor of narrow wooden boards, mid brown with slightly darker seams, seams broken and irregular.
Row 2: four variations of a station floor of wider, slightly paler boards.
Row 3: four variations of a fire tower floor of pale, weathered boards.
Row 4: two variations of flat grey hearth stone; a woven doormat filling the tile; a square trapdoor hatch set into wooden boards.
```

**Prompt 2. Save as `raw_int_walls_01.png`**

```text
Create a 1536 by 1024 image: six tall back-wall sections for the inside of buildings in a top-down game, side by side in a row of six equal cells, each cell 256 wide. Draw it as if the image were a 96 by 64 pixel canvas enlarged 16 times. Each section is 16 pixels wide and 48 pixels tall on that small canvas, standing at the bottom of its cell, seen face-on.

Each section is a wall face with a wooden trim along its top and a darker skirting board along its bottom. Each must join seamlessly to the left and right with the others of its kind.

1 and 2: horizontal log wall, warm light brown, two variations.
3 and 4: smooth vertical plank wall, slightly paler, two variations.
5: the left end of a log wall, with a corner post.
6: the right end of a log wall, with a corner post.

Keep the walls quiet: a touch lighter than a mid-brown floor, low contrast, simple.
```

**Prompt 3. Save as `raw_int_furniture_big_01.png`**

```text
Create a 1536 by 1024 image with a transparent background: six large pieces of furniture in a 3 by 2 grid of equal cells, each cell 512 by 512. Draw each piece as if on a small pixel canvas enlarged 8 times, at the game size given, centered in its cell, standing on the bottom of the cell area.

Row 1:
- A single wooden bed with a red plaid blanket and a cream pillow: 32 wide by 48 tall. Headboard at the top, footboard at the bottom, blanket on top between them.
- A black cast-iron wood stove with a short pipe and a small door showing a glowing fire: 32 by 32.
- A sturdy workbench with a vice, a saw hanging on its front and a few tools on top: 48 wide by 32 tall.
Row 2:
- A wooden desk with two drawers, its top neat and clear: 48 by 32.
- A wooden storage chest with iron bands and a latch: 32 by 32.
- A tall wooden supply shelf with three shelves holding crates, planks and a bag of nails: 32 wide by 48 tall.

Every piece shows its top AND its front face, with a thin dark shadow on the floor under it.
```

**Prompt 4. Save as `raw_int_furniture_01.png`**

```text
Create a 1536 by 1152 image with a transparent background: twelve pieces for the inside of a cabin, in a 4 by 3 grid of equal cells, each cell 384 by 384. Draw each piece as if on a small pixel canvas enlarged 8 times, at the game size given, centered in its cell.

Row 1: a small square wooden table, 32 by 32; a wooden chair facing down, 16 wide by 32 tall; a round table with a map spread on it and a compass, 32 by 32; a neat stack of split firewood, 32 by 32.
Row 2: a rectangular woven rug in muted reds and creams, lying flat, 48 wide by 32 tall; a small narrow iron stove with a tall pipe, 16 wide by 32 tall; a cork note board with three blank pinned papers, 32 by 32; a wooden board with a few blank cards pinned in rows, 32 by 32.
Row 3: a window with four panes and wooden shutters, seen face-on as if set in a wall, 32 by 32; a wall shelf holding a few jars and tins, 32 by 32; a row of coat pegs with a coat and a hanging lantern, 32 by 32; a metal trash can with a lid, 16 wide by 32 tall.
```

**Prompt 5. Save as `raw_int_tidy_01.png`**

```text
Create a 1024 by 1536 image with a transparent background: three pairs of objects, untidy on the left and tidy on the right, in a 2 by 3 grid of equal cells, each cell 512 by 512. Draw each as if on a small pixel canvas enlarged 8 times, at the game size given, centered in its cell. Each tidy object must be exactly the same size and shape as its untidy partner.

Row 1: the same wooden desk with two drawers, 48 by 32: left, its top heaped with messy papers and an old mug; right, the papers in one neat stack beside the mug.
Row 2: the same wall shelf, 32 by 32: left, dusty, with cobwebs and things tipped over; right, clean, with jars standing in a neat row.
Row 3: boots by a door, 32 wide by 16 tall: left, a jumbled pile of old boots and a coat dropped on top; right, one neat pair of boots side by side.
```

**Prompt 6. Save as `raw_int_props_01.png`**

```text
Create a square 1024 by 1024 image with a transparent background: 16 small props that sit on tables and shelves, in a 4 by 4 grid of equal cells, each cell 256 by 256. Draw it as if the sheet were a 64 by 64 pixel canvas enlarged 16 times, so each prop is at most 16 by 16 big square pixels. Each prop is ONE bold, simple shape with two or three colors, centered, recognizable at a glance. No fine detail.

Row 1: an old wooden radio with a round dial; an oil lantern with a warm glow; a tin mug; a short stack of three books.
Row 2: a jar of red preserves; two tin cans; a rolled map tied with string; a pile of papers.
Row 3: a candle in a holder; a fern in a clay pot; a black kettle; a plate with a sandwich.
Row 4: a brass compass; a small round clock; a picture frame with a plain blank picture; a pencil cup with two pencils.
```

## Checking the results

Before accepting a piece, check:

- [ ] It shows both its top and its front.
- [ ] It has a contact shadow and a top-edge highlight.
- [ ] You can name it in one second at game size.
- [ ] Its silhouette alone is recognizable.
- [ ] It stands out clearly against the floor tiles.
- [ ] Untidy and tidy versions match in size and shape exactly.

Then ask the lab to build one room, the old cabin first, and look at it in game, by day and by night, before redrawing anything else.
