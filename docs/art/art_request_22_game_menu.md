# Strange Ranger: Art Request 22 (revised), the gear wall

From the lab, 23 November 2026. **This replaces the first Art Request 22**, which asked for tab pictures and a backdrop for a farming-game style menu. The designer found that menu too close to Stardew Valley, so in 0.7.10 the menu became something of our own: **the gear wall at the trailhead.**

The pack page is a wall of boards. On it hang:

- the ranger's **park ID card**, with their photo at dusk and the park patch stamped on its corner
- the **pack**, opened, with the hip belt's ten pockets (the item bar) over the main compartment's stitched canvas, and a Repack strap, Drop and a Leave No Trace bin below it
- the **gear wall**: the hat on a peg, the coat on a hanger, the boots on a mat, and spare clothes on a rail of pegs

The menu's tabs are **round scout patches** sewn along the top. Pointing at an item swings down a **paper tag on twine**, with its kind stamped in red.

All of it works now, drawn by code with the game's existing pictures. These sheets would give it your hand. **Nothing waits on them.** The screenshots in the email show it as it is.

## Rules

The same as Art Requests 17 to 21: the bright palette, a one-pixel dark outline, light from the top left, big drafts are fine, cells on an even grid, and your colours are kept as drawn.

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

## G1. Six scout patches (the tabs)

One sheet, 6 cells in a row, each **24 × 24**: round embroidered patches with a stitched rim, like your skill badges. Each has a bold picture in the middle, readable at a glance.

| Cell | Name | Patch colour | Picture |
| --- | --- | --- | --- |
| 1 | `ui_patch_pack` | pine green | a backpack |
| 2 | `ui_patch_jobs` | tan | a clipboard |
| 3 | `ui_patch_map` | sky blue | a folded trail map |
| 4 | `ui_patch_town` | coral | a little main street, or a house with a heart |
| 5 | `ui_patch_make` | brown | a hammer and saw crossed |
| 6 | `ui_patch_book` | violet | an open field book |

## G2. The ranger's photo backdrop

`ui_portrait_backdrop`, **56 × 60**: the view behind the ranger in their ID photo. Dusk River Park at dusk: a violet-to-orange sky, a first star, far blue hills, a ridge of pines, and a strip of grass along the bottom 12 pixels for the ranger to stand on. Keep the middle third of the lower half plain. No frame.

## G3. Gear wall pieces

One sheet, cells in a row.

| Cell | Name | Size | Picture |
| --- | --- | --- | --- |
| 1 | `ui_gear_peg` | 8 × 8 | a turned wooden peg, seen from the front |
| 2 | `ui_gear_hanger` | 24 × 10 | a wire coat hanger |
| 3 | `ui_gear_mat` | 30 × 6 | a little woven boot mat |
| 4 | `ui_gear_buckle` | 8 × 12 | a hip-belt buckle, grey plastic or brass |
| 5 | `ui_gear_clip` | 12 × 6 | the metal clip the ID card hangs from |
| 6 | `ui_gear_bin` | 12 × 12 | a small Leave No Trace bin with the park pine on it |

## G4. Textures (optional)

Tiling textures for what the lab draws as flat colour today: `ui_wall_boards` (32 × 32, upright boards), `ui_pack_canvas` (16 × 16, khaki canvas weave) and `ui_belt_webbing` (16 × 16, olive webbing). Tiles must join seamlessly on all four sides.

Name the sheets `ar22_G1_patches.png`, `ar22_G2_backdrop.png`, `ar22_G3_pieces.png` and `ar22_G4_textures.png`. The lab cuts them and drops them in.
