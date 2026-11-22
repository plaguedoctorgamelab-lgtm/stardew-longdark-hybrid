# Strange Ranger: Graphics Polish

This request makes the game look and feel better without changing what it is. Part one is work the lab can do in code with the art the game already has. Part two is an audit of the art, so the designer knows which pictures to redo and how. Part three takes the things that already look best, buildings, weather and water, and makes them better still.

It adds no new systems, areas or content. Where it conflicts with the art style guide, the style guide wins.

## Part one: code-only polish

Each item below uses only art the game already has. Each has its own tuning values, and each can be switched off from the debug panel so the designer can compare before and after.

### 1. Depth sorting

- Every object standing in the world (ranger, visitors, staff, badgers, trees, buildings, props, placed things) is drawn in order of the y position of its **base**, the point where it meets the ground.
- The ranger walking north of a tree passes behind it; walking south, in front.
- Each object's base is set in its content data, not guessed from the picture's edge. Trees use the foot of the trunk; buildings use the front wall's foot.
- Large objects that the ranger can walk behind (tall trees, the tower, buildings) fade to about 60% opacity while the ranger is hidden behind them, so the ranger is never lost from view. Tuning: fade amount and fade time.
- **If the game already does this,** the lab confirms it and checks every object's base point, reporting any that sort wrongly.

### 2. Hit-stop and hit reactions

- When the axe, saw, shovel or hammer lands, the ranger freezes for a few frames while the world keeps moving. Start at 3 frames for light actions and 5 for heavy ones such as felling a tree. Tuning: frames per tool.
- The thing hit reacts on the same frame the tool lands, or one frame before:
  - trees and bushes shake sideways by one game pixel, twice;
  - stumps, trunks, branches and brush jolt by one pixel toward the ranger and back;
  - a few small chips (wood, leaves, dirt or stone, by material) burst from the point of impact. Chips are tiny palette-colored particles.
- A felled tree falls away from the ranger: its picture tips over in two or three pixel-snapped steps before becoming a stump. No smooth rotation, which would blur the pixels.
- Every movement snaps to whole game pixels. Nothing is ever stretched, squashed or smoothly rotated, because that breaks the pixel grid.

### 3. Small signs of life

- **Idle bob.** After two seconds standing still, the ranger, visitors and staff rise one pixel and settle, on a slow loop, as if breathing. Tuning: delay and period.
- **Footsteps.** A tiny puff of dust on dry ground, a splash in shallows, a print in snow that fades after a few seconds.
- **Mirroring.** Left-facing walk frames are made by flipping the right-facing ones, if they are not already. The designer's row 4 frames are kept only if they look better.
- **Picking up.** Forage, litter and items hop one or two pixels toward the ranger and vanish, with a sparkle for magical ingredients.

### 4. A weather overlay

- Fog and snow get a full-screen overlay layer as well as their particles: a slowly drifting, tiled texture of soft pale patches, blended lightly over the world. Two layers moving at different speeds give depth.
- The overlay is drawn at game resolution and scaled with the world, so it stays pixel-sharp.
- The lab makes the overlay texture itself from palette colors; no new art is needed.
- Tuning: strength and drift speed per weather type.

## Part two: an art audit

The lab inspects every finished picture and writes a report that ranks them, worst first, so the designer redoes the pictures that matter most. Much of this can be measured by the cleanup tool; the rest needs the lab's eye in a test scene.

### What to look for

| # | Problem | How to spot it | Usually caused by | Usual fix |
| --- | --- | --- | --- | --- |
| 1 | **Mush** | Detail finer than a game pixel turns into speckled noise after shrinking | ChatGPT drawing too finely for the target size | Redo with "much simpler shapes, far fewer pixels", or hand cleanup |
| 2 | **Stray pixels** | Single pixels of a color with no neighbor of the same color | Palette snapping of soft edges | Cleanup tool removes them automatically; report the count |
| 3 | **Unreadable icon** | Can't tell what it is at 16 by 16 at normal zoom | Too many details, weak silhouette | Redo with one bold shape and two or three colors |
| 4 | **Wrong view** | Side-on or diagonal instead of top-down three-quarter | Prompt ignored | Redo with the view correction line |
| 5 | **Wrong light** | Highlights not on the top-left | Prompt ignored | Redo, or flip the picture if it is symmetrical |
| 6 | **Outline trouble** | Pure black outlines, missing outlines, or outlines of uneven width | Inconsistent generations | Cleanup tool recolors black outlines to a dark shade of the object's own color; redo if outlines are missing |
| 7 | **Wrong scale** | Out of proportion with the ranger, the door or a tile | Generated at the wrong size | Resize in the manifest, or redo |
| 8 | **Flat or banded** | One shade over a whole area, or a staircase of too many shades | Snapping to too few or too many tones | Redo, or a hand pass to set 2 to 3 tones per material |
| 9 | **Visible repeats** | A tile's pattern forms obvious stripes or a grid when laid in a field | A distinctive mark repeated each tile | Use the tile's variants at random; redo the tile if a mark is too strong |
| 10 | **Lost at night** | Disappears or turns to mud under the night tint | Too little contrast between its tones | Redo with stronger contrast, or brighten its lightest tone |
| 11 | **Wobbly frames** | A character's size, colors or outline change between animation frames | Generators drift between frames | Hand cleanup of the odd frames |
| 12 | **Clashing pieces** | Looks like it came from a different game beside its neighbors | Made in a different session or without a reference image | Redo with the accepted ground tiles attached as reference |

### The report

- One row per finished picture: its name, which of the twelve problems it has, a severity from 1 (barely noticeable) to 3 (stands out in play), and a suggested fix.
- Each picture is shown three ways: alone at game size, in a typical scene beside the ranger, and in that scene under the night tint.
- The lab measures what it can: stray pixel count, colors used, outline color, size against target, and contrast under the night tint.
- The report ends with the **ten pictures most worth redoing**, chosen by how bad they look and how often the player sees them. A picture on screen all the time, such as the ranger or grass, outranks one seen once.
- For each of the ten, the lab writes a ready-to-paste ChatGPT prompt for the redo, in the art guide's format, or says it needs a hand pass instead.
- Pictures for things the designer has not found are reported by count only, as the secrecy rules require.

### Likely candidates

These came up when the first batch was checked and are worth looking at first: the ranger's walk frames (squat, with a hat wider than the 16-pixel frame), the tool icons (drawn finer than 16 by 16 can hold), and the interior floor and wall tiles (drawn with a border that must be cropped).

### Hand cleanup and the pixel artist

Some problems, wobbly frames above all, cannot be fixed by asking ChatGPT again. The report marks these "hand pass". They are the start of a list for a pixel artist, whom the designer plans to hire before phase 4 for characters, portraits and animation. Until then, the lab may make small hand fixes to individual pixels in `art/final/` overrides, never in `art/raw/`, and lists every one in its status email.

## Part three: making the best look better

The buildings, weather and water already look good, including the newest additions. These additions build on them. Most are code; the few that need art are marked.

### Buildings

| Addition | What it looks like | Needs art? |
| --- | --- | --- |
| Ground shadows | A soft, palette-dark shadow on the ground under each building's front and right side, matching top-left light | No |
| Chimney smoke | A thin, wavering column of small smoke puffs from any chimney whose stove is lit, leaning with the wind | No |
| Window glow | Windows of a lit building glow warm after dusk, and cast a small pool of warm light on the ground outside | No |
| Doors | The door opens on its picture for a moment as the ranger goes in or out | One open-door frame per building |
| Weather on roofs | Snow lies on roofs in winter; roofs look darker and wetter in rain | Winter roof versions |

### Weather

| Addition | What it looks like | Needs art? |
| --- | --- | --- |
| Rain splashes | Tiny splashes where drops land, on ground and water | No |
| Wet ground | Ground darkens slightly during and after rain, drying over an hour | No |
| Puddles | A few puddles form on trail during heavy rain and dry the next day | Two small puddle sprites |
| Wind | Grass tufts, bush tops and tree crowns sway by one pixel in wind, more in storms; the trunk never moves | No |
| Lightning | In storms, a brief white flash of the whole screen, then a short darkening, now and then | No |
| Falling leaves | In autumn, a few leaves drift down from trees and across the screen with the wind | No |
| Snow settling | In snow, open ground turns gradually whiter over a few hours, and greener again after a thaw | No |
| Fog depth | Fog is thicker in hollows and over water, using the overlay from part one | No |

### Water

| Addition | What it looks like | Needs art? |
| --- | --- | --- |
| Moving water | Water tiles cycle through three or four frames, or shimmer with a pixel-snapped ripple, so lakes and streams are never still | Possibly two or three extra frames of each water tile |
| Flowing water | Streams and the river show ripples drifting downstream | Uses the same frames, moved |
| Shorelines | A thin, shifting line of pale foam or light where water meets land | No |
| Sparkle | Occasional one-pixel glints on open water in clear sunshine | No |
| Ripples | Rings spread from the ranger's feet in shallows, from rain, and from things that land in water | No |
| Night water | Water reflects the tower's light, window glow and lantern light as a soft wavering streak | No |
| Ice | In winter, frozen water uses a pale, still version with cracks | One ice tile set |

### What not to do

- No smooth rotation, scaling, blur or soft glow on any sprite. Light and glow are done with palette-colored overlays and the existing tint.
- No effect may make a path, sign or site harder to see. The designer must still be able to find their way in rain and at night.
- Every effect has an off switch in settings, grouped as "Weather effects" and "Motion", for players who prefer a calmer screen.

## Order of work

1. Depth sorting.
2. Hit-stop and hit reactions.
3. The art audit report, so the designer can start redoing pictures while the lab carries on.
4. Small signs of life.
5. Weather: the overlay, then the additions.
6. Water.
7. Buildings.
8. An art request for the few new pictures part three needs, in the art guide's format.

Each step ends with a short screen recording or before-and-after screenshots in the status email, since this work is judged by eye.

## Tests

| Area | Must be true |
| --- | --- |
| Depth | The ranger is drawn behind and in front of every kind of object correctly, from all four sides |
| Pixel grid | No sprite is ever drawn at a fractional pixel position, stretched, squashed or rotated smoothly |
| Hit-stop | Each tool freezes the ranger for its tuned frames and never freezes the world |
| Weather | Every effect appears only in its weather and season, and none hides a trail, sign or site marker |
| Settings | Every effect group can be switched off and stays off after a reload |
| Performance | 60 frames per second in a storm at night by the lake, with visitors on screen |

## Play checklist

- [ ] Walk around a large tree and the tower, and judge whether depth looks right.
- [ ] Chop a tree, and judge whether it feels weightier.
- [ ] Stand still and watch the ranger breathe.
- [ ] Walk through rain into a puddle and through shallows.
- [ ] Watch the lake at dawn, midday and night.
- [ ] Stand outside a lit cabin at night in falling snow.
- [ ] Read the art audit's top ten, and decide which to redo first.
- [ ] Switch the effects off, and judge whether you prefer the game with them.
