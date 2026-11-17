# Strange Ranger: Phase 3 Status

17 November 2026 · from the lab · version 0.4.0

## Summary

Phase 3, as written in your Phase 3 Build Spec, is built: all ten steps. All automated tests pass: **217 passed, 0 failed.** The keyboard check passes 25 of 25, and the windowed check holds 60 frames a second with 80 visitors in the park and 33 drawn on screen.

Opening a place now fills it with people. Visitors arrive at the gate, walk your trails to the sites that are ready, spend money at the kiosk, use the bathrooms, drop litter, and go home. Leave the park and it runs without you. Leave it messy and troll badgers move in. The Chief writes every week.

As with the hidden things, this report gives only counts for the places in the spoiler addendum, so where they are stays a surprise.

## What was built

1. **Money.**
   - A wallet beside the clock. A new game, or an older save, starts with $500.
   - $250 from the Chief every seventh day. Nothing else changes it.
   - The supply catalog sits on a desk in the station. Orders by midnight arrive at 6:00: supplies on the supply shelf, kits at their pad. Prices are your table's.
   - A rescue costs 10% of the wallet, up to $250, said in one line of the rescue note. Nothing from an empty wallet.
   - The ledger is a page of the new book (J): today, this week and last week, by source.
2. **The trail network.** Every trail, stone step and boardwalk tile joined to the gate, with short straight fords. It is rebuilt the moment anything changes it. Walking times on it match the walked routes within 1.2%.
3. **Visitors.**
   - Six kinds, with your party sizes and stays: day hikers, families, campers, anglers, tour groups with a guide, and scout troops with a leader.
   - They walk only on trail, at 85% of the ranger's speed, and stop at benches and finds.
   - Each party picks somewhere it can reach and get back from in time: a day party back by 18:00 or dusk; campers measured from their campground; renters from the cabin.
   - Far away a party is a record moving along the trails; near the ranger it is drawn as people. Both are the same record.
   - At most 80 in the park; the rest come the next day.
   - Storms send day parties home and campers to their tents.
4. **Arrivals.** Each morning, from the sites visitors can reach, their facilities and mess, the season, the day of the week, the weather and last week's mood, with your multipliers. Over a simulated year, arrivals come within 5% of the numbers expected.
5. **Facilities.**
   - 13 pads in all: 6 at the gate, the old cabin and the outlook (2 of them, the kiosk and the suggestion box, already built), and 7 in the spoiler addendum.
   - A pad shows as stakes with a flag once its site is ready. Order the kit, find it at the pad the next morning as crates, and build it with the hammer: 20 minutes an action, your number of actions. The hammer takes a facility down again for half back, after asking.
   - Benches, trash cans, picnic tables and fire rings: bought from the catalog or made (bench and table at a workbench, fire ring anywhere), put down near a trail on mapped ground, and picked up whole with the hammer.
   - The old cabin has a sign by its door: For rent or Ranger only.
6. **Income.** Entrance fees, camping permits, cabin rent, tours, fishing permits, gear rental, park maps (once three sites are mapped), and the gift shelf. The kiosk's shelf takes only gift goods and berry preserve; the five gift goods' recipes are learned the first time the ranger looks at the empty shelf.
7. **Upkeep.** Bathrooms lose 4 for each visit, grubby below 40, filthy below 15, and avoided when filthy. Trash cans hold 20. With no room within 15 tiles, half the trash ends up as litter. Cleaning, emptying and picking up take your times and energy. One piece of litter in fifty is a lost belonging, logged in the notebook.
8. **Troll badgers.** Two nights of mess, then an even chance each night. Up to one bit of mischief a day: tipping a can, napping in a bathroom, raiding a picnic, digging a hole in the trail (the shovel fills it). Shooing takes 10 minutes and works for a day. Clearing the mess sends a badger off for good. At most 3 in the park, one a site. They never touch a sign.
9. **Staff, the box and the Chief.**
   - A staff board in the station: three people looking for work, hired as custodians or trail crew, paid every seventh day. With too little money, staff take the week off: no debt, nobody quits.
   - The suggestion box by the kiosk fills each night with up to five cards, each written from something that really happened. Cards that ask for something can be pinned to the job list.
   - The Chief's weekly report, his praise for five milestones, at most one grumble a week, and a hint at the end of about one letter in four. All on the station's note board, and kept in the book.
   - Lost parties: in fog, at night or in a storm, a party at a junction with no sign to where it is going may take a wrong turn. The radio and the note board say so, the job list adds it and the map shows a circle. Finding them earns a thank-you card, a tip of $20 to $50 and Surveying experience. Nobody found turns up at the gate at 6:00.
10. **The ranger's book (J):** jobs and sites, the park today, the ledger, cards, letters and a notebook.
11. **Debug panel:** money in and out, skip to the seventh day, spawn any party, lose a party, build a pad, set a bathroom's cleanliness or a can's contents, send a badger, show visitors on the map, and run the park unattended for any number of days. Spoiler pads and places are listed only with "Show spoilers" ticked.

## Reach checks (spoiler addendum)

The lab opened trail along the planned routes and checked the reach rules. **4 of the 5 checks hold.** The fifth is looser than planned: the lab will say which only if you ask.

## Tests

- **Automated:** 217 passed, 0 failed, including 44 new phase 3 tests that cover the spec's test table: money, the trail network, reach, arrivals, near and far, facilities, income, rental, upkeep, badgers, lost visitors, staff, cards and letters, a month left unattended, saves, and the secrecy of the debug panel.
- **Keyboard check:** 25 of 25, with new checks for the book, the wallet and ordering from the catalog.
- **Performance:** 80 visitors, 33 drawn: 60 frames a second, 99th percentile 16.8 ms.
- **The unattended month** (a test, and the debug panel's button): no failure of any kind, and the wallet never below zero.

## Different from the spec

1. **Pads outside ring one** are kept in a spoiler table in the game's data, like the other spoiler tables, not loaded from `docs/spoilers/`, because that folder is not in the repository or the build.
2. **The old cabin and the outlook are now sites**, with the usual six steps, because the spec gives them pads and visitors need somewhere to go. Phase 2 said the old cabin stays a shelter; this follows the newer spec.
3. **Storm-fallen trunks:** the game has none yet, so the trail crew has nothing to clear there.
4. **Art Requests 08 and 09:** the spec calls them 04 and 05, which were already used.

## Questions

1. **Starting supplies.** The free shelf is gone, but a new game still starts with the old shelf's stock once, so the first cabin repair needs no shopping. *Suggested answer:* keep it, as a welcome box from the Chief.
2. **The radio valve** is in the catalog at $60, as listed, but nothing uses it yet. *Suggested answer:* leave it for a later radio repair, or hide it until then.
3. **Park maps:** the spec does not say how many visitors buy one. *Suggested answer:* one visitor in ten, once three sites are mapped (tunable).
4. **Bookings** for the cabin are told in the wake-up note and on the station's note board. *Suggested answer:* keep both.
5. **Next.** *Suggested answer:* you play the checklist below, and the lab tunes phase 3 from your notes.

## How to run

Download the build, or run `C:\Godot\Godot_v4.7.2-stable_win64.exe --path .` from the repository. F1 opens the debug panel in test builds. To try the park quickly: F1, then "Ready cabin+outlook" (or, in play, repair the cabin and put up signs naming the cabin and the outlook), then wait for 8:00, or press "To 7th day" or "Run unattended".

## Pictures

In `docs/status/phase_3_shots/`: visitors at the gate, litter and a troll badger, the catalog, the staff board, the ledger and park pages of the book, and a lost party's circle on the map. Everything new is a stand-in until Art Requests 08 and 09 come back.

## Play checklist: phases 2 and 3

**Phase 2 (still to play):**

- [ ] Read the note board after repairing the cabin, and set out for a place you have only heard of.
- [ ] Cross new forest with no trail and feel how big it is. Get lost once.
- [ ] Find the fire tower, repair it, sleep there and survey from the top.
- [ ] Clear (saw, axe) and dig (shovel) your way so the tower joins the trail, and feel the new trail get faster to walk.
- [ ] Put up a sign naming the tower near it, then open the tower.
- [ ] Come home from an ordinary walk with things you did not set out to gather.
- [ ] Have an idea, and make what it suggested. Cook at a campfire and at a stove.
- [ ] Set up a workbench kit in the cabin or tower and make planks there.
- [ ] Lay boardwalk across wet ground. Make the pack frame.
- [ ] Find one magical ingredient without being told where, refit a tool with it, and work out what changed.
- [ ] Reach level 2 or 3 in a skill, and choose a specialty at level 5 (F1 can set a level).
- [ ] Judge whether foraging feels like a pleasure or a chore, and whether the bigger forage art is easy to see.
- [ ] Stumble on at least one thing you didn't expect.

**Phase 3:**

- [ ] Make a site ready (repair and sign the old cabin, or sign the outlook), and watch the first visitors walk to it on your trail.
- [ ] Order from the catalog on the station desk, and find it on the supply shelf the next morning.
- [ ] Build a bathroom and a picnic area at the gate, and place benches and trash cans where you think they belong.
- [ ] Build a campground, and see visitors reach places a day hiker could not.
- [ ] Rent out the cabin (the sign by its door), and plan a trip around a booking.
- [ ] Stock the kiosk's gift shelf with things you made, and see them sell (J, Ledger).
- [ ] Read a week of suggestion cards, and pin one you like to the job list.
- [ ] Find a lost party in fog (F1 can lose one, and force fog).
- [ ] Leave the park for a week of backcountry, come back to the mess, and judge whether it is funny or annoying.
- [ ] Meet a troll badger, and shoo it.
- [ ] Hire a custodian, and judge whether the chores fading feels like a reward.
- [ ] Read the Chief's weekly report on the station's note board, and judge whether he sounds like himself.
- [ ] Judge whether money feels too tight, too loose or about right.
- [ ] Write down what felt wrong, and what you wanted to build and could not.
