# Strange Ranger: Art Request 21, the rest of Phase 4

From the lab, 23 November 2026. This is every picture the rest of Phase 4 needs, so the lab can build it in one run once the pieces come back. It is long, so it is in two parts:

- **Part A, the town's life (4a):** the eleven townsfolk, clothes for the ranger, the insides of the eight houses, and the pieces for the Social page, the calendar, the mailbox and Townsfolk Favors. **Please send Part A first.** The lab starts building the moment it arrives.
- **Part B, a life there (4b):** faces and feelings for heart events and romance, the fortune teller's cards, the four festivals, the station's upgrades and decorating, and the garden.

A last, optional section asks for **portraits**. The game works without them.

Sheets are numbered A1 to A6 and B1 to B9. Send them in any order and as many at a time as suits you. Name each sheet by its number (for example `ar21_A1_rosa.png`) and the lab will know where it goes.

## Rules for every sheet

The same as Art Requests 17 to 20:

- **Style:** the bright palette, a one-pixel dark outline, and light from the top left.
- **Placement:** each piece stands on the bottom middle of its cell.
- **Size:** big drafts are fine. The lab cuts and shrinks them to the game size given. A transparent or plain background is easiest to cut.
- **Layout:** cells on an even grid. Thin grid lines between cells are fine.
- **Furniture:** the Interior Art Guide's rules: two faces, a contact shadow, a highlight on top edges, two or three tones per material, and the one-second test for small things.
- **Colours are kept as you draw them.** Since Art Request 18 the lab keeps your own colours rather than snapping them to a palette.

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

---

# Part A: the town's life (4a)

## A1 to A3. The eleven townsfolk

Today only Wren has her own sprites (your Phase 4 first-pass sheet). The other eleven are built from the visitors' plain layered bodies in their own colours, which is why they all look alike. Each needs a walk sheet like Wren's.

**Each sheet:** 4 rows by 4 columns of 16 × 32 frames. Rows are facing **down, right, up, left**. Column 0 is standing; columns 1 to 3 are the walk. The same layout as Wren's and the ranger's sheets. Named `npc_<id>`.

Their colours today are below, so the town stays recognisable, but **looks are yours to change**: these were the lab's guesses.

| Sheet | id | Who | Age | Today's colours | Notes for the look |
| --- | --- | --- | --- | --- | --- |
| A1 | `rosa` | Rosa Mendoza, runs Casa Luna | 50s | brown skin, near-black hair, brick red top `#b04034`, dark trousers | An apron; hair up; she feeds everyone |
| A1 | `teo` | Teo Mendoza, cooks at Casa Luna | 20s | brown skin, black hair, white chef's top, denim trousers, red beanie | Gentle, a little lost; writes songs |
| A1 | `marge` | Marge Pelletier, runs the outfitters | 60s | pale skin, silver hair, forest green fleece `#386e50`, tan trousers | Retired mountaineer: brisk, sturdy, a carabiner on her belt |
| A1 | `nell` | Nell Pelletier, works at the outfitters | 30s | pale skin, auburn hair, orange shell `#e8963c`, slate trousers, green beanie | A climber, restless |
| A2 | `agnes` | Agnes Thistlewood, the librarian | 70s | pale skin, white hair, plum cardigan `#78548c`, long skirt | Glasses on a chain, a little stooped |
| A2 | `bev` | Bev Kowalski, runs Gifts & Notions | 40s | pale skin, honey-blonde hair, pink blouse `#dc6e96` | Big earrings, a brooch, a shopping-bag kind of person |
| A2 | `gus` | Gus Lindqvist, the carpenter | 50s | fair skin, sandy hair and beard, red flannel `#963c32`, brown work trousers | Big hands, a pencil behind his ear, tool belt |
| A2 | `sol` | Sol Arden, a painter | 30s | olive skin, dark hair, sky-blue smock `#6496be`, cream trousers, straw sun hat | Paint on the smock |
| A3 | `lyle` | Mayor Lyle Pruitt | 60s | pale skin, grey hair, charcoal suit `#464a5a` | A sash or a tie pin; proud of how ordinary Humdrum is |
| A3 | `esme` | Esme Vale, the fortune teller | Unknown | warm skin, plum hair, violet shawl `#5a3c82`, wide dark hat | Kind and cryptic; nothing about her is strange to anyone |
| A3 | `pip` | Pip Abernathy | 10 | fair skin, ginger hair, green T-shirt `#3c8250`, khaki shorts, a too-big ranger hat | **A child, a head shorter than the grown-ups:** draw Pip in the bottom 24 pixels of the 32 |

**Sending:** four people a sheet (A1 and A2) and three on A3, each person as a 4 × 4 block. Or one sheet a person, if that's easier.

**Rain:** in the spec some townsfolk carry umbrellas in rain. Optional: an `npc_umbrella` layer, 4 × 4 frames of 16 × 32 to sit over anyone, a closed-overhead umbrella in a cheerful colour.

## A4. Clothes for the ranger

The ranger will wear three things: a hat, a coat and boots. The starting three are the ones already drawn on your ranger sheet. The outfitters sells six more, and each must show on the ranger.

**Each piece is an overlay sheet:** the same 4 × 4 layout of 16 × 32 frames as the ranger's walk sheet, with **only that piece drawn** on a transparent background, lined up exactly over your ranger's frames. The lab lays it over the ranger, so a coat covers the ranger jacket and a hat replaces the ranger hat. The easiest way may be to trace over your ranger sheet and then delete the ranger.

| Piece | id | Slot | What it looks like | Overlay name |
| --- | --- | --- | --- | --- |
| Wool toque | `wool_toque` | Hat | A knitted toque with a bobble, red and cream bands | `ranger_wear_wool_toque` |
| Rain shell | `rain_shell` | Coat | A bright yellow rain jacket with its hood down | `ranger_wear_rain_shell` |
| Wool coat | `wool_coat` | Coat | A buffalo-check wool coat, red and black, to the hips | `ranger_wear_wool_coat` |
| Down parka | `down_parka` | Coat | A puffy, quilted parka with a fur-trimmed hood, long; the ranger looks rounder in it | `ranger_wear_down_parka` |
| Waterproof boots | `waterproof_boots` | Boots | Green rubber boots | `ranger_wear_waterproof_boots` |
| Insulated boots | `insulated_boots` | Boots | Tall lace-up winter boots with a fleece cuff | `ranger_wear_insulated_boots` |

**With the hat off:** when the ranger wears the toque, the ranger hat comes off. Please also send `ranger_wear_bare_head`: the same 4 × 4 frames showing just the ranger's hair where the hat brim was, so nothing of the old hat shows under the toque.

**Backpack icons, 32 × 32, one sheet:** the nine pieces as they lie in the backpack: the ranger hat, the ranger jacket, work boots, and the six above. Named `item_<id>` (for example `item_wool_toque`; the starting three are `item_ranger_hat`, `item_ranger_jacket`, `item_work_boots`).

**Also sold at the outfitters, icons 32 × 32:** `item_bedroll_big` (a thick rolled bedroll with straps), `item_lamp_oil` (a small tin can with a spout) and `item_matches` (a box of matches).

## A5. Inside the eight houses

Each house needs an inside you can walk into when its owner is home. The lab builds each room with your Art Request 18 walls, floors, rugs, plants and pictures, so this sheet is only **what makes each home theirs**: a bed and the pieces of their life.

**Sizes** follow the Interior Art Guide: the picture is the whole drawing, and its bottom row of tiles is what blocks walking.

**A5a: the home set (one sheet).** Pieces every house shares, also sold later for decorating the station:

| Piece | Name | Picture |
| --- | --- | --- |
| Double bed with a quilt | `home_bed_double` | 48 × 48 |
| Single bed | `home_bed_single` | 32 × 48 |
| Child's bed with a star quilt | `home_bed_child` | 32 × 40 |
| Kitchen counter with a sink | `home_kitchen_sink` | 48 × 32 |
| Kitchen range (stove and oven) | `home_kitchen_range` | 32 × 32 |
| Dresser | `home_dresser` | 32 × 32 |
| Wardrobe | `home_wardrobe` | 32 × 48 |
| Sofa | `home_sofa` | 48 × 32 |
| Round dining table with two chairs | `home_dining_table` | 48 × 32 |
| Side table with a lamp | `home_side_table` | 16 × 32 |
| Fireplace with a mantel | `home_fireplace` | 48 × 48 |

**A5b: each home's own pieces (one or two sheets),** three or four each, about 32 × 32 unless given:

| House | Who | Their pieces |
| --- | --- | --- |
| The Pelletiers' | Marge and Nell, climbers | A gear wall of ropes and ice axes (`home_gear_wall`, 48 × 48, on the wall); a framed summit photo; a pair of boots by the door (16 × 16); a hangboard over a doorway |
| Bev's | Bev Kowalski | A curio cabinet full of baubles (32 × 48); a frilly armchair with a doily; a shelf of snow globes (on the wall); a big potted fern |
| Agnes's | Agnes, the librarian | Stacks of books on the floor (16 × 16, two kinds); a reading chair with a blanket and lamp; a writing desk with an old typewriter; a cat asleep on a cushion (16 × 16) |
| The mayor's | Mayor Lyle | A grand desk with a nameplate (48 × 32); a portrait of himself (32 × 32, on the wall); a grandfather clock (16 × 48); a trophy shelf ("Most Ordinary Town, Third Place") |
| The Abernathys' | Pip and grandparents | A cryptid poster wall (Bigfoot, a lake monster, a mothman; 48 × 32, on the wall); Pip's toy chest; a rocking chair with knitting; a homemade "Ranger HQ" sign |
| The Mendozas' | Rosa and Teo | A big family dining table (64 × 32); strings of dried chillies (on the wall); a guitar on a stand (16 × 32); a shelf of family photos |
| Gus's | Gus, the carpenter | A log-frame bed he built (48 × 48); a whittling corner with a stool and shavings; a carved bear (16 × 32); a wall of hand tools |
| Sol's | Sol, a painter | An easel with a half-done painting of the park (32 × 48); a paint-spattered table; canvases leaning on the wall (32 × 32); a big north window with a cushion seat (48 × 32, on the wall) |

## A6. The Social page, the calendar, the mailbox and Favors

**One sheet** of small things.

| Piece | Name | Size | Notes |
| --- | --- | --- | --- |
| Heart, full | `ui_heart_full` | 8 × 8 | For the Social page's rows of hearts |
| Heart, empty | `ui_heart_empty` | 8 × 8 | The outline of the same heart |
| Heart, locked | `ui_heart_locked` | 8 × 8 | A heart with a tiny padlock, for hearts 9 and 10 before dating |
| Gift given | `ui_gift_tick` | 8 × 8 | A small wrapped box, for "gift given this week" |
| Talked today | `ui_talk_tick` | 8 × 8 | A small speech bubble |
| Calendar page | `ui_calendar` | 240 × 160 | A paper wall calendar: a header band for the season's name and a 7 × 4 grid of day boxes, blank. The lab writes the dates in. |
| Birthday cake | `ui_cal_birthday` | 12 × 12 | Sits in a day box with the person's head |
| Festival flag | `ui_cal_festival` | 12 × 12 | A pennant, for festival days |
| Social page panel | `ui_social` | 240 × 160 | A paper or leather ledger page, blank, ruled for 6 rows |
| Station mailbox, flag down | `obj_station_mailbox` | 16 × 24 | A rural post-and-box mailbox for outside the station door |
| Station mailbox, flag up | `obj_station_mailbox_full` | 16 × 24 | The same, red flag raised: mail has come |
| A letter | `item_letter` | 32 × 32 | A sealed envelope |
| A parcel | `item_parcel` | 32 × 32 | A brown-paper parcel tied with string |
| Teo's song notebook | `item_song_notebook` | 32 × 32 | A battered notebook with a music note on the cover |
| Lost things | `item_lost_mitten`, `item_lost_keys`, `item_lost_locket`, `item_lost_glasses` | 32 × 32 each | For "[Person]'s Lost [thing]" favors |
| The pond painting | `decor_pond_painting` | 32 × 32 | Sol's small painting of the pond, framed, for the station wall |
| Pip's drawing | `decor_pip_drawing` | 16 × 16 | A child's crayon drawing of the ranger and a bigfoot |
| Favor note | `town_note_pinned` | 16 × 16 | A note pinned to the town notice board, so the board shows how many favors are up |

The favors' job icon (the berry-red basket) and card picture are already drawn: `job_type_townsfolk` and `job_pic_townsfolk`.

---

# Part B: a life there (4b)

## B1. Feelings: emote bubbles

Little bubbles that pop up over a head during heart events and talk. **One sheet, 16 × 16 each:** heart, exclamation mark, question mark, music note, sweat drop, "…", a happy face, a cross face, a sleepy "Zzz", and a lightbulb. Named `emote_heart`, `emote_alarm`, `emote_question`, `emote_music`, `emote_sweat`, `emote_dots`, `emote_happy`, `emote_cross`, `emote_sleep`, `emote_idea`.

## B2. Romance

| Piece | Name | Size | Notes |
| --- | --- | --- | --- |
| Bouquet | `item_bouquet` | 32 × 32 | Wildflowers in brown paper with a ribbon; sold at Gifts & Notions |
| Bouquet, held | `ranger_hold_bouquet` | 16 × 16 | The bouquet as the ranger holds it out, facing down only |
| Mailbox gift | `item_gift_wrapped` | 32 × 32 | A small wrapped gift with a tag, as a partner leaves in the mailbox |

## B3. The fortune teller's cards

Esme draws three cards from her own deck. The reading shows them face up, side by side.

| Piece | Name | Size | Notes |
| --- | --- | --- | --- |
| The Sky | `fortune_card_sky` | 48 × 72 | Her weather card: a sun, a cloud and a moon around one eye-like star |
| The Path | `fortune_card_path` | 48 × 72 | Her hint card: a winding path into pines, with a small lantern |
| The Heart | `fortune_card_heart` | 48 × 72 | Her people card: two hands around a little flame |
| Card back | `fortune_card_back` | 48 × 72 | The back of her deck: a violet pattern with the compass-with-eye emblem |
| Reading cloth | `fortune_cloth` | 240 × 120 | The table she lays them on: a fringed velvet cloth, dark violet with gold stitching, seen from above |
| Path mark | `map_fortune_path` | 16 × 16 | The symbol at the middle of a Path circle on the map: a small eye in a star, no words |

## B4 to B7. The four festivals

Each festival dresses the square for one day. The lab places the pieces.

**B4. The Thaw Fair (spring 13, morning): the Grand Display**

| Piece | Name | Size |
| --- | --- | --- |
| A display table with a white cloth and a number card | `fest_display_table` | 48 × 32 |
| A judges' stand with bunting | `fest_judges_stand` | 48 × 48 |
| A market stall with a striped awning, empty | `fest_stall` | 48 × 48 |
| Spring flower garlands, to hang between lamps | `fest_garland_spring` | 32 × 16 |
| The prize ribbon (for the station wall) | `decor_ribbon_thaw` | 16 × 24 |

**B5. Lantern Night (summer 20, evening): the Lantern Walk**

| Piece | Name | Size |
| --- | --- | --- |
| Paper lanterns floating on the creek, two frames bobbing, in six colours (red, orange, yellow, green, blue, violet) | `fest_lantern_float_<colour>_0` and `_1` | 16 × 16 |
| A paper lantern on a stick, as carried | `fest_lantern_stick` | 16 × 32 |
| Strings of lanterns, to hang between lamps | `fest_lantern_string` | 32 × 16 |
| The prize paper lantern (for the station) | `decor_paper_lantern` | 16 × 32 |

**B6. The Big Foot Supper (autumn 18, evening): the Look-Alike Contest**

| Piece | Name | Size |
| --- | --- | --- |
| A Bigfoot costume overlay: shaggy brown suit and head, **the same 4 × 4 layout of 16 × 32 frames as a townsfolk sheet**, to wear over anyone. Homemade and a bit wonky: it's the town's best effort, taken entirely seriously | `fest_bigfoot_suit` | 4 × 4 of 16 × 32 |
| A long supper table with a cloth, pies and lanterns | `fest_supper_table` | 64 × 32 |
| A bench to go with it | `fest_supper_bench` | 64 × 16 |
| Hay bales and pumpkins, for the edges | `fest_hay_bale` | 32 × 24 |
| The judge's sash, as worn (facing down only) | `ranger_wear_sash` | 16 × 32 |
| The sash, as a backpack item | `item_judges_sash` | 32 × 32 |

**B7. The Long Night (winter 25, evening): the Bonfire**

| Piece | Name | Size |
| --- | --- | --- |
| A bonfire, four frames of flame | `fest_bonfire_0` to `_3` | 48 × 64 |
| Log benches round it | `fest_log_bench` | 48 × 16 |
| A cocoa stall with a steaming pot | `fest_cocoa_stall` | 48 × 48 |
| The prize blanket, folded, for the station | `decor_blanket` | 32 × 16 |

## B8. The station, upgraded and decorated

**Outside: the station after each upgrade.** Your station today is `building_station`, 96 × 80. The door must stay where it is.

| Picture | Name | Size | What changes |
| --- | --- | --- | --- |
| Upgrade 1, Shipshape | `building_station_shipshape` | 96 × 80 | The roof and shutters mended and painted; flower boxes; the station looks cared-for |
| Upgrade 3, a second room | `building_station_two_rooms` | 128 × 80 | A room added on the **right**, with a second window; the original front and door unchanged |

(Upgrade 2, the kitchen, changes only the inside.)

**Inside: the kitchen and the second room.**

| Piece | Name | Size |
| --- | --- | --- |
| Cooking range, cold | `furniture_cooking_range` | 32 × 32 |
| Cooking range, in use (lit, a pot steaming) | `furniture_cooking_range_lit` | 32 × 32 |
| Pantry chest | `furniture_pantry` | 32 × 48 |
| Reading chair with a lamp | `furniture_reading_chair` | 32 × 32 |

**Decorating: the station's furniture catalogue.** The spec asks for about 40 pieces. About ten are already drawn (your Art Request 18 rugs, plants, armchair and wall pictures, and the A5a home set), so **30 new pieces**, sold at Gifts & Notions and the carpentry. A spread across the room:

| Kind | Pieces (name: size) |
| --- | --- |
| Seats | `deco_rocking_chair`: 16 × 32 · `deco_bench_carved`: 32 × 24 · `deco_stool`: 16 × 24 · `deco_loveseat`: 48 × 32 |
| Tables | `deco_coffee_table`: 32 × 24 · `deco_writing_desk`: 48 × 32 · `deco_plant_stand`: 16 × 32 |
| Storage | `deco_bookshelf_low`: 32 × 32 · `deco_trunk`: 32 × 24 · `deco_coat_tree`: 16 × 48 · `deco_cabinet_glass`: 32 × 48 |
| Lights | `deco_floor_lamp`: 16 × 48 · `deco_table_lamp`: 16 × 16 · `deco_lantern_hanging`: 16 × 32 · `deco_candles`: 16 × 16 |
| Plants | `deco_fern`: 16 × 32 · `deco_cactus`: 16 × 16 · `deco_monstera`: 32 × 32 · `deco_herb_pots`: 32 × 16 |
| On the wall | `deco_antlers`: 32 × 16 · `deco_park_map`: 32 × 32 · `deco_pennants`: 32 × 16 · `deco_clock`: 16 × 16 · `deco_mirror`: 16 × 32 · `deco_snowshoes`: 16 × 32 |
| Small things | `deco_radio`: 16 × 16 · `deco_globe`: 16 × 16 · `deco_teapot`: 16 × 16 · `deco_binoculars`: 16 × 16 · `deco_pinecone_bowl`: 16 × 16 |

**Wallpapers and floors.** The spec wants six of each. Three walls (planks, brick, paper) and three floors (plank, warm boards, checker) are already yours, so three more of each:

- **Walls,** 16 × 48 each, a repeating column like Art Request 18's: `interior_wall_stripes` (cream and sage stripes), `interior_wall_pines` (a small pine-tree print), `interior_wall_logs` (round logs, cabin-style).
- **Floors,** 16 × 16 each, quiet like Art Request 20's: `interior_floor_slate` (grey flagstones), `interior_floor_herringbone` (light oak herringbone), `interior_floor_rag_rug` (woven rag rug, wall to wall).

## B9. The garden

A small fenced plot behind the station, 6 × 6 tiles.

**The plot.**

| Piece | Name | Size |
| --- | --- | --- |
| Garden fence, straight run | `garden_fence_h` | 16 × 24 |
| Garden fence, side | `garden_fence_v` | 16 × 24 |
| Garden fence, corner post | `garden_fence_post` | 16 × 24 |
| Garden gate | `garden_gate` | 16 × 24 |
| Soil, dug and dry | `garden_soil_dry` | 16 × 16 |
| Soil, watered (darker) | `garden_soil_wet` | 16 × 16 |
| Soil, under snow | `garden_soil_snow` | 16 × 16 |
| Watering can, backpack icon | `item_watering_can` | 32 × 32 |
| Water splash on soil, three frames | `fx_water_0` to `_2` | 16 × 16 |

**The crops.** Nine crops, three a season (none in winter). Each needs **four growth stages** on the soil (16 × 16, or 16 × 32 for tall ones) and a **picked item** (32 × 32). Crops that regrow need a fifth picture: **picked, regrowing**.

| Season | Crop | Stages named | Tall? | Regrows? | Picked item |
| --- | --- | --- | --- | --- | --- |
| Spring | Peas | `crop_peas_0` to `_3`, `crop_peas_regrow` | Tall (on a little trellis) | Yes | `item_peas` |
| Spring | Radishes | `crop_radish_0` to `_3` | No | No | `item_radish` |
| Spring | Rhubarb | `crop_rhubarb_0` to `_3` | No | No | `item_rhubarb` |
| Summer | Tomatoes | `crop_tomato_0` to `_3`, `crop_tomato_regrow` | Tall (staked) | Yes | `item_tomato` |
| Summer | Beans | `crop_beans_0` to `_3`, `crop_beans_regrow` | Tall (on a pole) | Yes | `item_beans` |
| Summer | Sweetcorn | `crop_corn_0` to `_3` | Tall | No | `item_corn` |
| Autumn | Pumpkins | `crop_pumpkin_0` to `_3` | No | No | `item_pumpkin` |
| Autumn | Squash | `crop_squash_0` to `_3` | No | No | `item_squash` |
| Autumn | Kale | `crop_kale_0` to `_3` | No | No | `item_kale` |

Stage 0 is the seed just in (a little mound), stage 3 ready to pick. Also `crop_withered` (16 × 16): a gentle dry tuft for crops when their season ends.

**Seed packets,** 32 × 32 each: `item_seeds_<crop>` for all nine, a paper packet with the crop's picture on it.

**Three garden dishes,** 32 × 32: `item_tomato_soup`, `item_pumpkin_pie`, `item_garden_salad`.

---

# Optional: portraits

The spec calls portraits "the strongest case for hiring a pixel artist". Without them, the talk box shows a big crop of the person's sprite head. If you want to try them, or brief someone:

- **64 × 64** each, head and shoulders, facing slightly to the side, on a plain background.
- **Four expressions** per person: neutral, happy, sad, surprised. Named `portrait_<id>_neutral` and so on.
- **All twelve** townsfolk, Wren included.
- Pip's are a child's: cheerful and simple.

They drop in with no code change whenever they come.

---

## What comes back first

**Part A unlocks the rest of 4a.** With A1 to A6 the lab can build:

- the Social page and calendar;
- clothing at the outfitters;
- Townsfolk Favors with the mailbox;
- the house insides;
- the townsfolk in their own sprites.

Then comes the 4a play test. **Part B** can come after, or alongside, as you like.

Anything you'd rather draw differently, or leave out, just say so: these lists are the lab's proposal.
