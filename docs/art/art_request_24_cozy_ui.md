# Strange Ranger: Art Request 24, one clipboard, many sheets

From the lab, 24 November 2026. It goes with the cozy UI plan (`docs/ui/cozy_ui_plan.md`), agreed today.

**The idea.** Every page becomes a sheet on the jobs clipboard: same board, same size, flip with the tabs. Facts become pictures with a number (a flame and "+1"), so the game needs a set of small icons, a few page pieces, and the doodles and stationery that make the logbook feel handmade. **Your clipboard, card, ribbon, tile and patch pictures from Art Requests 21 and 22 are all kept.** Every sheet is built from them; this request only fills the gaps.

**Nothing waits on this.** Each piece has a stand-in in the mockups (a dashed box with its name), and the game can be built with stand-ins first.

## Rules

As Art Requests 17 to 23: the bright palette, a one-pixel dark outline, light from the top left, cells on an even grid, each piece on the bottom middle of its cell, your colours kept as drawn.

**Sizes are exact for icons.** Icons are drawn pixel for pixel at the size given: 12 × 12 for chips, 16 × 16 for ribbons and stations. They sit next to 7-pixel text, so they must read at that size. The bigger pieces can come as large drafts.

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, light from the top left.

## A. Sheet pieces (the furniture of every page)

| Piece | Name | Size | Notes |
| --- | --- | --- | --- |
| Picture mount | `ui_mount` | 40 × 40 | The frame for the big picture at the top of every detail: a photo mount with paper corners, a 32 × 32 window in the middle. |
| Label strip | `ui_label_strip` | 96 × 24 | Replaces the item tag: a strip of card along the foot of the Pack sheet. Stretched sideways: plain middle, ends drawn (a little punched hole on the left). |
| Count badge | `ui_badge` | 10 × 8 | The little dark oval a number sits on, bottom right of a tile. |
| Short tile | `ui_tile_red` | 24 × 24 | As `ui_tile_gold` and `ui_tile_grey`, red-brown: "you don't have enough". |
| Index tab, with a picture | `ui_itab` / `ui_itab_open` | 28 × 14 | Paper tabs along the top of a sheet (Current, People, Buy...) with room for a 12 × 12 icon and no word. Shut: darker, a little lower. |
| Stamp button | `ui_stamp_round` | 40 × 20 | A rubber stamp for actions (Make, Buy, Sell, Pin, Map). Room for a 12 × 12 icon in the middle; the word goes beside it. Also `_hover` and `_pressed`. |
| Key cap | `ui_key` | 12 × 12 | A blank keyboard key, a letter drawn on in code. Also `ui_key_wide` 24 × 12 (Esc, Tab). |
| Mouse | `ui_mouse_left`, `ui_mouse_right`, `ui_mouse_wheel` | 12 × 12 | A little mouse with that button or wheel lit. |
| Action chip | `ui_chip` | 64 × 14 | The plate just above the item bar that replaces the name tags: [X] + verb icon + name. Stretched sideways like the label strip. |
| Toast card | `ui_toast_idea` | 96 × 28 | The "you can make something new" card that slides in at the top right: a little recipe card with a lightbulb in the corner and room for a 24 × 24 picture. |
| Mapped bar | `ui_mapped_bar` | 64 × 10 | The "% mapped" bar on the map sheet, with the compass at its left end. |

## B. Fact icons (12 × 12): one picture, one number

Used as chips: icon, then a number or a word or two.

| Name | What to draw |
| --- | --- |
| `icon_energy` | A little lightning bolt in a green circle (energy) |
| `icon_warmth` | A small orange flame (warmth) |
| `icon_speed` | A winged boot (moves faster) |
| `icon_rest` | A pillow with a "z" (rests better) |
| `icon_carry` | A backpack with a "+" (carries more) |
| `icon_light` | A lantern's glow (light at night) |
| `icon_time` | A clock face (hours, days) |
| `icon_walk` | A boot print (how far to walk) |
| `icon_coin` | A single gold coin (price) |
| `icon_coins_up` / `icon_coins_down` | A coin with a green up arrow, a red down arrow (ledger in and out) |
| `icon_marks_map` | A map pin (marks a spot) |
| `icon_have` / `icon_short` | A green tick and a red cross, tiny (have enough / short) |
| `icon_lock` | A small padlock (an idea you haven't had yet) |
| `icon_unknown` | A "?" on a paper scrap (a gift or fact you haven't learned) |

## C. Verb icons for the action chip (12 × 12)

`verb_talk` (speech bubble), `verb_open` (an open door), `verb_pick` (a hand picking up), `verb_use` (a hand pressing), `verb_read` (an open book), `verb_sit` (a chair), `verb_sleep` (a bed), `verb_buy` (a coin over a hand), `verb_give` (a wrapped gift), `verb_dig` (a shovel), `verb_water` (a watering can), `verb_cook` (a pot with steam), `verb_make` (a hammer).

## D. Make: stations and kinds (16 × 16)

| Name | What to draw |
| --- | --- |
| `station_hands` | Two hands (made anywhere) |
| `station_workbench` | The workbench, front on |
| `station_campfire` | A small campfire |
| `station_range` | The cooking range |
| `kind_tools` / `kind_building` / `kind_food` / `kind_refits` / `kind_decor` / `kind_garden` | For the ribbons on the Make list: a crossed hammer and saw, a plank and nails, a bowl with a spoon, a lantern with a spark, a little framed picture, a sprout |

## E. Town (12 × 12)

| Name | What to draw |
| --- | --- |
| `icon_cake` | A slice of birthday cake with a candle (bigger than `ui_cal_birthday`) |
| `icon_gift_love` / `icon_gift_like` / `icon_gift_dislike` | A gift box with a heart, a smile, a frown |
| `icon_where` | A map pin on a little house (where someone is now) |

## F. The logbook (Park, Ledger, Cards, Letters, Notebook)

The biggest gap: today these pages are all sentences.

| Piece | Name | Size | Notes |
| --- | --- | --- | --- |
| Visitors | `log_visitors` | 16 × 16 | One hiker |
| Parties | `log_party` | 16 × 16 | Three hikers of different heights |
| Arriving | `log_arriving` | 16 × 16 | A little car with a canoe on top |
| Sites ready | `log_site` | 16 × 16 | A tent with a tick |
| Litter | `log_litter` | 16 × 16 | A full litter bag |
| Staff | `log_staff` | 16 × 16 | A ranger's hat |
| Park ID card | `log_id_card` | 96 × 56 | The park ID card from the old Pack page, drawn as a laminated card with the park's emblem, a space for the ranger's picture and three lines. |
| Ledger bar | `log_bar` | 6 × 32 | One day's bar for the week chart: a stack of coins, cut to height in code |
| Suggestion card | `log_card` / `log_card_big` | 24 × 24, 120 × 80 | An index card, small for the list, large for reading, with faint lines |
| "Done" stamp | `log_stamp_done` | 32 × 16 | A red rubber stamp, slightly crooked |
| Envelope | `log_envelope` / `log_envelope_open` | 24 × 24 | Sealed with a red wax seal; open with the letter peeping out |
| Stationery | `log_letter_paper` | 160 × 112 | Writing paper with a deckled edge, for the letter in the detail |
| Sticky notes | `log_note_yellow`, `_green`, `_blue`, `_purple` | 24 × 24 | Square sticky notes with a pin; purple is for the strange ones |
| Big note | `log_note_big` | 160 × 112 | The note large, for reading, pinned at the top |
| Doodles | `doodle_footprint`, `doodle_paw`, `doodle_mug`, `doodle_ribbon`, `doodle_sign`, `doodle_eye`, `doodle_tracks`, `doodle_question`, `doodle_star` | 16 × 16 | Drawn as if in pencil by the ranger: a big footprint, an animal paw, a mug, a tied ribbon, a signpost, an eye, a line of tracks, a question mark, a star |
| Weather day | `log_sky_clear`, `_cloud`, `_rain`, `_snow`, `_fog` | 16 × 16 | Three in a row on the Park sheet for today and the next two days |

## G. Shops

| Piece | Name | Size | Notes |
| --- | --- | --- | --- |
| Sold out | `shop_sold_out` | 24 × 24 | A small "sold" stamp to lay over a goods tile |
| Shop clips | `clip_percolator`, `clip_outfitters`, `clip_gifts`, `clip_carpentry`, `clip_library`, `clip_casa_luna` | 32 × 32 | Each shop's sign, small, to sit on the clipboard's clip in place of the pine tree |

## H. Page clips (32 × 32)

The pine tree on the clipboard's clip, one per sheet so you know where you are at a glance: `clip_pack` (a backpack), `clip_jobs` (the pine tree, as now), `clip_map` (a compass), `clip_town` (a heart), `clip_make` (a hammer), `clip_log` (an open logbook), `clip_chest` (a chest).

## Sheets

One sheet per section, named `ar24_A_sheet.png` to `ar24_H_clips.png`. The lab cuts them and drops them in.
