# Strange Ranger: Art Request 27, the new festivals and the birds

From the lab, 27 November 2026. The year's festivals are changing, and birds are coming to the park. Code for both waits for these sheets, so both go in together.

**The new festival year:**

| Season | Festival | Day | What happens |
| --- | --- | --- | --- |
| Spring | **Lantern Night** (moved from summer) | Spring 20, evening | Paper lanterns floated down the creek on the snowmelt, each with a wish |
| Summer | **Midsummer** (new) | Summer 14, dusk to midnight | A huge wicker moose in the square, filled with wishes and burned at dusk, with fireflies everywhere |
| Autumn | **Samhain** (new) | Autumn 28, evening | Pumpkin carving judged by the town, costumes, apple bobbing, trick-or-treat at the shop doors |
| Winter | **The Big Foot Supper** (moved from autumn) | Winter 18, evening | The Look-Alike Contest and the long-table supper, now in the snow by braziers |

The Thaw Fair and the Long Night are retired. Their pieces you've already drawn stay in use: the judges' stand, the display table and the stall carry on at Samhain, and the log benches go round the wicker moose.

## Rules for every sheet

The same as Art Requests 17 to 26:

- **Style:** the bright palette, a one-pixel dark outline, and light from the top left.
- **Placement:** each piece stands on the bottom middle of its cell.
- **Size:** big drafts are fine. The lab cuts and shrinks them to the game size given.
- **Strange at night and magic only:** the festivals are ordinary town fun; only the magic crow and the magic owl glow.

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

---

# Part A: the festivals

## F1. Lantern Night, now in spring

Everything is drawn already: the floating lanterns, the lantern on a stick, the lantern strings and the prize lantern. **Nothing new is needed.** If you'd like, a spring touch:

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Pussy willows in a jar (optional) | `fest_willow_jar` | 16 × 24 | A glass jar of pussy willow stems, for the stall and the square's edges |

## F2. Midsummer: the wicker moose

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| The wicker moose | `fest_wicker_moose` | 64 × 80 | A huge moose woven from willow and straw, standing in the square on a low log platform. Paper wishes and ribbons tucked all over it. Proud and a little lopsided, plainly made by the town, by hand |
| The moose burning | `fest_wicker_moose_burn_0` to `_3` | 64 × 80 | The same moose with tall cheerful flames, four frames so they flicker. Warm and festive, a summer bonfire, not scary |
| What's left | `fest_wicker_moose_embers` | 64 × 32 | A glowing ring of embers and the charred log platform, for after midnight |
| A wish tag | `fest_wish_tag` | 8 × 16 | A small paper tag on a loop of string, as tucked into the moose |
| Summer garlands | `fest_garland_summer` | 32 × 16 | Daisies, yarrow and green leaves strung between the lamps |
| Flower crown | `fest_flower_crown` | 4 × 4 of 16 × 32, the townsfolk layout | A crown of daisies and clover to sit on anyone's head, the ranger's too. Only the crown, on transparent |
| The prize | `decor_wicker_moose` | 16 × 24 | A small wicker moose for the station, with a ribbon round its neck |

## F3. Samhain

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| A pumpkin | `fest_pumpkin` | 16 × 16 | A plain, uncarved orange pumpkin with a curly stem |
| Jack-o'-lanterns | `fest_jack_o_lantern_<face>_0` and `_1` | 16 × 16 | Carved and lit, two frames so the candle flickers. Five faces: `friendly`, `spooky`, `silly`, `cat` and `moose`. The ranger picks one to carve, and the town's pumpkins use the rest |
| Carving table | `fest_carving_table` | 48 × 32 | A trestle table with newspaper, pumpkin guts, a scoop and carving knives |
| Apple bobbing | `fest_apple_tub` | 32 × 24 | A wooden tub of water with red and green apples floating in it |
| A bowl of sweets | `fest_sweets_bowl` | 16 × 16 | A bowl of wrapped sweets, set on a stool at each shop door |
| Sweets | `item_sweets` | 32 × 32 | A small handful of wrapped sweets, as a backpack item |
| Samhain bunting | `fest_garland_samhain` | 32 × 16 | Orange and black bunting with little paper bats |
| A scarecrow | `fest_scarecrow` | 32 × 48 | A friendly straw scarecrow in a patched coat and a pumpkin head, for the square's corner |
| Corn stalks | `fest_corn_stalks` | 16 × 32 | A bundle of dried corn stalks tied with twine, for the lamps |
| Costumes | `fest_costume_ghost`, `fest_costume_witch`, `fest_costume_skeleton` | 4 × 4 of 16 × 32 each, the townsfolk layout | Costume overlays, the same idea as the Bigfoot suit: a bedsheet ghost with eye holes, a witch's hat and cape, and a skeleton onesie. Homemade and cheerful. They go over townsfolk and the ranger alike |
| The prize | `decor_ribbon_samhain` | 16 × 24 | A prize rosette for the station wall, orange and black, with a tiny pumpkin in the middle |

The ranger also keeps their own jack-o'-lantern for the station. That's the carved face they chose, so no extra piece is needed.

## F4. The Big Foot Supper, now in winter

The Bigfoot suit, the supper table, the benches and the sash are all drawn already. What's new is the snow.

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Snowy supper table | `fest_supper_table_snow` | 64 × 32 | The supper table with snow on its edges, steaming pots of stew and mugs instead of pies |
| Snowy bench | `fest_supper_bench_snow` | 64 × 16 | The bench with a blanket and a dusting of snow |
| Brazier | `fest_brazier_0` to `_3` | 16 × 32 | An iron fire basket on legs, four frames of flame, to stand round the table |
| Snow-dusted spruce | `fest_spruce_lights` | 32 × 48 | A small spruce in a barrel, with a string of warm lights, for the edges where the hay bales were |

---

# Part B: the birds

Six birds: four ordinary, two magic. Birds hop on the ground, peck, perch and fly off when you come too close. The owls are out at night.

## The bird sheet layout

The same layout as the animal sheets, with the walk frames used for flight, so one cutting rule still fits:

- **3 rows:** facing **down, right, up.** Left is the right row flipped.
- **6 columns:** standing, **fly 1, fly 2, fly 3** (a wing flap), **pecking** (head down), **perched** (feathers fluffed, sitting still on a branch or a post).
- **Frames are 16 × 16** for every bird. Owls are plumper and stand taller in their frame, but use the same size.

## B1. Ordinary birds

| Bird | Sheet name | Notes for the look |
| --- | --- | --- |
| Crow | `animal_crow` | Glossy black with a hint of blue-purple shine, a bright clever eye. A bit of a busybody, like the raccoon |
| Owl | `animal_owl` | A barred owl: brown and cream stripes, big dark eyes, round and soft. Perched is its favourite pose |
| Blue jay | `animal_blue_jay` | Bright blue with a crest, a black necklace and a white front. Loud-looking |
| Cardinal | `animal_cardinal` | A red male with his crest and black mask. If you like, send `animal_cardinal_female` too: warm brown with red touches on the wings and crest |

## B2. Magic birds

The same frames and sizes as their ordinary cousins, so they can sit among them. Like the magic deer, each has a **glow layer**: only the glowing parts, on the same frames, on transparent, so the lab can make it pulse at night.

| Bird | Sheet name | Glow layer | What makes it strange |
| --- | --- | --- | --- |
| Magic crow | `creature_magic_crow` | `creature_magic_crow_glow` | A crow with tiny stars in its feathers, like a scrap of night sky, and pale silver eyes. The stars glow |
| Magic owl | `creature_magic_owl` | `creature_magic_owl_glow` | An owl with a third eye on its brow, closed by day and open at night. The eyes glow a soft moon-gold |

## B3. The guide

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Pencil sketches | `sketch_crow`, `sketch_owl`, `sketch_blue_jay`, `sketch_cardinal`, `sketch_magic_crow`, `sketch_magic_owl` | 32 × 32 each | The birds as quick pencil drawings, grey on paper colour, like the other animal sketches. If six is too many, send a few and the lab makes the rest from the sprites |
| Birds tab | `guide_tab_birds` | the same size as `guide_tab_animals` | A feather, for a new Birds tab in the field guide |
| A feather | `item_feather_<bird>` | 16 × 16 each | One feather for each bird (crow, owl, blue jay, cardinal, magic crow, magic owl), to find on the ground where they've been. The magic ones shimmer |

---

Name the sheets `ar27_F_festivals.png` and `ar27_B_birds.png`, or split them up as you like. Send them in any order. The lab cuts them and drops them in.
