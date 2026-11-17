# Strange Ranger: Art Request 10, Small Helpers

From the lab, 17 November 2026. Three small pieces for the 0.4.2 playtest fixes. All three work today with stand-ins the game draws itself, so nothing waits on them.

Keep the palette and the light from the top left of Art Request 06.

## The sheet

| # | File | Size | What |
| --- | --- | --- | --- |
| 1 | `ar10_helpers.png` | 96 × 32 | 3 pieces, a 3 × 1 grid of 32 × 32 cells |

**Cell 1, the "something new" mark**, about 12 × 14, centred in its cell. It floats and bobs over anything with something new to read or do: the note board with an unread job, the suggestion box with cards, the supply shelf with a delivery, a site ready to open, and the station's door when any of those is inside. Today it is a yellow disc with a brown "?" (see `docs/status/0.4.2_shots/fb_1_hint_and_question_mark.png`, over the station door). A small parchment tag or a round yellow badge with a dark "?" would suit. It must read at a glance against grass, trail, timber walls and the dark room floors.

**Cell 2, a dropped bundle**, about 16 × 12, on the bottom middle of its cell. What the ranger has put down on the ground with the backpack's new Drop button; X picks it up again. Today the game shows the first item's icon at half size, which can look like forage. A small tied canvas sack or a bundle wrapped in cloth with a strap would say "yours, put down here".

**Cell 3, a gold coin**, about 14 × 14, centred. Money is now in gold coins, not dollars. It will sit beside the wallet under the clock and before prices in the catalog. A plain round coin with a stamped pine tree or the ranger badge's shape.

**Prompt.** Start with the style line from Art Request 06, then:

> A 3 by 1 grid of 32 by 32 cells of pixel art for a top-down forest park game, transparent background, one-pixel dark outline. Cell 1, centred: a small round yellow badge with a dark brown question mark, about 12 by 14. Cell 2, on the bottom middle: a small tied canvas sack lying on the ground, about 16 by 12. Cell 3, centred: a small gold coin stamped with a pine tree, about 14 by 14.

## Where they go in the game

- The mark replaces the drawn disc in `scripts/world/hint_overlay.gd`.
- The bundle replaces the half-size icon in `refresh_piles()` in `scripts/world/world_view.gd`.
- The coin goes beside the wallet in `scripts/ui/hud.gd` and in the catalog's lines.
