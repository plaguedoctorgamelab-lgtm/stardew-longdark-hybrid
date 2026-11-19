# Strange Ranger: the Jobs Rebuild, 0.5.0

From the lab, 19 November 2026. What was built from the Jobs Spec and the jobs art, the choices the lab made where the spec left room, what is not in yet, and what to test.

## What's in

All eight steps of the spec's build order:

1. **The engine.** One jobs module. Jobs, templates, types, givers, steps and rewards are all data. Steps are worked out from the world; steps that stay done are recorded; a job finishes the moment its last step is done and stays finished. It has the five signals. The old jobs code and the book's Jobs page are retired.
2. **Rewards.** Every kind the spec lists is given on the finishing card, once only, even across a reload. Something you already have is swapped for gold. Opening a joined site gives trail travel (tracker #15).
3. **The clipboard (J).**
   - Mark's frame, with Current, Noticed and Done tabs.
   - On the left, the list under a ribbon for each type. Each card has its icon, a progress bar, and pin, new and seasonal marks.
   - On the right, the chosen job: name and type picture, From, the note, You'll need (have/need in green, and where to get each thing), the steps (the next one on a yellow band, counts, "broken again", links to other jobs), and the rewards with "Something more...".
   - Pin and Show on map buttons, and the spec's keys and mouse controls.
4. **Notifications.**
   - Toasts at the left edge for new and noticed jobs, steps done or broken, and counts at each quarter.
   - The finishing card, with its DONE stamp and the rewards landing one by one, then the map opening on what changed.
   - The season's card, and "While you were away..." for an older save.
5. **The pinned note and the map.**
   - The note in the top left follows the spec's pinning rules; click it to open the job.
   - On the map, the pinned job's next step has a flag in its type's color and other jobs show dots. Hover one for its name and step.
   - Both settings are on the Options screen.
6. **The world and the opening.**
   - The station's three untidy spots, the branch on the trail, the trash can and its marker by the gate.
   - The pond trail, the last ranger's old path beside the stakes, and the old road are now old trail with gaps of no more than 30 tiles.
   - Get the Station Shipshape, then the first choice.
7. **All the jobs.**
   - 20 hand-written jobs and their notes, 17 templates, and the four seasonal jobs.
   - The season's turn and the morning top-up.
   - Some jobs are only found by noticing, and some rewards are a mystery: counts only, as asked.
8. **Full pass.** 259 automated tests pass. Older saves convert on load.

## Choices the lab made

- **When the three places appear.** The cabin, outlook and pond jobs (with their rumors) arrive on Get the Station Shipshape's finishing card, so they are its reward and the map opens on them. Tidying the papers turns up the notes as a message. Finding a place first still adds its job at once.
- **Seasonal jobs** appear only on a season's first morning, so a new game's first spring starts with just the first job. Spring's job first shows next spring.
- **The catalog in an older save** stays open: it was already in use.
- **Benches in the catalog** come from opening the outlook, as the spec says. Spruce Up the Gate needs a bench, so the gate job says "in the catalog, once the outlook is open".
- **The tower's radio** gives no forecast until Get the Tower Radio Talking is done. That includes older saves with the tower open: it needs a radio valve from the catalog.
- **Suggestion cards** that ask for a bench, a picnic table, a cleaner bathroom, a trash can or directions offer "Take this on" (up to 3 at a time). A card asking for a new bathroom has no job.
- **Gaps are dug** when trail joins their two ends. The count ("8 of 30") is the tiles of the gap's line that are trail.
- **A template job someone else does** (the custodian cleans the bathroom first) finishes on its own at half pay.
- **Trail travel** counts trail that comes within 3 tiles of a door, the same rule as a site being joined.

## Not in yet

- Townsfolk Favors (Phase 4, as the spec says).
- Two templates never come up yet: Tree Down needs storms that drop trees, and Point the Way at [junction] needs named junctions.
- No sounds: the game has no sound yet.
- The map's flourish draws a pulsing circle round each change. It does not yet draw a route along a trail travel way.
- A few of the hidden extras are simpler than described. The lab has a note of them.
- Your own save's tower case (tracker #15) can't be checked without the save. Trail travel is now a reward, and an older save with the tower open and joined gets it on load. Please load your save and look.

## Things to test

The spec's play checklist, with notes on where things are:

- [ ] Start a new game and finish Get the Station Shipshape: the desk, the bookshelf and the boots in the station (X), the axe from the chest for the branch just east of the door (C with the axe), the trash can by the door (X), and set it out by the red flag near the gate (C). Did it teach jobs without feeling like a tutorial?
- [ ] Choose where to go first. Was it a real choice?
- [ ] Open a site, then watch the finishing card and the map afterwards.
- [ ] Notice at least two jobs nobody told you about (a "!" over the ranger, and a toast).
- [ ] Mend a trail gap (the red flags on the map). Does one screen of digging feel right?
- [ ] Reach the tower by the stake trail without a week of digging. There are two gaps across the burn, with brush and two snags in the east one.
- [ ] Choose between two jobs because of their rewards.
- [ ] Get a Something more. Was it worth the wonder?
- [ ] Use the pinned note and the map to find your next step without opening the clipboard.
- [ ] Read the clipboard with eight or more jobs on it. Does it stay clear?
- [ ] Ignore the jobs for a few days. Did that feel fine?
- [ ] See a season turn (F1, then "+season"). Does the clipboard feel fresh?
- [ ] Load your old save. Did "While you were away..." pay you fairly, and is there trail travel to the tower?
- [ ] Write down what felt wrong, and any job you wished existed.

Also worth a look:

- [ ] J, Q/E, W/S, P, M and Escape on the clipboard; the mouse wheel over the list and over the detail; clicking outside the paper closes it.
- [ ] B now opens the book (the park, the ledger, cards, letters, the notebook, badges).
- [ ] Options: Show pinned job, and Show unlocks on the map.
- [ ] A suggestion card that asks for a bench: "Take this on".
