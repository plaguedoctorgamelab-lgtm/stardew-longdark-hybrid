# Strange Ranger: Art Request 26, the rest of Phase 5b

From the lab, 26 November 2026. Thank you for Art Request 25 Part B. Gord, the paw hearts, the stamps, the moon and the aurora are all here, and the wristwatch is perfect. The lab cuts them in as 5b is built.

The Phase 5b spec (`docs/Phase 5b Spec.md`) adds a few things that Part B didn't have. They're below, in three short sheets. **Nothing waits on these:** each one has a stand-in, and your picture replaces it with no code change.

## Rules for every sheet

The same as Art Requests 17 to 25:

- **Style:** the bright palette, a one-pixel dark outline, and light from the top left.
- **Placement:** each piece stands on the bottom middle of its cell.
- **Size:** big drafts are fine. The lab cuts and shrinks them to the game size given.
- **Strange at night and magic only:** the creature things can glow; the visitor and town pieces are ordinary.

**Style line, at the start of every prompt:**

> True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national park poster and scout patch feel, light from the top left.

## C1. Creature jobs and places

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Creature job picture | `job_pic_creature` | the same size as `job_pic_visitor` | The big picture on a creature job's card: a jackalope, a deer with faintly glowing antlers and a badger peeking out together, in a violet frame |
| Creature job icon | `job_type_creature` | the same size as `job_type_visitor` | A paw print, violet. Your `job_kind_creature` may already do; if so, skip this one |
| A burrow | `obj_burrow` | 16 × 16 | A neat round rabbit hole with a little fan of dug earth. Send `_filled` too: the same spot patted flat, with a few grass tufts |
| A food left out | `obj_trail_food` | 16 × 16 | A small pile of greens on a flat leaf, laid on the ground as bait |
| The badgers' stone | `obj_offering_stone` | 16 × 16 | A flat, mossy stone with a tiny scratched badger face on it. Send `_full` too, with a small offering of food on it |
| A full moon | `sky_full_moon` | 32 × 32 | A big, pale, friendly full moon with soft craters, for the top of the screen on full-moon nights |

## C2. People

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| Cryptid hunter | `visitor_layer_cryptid` | one full layer sheet, as in Art Request 8 (64 × 96) | A new visitor layer: a khaki vest with too many pockets, a bucket hat, and a big camera on a strap. Eager, a bit sunburnt |
| Gord at the window | `npc_gord_sit` | 2 frames of 16 × 32 | Gord dressed up, sitting side-on with a diner mug in both hands. Frame 2: he takes a sip, eyes shut, very happy |
| Wren's late sign | `obj_percolator_late` | 16 × 16 | A small chalkboard sign with a moon and a coffee cup, by the Percolator's door on full-moon nights |

## C3. The guide, the Log and Esme

| Piece | Name | Size | What to draw |
| --- | --- | --- | --- |
| The aurora card | `fortune_card_aurora` | the same size as `fortune_card_sky` | Esme's Sky card, but green and violet ribbons over a dark pine line |
| Aurora chip | `chip_aurora` | 8 × 8 | A tiny green and violet ribbon, the same style as the other chips |
| Taste chips | `chip_loves`, `chip_likes`, `chip_wont` | 8 × 8 each | A heart, a tick and a cross, for what a creature thinks of a food |
| Log: creatures | `log_creatures` | the same size as `log_visitors` | The Log's Creatures page header: a paw print on a page of field notes |
| A gift left | `log_creature_gift` | 16 × 16 | Your `obj_creature_gift` bundle, as a small icon for the Log and messages. If the bundle already reads well at 16, skip this one |

---

Name the sheets `ar26_C1_creature_jobs.png`, `ar26_C2_people.png` and `ar26_C3_guide_log.png`. Send them in any order. The lab cuts them and drops them in.
