# Strange Ranger: Art Request 29, the split station

From the lab, 28 November 2026. The station is getting a living half on its left, with its own door. The plan is in `docs/Split Station Spec.md`, and `docs/art/split_station_mock.png` is a rough view built from the art the game already has. It's a small request with one sheet. **Nothing waits on it:** each piece has a stand-in until yours arrives.

## Rules

The same as Art Requests 17 to 28:

- The bright palette, a one-pixel dark outline, and light from the top left.
- Each piece stands on the bottom middle of its cell. Big drafts are fine, and a plain or transparent background is easiest.

**Style line, at the start of the prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

**Sizes to compare with:** a tile is 16 × 16. The station now is 125 × 92, the bed 32 × 48 and the chest 32 × 32.

## S1. The station from outside, with its living wing

The same station as now, with **a smaller, lower log wing built onto its left side.** The wing has its own plain door and a small window with a stovepipe chimney. The station's own door stays in the middle of the main building, under the park sign.

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Station with wing | `building_station` | about 160 × 92 | As now, plus the living wing on the left |
| Shipshape | `building_station_shipshape` | about 160 × 92 | The same, mended: new roof and shutters on both parts |
| Bigger office | `building_station_two_rooms` | about 190 × 92 | Shipshape, with the main building also stretched to the right |

## S2. Inside pieces

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Nightstand | `furniture_nightstand` and `_lit` | 16 × 24 | A small wooden bedside table with one drawer, an oil lamp and a book on top. In `_lit` the lamp is glowing |
| Supply closet | `furniture_supply_closet` | 32 × 48 | A tall ranger-green cupboard, one door ajar showing tins, rope and folded blankets, with "SUPPLIES" stencilled on it |
| Station chest | `int_chest_station` | 32 × 32 | A green park footlocker with brass corners and the park badge on the lid. Make it clearly not the brown home chest |
| Inside wall | `interior_inner_wall` | 16 × 16 | The top of a thick inside wall seen from above, dark wood with a lighter edge each side. It tiles downward |
| Inside doorway | `interior_inner_doorway` | 16 × 16 | The same wall with an open doorway: a door frame and a worn threshold board, with no door |
