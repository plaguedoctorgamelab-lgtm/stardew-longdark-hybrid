# Strange Ranger: Art Request 22, the game menu

From the lab, 23 November 2026. A small request. In 0.7.9 the backpack became a game menu, with picture tabs along the top: Backpack, Ranger, Jobs, Map, People, Crafting and Book. The Backpack page now has the ranger's half below the backpack. The ranger stands in a little window, their hat, coat and boots sit in slots beside them, and the park, the wallet and the date are written alongside. Pointing at an item shows a card saying what it is.

It all works now, using stand-in pictures borrowed from elsewhere in the game (item icons for the tabs, a backdrop drawn by code). These sheets replace the stand-ins. **Nothing waits on them**, so send them whenever suits you.

The screenshots attached to the email show the menu as it is today.

## Rules

The same as Art Requests 17 to 21: the bright palette, a one-pixel dark outline, light from the top left, big drafts are fine, cells on an even grid, and your colours are kept as drawn.

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

## M1. Seven tab pictures

One sheet, 7 cells in a row, each **16 × 16**, on a plain background. They sit on the existing blue tab (`ui_tab`), so keep the pictures bold and readable at a glance.

| Cell | Name | Picture | Today's stand-in |
| --- | --- | --- | --- |
| 1 | `ui_tab_backpack` | **Keep the one you drew** (Art Request 16). Leave this cell empty. | yours |
| 2 | `ui_tab_ranger` | The ranger's flat hat with a tiny park badge | the hat item |
| 3 | `ui_tab_jobs` | A clipboard with a pinned note | the ledger tab |
| 4 | `ui_tab_map` | A folded trail map | the map item |
| 5 | `ui_tab_people` | Two small faces, or a heart over a little house | a heart |
| 6 | `ui_tab_crafting` | A hammer crossed with a saw | the hammer item |
| 7 | `ui_tab_book` | **Keep the one you drew.** Leave this cell empty. | yours |

## M2. The ranger's window

`ui_portrait_backdrop`, **56 × 72**, portrait shape. The view behind the ranger on the backpack page: Dusk River Park at dusk, with a violet-to-orange sky, a first star, far blue hills, a ridge of pines, and a strip of grass across the bottom 14 pixels. The ranger stands on that grass, so keep the middle third of the lower half plain. No frame: the game draws the wooden edge.

## M3. Small pieces

One sheet, 2 cells in a row.

| Cell | Name | Size | Picture |
| --- | --- | --- | --- |
| 1 | `ui_coin` | 10 × 10 | A gold coin with the park's pine on it, for the wallet line |
| 2 | `ui_sort` | 16 × 16 | Two arrows, up and down, painted like a trail sign, for the "tidy the backpack" button |

Name the sheets `ar22_M1_tabs.png`, `ar22_M2_backdrop.png` and `ar22_M3_pieces.png`. The lab cuts them and drops them straight in.
