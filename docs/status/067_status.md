# Strange Ranger 0.6.7: Humdrum gets its art, and its road opens later

From the lab, 22 November 2026. Mark's Art Request 19 sheets are in the town, and the road to Humdrum now opens once the ranger has found their feet in the park.

## The town's new look

Screenshots are in `docs/status/067_shots/`, by day, at night and in each season. The "before" pictures are in `docs/art/ar19_town_today/`.

- **Every building is Mark's.** Outfitters, Gifts & Notions, the carpentry, the library, Town Hall and post office, the bandstand, Esme's caravan and all eight houses. The Percolator and Casa Luna are unchanged.
- **Windows glow at night.** The game finds the pale blue glass in each picture and lights it warm yellow after dusk, drawn above the night's tint so it really glows.
- **Streetlamps light up** at night with Mark's lit lamp picture, as well as their glow.
- **Grounds meet properly.** Main Street, the lanes, the flower beds and the creek have soft edges where they meet the lawn, from Mark's edge sets. The lawn is recoloured to match his grass.
- **The square** has a paved south half with the compass-and-eye mosaic in the middle, benches either side, and a border of setts round the paving.
- **Dusk Creek** wanders a little, with sandy banks, shallows, reeds, stones and lily pads. Esme's caravan has its willow.
- **Backyards.** The north houses have a picket fence, a hedge (the mayor's) or a stone wall behind them, and each yard fits who lives there: the Pelletiers' washing line, Bev's birdbath, Agnes's bench, the Mendozas' vegetables, Gus's crates. Every house has a mailbox.
- **No bare lawn.** Bushes in clumps, grass tufts and wildflowers scattered, a darker forest floor round the edge, and the border forest two trees deep.
- **Main Street** has a signpost, the Percolator's chalk board, planters, a bin, crates and barrels by the carpentry, and a bike rack by the library.
- **The seasons:** crabapples along Main Street blossom in spring with petals underneath; bunting between the shops in summer; leaves and pumpkins in autumn; string lights in winter, lit at night.

## The road opens later

A new game starts with the road to Humdrum closed. Pressing X at the gate says: "ROAD CLOSED FOR REPAIRS, says a sawhorse across the town road. The station needs you first anyway."

The road opens the morning after the first job, **Get the Station Shipshape**, is done, or on **day 4** whatever happens. That morning a letter from the chief is waiting at the station: the county crew has finished the road, Humdrum would like to meet its new ranger, and Wren says the first coffee's on her.

Saves from before 0.6.7 have the road open already. The debug panel can still go to town at any time. The condition is one line in tuning (`town.opens_when`), so it is easy to change.

## Choices the lab made

- **Inner corners.** Mark's sheet drew the inner corners as small ponds, so the lab made its own from his outer corners.
- **The lawn's colour.** Mark's grass is brighter than the town's older lawn, so the lawn keeps its texture in his colours.
- **The bandstand** is a tile narrower than before (six tiles) to fit Mark's picture.
- **Signs** shrink to texture at game size: they read as signs, not as words.
- **The Town Hall** keeps Mark's clock and flag for now.

## Things to test

- [ ] **Start a new game** and try the gate on day 1. Does the closed road make sense?
- [ ] **Finish Get the Station Shipshape** and sleep. Is the chief's letter there, and does the gate open?
- [ ] **Walk Main Street by day and at night.** Do the windows and lamps feel warm?
- [ ] **Look at the square.** Does the compass read as our emblem?
- [ ] **Walk behind the houses.** Do the backyards say who lives there?
- [ ] **Cross the footbridge** to the caravan. Does the creek look like a creek?
- [ ] **Check each season** if you can (the debug panel sets the date).
