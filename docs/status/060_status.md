# Strange Ranger 0.5.4 and 0.6.0: the graphics refresh and Humdrum

From the lab, 21 November 2026.

## 0.5.4: the graphics refresh, first pass

From your Graphics Polish request and Interior Art Guide.

**The old cabin** is laid out to the guide's plan, with your new bed, stove (cold and lit) and chest. Your workbench, desk and supply shelf are cut too, ready for the station and the tower once you've seen the cabin. The guide asked for one room first.

**What's in from the Graphics Polish request:**

- **What am I looking at?** Indoors, the piece you face shows its name above it: "Wood stove", "Chest", "Bed".
- **Hits:** when the axe, saw, shovel or hammer lands, the ranger holds still a few frames, and chips of wood, leaves, dirt or stone burst out. Brush and fallen trunks jolt a pixel. A felled tree tips away in pixel steps and fades.
- **Breathing:** stand still for two seconds and the ranger rises a pixel and settles.
- **Depth:** buildings fade while the ranger walks behind them.
- **Fog and snow** drift over the world as pale patches, two layers at different speeds.
- **Options** has two new switches: Motion and Weather effects.
- **Water** already moves, with its shore of sand and foam (0.5.3).

**Not in yet:** footsteps, the pickup hop, rain splashes, puddles, wet ground, wind, lightning, falling leaves, settling snow, chimney smoke, opening doors and trees fading. They're next on the list.

**The art audit** is in `docs/art/art_audit.md`, with a contact sheet in `docs/art/art_audit_top10.png`. Every finished picture was measured and ranked.

- **Your ten most worth redoing:** mostly the item icons (compass, nails, pencil, reeds, repair kit, rope, saw, shovel, wildflowers), as you suspected: drawn finer than 32 by 32 can hold.
- **Wren's sheet** is on the list too. It keeps your own colours, so it needs a light hand pass for stray pixels.
- **Prompts:** each of the ten has a ready-to-paste prompt.
- **Not yet found:** 15 pictures are of things you haven't found yet. They're counted only.

## 0.6.0: Phase 4, the first pass

The first four steps of 4a, the town:

- **Humdrum:** press X at the park gate, the place that used to say the road wasn't open.
  - Humdrum has Main Street, the square, two lanes of houses, and Dusk Creek with its footbridge and the caravan.
  - Walk back east along the road to return to the park.
  - The Percolator, Casa Luna, the town ground and Wren are your art. The other buildings, the lamps and the notice board are the lab's stand-ins.
- **Named days:** the clock shows the day, as in "Mon Spr 1". Day 1 of every season is a Monday, so the Chief's report comes on Sundays.
- **Twelve townsfolk**, as in the spec:
  - Each has a home, a routine for each day, a rainy-day routine and a birthday.
  - They walk between places along the town's paths.
  - A keeper stands at their shop's door while it's open. At night and at home they're inside.
  - Wren is your sheet; the others are built from the visitors' layers in their own colours until their sheets come.
- **Talking:** X near someone.
  - Their name shows over them as you get close.
  - The box shows their name, hearts and what they say.
  - Talking once a day is worth 20 points.
  - Each person keeps to one line a day, and no line comes back within the week.
  - They mention what you've done in the park: sites opened, the first visitors, a badger, jobs done.
  - 193 everyday lines in all, and 12 more that come with friendship.
- **Gifts:** hold something and press C near someone.
  - Each person loves, likes, dislikes and hates their own things, and each loves something found only in the park.
  - Two gifts a week, plus a birthday gift that counts eight times.
  - Hearts never go down.
  - Wren, Teo, Nell and Sol stop at 8 hearts until dating, which comes in 4b.
- **Debug (F1):** Town, and "+1 heart all" to try the heart lines.

**Not yet in Phase 4:**

- the insides of the shops and houses, and buying and selling;
- clothing;
- the Social page and calendar;
- Townsfolk Favors and the notice board's notes;
- portraits;
- everything in 4b.

The town's building art also needs its own request.

## Things to test

- [ ] **The cabin:** go in by day and night. Does the guide's layout feel roomy? Does the stove's name show as you face it?
- [ ] **Hits:** chop a tree, clear brush and dig. Do they feel weightier? Try Motion off in Options.
- [ ] **Fog and snow** (F1, weather): are the patches pleasant or too much? Try Weather effects off.
- [ ] **Walk behind the station.** Does it fade so you can see yourself?
- [ ] **Humdrum:** X at the gate. Does it feel like a different, welcoming place?
- [ ] **Find someone at a given hour:** Wren is at her shop from 5:00 and by the creek at 15:00, except Wednesdays and rainy days.
- [ ] **Talk to everyone.** Does each sound like their own person?
- [ ] **Give a loved gift.** Wren loves roast hazelnuts, Pip berries, Gus planks.
- [ ] **Hear the town mention the park:** open the old cabin, then talk to Gus or Wren.
- [ ] **Walk Main Street at night.** Are the lamps warm enough?
- [ ] **Your old save** loads outside town, with nobody met yet.
