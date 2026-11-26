# Strange Ranger: Phase 5b Build Spec, Gord and the night

From the lab, 26 November 2026, for the designer to change as he likes. The Phase 5 Spec stays the source. This fills in its second half now that 5a is built (0.8.0 to 0.8.2) and Mark's Art Request 25 Part B sheets are in.

**The scene that proves it** (from the Phase 5 Spec): on a full-moon night the ranger walks out with the dog to the meadow where a moose has been standing about all month looking self-conscious. Tonight there's a tall, awkward man there instead. He would very much like a coffee in town, but he doesn't know how you order one. The ranger helps him over the next few full moons, then decides whether anyone else ever hears about him.

**Done when:** a player can meet, settle and decide the fate of one magical creature.

**Builds:** 0.8.4 onwards (0.8.3 is this spec), one patch per step, with tests and screenshots as before. When Phase 5 is signed off, the next build is 0.9.0.

## What 5a left ready

- The jackalope, the magic deer and the troll badgers are in the world and the guide. Nothing yet can be done about them.
- Lore already counts experience for feeding a creature, and the Whisperer specialty already holds its two effects (friendship faster, gifts). They only start working in 5b.
- The pet, the field guide sheet, the Town sheet's calendar, Esme's readings and the jobs clipboard all exist. 5b adds to each rather than building anything new beside them.

## 1. Creature friendship

The four magical creatures of Phase 5 each have a friendship of **five paw hearts**, drawn with Mark's `ui_paw_heart` pictures:

- the jackalopes (as one family)
- the magic deer
- the troll badgers (as one clan)
- Gord

**Where it shows:**

- on the creature's field guide page, under its picture
- on its job card on the clipboard

**How it grows** (100 points a heart; the numbers are tuning):

| What you do | Points | How often |
| --- | --- | --- |
| Give it food it loves | 40 | Once a day per creature |
| Give it food it likes | 20 | Once a day |
| Give it anything else it will eat | 5 | Once a day |
| Spend an hour near it at its hour without startling it | 10 | Once a day |
| A step of its job | 25 | Each step |

**Rules:**

- **Giving works like gifts in town.** Walk slowly up to it with a food in hand and press X. What it thinks shows as a line: "It loved that", "It ate it politely", "It sniffed and wandered off".
- **Tastes are learned.** Once you've tried a food, the guide page shows it with a chip, a tick or a cross.
- **Friendship never goes down.** Startling a creature (walking up at full speed inside its shy distance) only loses that day's hour near it, and says so: "Too close. It bolted."
- **Hearts do things.**
  - At 1 heart it no longer moves off while you walk slowly.
  - At 2 hearts, the last step of its job can be done.
  - At 5 hearts, it has a small scene of its own (the lab writes these, and keeps them for the player).
- **Whisperer** makes all of this half again as fast.

## 2. Creature jobs

A sixth job type, **creature**:

- Its colour is a deep violet.
- Its picture is Mark's `job_kind_creature`, a paw print in a ring.
- The giver is the creature itself, shown by its guide picture.

Creature jobs are written as steps in data, exactly like the others: the same cards, the same clipboard, the same map circles. 5b adds these step kinds:

| Step | Counts when | Map mark |
| --- | --- | --- |
| Feed | The creature is given a food of the named sort | The creature's place |
| Be near | You spend an hour near it at its hour, on the named number of different days | The creature's place |
| Hearts | Its friendship reaches the named hearts | None |
| Lay a trail | A food is put down at each of the marked spots, in order | Each spot, one at a time |
| Wait at | You are at a place between two hours (dusk at the meadow, say) | The place |
| Choose | You pick one of a few cards | None |
| Keep | Something stays true for a number of days (an offering left each week, say) | The place |
| Full moon | You are at a place on a full-moon night | The place, on the calendar too |

**Every step says when it counts,** as the Phase 4 play tests asked: "the trail's first stop is laid", "the badgers took the offering".

## 3. The three cousins' answers

Each cousin's job only appears when its trouble shows. None is locked behind another, and they can run side by side. **The lab keeps the exact foods, places and solutions for the player.** What follows is the shape of each.

### The troll badgers: a deal

- **When:** a facility has had its third bit of badger mischief. They're already in the park, so this is usually the first creature job.
- **Steps:**
  1. Watch one at it, through the binoculars, at that facility.
  2. Be near them at dusk twice.
  3. Agree terms: **a choice of three offerings**, each a different weekly cost and a different gift back.
  4. Leave the offering at their stone, the right way, two weeks running.
- **Settled:**
  - There's no more mischief at that facility.
  - As more facilities open, the deal can be **renegotiated** to cover another one. This is a short new job with the same shape.
- **They stay.**

### The jackalopes: coaxed to move

- **When:** in spring, once the campground is open and a jackalope has been sketched.
  - Burrows appear at the campground, three holes in the ground.
  - Campers complain on suggestion cards.
  - A camper twists an ankle, gently and comically, and goes home early.
  - No chasing, ever. Walking at them only makes them dig in.
- **Steps:**
  1. Find out what they love.
  2. Lay a trail of it to a meadow of their own, over a few evenings.
  3. Wait for them there at dusk.
  4. Fill the old burrows with the shovel.
- **Settled:** they live in their new meadow from then on. They move, but stay in the park.

### The magic deer: what it wants

- **When:** from the first autumn, once the magic deer has been sketched.
  - At night it comes to the station's yard, looks at the ranger and walks away.
  - It does this every few nights until its job is done.
- **Steps:**
  1. Notice it in the yard.
  2. Learn what it's looking for. Esme's reading, a note in the station and the guide each give a piece of it.
  3. Find the thing.
  4. Bring it to the place.
  5. Be there at night.
- **Settled:** it comes back each autumn and winter and is away in spring and summer, like the suggested answer to the "stays or goes" question.

## 4. Secret, hint or public

The choice comes at the end of each creature's job, as its last card: **three stamps**, Mark's `stamp_secret`, `stamp_hint` and `stamp_public`. Pressing one stamps the card.

| Choice | What it does (tuning in brackets) |
| --- | --- |
| **Secret** | No visitor sees it, and visitors never go there for it. Friendship grows faster (×1.5). Now and then it leaves a small gift on the nearest cabin's step (about once a week) |
| **Hint** | A line on the brochure: "Strange things are seen in the east meadow". **Cryptid hunters**, a new kind of visitor, come looking. They hang about its place at its hour, go home happy with a blurry photo, and leave suggestion cards. A little income per hunter |
| **Public** | On the brochure and the map. More visitors of every kind come to that site, and each pays a little more. The creature is shyer (shy distance ×1.5) and its friendship grows more slowly (×0.5) |

**Where you see it:**

- The Log gets a **Creatures** page: each creature with its picture, its hearts and its stamp. A public one shows Mark's `brochure_creature` panel.
- The Chief's letters react: pleased by the money, curious about what's being kept back.

**Changing your mind:**

- At the station's note board, one step at a time.
- At most one step per creature per season.
- Public can go down to hint and then to secret, a season apart.

**The troll badgers are the exception.** They are part of the park already, so their choice only changes what visitors hear about them.

## 5. The moon and the calendar

**The moon:**

- A full moon on the **7th and 21st** of every season. This is a change from the Phase 5 Spec; see question 1.
- The HUD clock shows the moon's phase at night, using Mark's eight `hud_moon` frames.
- On a full-moon night, a big pale moon sits in the sky at the top of the screen. The world is a little brighter, so the lantern reaches further.
- Strange cousins are out twice as often.

**Calendar events** are rows of data:

- a day
- a place
- what happens
- how the ranger hears of it

They show on the Town sheet's calendar with Mark's `ui_cal_event` star **once heard of**. Until then the day is plain.

| When | What | Heard of from |
| --- | --- | --- |
| Every full moon | Gord in his meadow; cousins out more | The calendar always shows full moons |
| First full moon of autumn | All the magic deer come to the outlook, for one night | Esme |
| First snowfall | The jackalopes play in the snow (a good photo) | The guide's jackalope page, once settled. Shown on the calendar the day it snows |
| Midsummer night (summer 14) | Fireflies over every pond, not just some | A townsperson's chat in early summer |

The lab adds a few of its own and keeps them for the player.

**A missed event comes again next year.** A full moon comes twice a season.

## 6. Gord

**His meadow:**

- At the edge of the old burn, beside the road up to the static tower. It's land the park already has, on a walk the ranger already makes (the suggested answer to question 1 of the Phase 5 Spec).
- It has Mark's crooked "MEADOW" sign.

**By day,** every day of the month, a moose stands about there:

- He is Mark's moose with a wristwatch.
- Through the binoculars, the guide sketches him as "a moose (?)". The question mark stays until you've met him.
- He is never shy of the ranger. He is shy of everyone else.

**On full-moon nights,** from dusk until 02:00:

- The moose is gone, and Gord the man is in the meadow.
- He talks like a townsperson, with Mark's four portraits.
- He has creature friendship, with paw hearts, not townsfolk hearts.

**His job, "A coffee, like a normal person"**, over three full moons:

| Full moon | What happens |
| --- | --- |
| **First** | You meet him. He explains, very politely, what he'd like. Before the next full moon you need two things from town: a coat big enough for him (the outfitters stock one once you've met him) and the words for ordering a coffee (ask Wren; she tells you, and is delighted by the question) |
| **Second** | Bring him the coat. He tries it on (now Mark's `npc_gord_dressed`). Then he practises ordering on you. You answer from a few choices, and the kind ones help |
| *Between* | Ask Wren to keep the Percolator open late on the next full moon. She closes at 18:00, so this needs Wren at 2 hearts |
| **Third** | Walk him into Humdrum. He follows like the pet does. Be there while he orders. It goes fine. Nobody blinks (standing rule 9). He's thrilled. Badge: **"Coffee, black"** |

**Afterwards:**

- Gord stays.
- On every full moon he comes into town at 20:00 and sits by the Percolator's window with a mug until 23:00. Wren keeps it open late on full moons from then on.
- Each townsperson has a line for him ("Evening, Gord").
- Then comes his meadow's secret, hint or public choice. His friendship carries on to five hearts, and his fifth heart has its own scene.

**Missed a full moon?** The step waits for the next one, two weeks later.

## 7. Aurora nights

**When:**

- Two or three a year, picked at the start of each year from the save's seed.
- Never within 20 days of each other.
- At least one in winter.
- Never on a full moon.

**The only hint:**

- On the day before, Esme's **Sky** card is the aurora card, "Look up tomorrow night", whatever the weather.
- The radio never says a thing. The weather that night is always clear.

**What happens, from dusk to dawn:**

- Mark's `sky_aurora` ribbons ripple across the top of the screen, and a green and violet light washes over the world.
- Every strange cousin is out.
- Every site's night path is lit, not just a few.
- A photo of anything under the aurora goes in the guide as a good one. "Under the aurora" is a new entry on the guide's places page.
- One aurora-only thing happens, kept for the player.

**Missed one?** Another comes.

## 8. The second pet

- **When:** from the first winter, on the first snowy morning. The other animal (the cat if you have the dog, or the dog if you have the cat) is waiting on the step of the nearest repaired cabin.
- **Taking it home:**
  - Press X to take it home and name it. Or leave it; it waits there until spring and then tries again next winter.
  - It gets its own bed and bowl beside the first, east of the station.
- **Both pets:**
  - Pet each once a day, and fill both bowls.
  - X at a pet tells that one to come along. The other stays home.
  - Doors still come first, as in 0.8.2.

## 9. Badges

All from Mark's B5 sheet:

- Field guide: 10 entries, half the animals, all the animals, all the strange cousins.
- Night photography: at night, in fog, and under the aurora.
- Friend of the park: a creature settled, and a creature at five paw hearts.
- Gord's "Coffee, black".

## 10. New data and tuning

**Tables:**

| Table | Rows |
| --- | --- |
| `creatures` | The four creatures: their guide entry, loves, likes, their job, stays or goes, their gift |
| `creature_jobs` (in `job_templates` and `job_steps`) | The steps above, and the eight new step kinds |
| `calendar_events` | Day, place, what happens, how it's heard of |
| `visitor_types` | A new row: cryptid hunters |
| `spoiler_creatures`, `spoiler_calendar` | The lab's hidden things, kept out of designer-facing files |

**Tuning values:**

- full-moon days (7 and 21)
- points per paw heart (100)
- gift points (40, 20 and 5)
- an hour near (10)
- a job step (25)
- secret, hint and public factors
- cryptid hunter weight
- aurora count (2 to 3) and gap (20 days)
- Gord's town hours (20:00 to 23:00)
- the second pet's season (winter)

## 11. Build order

| Build | Step |
| --- | --- |
| 0.8.4 | Creature friendship: paw hearts, giving, an hour near, tastes in the guide |
| 0.8.5 | The creature job type and its eight step kinds |
| 0.8.6 | The troll badgers' deal |
| 0.8.7 | The jackalopes coaxed |
| 0.8.8 | The magic deer's wish |
| 0.8.9 | Secret, hint or public: the stamps, cryptid hunters, the brochure, the Log's Creatures page, the Chief's letters |
| 0.8.10 | The moon, the HUD phase, the calendar's events and how they're heard of |
| 0.8.11 | Gord: the meadow, the moose, his three full moons, the coffee, his evenings in town |
| 0.8.12 | Aurora nights and Esme's card |
| 0.8.13 | The second pet, the badges, the last of Mark's Part B art, and the play test build |

**Debug tools (F1):**

- jump to the next full moon
- start an aurora tonight
- set a creature's hearts
- finish any step of a creature job
- swap the second pet in
- fill the calendar's heard-of events

## 12. Automated tests

- Paw hearts: giving loves, likes and others; once a day; an hour near; never going down; Whisperer's ×1.5.
- Each new step kind counts only when it should, and says so.
- Each cousin's job starts only when its trouble shows, and each can be settled.
- The choice: secret gives gifts and no visitors; hint brings cryptid hunters; public brings visitors and a shyer creature; one step a season back down.
- Full moons fall on the 7th and 21st. Events show only once heard of.
- Gord:
  - only a man on full-moon nights
  - each step waits for the next full moon
  - Wren stays open late only when asked, and then on every full moon
  - he's in town every full moon afterwards
- Aurora nights: two or three a year, 20 days apart, one in winter, never on the radio, Esme's card the day before.
- The second pet: winter only, both bowls, one along at a time.
- A 0.8.2 save loads with nothing lost.

## 13. Play checklist

For Mark's play test, as before:

- Make a deal with the badgers. Is it clear what they want and when it's kept?
- Coax the jackalopes. Does laying the trail feel like a nice evening, not a chore?
- Follow the magic deer's clues. Too hard? Too easy?
- Help Gord across his three full moons. Is the wait between them about right?
- Make a secret, hint or public choice, then live with it a week. Do you see a difference?
- Catch an aurora from Esme's hint.
- Is anything about creatures unclear, slow or wordy?

## Questions for the designer

The lab goes ahead on the suggested answer unless you say otherwise.

| # | Question | Suggested answer |
| --- | --- | --- |
| 1 | The Phase 5 Spec has one full moon a season, on the 14th. Gord's story needs three full moons, so it would take from spring to autumn. Is that too slow? | Two full moons a season, on the 7th and 21st, so Gord takes about six weeks |
| 2 | When can you first meet Gord? | Only once you've seen the moose in his meadow through the binoculars, so you've noticed the wristwatch first. Any full moon after that |
| 3 | Do the cousins' jobs come in a set order? | No. Each starts when its trouble shows: badgers after a facility's third mischief, jackalopes in spring once the campground is open, the magic deer from the first autumn |
| 4 | Should creature friendship ever go down? | Never. Startling one only loses that day's hour near it |
| 5 | Can public go back to secret? | Yes, one step a season: public to hint, then hint to secret |
| 6 | Where does Gord's coat come from? | The outfitters stock a big buffalo-check coat once you've met him (Mark's dressed-up Gord). The ranger's own spare coat works too |
| 7 | How do the townsfolk take Gord? | As an ordinary regular (standing rule 9). Nobody mentions moose. Esme winks |

**The Phase 5 Spec's seven questions were built on their suggested answers in 5a.** Two are now settled by Mark's art:

- Gord's tell is the **wristwatch** on his foreleg. It's in Mark's B1 sheet.
- His meadow is on land the park already has: the old burn, by the tower road.
