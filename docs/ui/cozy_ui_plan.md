# Strange Ranger: the cozy UI plan

From the lab, 24 November 2026. Agreed the same day (see the end); nothing is built yet. Mockups of every page are on the design canvas (https://claude.ai/artifact/UDEjqPphT13N7Zzh7Fb6MS), made from the game's real art, and the art they need is Art Request 24 (`docs/art/art_request_24_cozy_ui.md`).

## What you asked for

1. The jobs clipboard is the model.
2. Every page the same size, and you flip between them, crafting included, so it all feels like one thing.
3. The map no bigger than the rest: the same size as the clipboard.
4. Pictures, not words, words, words. The notes, the crafting, all of it. Keep what's good about the backpack and the outfits, but on the clipboard and at its size.
5. The tags go. They're slow and in the way.

## What's there now (0.7.13)

I opened every page and took screenshots (`tests/support/screenshots_ui_review.gd`). Six different frames and six different sizes:

| Page | Frame now | Size (game pixels) | How it reads |
| --- | --- | --- | --- |
| Jobs | the clipboard | 456 × 258 | Pictures and words mixed well: cards with a picture and a bar, ribbons, reward tiles. **The model.** |
| Backpack and outfits | the gear wall (planks) | 462 × 160 | Good pictures; but a different frame, and the outfit side trails off ("Nothing spare yet. To…") |
| Map | its own paper, no frame | 400 × 270, taller than the rest | Legend and trail travel are text boxes that cover the map |
| People and calendar | a leather book and a wall calendar | 384 × 256 | Two more frames. The calendar is nice; People is a list of names |
| Crafting | a plain list box | 360 × 230 | All words: "Blank sign: 2 Planks (have 12), 1 Nails (have 20)" |
| Book: park, ledger, cards, letters, notebook | plain paper with blue word tabs | 380 × 236 | Pages of sentences. The badges page is the only picture page |
| Shops | the same plain list box | 360 × 230 | "Insulated boots · +1 warmth outdoors · 160g", one line each |
| Chest | the gear wall, a second grid underneath | 462 × about 230 | Works, but a different frame from the rest |

Plus three kinds of tag that float over things:
- the **item tag** on the pointer (paper luggage tag) in the backpack, chest and item bar;
- the **name tag** over whatever the ranger faces in the world ("Supply catalog");
- the **hover hint** beside the pointer.

All three wait a moment before showing, cover what you're looking at and follow the mouse.

Also seen: a new-recipe notice ("You can make something new!") opens as a big talk box over whatever page is open. That's the same problem in another form.

## The plan in one picture

**One clipboard, many sheets.** The board, the clip and the six patches never move. Flipping a tab swaps the sheet clipped to it. Every sheet is laid out the jobs way:

```
 [patches: Pack  Jobs  Map  Town  Make  Log]
+---------------------------------------------+   the clipboard, 456 x 258,
|  (index tabs)        [ clip ]                |   always at (12, 6)
|  +-----------+  +--------------------------+ |
|  | LIST      |  | DETAIL                   | |   paper 396 x 192
|  | picture   |  | [big picture] Title      | |   list column 112 wide
|  | cards     |  | chips: icon + number     | |   detail column 276 wide
|  | under     |  | == ribbon ==             | |
|  | ribbons   |  | picture tiles            | |
|  |           |  | == ribbon ==             | |
|  |           |  | picture tiles            | |
|  |           |  | [stamp] [stamp]          | |
|  +-----------+  +--------------------------+ |
|  key caps: [Q][E] tabs  [W][S] list  [X] use |
+---------------------------------------------+
```

### The rules for every sheet

1. **Same board, same place, same size.** 456 × 258 at (12, 6), paper 396 × 192, for every page and every list: the six tabs, shops, the chest, the workbench, the stove. Nothing else opens in its own window.
2. **A list on the left, the chosen one on the right.** Cards 104 × 32: a 24 × 24 picture, a name, and one line drawn as a picture (a bar, hearts, coins or dots), never a sentence.
3. **Pictures carry the facts, words name things.** A fact is an icon plus a number: a flame and "+1" for warmth, a coin and "160" for a price. Sentences are only for the voice of the game (a job's note, a letter, a notebook entry, what someone says), in the handwriting colour.
4. **Ribbons split a detail** into "You'll need", "Steps", "Rewards", "Loves" and so on, as on the jobs sheet. Each ribbon gets a small icon so it reads at a glance.
5. **Tiles, not lines.** Anything countable is a 24 × 24 tile: the picture, a count badge, and a gold, grey or red frame for enough, done or short.
6. **Stamps for actions.** Make, Buy, Sell, Pin and Show on map are rubber stamps with an icon, at the foot of the detail, always in the same place.
7. **Key caps, not key words.** The foot of the board shows little key pictures ([Q][E], [W][S], [X], [Esc]) beside icons, instead of "Q/E tabs · W/S jobs · wheel scrolls…".
8. **Nothing floats.** What you point at shows on the sheet itself, at once (next section).

## The tags go

| Tag now | Instead |
| --- | --- |
| Item tag on the pointer (backpack, chest) | The **label strip** at the foot of the Pack sheet: the item's picture, name, kind stamp and its facts as chips (energy, warmth, price). It fills **at once** on hover or selection, stays put, and covers nothing. |
| Item tag on the item bar | The **action chip** (below) shows the held item's name and what C does with it. |
| Name tag over things in the world | The **action chip**: a small fixed plate just above the item bar with a key cap, a verb icon and one or two words: **[X] (talk) Gus**, **[X] (open) Supply catalog**. Nothing hovers over the world. |
| Hover hint beside the pointer | Into the same action chip. |
| "You can make something new!" talk box | A **toast card** that slides in at the top right: the new thing's picture on a little recipe card with a lightbulb, for a few seconds. It never stops play and never covers an open page. |

The left-hand job ribbons ("New job: …", "Done: …") stay as they are: they're the toasts you said you like. They'd shrink to one line each with the job's picture.

## Sheet by sheet

### 1. Pack (backpack and outfits)

What you like stays: the slots, the ranger in their clothes, the pegs. Now on the clipboard:

- **List side becomes the pack grid**: the item-bar row (numbered 1 to 0) on top, then the rest of the pack, on the canvas webbing.
- **Detail side becomes the ranger**: the ranger standing on the gear mat with hat, coat and boots slots round them, and the spare pegs beside. The warmth from clothes shows as a flame chip with a number.
- **Label strip** across the foot of the paper: whatever is pointed at or picked, as picture, name, kind stamp and fact chips. This is where the item tag's information goes.
- **Stamps**: Repack (arrows), Drop (open hand) and Bin (the bin picture), as now.
- The park ID card (Dusk River Park, funds, earned, the date) moves to the **Log's Park sheet**, which is where money and the park's day already live.

### 2. Jobs

It stays as it is, the model, with small fixes:
- Long names are cut off ("Get the Tower Radio Ta…"): shrink the font a step, or let the name wrap to two lines.
- Reward tiles show picture and number only ("20" by a coin); the words sit under the tiles only for the one you point at.
- "Pin to screen (P)" and "Show on map (M)" become stamps with key caps.
- The key line becomes key caps.

### 3. Map

The same clipboard, with the map paper clipped to it:
- The map fills the 396 × 192 paper and pans and zooms inside it (wheel to zoom, drag to pan, centred on the ranger when it opens). It's never bigger than the board.
- **Trail travel** becomes a list column on the right (the jobs layout mirrored): a card for each walkable landmark with its map icon, name, and a boot icon with the hours. Clicking one shows it on the map; a Walk stamp goes.
- **The legend** becomes a strip of icons along the paper's foot, no box over the map.
- **"4% mapped"** becomes a compass with a fill bar.
- Job flags, Esme's circle and "you are here" stay on the map as they are.

### 4. Town (people and calendar)

Index tabs on the sheet: **People | Calendar**.

- **People**: a card for each person: their face, name and ten small hearts. In the detail: their portrait, the hearts with a sweetheart heart when dating, and chips for birthday (cake and date), talked today (bubble tick) and gift today (box tick). Then ribbons:
  - **Loves**: gift tiles you've learned, with "?" tiles for the rest.
  - **Where now**: the place's icon and name.
- **Calendar**: the month on the sheet as a 7 × 4 grid with the icons it has now (birthdays, festivals), plus the season's picture in the clip's place. The calendar art you have stays; it just moves onto the board.

### 5. Make (crafting, and every workbench and stove)

The jobs layout exactly:
- **List**: recipe cards under ribbons by kind (Tools, Building, Food, Refits, Decor, Garden), each card with the thing's picture, its name, and a dot: green = can make now, grey = missing something, a lock = an idea you haven't had.
- **Detail**: the big picture and name, a chip for where it's made (hands, workbench, campfire, range), then ribbons:
  - **You'll need**: ingredient tiles with "have/need" badges, red when short.
  - **Does**: chips (flame +1, energy +70, map pin for "marks a spot").
  - **Makes**: the result tile with its count.
- **Stamps**: **Make** (hammer), and **Make 5** when you can.
- At a workbench or stove the same sheet opens, showing only that station's recipes, with its picture on the clip.

### 6. Log (was Book)

Index tabs with pictures: **Park, Ledger, Cards, Letters, Notebook, Badges**.

- **Park today**: a dashboard of picture tiles: visitors (a person) and parties (a group), arriving today (a car), sites ready (a tent), litter (a bag), and the park ID card from the Pack page, with the wallet. The weather for three days as three little sky tiles.
- **Ledger**: the wallet as a coin tile; this week as seven little bars; then cards for each entry with an icon (a job, a sale, a fee, a visitor) and its coins in green or red.
- **Cards** (from the suggestion box): little index cards in the list; the chosen one shown large, handwritten, with a stamp when it's done.
- **Letters**: envelopes in the list (the sender's face and a wax seal, open or sealed); the letter on stationery in the detail, with the sender's portrait.
- **Notebook** (the ranger's notes): sticky notes in the list, each with a small doodle for what kind of thing it is (big footprints, a paw, a mug, a ribbon, a sign, an eye) and the day. In the detail: the note large in handwriting, with its doodle drawn big. Strange things get their own colour of note.
- **Badges**: as now, moved onto the board.

### 7. Shops

Shops open the **Make layout**: goods cards on the left with a coin and price, and the detail with the big picture, fact chips, the price, and **Buy** and **Sell** stamps. The shopkeeper's portrait sits in the clip's place, and **Buy | Sell** are the index tabs. The Percolator's one-line "Buy" menu goes: you land straight on its goods.

For clothes, a **You're wearing** ribbon shows what you have on in that slot beside the one you're looking at, with the difference as a chip ("+1 warmer than now"), and a second stamp, **Buy and wear**.

### 8. Chest

The Pack sheet with the chest's grid in place of the ranger: pack on the left, chest on the right, the label strip along the foot. Click or drag between them.

### 9. Choices and talk

- The talk box stays as it is: the portraits make it.
- Choice lists (festival choices, scene choices, Esme's offer) become picture cards when the options have pictures (a lantern's colours, the Big Foot contestants' faces), and stay words when they don't.

## What changes in the code (for later)

Not now. For the record, so the size of the job is clear:

1. One `Sheet` base (the board, the patches, the paper, a list column, a detail column, ribbons, tiles, chips, stamps, the label strip, key caps), pulled out of `clipboard_screen.gd`.
2. Pack, Map, Town, Make, Log, shop and chest rebuilt as sheets on that base. Jobs moves onto it unchanged.
3. `item_tip.gd`, the HUD's look tag and its hover tip go; the action chip and toast card come in.
4. The book's text pages need their facts as data (counts, entries) rather than finished sentences. The park module already has most of them.
5. Tests: one that opens every sheet and checks it sits at (12, 6) at 456 × 258, plus the existing page tests moved over.

Probably three builds (0.7.15 to 0.7.17): the base and Make first, then Pack, Map and Town, then Log, shops, the chest and the tags.

## Agreed

You agreed the plan on 24 November 2026, as written. The four open questions were settled the way the mockups show them:

1. "Book" becomes **Log**. The patch art stays.
2. The park ID card moves from Pack to the **Log's Park sheet**.
3. The map's trail travel list goes on the **right**.
4. The action chip sits **just above the item bar**.
