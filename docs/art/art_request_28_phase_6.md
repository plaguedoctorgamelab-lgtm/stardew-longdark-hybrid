# Strange Ranger: Art Request 28, the whole forest (Phase 6)

From the lab, 27 November 2026. Thank you for the costumes and the sweets: they're in as 0.8.7, and the square looks great.

This is the art for Phase 6 (`docs/Phase 6 Spec.md`): the far bank of the Dusk River, Skull Lake, eighteen new sites, the canoe and the cart, a few new creatures, and the yearly review. It's a big request, so it comes in **eight sheets, in the order the lab builds them.** Send them whenever suits you. **Nothing waits on them:** each piece has a stand-in until yours arrives.

## Rules for every sheet

The same as Art Requests 17 to 27:

- **Style:** the bright palette, a one-pixel dark outline, and light from the top left.
- **Placement:** each piece stands on the bottom middle of its cell.
- **Size:** big drafts are fine. The lab cuts and shrinks them to the game size given. A plain or transparent background is easiest.
- **Strange at night and magic only:** the magical sites can glow; the ordinary ones are ordinary.

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

**Sizes to compare with:** a tile is 16 × 16. The Old Cabin is about 80 × 80, Static Tower about 72 × 112, a person 16 × 32, a bear 48 × 32 frames.

---

## G1. The far bank's ground and Skull Lake (for 0.9.0 and 0.9.1)

Ground tiles are 16 × 16. Send three or four variants of each so it doesn't look tiled.

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Lake water | `ground_lake` | 16 × 16 | Deep, dark blue-green lake water, a little calmer than the pond |
| Lake ice | `ground_ice` | 16 × 16 | Thick winter ice with faint cracks and a dusting of snow. One variant with a crack line |
| Ice edge | `ground_ice_edge` | 16 × 16 | Where ice meets open water in early winter: broken, slushy edge |
| Sandbar | `ground_sandbar` | 16 × 16 | A pale summer sandbar in the river, with a few pebbles |
| Fen | `ground_fen` | 16 × 16 | Boggy ground: dark peat, cotton-grass tufts, little pools |
| Snowed-in trail | `ground_trail_snowed` | 16 × 16 | A trail under deep untrodden snow, the edges of the path just visible |
| Closed sign | `obj_sign_closed_winter` | 16 × 32 | A wooden sign on a post, "TRAIL CLOSED FOR WINTER", with snow on top |
| Birch | `tree_birch` | 32 × 48 | A white birch with dark marks, light green leaves. Send autumn (yellow) and winter (bare) too |
| Hemlock | `tree_hemlock` | 32 × 64 | An old, tall, dark hemlock with drooping branches. Winter version with snow |

## G2. The canoe and the cart (for 0.9.2 and 0.9.3)

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Ranger in the canoe | `ranger_canoe` | 4 × 2 frames of 32 × 32 | The ranger paddling a red canvas canoe, facing down, right, up, left. Two frames each: paddle left, paddle right |
| Canoe on the bank | `obj_canoe_beached` | 32 × 16 | The same canoe pulled up on the bank, paddle resting in it |
| Canoe kit | `item_canoe_kit` | 32 × 32 | A bundle of planks, canvas and a paddle, tied with rope |
| The cart | `vehicle_cart` | 4 frames of 32 × 32 | A small, boxy, four-wheeled park utility truck in ranger green with a park badge on the door, the ranger at the wheel. Facing down, right, up, left |
| Cart, broken down | `obj_cart_broken` | 32 × 32 | The same cart, rusty, a flat tyre, a fern growing in the bed |
| Cart trail | `ground_trail_cart` | 16 × 16 | A wider trail with two packed wheel ruts |

## G3. Wave 1 sites (for 0.9.0 to 0.9.4)

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Troll Badger Bridge, mended | `building_bridge_mended` | 96 × 48 | The broken bridge rebuilt in fresh timber, a bit patchwork, with a little toll box nailed to the rail |
| Toll box | `obj_toll_box` | 16 × 16 | A tin box with a slot and "TOLL" scratched on it, a badger paw print beside |
| Boathouse | `building_boathouse_broken` and `_repaired` | 80 × 64 | A small timber boathouse on stilts at the river's edge, with a ramp. Broken: missing boards, sagging roof |
| Landing dock | `obj_dock` | 32 × 16 | A short plank dock |
| Sawmill ruin | `building_sawmill_broken` and `_repaired` | 96 × 64 | An old open-sided sawmill with a big round blade, a tin roof. Broken: roof half off, ivy |
| Narrow-gauge track | `obj_rail_track` | 16 × 16 | Old rails on sleepers, grass between |
| Old plank pile | `obj_plank_pile` | 32 × 16 | A stack of weathered planks under a tarp |
| The Hollow Giant | `building_hollow_giant_broken` and `_repaired` | 96 × 128 | An enormous old tree with a cabin built into its trunk: a round door, a small window, a stovepipe poking out of the bark. Broken: door hanging, window boarded |
| Beaver dam | `obj_beaver_dam` | 48 × 24 | A dam of sticks and mud across a stream, water trickling over |
| Beaver lodge | `obj_beaver_lodge` | 32 × 24 | A dome of sticks in a pond |
| Boardwalk | `obj_boardwalk` | 16 × 16 | Plank boardwalk on short posts over wet ground (the pond's boardwalk can use it too) |
| Beaver | `animal_beaver` | the animal layout, 16 × 16 frames | A beaver: stand, swim-walk ×3, gnawing, resting |

## G4. Wave 2 sites (for 0.9.5 and 0.9.6)

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Picnic beach | `obj_beach_umbrella` | 16 × 32 | A striped beach umbrella stuck in sand |
| Swim float | `obj_swim_float` | 32 × 16 | A wooden swim raft anchored off the beach |
| Skating rink sign | `obj_sign_skating` | 16 × 32 | A sign with a skate on it |
| Hemlock Tower | `building_tower2_broken` and `_repaired` | 72 × 112 | A second fire tower, different from Static Tower: stone base, timber cab, a weather vane shaped like a fish |
| Hot spring | `obj_hot_spring` | 48 × 32, 2 frames | A round rock pool of steaming blue water. Two frames of steam |
| Bear in the spring | `npc_bear_spa` | 2 frames of 32 × 32 | A bear sitting up to its chest in the pool, eyes shut, a little towel on its head. Frame 2: a contented sigh |
| Spa timetable | `obj_spa_timetable` | 16 × 32 | A sign with paw prints on some days and boots on others |
| Upfalls by day | `obj_upfalls_day` | 48 × 96, 4 frames | A tall waterfall over a rock ledge, falling down normally |
| Upfalls at night | `obj_upfalls_night` | 48 × 96, 4 frames | The same waterfall flowing **upward**, water and spray rising, a soft blue glow |
| Wisps | `creature_wisp` | 4 frames of 8 × 8 | A small floating light, pale green-gold, flickering |
| Fen pool | `obj_fen_pool` | 32 × 16 | A dark little pool with reeds, lights reflected in it |

## G5. Wave 3 sites (for 0.9.7 and 0.9.8)

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Mushroom ring | `obj_mushroom_ring` | 64 × 32 | A fairy ring of pale mushrooms in grass. Send a `_night` version with the caps softly glowing |
| Sprite stall | `obj_sprite_stall` | 16 × 24 | A tiny market stall made from a mushroom and a leaf awning, odd goods on it. Send two or three |
| Sprites | `npc_sprite` | 4 × 4 frames of 16 × 16 | A small winged sprite, the townsfolk layout. Two colour versions (`npc_sprite_b`) |
| Raccoon tents | `obj_raccoon_tent` | 32 × 32 | An old canvas tent with raccoon "improvements": a bottle-cap doorbell, a sock flag |
| Raccoon mayor | `npc_raccoon_mayor` | 4 × 4 frames of 16 × 16 | A raccoon wearing a bottle cap like a crown, very self-important |
| Raccoon Camp sign | `obj_sign_raccoon_camp` | 32 × 32 | The old campground sign, with "RACOON TOWN" painted over it, misspelled |
| Elf doors | `obj_elf_doors` | 32 × 32 | The base of an old oak with three tiny round doors, little windows, a tiny mailbox |
| Elf | `npc_elf` | 4 frames of 8 × 12 | A tiny elf in a red cap carrying a letter bigger than itself |
| Ring of Nine stone | `obj_ring_stone` | 16 × 32 | A weathered standing stone, lichen on it |
| The tall stone | `obj_ring_stone_tall` | 16 × 48 | The tallest of the nine, with a worn carving of a sun |
| The Teeth | `obj_tooth_stone` | 16 × 32 | A curved standing stone like a tooth. Send a `_glow` layer: faint lines in the stone that glow on aurora nights |

## G6. Wave 4 and the lake's islands (for 0.9.9)

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Lighthouse | `building_lighthouse` | 48 × 112 | A small white and red lighthouse on rocks, a little door, a gallery at the top |
| Lighthouse beam | `fx_lighthouse_beam` | 4 frames of 96 × 32 | A soft yellow beam sweeping round, for night |
| Cave mouth | `building_nose_cave` | 64 × 48 | A dark cave mouth in a rocky island, old steps going down, a rope rail |
| Island rocks | `obj_island_rock` | 32 × 32 | Mossy shore rocks for the islands. Send three |
| Bigfoot glimpse | `creature_bigfoot_glimpse` | 32 × 48 | A tall, dark, shaggy shape half behind trees, in snow. Only a shape |
| Bigfoot prints | `obj_bigfoot_prints` | 16 × 32 | A line of huge footprints in snow |

## G7. New pieces at old sites (for 0.9.9)

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Fishing dock | `obj_fishing_dock` | 48 × 16 | A small dock with a rod rack |
| Coin telescope | `obj_coin_telescope` | 16 × 32 | A park coin-operated telescope on a post |
| Woodshed | `obj_woodshed` | 32 × 32 | A lean-to of split logs |
| Radio dial | `ui_radio_dial` | 64 × 32 | Static Tower's radio, close up: a big round tuning dial, a needle, two knobs. For the tuning screen |

## G8. The Log, the review, status and badges (for 0.9.10 to 0.9.13)

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Journal page | `item_journal_page` | 32 × 32 | A torn page of the last ranger's journal, handwriting, a doodle in the corner |
| Mystery icons | `log_mystery_ranger`, `log_mystery_lighthouse`, `log_mystery_signs` | 32 × 32 each | For the Log: a ranger's hat on a peg; a lighthouse; a signpost with arrows every which way |
| Review letter | `ui_review_letter` | 256 × 160 | The Chief's letter paper: park letterhead, room for five stamps down the side |
| Review stamps | `stamp_review_<n>` | 24 × 24 each | Five rubber stamps for the levels: "A START", "COMING ALONG", "GOOD WORK", "FINE WORK", "OUTSTANDING" |
| Status ribbons | `ui_status_<n>` | 48 × 16 each | Five ribbons for park status, plain to grand: Forgotten backwater, Local secret, Weekend favourite, Regional gem, Famous destination |
| Map icons | `map_icon_<site>` | 12 × 12 each | One small icon for each of the eighteen new sites, like the current ones |
| Badges | `badge_<name>` | 32 × 32 each | Twelve badges, as in the spec's section 10: far bank found, skull on the map, first canoe trip, first cart drive, walked to Nose Island, nine journal pages, lighthouse answered, a sign that stayed, the Ring's four shadows, a night at the Sprite Market, a five-star stamp, famous destination |

---

Name the sheets `ar28_G1_ground.png` to `ar28_G8_log.png`, or split them up as you like. The lab cuts them and drops them in.
