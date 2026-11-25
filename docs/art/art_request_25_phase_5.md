# Strange Ranger: Art Request 25, Phase 5 (creatures and night)

From the lab, 25 November 2026. This is every picture Phase 5 needs, so the lab can build it in one run as the pieces come back. It's in two parts to match the spec's halves:

- **Part A, out in the woods (5a):** the animals, the first strange cousins as they're seen, the pet, binoculars and camera views, the field guide sheet, the Lore skill, and night.
- **Part B, Gord and the night (5b):** Gord in both shapes, creature friendship, the secret, hint or public choice, the moon and the calendar, aurora nights, and the new badges.

**Please send Part A first.** The lab starts building the moment it arrives. **Nothing waits on these:** each piece has a stand-in in the game, and your picture replaces it with no code change.

Sheets are numbered A1 to A7 and B1 to B5. Send them in any order and as many at a time as suits you. Name each sheet by its number (for example `ar25_A1_small_animals.png`) and the lab will know where it goes.

## Rules for every sheet

The same as Art Requests 17 to 24:

- **Style:** the bright palette, a one-pixel dark outline, and light from the top left.
- **Placement:** each piece stands on the bottom middle of its cell.
- **Size:** big drafts are fine. The lab cuts and shrinks them to the game size given. A transparent or plain background is easiest to cut.
- **Layout:** cells on an even grid. Thin grid lines between cells are fine.
- **Colours are kept as you draw them.**
- **Strange at night and magic only** (the visual direction): animals look like friendly, ordinary animals. Only the strange cousins and night things get the odd colours and glows.

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

## The animal sheet layout

Every animal, cousin and pet uses the same sheet layout, so one cutting rule fits them all:

- **3 rows:** facing **down, right, up.** Left is the right row flipped, so it isn't needed (unless the animal isn't the same both sides).
- **6 columns:** standing, walk 1, walk 2, walk 3, **eating** (head down), **resting** (lying down, or curled up).
- Each frame is the size given for that animal.

---

# Part A: out in the woods (5a)

## A1. Small animals

Each frame **16 × 16**, the animal layout above. They should read at a glance against grass and snow.

| Animal | Sheet name | Notes for the look |
| --- | --- | --- |
| Rabbit | `animal_rabbit` | Brown-grey, white tail. Sits up when standing; hops for the walk |
| Squirrel | `animal_squirrel` | Red squirrel, big tail. Eating: holding a nut |
| Hedgehog | `animal_hedgehog` | Round and brown; resting is a ball |
| Raccoon | `animal_raccoon` | Masked, ringed tail; a bit of a busybody |
| Badger | `animal_badger` | An ordinary badger: grey with the white stripe. Your troll badger is its cousin, so keep them related but clearly different |

## A2. Big animals

The animal layout above, at these sizes:

| Animal | Sheet name | Frame size | Notes for the look |
| --- | --- | --- | --- |
| Deer | `animal_deer` | 32 × 32 | A doe and a buck would be lovely: send `animal_deer_buck` as a second sheet if you like |
| Moose | `animal_moose` | 48 × 48 | Big, gentle, a little gangly |
| Bear | `animal_bear` | 48 × 32 | Black bear, round and calm. Resting is asleep. Nothing scary: the bear is unbothered, not fierce |

## A3. The strange cousins

The same layout and sizes as their ordinary cousins, so they can stand among them.

| Cousin | Sheet name | Frame size | What makes it strange |
| --- | --- | --- | --- |
| Jackalope | `creature_jackalope` | 16 × 16 | A rabbit with small antlers. Otherwise a perfectly ordinary rabbit |
| Magic deer | `creature_magic_deer` | 32 × 32 | A deer whose antlers glow softly, a pale mint or moonlight colour. Also send `creature_magic_deer_glow`: **only the antlers' glow** on the same frames, on transparent, so the lab can make it pulse at night |
| Troll badger | `troll_badger_sheet` | 16 × 16 | Your troll badger in the full layout (today it has four frames). Add a seventh column: **pleased**, holding up a snack |

**Pieces for their answers,** each 16 × 16 unless given:

| Piece | Name | What to draw |
| --- | --- | --- |
| A burrow | `obj_jackalope_burrow` | A small hole with a mound of earth and one tiny antler print beside it |
| A burrow, filled | `obj_jackalope_burrow_filled` | The same spot smoothed over, a tuft of grass |
| A snack bowl | `obj_badger_bowl` | A chipped enamel bowl left out for badgers. Send `_full` (with snacks) and `_empty` |
| Deer tracks that glow | `obj_magic_tracks` | Two hoof prints, faintly lit, for the ground at night |

## A4. The pet

Dog and cat, the animal layout, **16 × 16**, plus a seventh column: **sitting** (facing down), and an eighth: **pointing** (the dog: nose out, one paw up; the cat: staring wide-eyed).

| Piece | Name | Size | Notes |
| --- | --- | --- | --- |
| Dog | `pet_dog` | 16 × 16 frames | A medium, scruffy, friendly dog, a trail partner. Your choice of breed |
| Cat | `pet_cat` | 16 × 16 frames | A cat with a bit of mystery: a dark cat with one white sock, or your choice |
| Faces for the choice | `pet_dog_face`, `pet_cat_face` | 64 × 64 | For the Chief's letter that offers them: head and shoulders, like the townsfolk portraits |
| Water bowl | `furniture_pet_bowl` | 16 × 16 | Two frames side by side: empty, full |
| Dog bed | `furniture_dog_bed` | 32 × 16 | A round plaid cushion. (The cat already has `home_cat_cushion`.) |
| A treat | `item_pet_treat` | 32 × 32 | A backpack icon: a small paper bag of biscuits |

## A5. Binoculars, camera and the field guide

The binoculars and camera icons already exist. These are the views and the guide's sheet.

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Binocular view | `ui_binocular_view` | 480 × 270 | The game screen seen through binoculars: two overlapping round lenses, clear in the middle, the rest dark green-black. The middle is transparent |
| Camera viewfinder | `ui_viewfinder` | 96 × 72 | Four corner brackets and a small centre cross, in white with a dark outline. Transparent in between |
| Shutter flash | `ui_shutter` | 32 × 32 | A small white starburst for the moment a photo is taken |
| The guide's clip | `clip_guide` | the same size as `clip_town` | A field-guide plate for the clipboard's clip: a leaf and a paw print |
| Tab: animals | `guide_tab_animals` | 16 × 16 | A paw print |
| Tab: strange cousins | `guide_tab_strange` | 16 × 16 | A paw print with a small star or sparkle |
| Tab: places and nights | `guide_tab_places` | 16 × 16 | A crescent moon over a pine |
| Unknown entry | `guide_unknown` | 48 × 40 | A card with a grey silhouette area and a "?" (the lab lays the animal's silhouette over it) |
| Sketch frame | `guide_sketch_frame` | 48 × 40 | A torn notebook page, for pencil sketches |
| Photo frame | `guide_photo_frame` | 48 × 40 | An instant photo with a white border and a strip of tape |
| A good photo | `guide_good_stamp` | 12 × 12 | A small gold star stamp for the corner of a good photo |
| Pencil sketches | `sketch_<animal>` | 32 × 32 each | The animals as quick pencil drawings, grey on paper colour, one for each of A1 to A3 (`sketch_rabbit`, `sketch_jackalope` and so on). If that's too many, send just a few and the lab makes the rest from the sprites |

**Chips for where and when,** each 8 × 8, the same style as the other chip icons: `chip_meadow`, `chip_forest`, `chip_water`, `chip_rock`, `chip_dawn`, `chip_day`, `chip_dusk`, `chip_night`, `chip_full_moon`, `chip_snow`.

## A6. Lore

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| The skill | `skill_lore` | 16 × 16 | The same style as the other four skill icons: an open field guide with a paw print |
| Level badges | `badge_lore_2`, `badge_lore_3`, `badge_lore_4` | 32 × 32 | The same style as `badge_foraging_2` and the others |
| Naturalist | `badge_spec_naturalist` | 32 × 32 | Binoculars on a leaf |
| Whisperer | `badge_spec_whisperer` | 32 × 32 | A hand held out, a small animal's nose touching it |

## A7. Night

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Fireflies | `night_fireflies` | 32 × 32, 4 frames | A small drift of yellow-green lights over water. Four frames in a row so they twinkle |
| A night path stone | `night_path_stone` | 16 × 16 | A flat stone that glows softly from inside, pale blue. Send `_dim` too, the same stone by day (just a stone) |
| A glowing spot | `night_glow_spot` | 16 × 16 | A patch of moss or a stump with a soft glow, where a night-only find is |
| Night flowers | `forage_moonflower` | 16 × 16 | A pale flower that's closed by day and open at night: send `_closed` and `_open` |
| Its icon | `item_moonflower` | 32 × 32 | The backpack icon |

---

# Part B: Gord and the night (5b)

## B1. Gord

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Gord the moose | `creature_gord_moose` | 48 × 48 frames, the animal layout | A moose very like `animal_moose`, but with **one thing off** that you can see through the binoculars. Your call what: the spec's stand-in is a wristwatch on one foreleg |
| Gord the man | `npc_gord` | 4 × 4 frames of 16 × 32 | The townsfolk layout (rows down, right, up, left; standing and three walk frames). Tall, broad, awkward, holding his elbows, brown hair a bit like a moose's mane, dressed in what he could find |
| Gord dressed up | `npc_gord_dressed` | 4 × 4 frames of 16 × 32 | The same, in a borrowed buffalo-check coat and a toque, trying very hard to look ordinary |
| Portraits | `portrait_gord_neutral`, `_happy`, `_sad`, `_surprised` | 64 × 64 | The same four moods as the townsfolk. Nervous even when happy |
| His meadow sign | `obj_gord_meadow_sign` | 16 × 32 | A small, slightly crooked hand-painted sign that just says "MEADOW" |

## B2. Creature friendship

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| A paw heart, full | `ui_paw_heart_full` | 8 × 8 | A heart with a small paw print in it, warm gold-orange. The same style as `ui_heart_full` |
| A paw heart, empty | `ui_paw_heart_empty` | 8 × 8 | The same, empty |
| The creature job type | `job_kind_creature` | the same size as `job_kind_badger` | A paw print in a ring, for creature jobs on the clipboard |
| A gift left behind | `obj_creature_gift` | 16 × 16 | A small bundle of leaves tied with grass, left on a cabin step |

## B3. The secret, hint or public choice

Three stamps for the choice, **24 × 24**, the same style as the clipboard's round stamps:

| Piece | Name | What to draw |
| --- | --- | --- |
| Secret | `stamp_secret` | A finger to the lips, or a closed padlock with a leaf |
| Hint | `stamp_hint` | A half-open eye, or a question mark in a speech bubble |
| Public | `stamp_public` | A brochure, open |

And for the brochure: `brochure_creature` (**64 × 48**), a small brochure panel with a blurry photo of "something" in a meadow, for the park's Log when a creature is public.

## B4. The moon and the calendar

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Full moon on the calendar | `ui_cal_moon` | 10 × 10 | The same style as `ui_cal_festival` and the birthday cake |
| An event on the calendar | `ui_cal_event` | 10 × 10 | A small star with a tail |
| The moon's phases | `hud_moon` | 8 frames of 12 × 12 | New, waxing crescent, first quarter, waxing gibbous, full, waning gibbous, last quarter, waning crescent, for the clock at night |

## B5. Aurora nights and badges

**The aurora** is mostly light washing over the world, which the lab does in code. One picture helps:

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Aurora ribbons | `sky_aurora` | 480 × 64, 3 frames | Green and violet curtains of light on transparent, for the top of the screen on aurora nights. Three frames stacked so they ripple slowly |

**Badges, 32 × 32,** the same style as the others:

| Badge | Name | What to draw |
| --- | --- | --- |
| Ten guide entries | `badge_guide_10` | A field guide with a bookmark |
| Half the animals | `badge_guide_half` | A paw print, half coloured in |
| All the animals | `badge_guide_animals` | A paw print, gold |
| All the strange cousins | `badge_guide_strange` | A paw print with antlers |
| Night photography | `badge_photo_night` | A camera under a crescent moon |
| In the fog | `badge_photo_fog` | A camera half lost in grey mist |
| Under the aurora | `badge_photo_aurora` | A camera under green ribbons |
| A creature settled | `badge_creature_settled` | A paw print on a heart |
| Five paw hearts | `badge_creature_friend` | Five small paw hearts in a ring |
| Coffee, black | `badge_gord_coffee` | A diner mug with a small antler on its side |

---

Name the sheets `ar25_A1_small_animals.png`, `ar25_A2_big_animals.png`, `ar25_A3_cousins.png`, `ar25_A4_pet.png`, `ar25_A5_guide.png`, `ar25_A6_lore.png`, `ar25_A7_night.png`, then `ar25_B1_gord.png` to `ar25_B5_aurora_badges.png`. The lab cuts them and drops them in.
