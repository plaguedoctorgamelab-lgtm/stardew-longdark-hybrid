# Strange Ranger: Phase 2b Feedback, Fixed

17 November 2026 · from the lab · version 0.4.2

## Summary

Every point in the Phase 2b feedback is addressed in 0.4.2. All automated tests pass: **231 passed, 0 failed** (14 of them new, one for each fix). The keyboard check passes 25 of 25.

The main change for "it's easy to get confused" is a **hint line** just over the item bar. It always says what X and C will do right where you stand, or why C won't work there (for example "C: face boggy ground or shallows to lay boardwalk"). It sits alongside "?" marks over things with something new, a **Next** list at the top of the book (J), and every recipe shown with where it's made or how it's learned.

## Your questions

**The things around the station: picnic table, flags, gift shelf, suggestion box. Do you need more graphics?** No; those are Mark's Art Request 09 pieces. The hut with the counter is the visitor kiosk, which holds the gift shelf. The little box on a post is the suggestion box. The flags on stakes are empty pads: places where a bathroom or a picnic area can be built once you order its kit from the catalog in the station. Walk up to any of them and the hint line now says what it is and what X does. Art Request 10 asks for three small new pieces for the new features (below), and nothing waits on them.

**How do the gift shelf and suggestion box work?**
- **Gift shelf (at the kiosk):** put gift goods and berry preserve on it. Visitors buy from it as they leave, and the gold goes in your wallet. The first time you look at it empty, you get the ideas for the gift recipes. Opening it now explains this in one line.
- **Suggestion box:** visitors leave cards about their day. Read them to see what they liked and what they want. A card that asks for something can be pinned to your jobs. A "?" floats over the box when new cards are in it. Opening it empty now says what it is for.

**Did the cabin do what's next?** The book's Jobs page now starts with **Next:**, one line for each site you've found, saying only the next thing to do in plain words, for example "Old Cabin: repair it: hammer (C) at the door, with what it needs".

**Trail travel?** A good idea. It fits the game: the walking is the point the first time, a chore the tenth. Built as you described it:
- Once you have arrived at a place twice and a trail joins it to where you stand, the map (M) lists it under **Trail travel**, with the time it takes.
- Click it: you are there, the time passes, and you are as tired as if you had walked it.
- It works only from the trail, outdoors, so exploring and foraging still mean walking.
- It goes to the station and to sites you've found.
- It's all in the tuning file (`travel`): how many visits it takes, and it can be switched off.

## What changed

1. **Gold coins, not dollars**, everywhere: the wallet, the catalog, the ledger, wages, the Chief's report.
2. **The map opens by itself** when a survey (or a tower or outlook survey) finishes.
3. **Recipes are shown everywhere.**
   - The crafting page (K) lists every recipe you know, wherever it's made. Workbench recipes are greyed with "(at a workbench)", and cooking with "(at a lit stove or camp fire)".
   - Recipes not learned yet are listed under **Not learned yet** with how to learn them: "Boardwalk: learn at Trailcraft 3", or "Pack frame: an idea comes when you carry rope".
   - Cooking now shows its recipes too, not just "Add firewood".
   - Magic refits stay hidden until found.
4. **Signs.**
   - A sign may go on a trail or up to two tiles beside one.
   - The list of places to name now includes every site you've found, nearest first, mapped or not.
   - Putting one up says whether it counts for the site, or that it's too far and how close it must be.
5. **Boardwalk.** Holding boardwalk shows a square on the tile you face: green where it can go, red where it can't. The hint line says it goes on boggy ground or shallows. The same square shows for signs, markers, cairns, benches and the shovel.
6. **Foraging.** X gathers every forage spot within 2.5 tiles at once, told in one line ("You gather 3 stones, 2 berries").
7. **The backpack.**
   - Stacks are about three times bigger (berries 30, planks 30, nails 99, firewood 20, sticks 50).
   - Drag a stack onto another slot to move it, top up the same item, or swap. This works between the backpack and any chest or shelf too.
   - Drag onto **Drop** to put it on the ground (X picks it up again; indoors it goes in the chest), or onto **Trash** to throw it away. Tools can't be trashed.
8. **"?" marks** float over:
   - the station door and the note board, when there's an unread job, note or letter;
   - the supply shelf, when a delivery is on it;
   - the suggestion box, when it has cards;
   - a site, when it's ready to declare open;
   - a pad, when its kit is waiting.
9. **Trail travel**, as above.

One number moved: the Phase 2b check that "an hour's walk fills 2 to 3 slots" still measures the same amount of forage. It now counts in the old stack sizes, since slots hold more now.

## Things to test

Short, one thing each.

**New in 0.4.2**
1. Walk around the station. Does the hint line over the item bar always say something useful?
2. Is there a "?" on the station door at the start, and does it go once you read the note board?
3. Press K. Can you see the workbench recipes and the ones still to learn?
4. Light a fire and cook. Do the recipes show?
5. Hold boardwalk near the station. Is the square red, and green on a bog?
6. Put a sign beside the trail near the cabin. Does it say it counts?
7. Press X in a patch of forage. Does it all come at once?
8. Open the backpack. Drag a stack to another slot, then onto Drop, then pick it up with X.
9. Drag something onto Trash. Try the map: it should refuse.
10. Survey. Does the map open when it's done?
11. Visit the cabin twice by trail, then press M on the trail. Is it listed? Does the trip feel right?
12. Press J. Is the Next list clear?

**Phase 2b, still to judge**
1. Does foraging feel like a pleasure or a chore now?
2. Are the bigger stacks enough?
3. Make the pack frame (reeds → rope → the idea).
4. Reach Trailcraft 3 and lay boardwalk across a bog.

**Phase 3**
1. Open the cabin and the outlook. Do visitors come?
2. Order a picnic area kit and build it.
3. Stock the gift shelf. Does gold come in?
4. Read the suggestion cards and pin one.
5. Leave the park messy for a few days. Do badgers come?
6. Hire someone from the staff board.
7. Read the Chief's weekly letter.

F1 opens the debug panel for shortcuts ("Ready cabin+outlook" starts the park quickly).

## Art

Art Request 10 (`docs/art/art_request_10_feedback.md`): three small pieces.
- A "?" mark.
- A dropped bundle.
- A gold coin.

All three work today with stand-ins.

## Pictures

In `docs/status/0.4.2_shots/`: the hint line and the "?" on the station, the red square for boardwalk, the backpack with Drop and Trash, the crafting page, the book's Next list and the map's trail travel.
