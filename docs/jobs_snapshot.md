# Strange Ranger: Jobs, a Snapshot

From the lab, 19 November 2026, version 0.4.10. What the game has right now, as a starting point for a new jobs design. No analysis: just what is there.

## 1. Where jobs come from

- **The note board** in the ranger station (X). Reading it:
  - offers the one written job, "Fix up the old cabin", and adds it to the Jobs page;
  - shows notes from the last ranger once a building is open, and each note adds rumor circles to the map;
  - shows the Chief's letters, a booked cabin and a lost party.
- **Finding a site.** Walking within 14 tiles of one of the four sites adds it as a job ("You've found the Scenic Outlook").
- **The radio** (station or tower) tells of a lost party, which adds a job.
- **The suggestion box.** A visitor's card that asks for something can be pinned, and shows under the jobs.

## 2. The jobs in the game now

| Job | Kind | Comes from | Building to repair | Materials for the repair |
| --- | --- | --- | --- | --- |
| Fix up the old cabin (the Old Cabin site) | Site with a building | Note board at the start | Old Cabin: door, walls, roof, window | 8 planks, 20 nails, 4 roofing, 1 window glass |
| Open the Static Tower | Site with a building | Finding it (rumor circle after the cabin opens) | Fire tower: stairs, cab floor, roof, windows | 10 planks, 22 nails, 4 roofing, 2 window glass |
| Open the Scenic Outlook | Site with no building (a marker post) | Finding it | None | None |
| Open the Kettle Pond | Site with no building (a cairn) | Finding it (rumor circle after the cabin opens) | None | None |
| Find the lost party | Park job (Phase 3) | Radio or note board, when visitors get lost | None | None |
| Ideas from the suggestion box | Pinned cards (Phase 3) | Pinning a card that asks for something | None | None |

The cabin job's note, as written in the game: "A note pinned to the board, in the last ranger's hand: 'There's an old cabin out past the stream, northeast, by my reckoning. Roof's gone, door's off. If you ever fancy fixing it up, it'd make a fine place to sleep out there. I've marked roughly where on your map. The axe and bedroll in the chest are yours.'" The job also lists "Handy to have: Bedroll, Axe".

**Notes from the last ranger** (on the note boards):
- **At the station, once the cabin is open:** "Past the pond our creek comes out of, there's an old fire tower. I put stakes in across the burn so I'd stop losing it. Follow the ribbons. Bring nails. More than that." It adds rumor circles for the pond and the tower.
- **At the tower, once it is open:** "The old road runs down off the hill to the river. The bridge was fine last time." It adds a rumor circle for the broken bridge. The bridge is a landmark, not a site, and has no job.

**Rumor circles on the map:**
- "Old cabin?" is there from the start.
- "Pond?", "Old tower?" and "Bridge?" come from the notes.

**Starting tools:**
- The axe, bedroll and shovel start in the station's chest.
- The saw is in the old cabin's chest.
- The hammer, lantern, map, compass and pencil start in the backpack.

## 3. How a site job works

Each site job has these steps, in this order:

| Step | Done when | Details |
| --- | --- | --- |
| Gather and bring | The backpack holds everything for the steps still to do | Repair materials for parts not started, the hammer, the shovel if the trail isn't joined, and a trail sign and hammer if there's no sign. Each item says where to get it: a chest, a supply shelf or a workbench box in a building that's open (the station first), or "make it", "order it from the catalog" or "gather it outdoors". |
| Find | The ranger has come within 14 tiles of it | |
| Map | X at its door, or at its marker post or cairn | |
| Join to the trail | Unbroken trail or boardwalk joins it to the station's door | Shallows count as a ford up to 24 tiles in a row. Tiles must touch side by side, not just at the corners. A site with no building counts once the station's trail comes within 3 tiles of its spot. |
| Repair | Every part of its building is repaired | Hammer (C) at its door. Each part takes 3 hammer actions of 20 minutes and its materials. Sites with no building skip this step. |
| Sign | A sign naming it stands on or beside the trail (up to 2 tiles off it) within 30 tiles of it | The sign is made with K (2 planks, 1 nail) or ordered from the catalog, and needs the hammer to put up |
| Settle | Only for a site with magic; no site has any today, so it isn't shown | |
| Open | X at its door or marker, then yes to "Declare the ___ open?" | Possible once all the steps above are done |

- Steps can be done in any order, and progress is never lost.
- Progress is worked out from the world each time, not counted. If a badger digs up the trail, "join to the trail" becomes undone again.
- **Opening a site:** it's marked on the map, visitors start coming to it (Phase 3), and its facility pads appear. Nothing else is given for finishing a job.
- **The lost party:** the job has a rumor circle where they were last seen. X near them sends them home, and they leave a tip, a thank-you card and Surveying experience. If nobody finds them, they turn up at the gate the next morning.

## 4. The Jobs page (J, the "Jobs" tab of the book)

1. **"Working on: ___"**: the job for the site last found, mapped or arrived at (it's saved).
   - Every step shows: [x] done, >> the next one, [ ] still to do.
   - Then "Handy to have", where a job has it.
2. **"Other jobs:"**: one line each with its next step ("Open the Kettle Pond: next, map it").
3. **The lost party and pinned suggestion cards**, when there are any.
4. **"Done:"**: the open sites.

**On the map and the screen:**
- A rumor circle for a place not yet found.
- Red flags at both ends of a trail still to dig, with dashes between.
- Red stars and pictograms at mapped landmarks.
- **"?" marks** over the station door and note board (unread jobs, notes or letters), a delivery on the supply shelf, new suggestion cards, a site ready to open, and a kit waiting at its pad.
- **Messages** at the moment a site is found, its trail joins the station's (or comes apart), and it opens.
- **Trail travel:** once you've arrived at a site twice and trail joins it to where you stand, the map lists it and you can walk there in one go.

## 5. Updates to jobs so far

| Version | What changed |
| --- | --- |
| 0.4.2 | A "Next:" list at the top of the book: the one next thing to do at each site found. |
| 0.4.7 | Jobs became ordered steps with "Gather and bring" first, counted for every step still to do. The Jobs page shows the job worked on in full, the others in a line, and what's done. Red dig flags on the map. |
| 0.4.9 | The job worked on follows the ranger (it used to always show the first site in the list). Things to bring and handy things say where to get them, never inside a building still locked. |
| 0.4.10 | Sites with no building can be opened at their post or cairn. Spot sites count as joined within 3 tiles. The game says when a site's trail joins or breaks. Steps for spot sites say "press X at its marker". |

## 6. Planned

- **Phase 4: jobs as typed steps with a step-done signal** (tracker #10, agreed on 18 November).
  - Keep progress worked out from the world.
  - Add typed steps in the job data (gather, go to, join trail, repair, sign, deliver, read), so new kinds of job are data, not code.
  - Add a signal when a step becomes done, for pop-ups, HUD ticks and rewards.
- **Roadmap, Phase 4 ("Humdrum"):** the town, with townsfolk who have daily routines and optional quests.
- **Game Bible:** the fortune teller "is the game's gentle hint system, in place of quest markers".
- **Earlier design lessons** (Open Questions): "A place you can't see needs a hint. A rough circle on the map works without becoming a quest marker." "An invitation helps. The note board and job list gave the cabin trip a reason without ordering it."

## 7. Tracker items about jobs

| # | Status | Title | Notes, as written |
| --- | --- | --- | --- |
| 2 | Fixed in 0.4.7 | needs unclear | "When you go to fix the tower you don't know what to bring for the job, so you can go all the way out there and still not have the right things. I also need more information about working on the trails, like use the shovel to connect these two locations I have marked on the map. Also maybe a job has sub-jobs?" |
| 3 | Fixed in 0.4.7 | jobs screen | "The jobs tab is a mess: old jobs, new jobs and sub-jobs get all tangled up and are still not clear enough. For example, it says to go to the pond then find the tower, but I have no idea what to bring to make it worth the trip. So maybe gather materials needs to be the first sub-job, and the sub-jobs add up to a big job." |
| 9 | Fixed in 0.4.9 | Jobs mixed up: the outlook showed the tower; tools not where expected | Reported in chat. |
| 10 | Open (Phase 4) | Phase 4: jobs as typed steps with a step-done signal | As in section 6. |
| 11 | Fixed in 0.4.10 | Scenic outlook could not be opened; its dig flags never cleared | Reported in chat. |
| 13 | Open | when done old cabin and scenic outlook it was confusing where to go next | "I know where to go, but I think it's at the cabin but not at the ranger station." |
| 15 | Open | we need to rethink jobs | "There needs to be an easy one at the start, like fixing the trail before even getting to the forest, so let's think strategically. Plus there should be multiple jobs at once so the game is not so linear. I connected the fire tower but could not get the map to show a shortcut to the fire tower, though I had been there more than once. I could get to the cabin but not further. So I will work on a job document tomorrow. Also you should get more rewards for finishing jobs." |

The tracker's notes are lightly tidied for spelling; the originals are on the tracker page.
