# Strange Ranger: Art Request 18, Insides

From the lab, 22 November 2026. This is the interior art request you asked to hold until your reference pictures came (tracker #27). It covers the shops in Humdrum (new in 0.6.2) and the pieces the station, cabin and tower still borrow from older sets.

Your two Stardew pictures are saved in `ref/stardew_interiors/` (kept out of git). They are for **how a room reads**, not for copying: no Stardew pieces, layouts or colours are to be traced. Everything stays in our bright palette and our own style.

## What your pictures show, and what we take from them

1. **The room has a shape.** A thick dark edge runs round the whole floor, and the room sits in black. Rooms can be L-shaped, not only boxes. *We take:* a dark border piece for the room's edge, and rooms that may step in and out.
2. **The back wall is tall and busy, the floor is calm.** About three tiles of wall with windows, pictures and posters spaced along it; the floor is long warm boards running one way with almost no pattern. *We take:* our walls carry the decoration; floors are lighter and warmer than ours today, and quieter.
3. **Windows throw light.** Each window drops a soft pale shaft onto the floor below it. *We take:* a window with its light shaft drawn as a separate see-through piece, so the game can turn it off at night.
4. **Rugs make the zones.** A big rug under the bed, another under the table, and that is how you know where each corner begins. *We take:* three rug sizes, used as the zone marker in every room.
5. **Few, big, chunky pieces.** Each piece has a strong outline and its own shape: you could name every piece from its silhouette. The small cabin has only a bed, a fireplace, a table and chair, a TV, a rug and one plant, and it is the clearest room of the two. *We take:* fewer pieces, drawn bigger, with nothing smaller than a mug loose on the floor (the Interior Art Guide's rules still hold).
6. **Colour accents pop against the floor.** Red armchairs and rugs, green plants and blue appliances stand out from the orange floor because the floor is one quiet family of colour. *We take:* each shop gets one accent colour, picked from the palette, repeated in its rug, its chairs and its sign.
7. **Plants fill corners.** Potted plants sit in the gaps that would otherwise look empty. *We take:* a set of potted plants in three sizes.
8. **Furniture hugs the walls; the middle stays open.** *We take:* this is already our layout rule (0.6.1), so the art just needs to fit the sizes below.

## How the shops are laid out today (0.6.2)

The lab laid out all seven shops to these rules with stand-ins. Screenshots are in `docs/status/062_shots/`. Every room is 12 to 15 tiles wide and 10 or 11 tall, the counter has the keeper behind it, and there is a clear way from the door to the counter.

| Shop | Accent | What's in it |
| --- | --- | --- |
| The Percolator | Cream and green | Café counter with a coffee machine on the left, three café tables, a goods shelf |
| Casa Luna | Terracotta and red | Restaurant counter with the stove behind, three tables, a rug |
| Humdrum Outfitters | Forest green | Counter, two goods shelves, a coat rack, a boot display, a wardrobe |
| Gifts & Notions | Pink | Counter, two goods shelves, a low cupboard |
| Lindqvist Carpentry | Pale wood | Counter, a big workbench, a lumber pile, a tool shelf |
| Humdrum Public Library | Deep blue | Four tall bookcases, the front desk, two reading tables |
| Town Hall and post office | Slate | Post office counter, the mayor's desk, a notice board, a cupboard |

## Rules for every sheet

Same as Art Request 17:

- **Style:** the bright palette, a one-pixel dark outline, and light from the top left.
- **Placement:** each piece stands on the bottom middle of its cell.
- **Size:** big drafts are fine. The lab cuts and shrinks them to the game size given.
- **Layout:** cells on an even grid. Thin grid lines between cells are fine.
- **Two faces:** every piece shows its top and its front (Interior Art Guide, rule 1).

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

**Interior line, after the style line:**

> Interior furniture seen from a top-down three-quarter view, showing each piece's top and front. Chunky shapes with a strong one-pixel outline, two or three tones per material, a contact shadow under each piece. Each piece must be recognisable from its silhouette alone.

## The sheets at a glance

| # | File | Grid | What | Priority |
| --- | --- | --- | --- | --- |
| 1 | `ar18_shell.png` | 4 × 3 | Floors, wall faces, the room's dark edge, windows and light shafts, the doormat | High |
| 2 | `ar18_counters.png` | 4 × 2 | Shop counters, the bookcase, goods shelves | High |
| 3 | `ar18_shop_pieces.png` | 4 × 3 | The pieces each shop needs | High |
| 4 | `ar18_comfort.png` | 4 × 2 | Rugs, potted plants, an armchair, wall pictures | Medium |

---

## Sheet 1: The room's shell (4 × 3)

| Cell | Name | Game size | What |
| --- | --- | --- | --- |
| 1 | `interior_boards_warm` | 16 × 16 | Warm honey floorboards running left to right, two close tones, broken seams |
| 2 | `interior_boards_warm_alt_1` | 16 × 16 | The same, seams in other places |
| 3 | `interior_boards_warm_alt_2` | 16 × 16 | The same, one board a shade lighter |
| 4 | `interior_tiles_checker` | 16 × 16 | Cream and terracotta floor tiles, for Casa Luna and the Percolator |
| 5 | `interior_wall_planks` | 16 × 48 | A cream planked back wall, three tiles tall, with a trim along its top |
| 6 | `interior_wall_brick` | 16 × 48 | A warm red brick back wall, three tiles tall, for the carpentry and Casa Luna |
| 7 | `interior_wall_paper` | 16 × 48 | A striped wallpaper back wall with a wooden skirting board, for the library and Gifts & Notions |
| 8 | `interior_edge` | 16 × 16 | The room's dark outer edge seen from above, with a lighter inside lip (tiles as corners and straights: please draw one straight, one outer corner and one inner corner in the cell, side by side) |
| 9 | `interior_window_day` | 32 × 32 | A window with a wooden frame and sill, sky and a hint of trees outside |
| 10 | `interior_window_night` | 32 × 32 | The same window at night: deep blue, one star |
| 11 | `interior_light_shaft` | 32 × 48 | The pale shaft of light a window drops onto the floor, on a transparent background |
| 12 | `interior_doormat` | 32 × 16 | A woven doormat at the door, two tiles wide |

**Prompt:**

> [style line] [interior line] A 4 by 3 sheet of interior building pieces on a plain background, each piece centred in its cell. Row 1: three seamless warm honey-coloured floorboard tiles running left to right with broken seams, and one cream and terracotta checker floor tile. Row 2: three tall back-wall strips, three tiles tall: cream wooden planks with a top trim, warm red brick, and striped wallpaper over a wooden skirting board; then the dark outer edge of a room seen from above, as a straight, an outer corner and an inner corner. Row 3: a wooden window with sky and trees by day, the same window at night in deep blue with one star, a soft pale shaft of window light on a transparent background, and a woven doormat.

## Sheet 2: Counters and shelves (4 × 2)

| Cell | Name | Game size | What |
| --- | --- | --- | --- |
| 1 | `int_shop_counter` | 48 × 32 | A wooden shop counter with panelled front and a brass till on top |
| 2 | `int_shop_counter_cafe` | 48 × 32 | A café counter with a cream top, a coffee machine and a cake stand under glass |
| 3 | `int_shop_counter_restaurant` | 48 × 32 | A restaurant counter with painted tiles on the front and a pot of something steaming |
| 4 | `int_post_counter` | 48 × 32 | A post office counter with a brass grille and a rack of pigeonholes behind it |
| 5 | `int_bookcase` | 32 × 48 | A tall bookcase, three shelves of coloured book spines, a few leaning |
| 6 | `int_goods_shelf` | 32 × 48 | A shop shelf of jars, boxes and folded cloth in three bright colours |
| 7 | `int_display_table` | 32 × 32 | A low display table with a few things set out on a cloth |
| 8 | `int_front_desk` | 48 × 32 | The library's front desk with a lamp, a stack of books and a date stamp |

**Prompt:**

> [style line] [interior line] A 4 by 2 sheet of shop furniture on a plain background, each piece centred in its cell. Row 1: a wooden shop counter with a panelled front and a brass till; a café counter with a cream top, a coffee machine and a cake under a glass dome; a restaurant counter with painted tiles on the front and a steaming pot; a post office counter with a brass grille and wooden pigeonholes. Row 2: a tall bookcase with three shelves of colourful book spines; a tall shop shelf of jars, boxes and folded cloth; a low display table with a cloth and a few small goods; a library front desk with a green lamp, a stack of books and a date stamp.

## Sheet 3: Each shop's own pieces (4 × 3)

| Cell | Name | Game size | Shop | What |
| --- | --- | --- | --- | --- |
| 1 | `int_cafe_table` | 32 × 32 | Percolator | A small round café table with two chairs and two cups |
| 2 | `int_menu_board` | 32 × 32 | Percolator | A chalk menu board on the wall, with a drawn cup |
| 3 | `int_restaurant_table` | 32 × 32 | Casa Luna | A square table with a bright woven cloth and two chairs |
| 4 | `int_bunting` | 48 × 16 | Casa Luna | Paper bunting in bright colours, strung along the back wall |
| 5 | `int_coat_display` | 32 × 48 | Outfitters | A rack of three coats (red, green, tan) with a hat on top |
| 6 | `int_boot_display` | 32 × 32 | Outfitters | A low step of three pairs of boots |
| 7 | `int_lumber_rack` | 48 × 32 | Carpentry | A rack of planks stacked by length |
| 8 | `int_tool_wall` | 32 × 32 | Carpentry | A pegboard of saws, hammers and planes for the back wall |
| 9 | `int_mayor_desk` | 48 × 32 | Town Hall | A grand desk with a flag, a stamp and a neat stack of papers |
| 10 | `int_filing_cabinet` | 16 × 32 | Library | The town archive's filing cabinet, tall and green |
| 11 | `int_gift_basket` | 16 × 16 | Gifts & Notions | A basket of wrapped gifts with ribbons |
| 12 | `int_reading_lamp` | 16 × 32 | Library | A standing reading lamp |

**Prompt:**

> [style line] [interior line] A 4 by 3 sheet of small-town shop furniture on a plain background, each piece centred in its cell. Row 1: a small round café table with two chairs and two cups; a chalk menu board with a drawn coffee cup; a square restaurant table with a bright woven cloth and two chairs; a string of bright paper bunting. Row 2: a clothes rack with a red, a green and a tan coat and a hat on top; a low step showing three pairs of boots; a rack of wooden planks stacked by length; a pegboard of saws, hammers and planes. Row 3: a grand wooden desk with a small flag, a stamp and papers; a tall green filing cabinet; a basket of wrapped gifts with ribbons; a standing reading lamp.

## Sheet 4: Comfort and colour (4 × 2)

| Cell | Name | Game size | What |
| --- | --- | --- | --- |
| 1 | `interior_rug_large` | 64 × 48 | A big oval rug, red with a cream border |
| 2 | `interior_rug_runner` | 48 × 16 | A long runner rug for a doorway |
| 3 | `interior_rug_round` | 32 × 32 | A small round woven rug, green and gold |
| 4 | `int_plant_tall` | 16 × 32 | A tall potted plant with broad leaves |
| 5 | `int_plant_small` | 16 × 16 | A small potted fern, for a table or shelf |
| 6 | `int_plant_flowering` | 16 × 32 | A potted plant with yellow flowers |
| 7 | `int_armchair` | 32 × 32 | A fat red armchair |
| 8 | `interior_pictures` | 16 × 16 | Four small framed pictures for walls: a mountain, a canoe, a bird, a pine (please draw all four in the cell's row, the lab cuts them apart) |

**Prompt:**

> [style line] [interior line] A 4 by 2 sheet of cosy interior pieces on a plain background, each piece centred in its cell. Row 1: a big red oval rug with a cream border; a long narrow runner rug; a small round woven rug in green and gold; a tall potted plant with broad leaves. Row 2: a small potted fern; a potted plant with yellow flowers; a fat red armchair; four tiny framed pictures side by side showing a mountain, a canoe, a bird and a pine tree.

---

## Not in this request

- **House insides** (the eight homes): the lab lays them out next, with these same pieces, and asks only for what's missing then.
- **The station's furniture** is Art Request 17, sheet 5. It stays there.
- **Townsfolk portraits** wait for the pixel artist brief.

## Checking the results

Drop the sheets in `art/raw/`. The lab cuts them, checks each piece at game size with the one-second and silhouette tests from the Interior Art Guide, and sends you screenshots of each shop with your pieces in place.
