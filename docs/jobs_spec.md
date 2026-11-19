# Strange Ranger: Jobs System Spec

This spec replaces the jobs system as it stands in version 0.4.10. It was worked out with the designer on 19 November 2026 from the lab's jobs snapshot. It adds no new areas and no new game systems: it rebuilds how jobs are offered, tracked, shown and rewarded, using what the game already has.

## Purpose and scope

The jobs system must become the bedrock that every later area, character and challenge plugs into. Today it is one chain of jobs shown as a page of text. It must become several kinds of job running side by side, each with a giver, a clear purpose, a visible reward and a satisfying finish, shown on a page that is a pleasure to read.

**What the designer found wrong, from play and the tracker:**

- The jobs run in one line: station, cabin, pond and tower, bridge. There is rarely a real choice of what to do next.
- Finishing a job gives nothing. "Several times I finished and was like, oh well, I did that."
- Building the trail to the tower took more than a game week of digging across open ground, with many nights out, no feedback and the rest of the park ignored.
- There is no gentle first job to learn how jobs work.
- The Jobs page is hard to read, runs over its edges and has no hierarchy.
- After the cabin and outlook it was unclear where to go next (tracker #13).
- Trail travel to the tower never appeared, though the trail was joined and the tower visited more than once (tracker #15).

**In this spec:**

- Five job types, each with its own giver, icon and color. Three and a part of a fourth are live now.
- Jobs from two sources, given and noticed, plus jobs unlocked by finishing others.
- Every job described the same way: name, giver, note, what you'll need, steps and rewards.
- Rewards for every job, shown before starting.
- Typed steps worked out from the world, with a signal when a step is done: tracker #10, brought forward from phase 4.
- Hand-written jobs and template jobs.
- The turn of the season: what stays, what goes, what is new.
- A new opening, with a first job that teaches jobs and a real choice straight after.
- Trail jobs no larger than one screen.
- Three levels of notification.
- A new Jobs page, a pinned job on the main screen, and job markers on the map.
- The fixes for tracker items #13 and #15.
- The small changes to the world these need.

**Not in this spec:** new areas, new sites, new tools, new creatures, townsfolk, badges, decorating, and any reward that needs a system the game does not yet have. Townsfolk Favors are designed here so the system is ready for them, but none exists until phase 4.

**Where this spec and older specs disagree,** this spec wins for everything about jobs. The Game Bible and Roadmap are updated to match.

## Design rules

Every job, hand-written or made from a template, must pass these rules.

1. **A job is an invitation.** Givers ask, suggest and wonder. They never order. No job is required to keep playing.
2. **Doing nothing is fine.** A day with no job touched costs nothing. No job fails, and no job has a deadline except the end of its season.
3. **There is usually a choice.** After the first job, the player should almost always know of at least two jobs of different types, and often two of the same type.
4. **Every job pays.** Every job has at least one reward, and every reward is shown before the job is started.
5. **Unlocks come first.** The best rewards open something: a place, a way of travelling, an ability, a hint. Money and supplies fill in around them.
6. **Jobs are small.** No single job should need more than about one game day of work, or more than one night away from a bed. Large aims are split into several jobs.
7. **Trail jobs mend, they don't build.** No trail job asks for more than one screen of new trail, and old trail is always visible at both ends of the gap.
8. **Progress is never lost.** Work done on a job stays done. A job finished stays finished, even if the world later changes.
9. **The player always knows the next step.** Every job shows its next step, where to do it, and what to bring.
10. **Not everything is told.** Some jobs are only found by wandering, and some rewards are a mystery until they are given.
11. **Magic runs through everything.** Any type of job may lead to something odd, and none explains it.
12. **When in doubt, do it like Stardew Valley.**

## The five job types

Each type has a giver, a color and an icon, so the player knows at a glance what kind of job it is and whose voice it speaks in.

| Type | Giver | Color | Icon | What its jobs are about | Live now |
| --- | --- | --- | --- | --- | --- |
| Exploring | The last ranger, through notes left behind | Pine green | Compass | Finding, mapping and opening places | Yes |
| Park Upkeep | The Chief, through letters | Lake blue | Broom | Keeping the park clean, stocked and welcoming | Yes |
| Trail Work | The Chief | Earth brown | Shovel | Clearing, mending and signing trail | Yes |
| Visitor Requests | Visitors, through suggestion cards and the radio | Warm orange | Speech bubble | What visitors ask for, and finding those who get lost | Yes: pinned cards and lost parties |
| Townsfolk Favors | People in Humdrum | Berry red | Basket | Favors for the town's people | No: phase 4 |

**Givers' voices.**

- **The last ranger** writes in quick, cheerful, practical scraps, a little scattered, and fond of the park. Their notes are found, not sent.
- **The Chief** writes short, warm, slightly formal letters, and now and then lets slip that he knows more than he says.
- **Visitors** write a line or two in their own voices: hikers, families, scouts, anglers.
- **Noticed jobs** have no giver. They are the ranger's own jotted notes, in a plain first-person shorthand: "Bench at the outlook's rotten. Worth a new one."

**Magic in every type.** A noticed note may describe something that should not be there. An upkeep job may turn up an odd object. A trail job may pass a place that changes overnight. A visitor's card may mention a light, a ripple or a voice. None of these is explained, and the details are kept in the spoiler addendum.

## Anatomy of a job

Every job, of every type, has the same parts, always shown in the same order. This is what the Jobs page displays and what the job data holds.

| Part | What it is | Example |
| --- | --- | --- |
| Name | A short, plain verb phrase, at most about 28 characters | Mend the Gap by the Pond |
| Type | One of the five | Trail Work |
| Giver | Who asks, shown as "From: ..." | The Chief |
| Note | Two to four lines in the giver's voice: why it matters, and a hint of where | "The old trail past the cabin gives out before the pond..." |
| Appears when | The condition that adds the job to the clipboard. Not shown to the player. | The pond has been found |
| You'll need | The tools and materials for every step still to do, with counts and where to get each | Shovel ×1, Axe ×1, Food for a day ×1 |
| Steps | Two to six steps, each a typed step | Reach the gap, Clear the fallen trunk, Dig the gap, Walk the trail |
| Rewards | One to four rewards, shown before starting | Trail travel to the pond, $40, A rumor of somewhere new |
| Something more | An optional hidden bonus, shown only as "Something more..." | (Kept in the spoiler addendum) |
| Season | Whether it lasts until done, belongs to one season, or may retire at the season's turn | Until done |
| Size | Small, medium or large. Decides the reward scale and the finishing notification. | Medium |
| Map spot | Where the job's next step happens, if known | The west end of the gap |

**Rules for the parts.**

- "You'll need" counts only what the steps still to do require. As steps are done, it shrinks.
- Each thing in "You'll need" shows how many the ranger has against how many are needed, in green once there are enough. It also says where to get it: a named chest, the supply shelf, the catalog, "make it", or "gather it outdoors". Never a building the ranger cannot yet enter.
- "You'll need" may also list **handy** things, in grey, which help but are not needed, such as a bedroll for a job far out.
- A step that another job would complete shows a link to that job instead of instructions: "Join to the park's trails: see Mend the Gap by the Pond."

## Where jobs come from

Jobs reach the clipboard in three ways. All three add the job immediately, with a small notification, and all three can happen anywhere.

### Given

Someone asks.

| Channel | Gives | How |
| --- | --- | --- |
| Station note board | Exploring notes from the last ranger, the Chief's letters | Reading a note or letter adds its job |
| Notes elsewhere | Exploring notes in cabins, towers and other places | Reading them adds their job |
| Radio, at the station or a tower | Lost parties, and the Chief's urgent asks | Listening adds the job |
| Suggestion box | Visitor Requests | A card that asks for something offers a "Take this on" choice; yes adds it as a job |

The last only adds a job when the ranger chooses, because cards are many and most are only comments. This replaces "pinning" a card.

### Noticed

The ranger spots something.

- A **noticeable** thing is a spot in the world with a small trigger area. When the ranger first comes within it in daylight, or with a lantern lit at night, the ranger's jotted note appears and the job joins the Noticed tab.
- A small "!" bubble shows over the ranger's head for a moment, with a pencil-scratch sound.
- Noticed jobs are the main way the player finds jobs nobody told them about. The player is never told how many exist.
- Some noticeable things appear only in a season, after rain, or at night.
- The full list of noticed jobs for rings one and two is in the spoiler addendum.

### Unlocked

Finishing one job reveals others: its rewards may include rumors of new places, each of which comes with an Exploring job to find it, or a follow-on job. These arrive with the finishing card, so the player sees the new choices at the moment they are earned.

### Finding a site

Finding a site the ranger had no job for (by wandering, without the rumor) adds its Exploring job then and there, with its first step already ticked. This is how the game works today and it stays.

## Steps

Every step is one of a fixed set of kinds. A job's steps are data, so a new job needs new rows, not new code. This is tracker #10, built now rather than in phase 4.

### Step kinds

| Kind | Parameters | Done when | Stays done? |
| --- | --- | --- | --- |
| `pack` | The job's "You'll need" list | The backpack holds everything needed for the steps still to do | Yes, once the next step has begun |
| `go_to` | A place and a radius | The ranger is within the radius | Yes |
| `find` | A site or landmark | It has been found | Yes |
| `map` | A site or landmark | It has been mapped | Yes |
| `read` | A note, letter or card | It has been read | Yes |
| `talk_to` | A visitor party | The ranger has spoken to them | Yes |
| `clear` | One or more obstacles: trunk, brush, branch, stump, debris | All are gone | Yes |
| `dig` | A stretch of trail between two marked ends | Every tile between the ends is trail | No |
| `join_trail` | A site, or two trail points | Unbroken trail joins them, using the visitors' trail network | No |
| `repair` | A building, or one part of it | Every listed part is repaired | Yes |
| `sign` | A site, junction or trail end, and the kind of sign | A sign of that kind stands within its range | No |
| `place` | A placeable, a count, an area | That many stand within the area | No |
| `deliver` | Items, counts and a destination chest or spot | The ranger has put them there | Yes |
| `clean` | A bathroom or a messy spot | It has been cleaned since the job appeared | Yes |
| `empty` | Trash cans | Each has been emptied since the job appeared | Yes |
| `pick_up` | Litter in an area, or a count | That much has been picked up since the job appeared | Yes |
| `shoo` | A troll badger at a site | It has been shooed | Yes |
| `survey` | A place | A survey has been done there | Yes |
| `open` | A site | The ranger has declared it open | Yes |

### How steps are checked

- As today, progress is worked out from the world, not counted by hand, for every step that does not stay done.
- A step that **stays done** is recorded once it becomes true and is never undone. A step that does not, such as a trail join, is checked again whenever the world changes.
- Steps can be done in any order, apart from these:
  - `pack` is always shown first, and is done only while the job has another step still to do.
  - `open` can be done only when every other step is done.
- A step that is done before the job appears, for example trail the ranger dug for fun, shows as done as soon as the job appears.
- **The job is finished at the moment its last step is done.** It stays finished even if a step that does not stay done later comes undone. A trail broken after the job is finished becomes a new upkeep or trail job, never an unfinished old one.

### Signals

- `job_added(job, source)`, when a job joins the clipboard.
- `step_done(job, step)`, when a step becomes done for the first time.
- `step_undone(job, step)`, when a step that does not stay done comes undone before the job is finished.
- `job_done(job)`, when the last step is done.
- `job_retired(job)`, when the season's turn removes a job.

Notifications, the pinned note, rewards, sounds and the map all listen to these signals rather than checking jobs themselves.

## Rewards

Every job pays, and every reward is shown on the job before the player starts, so rewards help them choose. Rewards are given all at once, on the finishing card, at the moment the last step is done.

### Kinds of reward

Only rewards the game can already give are used. Listed in order of preference, as the designer asked.

| Kind | What it gives | Shown as |
| --- | --- | --- |
| Rumor | A rumor circle on the map, with an Exploring job to find what it points to | "A rumor of somewhere new" |
| Trail travel | Trail travel to a site, from any place joined to it by trail | "Trail travel to the pond" |
| Map reveal | Part of the map filled in, as a survey would | "A sketch of the burn" |
| Unlock | A catalog entry, a recipe, a facility pad, or a way of doing something | "Benches in the catalog" |
| Follow-on job | A new job that the finished one leads into | "Another job from the Chief" |
| Story | A journal page, a note or a hint, kept in the notebook | "A page of the last ranger's journal" |
| Things | Supplies, food, or a rare ingredient, put in the backpack or, if full, the nearest chest | "10 nails, 4 planks" |
| Money | Dollars into the wallet | "$40" |
| Experience | Experience in the skill the job used most | "Trailcraft experience" |

### Something more

- About one job in four has a hidden bonus, shown on the job only as a purple question mark and "Something more...".
- It is revealed on the finishing card, after the listed rewards.
- It is always pleasant and never just more money: a story item, an odd object for the notebook, a rare ingredient, a small unlock, or a strange happening.
- What each one is lives in the spoiler addendum, never in anything the designer reads.

### Reward sizes

Each job has a size that sets how much it gives.

| Size | Typical work | Rewards | Money | Experience |
| --- | --- | --- | --- | --- |
| Small | Under two game hours, near a trail | One or two | $10 to $30 | 20 to 40 |
| Medium | A morning to a day | Two or three, including at least one unlock, rumor, trail travel or story | $30 to $80 | 60 to 120 |
| Large | A day or so, with planning; opening a site with a building | Three or four, including at least one unlock and one rumor or trail travel | $80 to $200 | 150 to 300 |

### Rules

- Every medium or large job gives at least one reward that is not money, supplies or experience.
- Opening a site always gives trail travel to it, provided it is joined by trail, which fixes tracker #15.
- A reward is given once only, and recorded, so it is never given twice, even after a reload.
- Rewards that would duplicate something the ranger has already got are swapped for their value in money, and the card says so in one kind line.

## The turn of the season

The clipboard changes with the seasons, so each one feels fresh, without ever taking away work the player has started.

### What happens on the first morning of a season

| Kind of job | At the turn |
| --- | --- |
| Exploring jobs | Stay until done |
| Hand-written jobs marked "until done" | Stay until done |
| Seasonal jobs from the season just ended | Retire. Each may return next year in the same season. |
| Untouched template jobs (no step done) | Retire, and fresh ones are drawn |
| Any job with at least one step done | Stays until done |
| Lost parties | Unaffected; they last a night at most |

- The new season's hand-written seasonal jobs are added that morning.
- A **season card** greets the player on waking: the season's name, how many jobs have retired, and how many new ones are on the clipboard. It is one card, not a list.

### Keeping the clipboard stocked

Template jobs are kept topped up through each season, not only at its turn.

- Each type has a target for how many of its template jobs are on the clipboard at once.
- Each morning, if a type is below its target, one new template job of that type is drawn, if one fits the park.
- A template job is drawn only when its condition is true in the world. A park with no bathrooms gets no bathroom jobs.
- The same template is never offered twice at the same place at the same time.

| Type | Target of template jobs at once |
| --- | --- |
| Park Upkeep | 3 |
| Trail Work | 2 |
| Visitor Requests | Up to 3 cards a week offer "Take this on" |

The longer-term goal is 10 to 15 jobs per type each season. Rings one and two can support fewer, and that is right for now: the targets go up as the park grows.

### When there is nothing to do

If the clipboard is ever empty, the pinned note says "Nothing on the clipboard. The forest's still there." That is a fine state, never a problem.

## The opening

The first hours teach how jobs work, then hand the player a real choice of where to go.

### The first job

On the first morning, the station note board holds one letter from the Chief, which gives the job **Get the Station Shipshape**. It has three parts, done in any order, all within a few minutes' walk of the bed:

1. **Tidy the station.** Three untidy spots inside, each tidied by interacting: a heap of old papers on the desk, a dusty shelf, a pile of boots by the door. Tidying the papers turns up the last ranger's notes.
2. **Clear the branch.** A fallen branch lies across the trail a short way past the station door, toward the meadow. It needs the axe from the station chest and gives firewood.
3. **Set out the trash can.** A trash can stands in the station, and a marker by the gate shows where it goes.

This teaches, in turn: the Jobs page and pinned note, interacting, taking a tool from a chest, clearing an obstacle, and carrying and placing a thing. Each part gets its small tick. Finishing gives the first full finishing card.

### The first choice

The last ranger's notes, turned up in the tidying, give rumors of three places at once:

- the old cabin, out past the stream;
- a high place with a view: the outlook;
- a pond the creek comes from.

Each comes with its Exploring job. Two small template jobs, one Park Upkeep and one Trail Work, appear nearer home at the same time. The player now has five jobs of three types to choose among, and no wrong answer.

### How the first places lead on

| Opening this | Leads to |
| --- | --- |
| Get the Station Shipshape | Rumors of the cabin, the outlook and the pond; the supply catalog |
| The old cabin | A rumor of the tower, if not yet given; Reopen the Pond Trail |
| The outlook | A sketch of the land round it; benches in the catalog |
| Kettle Pond | A rumor of the tower, if not yet given |
| The tower, when found | The two trail jobs across the burn |
| The tower, when opened | A rumor of the bridge; Clear the Old Road |

The tower's rumor comes from whichever of the cabin or the pond is opened first, so the player can reach it through either. The walk itself always passes the pond and crosses the burn.

### Saves from before this change

- When an older save loads, every job is worked out from the world.
- Any job whose steps are already all done is finished on the spot, and all its rewards are given.
- One summary card, "While you were away...", lists the jobs finished this way and their rewards together, so the designer's past work is properly paid.
- Get the Station Shipshape is offered as normal. Its parts are still there to do.

## The hand-written jobs

These are every hand-written job in rings one and two. "You'll need" is worked out from the steps; only things it would not show are listed. Notes follow each table, in the giver's voice. The lab may polish wording but not change meaning. Every "Something more" is described only in the spoiler addendum.

### Exploring

| Job | Size | Appears when | Steps | Rewards |
| --- | --- | --- | --- | --- |
| Open the Old Cabin | Large | The station's papers are tidied, or the cabin is found | Pack; find the cabin; map it; repair the door, walls, roof and window; join it to the trail; sign it; open it | Trail travel to the cabin · Reopen the Pond Trail · a rumor of the tower, if not yet given · $100 · 200 Woodcraft · Something more |
| Open the Scenic Outlook | Medium | The station's papers are tidied, or the outlook is found | Find it; map it; join it to the trail; sign it; open it | Trail travel to the outlook · a sketch of the land round it (an outlook survey's reveal, given free) · benches in the catalog · $40 · 100 Surveying |
| Open Kettle Pond | Medium | The station's papers are tidied, or the pond is found | Find it; map it; join it to the trail (links to Reopen the Pond Trail); sign it; open it | Trail travel to the pond · a rumor of the tower, if not yet given · $60 · 100 Surveying · Something more |
| Open the Static Tower | Large | The tower's rumor is given, or the tower is found | Pack; find the tower; map it; repair the stairs, floor, roof and windows; join it to the trail (links to both stake trail jobs); sign it; open it | Trail travel to the tower · a rumor of the bridge · Clear the Old Road · Get the Tower Radio Talking · $150 · 250 Surveying · Something more |
| Get the Tower Radio Talking | Small | The tower is opened | Pack a radio valve; repair the radio | The forecast at the tower · $20 · Something more |
| Find the Old Bridge | Small | The bridge's rumor is given | Find the bridge; map it | A page of the last ranger's journal · $20 · 60 Surveying |

Find the Old Bridge ends with the bridge still broken. The job's finishing card says so kindly: it is beyond the ranger for now.

**Notes.**

- **Open the Old Cabin.** "There's an old cabin out past the stream, northeast, by my reckoning. Roof's gone, door's off. Fix it up and it'd make a fine place to sleep out there. I've marked roughly where on your map."
- **Open the Scenic Outlook.** "North of the fork, the trail climbs to a rock with the best view this side of the river. Bring a pencil. You'll want to draw it."
- **Open Kettle Pond.** "Our creek comes out of a pond somewhere up past the cabin. Never did find the name for it. Somebody ought to."
- **Open the Static Tower.** "Past the pond there's an old fire tower. I put stakes in across the burn so I'd stop losing it. Follow the ribbons. Bring nails. More than that."
- **Get the Tower Radio Talking.** "The tower radio needs a valve. Good radio, that, if a little ahead of itself."
- **Find the Old Bridge.** "The old road runs down off the hill to the river. The bridge was fine last time."

### Park Upkeep

| Job | Size | Appears when | Steps | Rewards |
| --- | --- | --- | --- | --- |
| Get the Station Shipshape | Medium | A new game begins | Tidy the station (three spots); clear the branch; set out the trash can by the gate | Rumors of the cabin, the outlook and the pond · the supply catalog · $50 · 40 Woodcraft |
| Spruce Up the Gate | Medium | Get the Station Shipshape is done | Pick up 5 litter at the gate; place 2 trash cans by the kiosk; place a bench by the kiosk | Picnic tables in the catalog · a letter from the Chief · $40 |
| Stock the Old Cabin | Small | The cabin is opened | Deliver 10 firewood and 2 tins of beans to the cabin chest | $25 · Something more |
| Stock the Tower | Small | The tower is opened | Deliver 10 firewood and 2 tins of beans to the tower chest | $30 · Something more |

**Seasonal upkeep.** One for each season. Each appears on the season's first morning, once the first job is done, and retires at the season's end.

| Job | Season | Steps | Rewards |
| --- | --- | --- | --- |
| Clear the Winter's Mess | Spring | Pick up 15 litter across the meadow and gate; clear 3 branches on the station trail | $40 · 60 Trailcraft · Something more |
| Ready for the Crowds | Summer | Place 2 more trash cans at the busiest open site; clean every bathroom once | 2 trash cans back, free · $60 |
| Stock Up for Winter | Autumn | Deliver 15 firewood to each open cabin and tower | $50 · 80 Woodcraft |
| Check on the Cabins | Winter | Go to each open cabin and tower; light its stove | $40 · Something more |

**Notes.**

- **Get the Station Shipshape.** "Welcome, Ranger. The station's been empty a while, and it shows. Tidy it up, clear the branch on the trail, and set the trash can out by the gate. Take your time. The Chief"
- **Spruce Up the Gate.** "Visitors judge a park by its front door. A couple of trash cans and somewhere to sit would go a long way."
- **Stock the Old Cabin / Stock the Tower.** "A chest with dry wood in it is the best welcome there is. Worth keeping one stocked."
- **Clear the Winter's Mess.** "Winter's left its usual calling cards. A tidy-up before the crowds would be grand."
- **Ready for the Crowds.** "Summer's here, and so is everyone else. More cans, cleaner bathrooms, fewer letters to me."
- **Stock Up for Winter.** "The nights are drawing in. I'd rather you were warm out there."
- **Check on the Cabins.** "Cold week coming. Would you look in on the cabins? I worry about them, in my way."

### Trail Work

| Job | Size | Appears when | Steps | Rewards |
| --- | --- | --- | --- | --- |
| Point the Way at the Fork | Small | Get the Station Shipshape is done | Put up pointer signs at the fork toward the cabin and the outlook | 2 blank signs · $20 · 40 Trailcraft |
| Reopen the Pond Trail | Medium | The cabin is opened, or the pond is found | Pack; clear the three fallen trunks; dig the first gap; dig the second gap; join the cabin to the pond | The pond joined to the park's trails · $50 · 100 Trailcraft · Something more |
| Mend the Stake Trail, West | Medium | The tower is found | Clear the brush; dig the gap; join the pond to the stake trail's middle | A sketch of the burn · $50 · 100 Trailcraft |
| Mend the Stake Trail, East | Medium | The tower is found | Clear the brush and snags; dig the gap; join the stake trail's middle to the tower steps | The tower joined to the park's trails · $60 · 100 Trailcraft · Something more |
| Clear the Old Road | Medium | The tower is opened | Clear the fallen trunk; clear the two overgrown stretches; join the tower to the bridge's west end | Trail travel to the bridge's end · $50 · 100 Trailcraft |

Each gap is at most one screen wide, with old trail plainly visible at both ends, as the world changes section sets out.

**Notes.**

- **Point the Way at the Fork.** "Hikers will reach the fork and stand there scratching their heads. A sign or two would save them."
- **Reopen the Pond Trail.** "The old trail past the cabin gives out before the pond. Trees down, and a couple of stretches gone to grass. Not much work, all told."
- **Mend the Stake Trail, West / East.** "The last ranger's stakes still mark the way across the burn, and their old path is mostly there. Two gaps want digging, one each side of the middle. Do them in either order."
- **Clear the Old Road.** "The road down to the river is sound underneath. A tree, two weedy stretches, and it's a road again."

### Visitor Requests

| Job | Size | Appears when | Steps | Rewards |
| --- | --- | --- | --- | --- |
| The Scouts' Litter Badge | Small | A scout troop first camps in the park | Talk to the troop leader; pick up 10 litter near their camp | A scout's drawing, for the notebook · $30 · 40 Trailcraft |

All other Visitor Requests come from templates.

**Note.** "Dear Ranger, my troop is working on the Litter badge and they need a real ranger to see them do it. We are at the campground. — Troop Leader"

## Template jobs

A template is a pattern for a job with blanks, filled from what is really in the park at the moment it is drawn. Templates keep the clipboard stocked with jobs that always fit the player's own park.

### How a template works

- **Condition:** what must be true for it to be drawn, such as "a bathroom at an open site is grubby".
- **Blanks:** filled from the world when drawn: \[site\], \[trail\], \[count\], \[item\], \[junction\].
- **Name and notes:** each template has a name pattern and at least three note wordings in its giver's voice, picked at random, so it rarely reads the same twice.
- **Steps and rewards:** as for any job, with sizes set by the template. Money may vary by up to 20% either way.
- **Lasts:** until done, or until the season's turn if untouched.

### Park Upkeep templates

| Template | Condition | Steps | Size | Rewards |
| --- | --- | --- | --- | --- |
| Clean Up at \[site\] | A bathroom at \[site\] is grubby or worse | Clean the bathroom | Small | $15 · 20 Woodcraft |
| Empty the Bins at \[site\] | Cans at \[site\] are three-quarters full | Empty each can | Small | $15 |
| Litter on the \[trail\] Trail | 5 or more litter along \[trail\] | Pick up the litter | Small | $15 · a chance of a lost belonging |
| More Cans for \[site\] | An open site with visitors has fewer than 2 cans | Place \[count\] trash cans at \[site\] | Small | $20 · a trash can back, free |
| A Seat at \[site\] | An open site has no bench | Place a bench at \[site\] | Small | $25 |
| Restock \[building\] | An open cabin or tower chest has under 5 firewood | Deliver 10 firewood to \[building\] | Small | $20 |
| A Badger at \[site\] | A troll badger has moved into \[site\] | Shoo the badger; clear the mess that drew it | Small | $25 · Something more, the first time only |

### Trail Work templates

| Template | Condition | Steps | Size | Rewards |
| --- | --- | --- | --- | --- |
| Tree Down on the \[trail\] Trail | A storm has dropped a trunk across \[trail\] | Clear the trunk | Small | $20 · 30 Trailcraft |
| Badger Diggings on the \[trail\] Trail | A badger has dug up a trail tile | Fill in the diggings | Small | $15 |
| Point the Way at \[junction\] | A junction of three or more trails leading to open sites has no pointer | Put up pointer signs at \[junction\] | Small | $20 · a blank sign |
| Name \[site\] | An open site's name sign has been taken down | Put up a name sign | Small | $15 |

### Visitor Requests templates

These come from suggestion cards. A card that asks for something carries a "Take this on" choice; taking it on adds the job, given by the card's writer.

| Template | Card asks for | Steps | Size | Rewards |
| --- | --- | --- | --- | --- |
| A Bench, Please | A bench at \[site\] | Place a bench at \[site\] | Small | $25 · a thank-you card |
| Somewhere to Eat | A picnic table at \[site\] | Place a picnic table at \[site\] | Small | $30 · a thank-you card |
| Which Way? | A sign at \[junction\] | Put up a pointer at \[junction\] | Small | $20 · a thank-you card |
| The Bathroom at \[site\] | A cleaner bathroom | Clean it | Small | $20 · a thank-you card |
| Find the Lost Party | (From the radio, not a card) A party is lost | Go to where they were last seen; find them; talk to them | Small | A tip of $20 to $50 · 60 Surveying · a thank-you card |

Find the Lost Party keeps its present behavior: a rumor circle where the party was last seen, and the party turns up at the gate by morning if nobody finds them. It is retired, not failed, at 6:00.

### Rules for templates

- A template's condition is checked again when the job would be drawn, and the job is never drawn if its work is already done.
- If the world later makes a template job pointless, such as a staff custodian cleaning the bathroom first, the job finishes on its own and pays half its money, with a line naming who did it. Nothing else is lost.
- No more than one template job of the same template is on the clipboard at the same place.

## Notifications

The game tells the player about their progress at three levels, louder for bigger moments. All are driven by the job signals.

### Small: a toast

**When:** a job is added, a step is done, a step comes undone, a job is noticed.

- A short line slides in at the left edge of the screen, under the pinned note, with the job type's icon and color.
- It stays four seconds, then fades. Up to three stack; more wait their turn.
- Play does not pause.
- Wordings:
  - Added: "New job: Open Kettle Pond".
  - Noticed: "Noted: the outlook bench is rotten", with a pencil-scratch sound and a "!" over the ranger.
  - Step done: a tick and the step's name, "Mended the first gap", with a soft chime.
  - Step undone: "The pond trail is broken again", with a gentle low note, never an alarm.
- **Counting steps:** for a step with a count, such as tiles to dig or litter to pick up, a toast shows at each quarter: "Gap: 8 of 30 tiles". The pinned note updates on every tile.

### Medium: the finishing card

**When:** any job is finished.

- Play pauses. A card rises in the middle of the screen, in the clipboard style.
- It shows the job's type icon, its name, and a stamp that thumps on: "DONE".
- The rewards appear one by one, each with a small sound as it lands: icon, label, and where it went ("$40 into your wallet", "Nails in your backpack").
- Something more, if any, comes last: the question mark flips over to show what it is.
- Any jobs the rewards have unlocked are listed at the bottom: "New on your clipboard: ...".
- One key or click closes it. It cannot be skipped before the stamp lands, about one second.

### Large: the finishing card, then the map

**When:** a job is finished whose rewards include a rumor, trail travel or a map reveal.

- After the finishing card closes, the map opens by itself, centered on the change.
- New rumor circles are drawn on in front of the player with a pencil sound; newly revealed land fills in; a trail travel route glows along its length.
- A line at the foot of the map says what happened: "Two new rumors."
- One key closes the map and play resumes.
- The setting "Show unlocks on the map" turns this off; the card alone is then shown.

### Other notices that stay

The "?" marks over the note board, supply shelf, suggestion box, pads and site markers stay, as today. The messages when a site is found and when a trail joins or breaks become toasts. The moment a site is opened becomes its job's finishing card.

### Queueing

- Cards and the map never interrupt a dialog, a menu, sleep or a collapse. They wait until play resumes.
- If several jobs finish at once, their cards show one after another, then one map showing all their changes.
- At the season's turn, the season card shows first, then anything else waiting.
- "While you were away..." is one card listing every job finished, for older saves.

## The Jobs page

The Jobs page becomes the ranger's clipboard, laid out as in the designer's reference image `docs/art/reference/jobs_clipboard.png`. That image is the target for layout and feel; its wording is placeholder.

### Frame and layout

- A wooden clipboard with a metal clip at the top, holding cream paper, over the dimmed game screen.
- The paper has a margin of at least 4% of the screen on every side. Nothing ever runs off it: long text wraps, long lists scroll.
- Text draws at full screen resolution, as all menu text now does. Frame, icons and decoration are pixel art.
- Three tabs along the top of the paper: **Current**, **Noticed**, **Done**.
- The paper is split into a **list** on the left, about one third of its width, and a **detail** pane on the right, about two thirds, with a faint ruled line between.

### The tabs

| Tab | Holds |
| --- | --- |
| Current | Every job that has been given, or has at least one step done, or is pinned |
| Noticed | Jobs the ranger has noticed but not yet done a step of |
| Done | Finished jobs, newest first, each with the date finished and the rewards it gave |

A noticed job moves to Current by itself the moment one of its steps is done. Tabs only sort; nothing is ever "taken on".

Each tab shows a small count. A tab holding anything new since the page was last opened shows a dot.

### The list

- Jobs are grouped under a heading for each type, in the order Exploring, Park Upkeep, Trail Work, Visitor Requests, Townsfolk Favors. Each heading is a ribbon in the type's color with its icon. A type with no jobs is not shown.
- Each job is a card with:
  - an icon for the kind of job: building, map, broom, branch, trash can, bench, shovel, sign, badger, lost hiker, and so on;
  - its name;
  - a progress bar of steps done out of steps, with the count, such as 2/4;
  - a red pin if it is pinned;
  - a dot if it is new since the page was last opened;
  - a leaf if it is seasonal, which is how the player knows it will retire at the season's end.
- Within a type: pinned first, then jobs with progress, most progress first, then the rest, newest first.
- The selected job's card is outlined. Opening the page selects the pinned job, or else the first in the list.
- The list scrolls by itself, with a small scroll bar, when it overflows. Type headings stay visible at the top as the list scrolls past them.

### The detail pane

Top to bottom, each section with a small ribbon heading, as in the reference image:

1. **Name**, large and bold, with a small picture for the job's type at the right. The reference image's bespoke picture for each job is not used: one picture per type keeps the art manageable.
2. **From:** the giver, with an envelope, note or pencil icon for given, found or noticed.
3. **The note**, in a handwritten-style font, two to four lines.
4. **You'll need:** up to six item tiles, each with its icon, name, "have of need" count (green once enough), and below in small type where to get it. Handy things are shown in grey. If nothing is needed, the section reads "Nothing to bring."
5. **Steps:** a checklist. Done steps have a green tick. The next step has a red arrow and a pale yellow band. Steps still to do have an empty box. A step with a count shows it, "Dig the gap: 8 of 30". A step that comes undone shows an orange mark and the words "broken again". A step that links to another job shows that job's name as a link.
6. **Rewards:** up to four reward tiles with icon and label. Something more shows as a purple question mark.
7. **Buttons** along the bottom: **Pin to screen** or **Unpin**, and **Show on map** when the job has a map spot.

On the Done tab, the Steps section is replaced by the date finished, and the Rewards section shows what was actually given, with Something more revealed.

### Controls

| Action | Keys | Mouse |
| --- | --- | --- |
| Open or close the page | J |  |
| Change tab | Q and E | Click a tab |
| Move through the list | W and S | Click a card; scroll the wheel over the list |
| Scroll the detail pane |  | Scroll the wheel over the pane |
| Pin or unpin | P | Click the button |
| Show on map | M | Click the button |
| Follow a link to another job | X on the step | Click the link |
| Close | Escape | Click outside the paper |

All through the input map, so a controller can be added later.

### Empty states

- **Current, empty:** "Nothing on the clipboard. The forest's still there."
- **Noticed, empty:** "Keep your eyes open out there."
- **Done, empty:** "Nothing finished yet. Plenty of time."

## The pinned job and the map

While playing, the job the player is working on stays in view, and the map shows where its next step is. This fixes tracker #13.

### The pinned note

- A small paper note pinned in the top left of the screen, clear of the clock and bars at the top right.
- It shows the job's type icon and name on one line, and its next step underneath, with any count: "Mend the Gap by the Pond" / "Dig the gap: 8 of 30".
- When a step is done, the line ticks, pauses a moment, and the next step slides in.
- When the job is finished, the note shows "Done!" briefly, then changes to the next job, by the rule below.
- Clicking the note opens the Jobs page at that job.

### Which job is pinned

1. A job the player has pinned stays pinned until they unpin it or it is finished.
2. Otherwise, the job the player last made progress on is shown, as "Working on" works today.
3. Otherwise, with nothing worked on, the note shows how many jobs are waiting: "4 jobs on the clipboard (J)".
4. With no jobs at all, it shows "Nothing on the clipboard" for a moment each morning and then hides itself.

Only one job is pinned at a time.

### The setting

**Show pinned job** is on by default. Turning it off hides the note entirely. Toasts, cards and the Jobs page are unaffected.

### On the map

- **Show on map** opens the map centered on the job's next step.
- The next step of the pinned job is marked on the map by a small flag in the job type's color. Other jobs' next steps show as smaller dots in their colors, so the map shows at a glance where there is work to do.
- Steps with two ends, such as a gap to dig, keep the red flags at both ends with dashes between, as today.
- A job whose next step is to find a place shows its rumor circle, never an exact spot. The map never gives away a place the ranger has not found.
- Hovering over a flag or dot shows the job's name and next step.

## Data, code and saves

Jobs are content data read by one jobs module. A new job, template, reward or noticed thing is new rows, never new code. This is what lets later areas and characters plug in.

### Content tables

| Table | Holds |
| --- | --- |
| `job_types` | Each type: name, giver, color, icon, order on the page, whether live |
| `givers` | Each giver: name as shown, icon, voice notes for writers |
| `jobs` | Each hand-written job: id, type, giver, name, notes, appears-when condition, steps, rewards, something-more id, size, season rule, map spot |
| `job_templates` | Each template: id, type, giver, condition, blanks and how each is filled, name pattern, three or more note wordings, steps, rewards, size, target count |
| `job_steps` | Each step kind: its parameters, how its done-when is checked, whether it stays done |
| `rewards` | Each reward kind: how it is given, its icon, its label pattern, what to give instead if it duplicates |
| `something_more` | Each hidden bonus: what it gives and its reveal text. Loaded from `docs/spoilers/`. |
| `noticeables` | Each noticed-job spot: position, trigger radius, conditions, the ranger's jotted note, the job it adds. Loaded from `docs/spoilers/`. |
| `seasonal_jobs` | Which hand-written jobs belong to which season |

**Conditions** are written in one small shared format used by appears-when, templates and noticeables, built from simple checks joined by "and" and "or": job finished, site found, mapped or opened, season, time of day, weather, item held, world state such as a bathroom's cleanliness or a can's fill. The lab defines the format once and uses it everywhere.

### The jobs module

- Holds every known job and its state.
- Checks conditions each morning, on each world change that could matter, and when the ranger enters a noticeable's area.
- Works out step progress from the world, records steps that stay done, emits the five signals, and gives rewards.
- Draws template jobs and retires jobs at the season's turn.
- Is the only thing that decides what a job is. The Jobs page, pinned note, map, notifications and rewards all read from it or listen to it.

The present jobs code is replaced, not extended. The "Next:" list from 0.4.2 and the "Working on" heading are retired; their jobs are done by the pinned note and the list's ordering.

### Saves

A save holds, for each known job: its id, or its template id and filled blanks; where it came from; the date it was added; which steps have been recorded as done; whether it is finished, and when; whether its rewards have been given; whether it is pinned; and whether it is new since the page was last opened. It also holds which noticeables have been seen, which something-mores given, and which seasonal jobs have retired this year. Everything else is worked out from the world on load.

Older saves are converted on load, as "Saves from before this change" sets out, with the "While you were away..." card.

## Changes to the world, and the tracker fixes

The jobs need a few small changes to rings one and two. Nothing else in the world changes.

### Changes to the world

| Where | Change | Why |
| --- | --- | --- |
| Inside the station | Three untidy spots: papers on the desk, a dusty shelf, boots by the door. Each clears when tidied. | Get the Station Shipshape |
| Inside the station | A trash can, standing by the door | Get the Station Shipshape |
| The trail just past the station | A fallen branch across it: a new, small obstacle cleared by one axe chop, giving one firewood | Get the Station Shipshape, and Clear the Winter's Mess |
| By the gate | A marker for the trash can's spot | Get the Station Shipshape |
| Cabin to pond | The old trail stays, with its three trunks. Its two gaps are each made no more than 30 tiles. Every other tile of it counts as trail. | Reopen the Pond Trail |
| Across the burn | The survey stakes stay. Beside them, the last ranger's old trail is added, plainly visible and counting as trail, with two gaps of no more than 30 tiles, one either side of its middle, some brush in the west gap, and brush and snags in the east. | The two stake trail jobs, and the designer's own wish for far less open digging |
| The old road | Counts as trail along its length except two overgrown stretches of no more than 30 tiles. The fallen trunk stays. | Clear the Old Road |
| Ring one and ring two | The noticeable spots in the spoiler addendum | Noticed jobs |

Trail the player has already dug stays exactly as it is. Where the designer's own save already joins places, those jobs finish on load and pay out.

### Tracker #13: unclear where to go next

Fixed by the pinned note always showing a next step, the map flag for it, every finished job's card listing what it unlocked, and the first choice offering five jobs of three types.

### Tracker #15: no trail travel to the tower

- Trail travel to a site is given as a reward when the site is opened, provided trail joins it to the station. The "arrived twice" rule is removed.
- Trail travel uses the visitors' trail network to decide whether places are joined, so the ranger and visitors always agree.
- A test walks a joined route that crosses a ford of shallows and boardwalk, and confirms trail travel is offered along it. The designer's case, a tower joined by trail but not offered, must be reproduced from their save and confirmed fixed.
- A site already opened and joined in an older save is given trail travel on load.

## Tuning values

Every number that shapes how jobs feel is in the tuning file, so it can be changed after play.

| Group | Value | Start |
| --- | --- | --- |
| Size | Largest gap of new trail in one step | 30 tiles |
| Size | Most work a job should ask | About one game day |
| Rewards | Money: small / medium / large | $10–30 / $30–80 / $80–200 |
| Rewards | Experience: small / medium / large | 20–40 / 60–120 / 150–300 |
| Rewards | Template money variation | ±20% |
| Rewards | Share of jobs with Something more | About 1 in 4 |
| Rewards | Payment when a template job is done by someone else | 50% |
| Templates | Target on the clipboard: Park Upkeep / Trail Work | 3 / 2 |
| Templates | Most cards a week that offer "Take this on" | 3 |
| Templates | Most new template jobs drawn per type per morning | 1 |
| Noticed | Trigger radius, default | 4 tiles |
| Toasts | Time on screen | 4 seconds |
| Toasts | Most on screen at once | 3 |
| Toasts | Count toasts for counted steps | At each quarter |
| Cards | Time before a card can be closed | 1 second |
| Map | Show unlocks on the map | On |
| Pinned note | Show pinned job | On |
| Sites | Distance at which a site is found | 14 tiles, as now |
| Sites | Distance within which a name sign counts | 30 tiles, as now |

## Build order, art and tests

The jobs rebuild is done in eight steps, each ending with passing tests and a spoiler-free status email. It is done when every test passes and the designer has played the checklist.

### Build order

1. **The engine.** The jobs module, condition format, typed steps, the five signals, the content tables, and save conversion. The old jobs code is retired. At the end of this step, every existing job works through the new module and the old Jobs page still shows them, so nothing is broken in between.
2. **Rewards.** Every reward kind, duplicates swapped for money, given once only, and trail travel as a reward (tracker #15).
3. **The Jobs page.** Frame, tabs, list, detail pane, scrolling, controls, empty states.
4. **Notifications.** Toasts, finishing cards, the map flourish, queueing, the season card, and "While you were away...".
5. **The pinned note and map markers.** The note, its pinning rules, the setting, map flags and dots (tracker #13).
6. **The world changes and the opening.** The station's untidy spots, branch, trash can and marker; the reshaped pond trail, stake trail and old road; Get the Station Shipshape and the first choice.
7. **All the jobs.** Every hand-written job and note, every template, the seasonal jobs, the turn of the season, noticeables, and Something more.
8. **Full pass.** All tests, a played season of game time by the lab from a new game, a load of the designer's current save, and a final report.

### Debug tools

The panel gains: list every job and its state; finish or reset any job or step; draw any template now; trigger any noticeable; give any reward; skip to the next season's turn; and show every job marker on the map. Spoiler details stay behind "show spoilers".

### Art

The lab writes an art request after step 1, building with stand-ins meanwhile. It needs:

- the clipboard frame, clip, paper, tabs and ribbon headings, matched to the reference image;
- five type icons and ribbons, one per type;
- one picture per type for the detail pane;
- about 16 job-kind icons;
- about 10 reward icons, including the purple question mark;
- checkboxes, tick, arrow, pin, dot, leaf, progress bar and scroll bar;
- the toast strip, the finishing card and its "DONE" stamp, and the season card;
- the pinned note;
- map flags and dots in the five colors;
- the station's untidy spots, the branch, the trash can marker, and pictures for any noticeables that need one, mixed in among ordinary pieces so nothing is given away.

### Automated tests

| Area | Must be true |
| --- | --- |
| Engine | Every hand-written job and template loads; every condition parses; every step kind checks correctly against a prepared world |
| Steps that stay done | Once recorded, they never come undone; steps that do not stay done are checked on every relevant world change |
| Order rules | Pack is shown first and is done only while another step remains; open is possible only when every other step is done |
| Finishing | A job finishes exactly when its last step is done, gives every reward once, and stays finished if a step later breaks |
| Signals | Each of the five fires exactly when specified and never twice for the same change |
| Rewards | Each kind gives what it says; a duplicate is swapped for money; nothing is given twice across a save and reload |
| Trail travel | Opening a joined site gives trail travel to it; the designer's tower case is fixed; ranger and visitors agree on every join |
| Size | No gap in any trail job exceeds the tuned width; old trail exists at both ends of every gap |
| Templates | Each is drawn only when its condition holds; targets are kept but never exceeded; no duplicate at the same place; a job made pointless finishes and pays half |
| Season's turn | Exploring jobs and started jobs stay; untouched template and ended seasonal jobs retire; new seasonal jobs appear; the season card shows |
| Noticeables | Each adds its job once, under its conditions, and never before |
| Opening | A new game offers only Get the Station Shipshape; finishing it gives the three rumors, the catalog, and the follow-on jobs listed |
| Older saves | The designer's save loads; jobs already complete are finished and paid; one summary card lists them |
| Notifications | Every signal produces its toast, card or map; nothing interrupts a dialog, menu, sleep or collapse; queued cards show in order |
| Pinned note | Follows the pinning rules; hides when the setting is off |
| Jobs page | Nothing draws outside the paper at any list length; every section appears as specified; all controls work |
| Secrecy | No status email, commit message or debug screen names a noticeable or Something more unless "show spoilers" is ticked |

### Play checklist

- [ ] Start a new game and finish Get the Station Shipshape. Judge whether it taught you how jobs work without feeling like a tutorial.
- [ ] Choose where to go first, and feel that it was a real choice.
- [ ] Open a site, and enjoy the finishing card and the map afterward.
- [ ] Notice at least two jobs nobody told you about.
- [ ] Mend a trail gap, and judge whether one screen of digging feels right.
- [ ] Reach the tower by the stake trail without a week of digging.
- [ ] Choose between two jobs because of their rewards.
- [ ] Get a Something more, and judge whether it was worth the wonder.
- [ ] Use the pinned note and the map to find your next step without opening the Jobs page.
- [ ] Read the Jobs page with eight or more jobs on it, and judge whether it stays clear.
- [ ] Ignore the jobs for a few days and feel that it was fine.
- [ ] See a season turn, and judge whether the clipboard feels fresh.
- [ ] Load your old save, and judge whether "While you were away..." paid you fairly.
- [ ] Write down what felt wrong, and any job you wished existed.
