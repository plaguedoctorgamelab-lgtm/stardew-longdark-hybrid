# Strange Ranger: Open Questions and Tuning List

Nothing here blocks phase one. Everything else is recorded so it is decided on purpose, at the right time, and not by accident.

## Confirmed decisions

| Question | Suggested answer |
| --- | --- |
| Is a content database of plain text tables acceptable, in place of SQLite? | Yes, confirmed by the designer on 14 November 2026. It behaves as a database, shows changes clearly in git and needs no add-on. It can move to SQLite later behind the same module. |
| Where does the ranger wake after staying up too late in the backcountry? | The nearest repaired shelter: station, cabin or fire tower, never a camp. Decided 15 November 2026. |

## Open design questions

| Question | Needed by | Notes |
| --- | --- | --- |
| What is the park called? | Phase 3 | Appears on signs, brochures and the gift shop map |
| Is Humdrum the town's final name? | Phase 4 | Provisional. Others floated: Dusk Hollow, Nearly, Lantern Gap, Odd Fork |
| How big is a region in tiles? | Phase 6 | The largest unknown. "A day to cross" at phase one's walking speed is a very large map. Phase one's play test should settle walking speed first; region size follows from it. |
| In what order do the swamp, plains, foothills and mountains open? | Phase 7 | Mountains last seems natural |
| What is the "magical" area in the first notes? | Phase 7 | The notes list it beside the five regions. It could be a hidden sixth region, a late reward, or small magical pockets inside every region. |
| What did happen to the last ranger, and why does the Chief never visit? | Phase 6 | The designer may decide, or may leave it to the lab as a hidden thing and be surprised |
| What are the giant robots and the UFOs? | Their region's phase | Creatures to befriend, ruins to explore, or both |
| What does a settled creature do: leave or stay? | Phase 5 | Suggested: it depends on the creature |
| What does a rescue cost once money exists? | Phase 3 | Stardew takes a small share of money |
| Does the player set prices for fees and rentals? | Phase 3 | Not yet discussed |
| How many visitors can be on screen and in the park at once? | Phase 3 | A performance question as much as a design one |
| When and how is the second pet adopted? | Phase 5 | Agreed in principle |
| How far does romance go? | Phase 4 | Assumed to follow Stardew |
| What does the game sound like? | Phase 7 | Not yet discussed. The Long Dark's sound is one of its great strengths: wind, footsteps, fire, quiet. Worth an early conversation. |
| What do the first ten minutes of a new game show? | Phase 7 | Stardew opens with a letter and a bus ride |
| Is a controller wanted at launch? | Phase 7 | The input rules already allow for it |

## To tune after playing phase one

- [ ] Walking speed, and how different each kind of ground feels.
- [ ] Distance to the cabin: is four game hours right for "far"?
- [ ] Length of the day. Is Stardew's 14 minutes right for a game about long walks?
- [ ] How fast warmth drains, above all in a blizzard.
- [ ] How fast energy drains, and how much food restores.
- [ ] How often the weather changes, and how much warning the signs give.
- [ ] Forecast accuracy.
- [ ] How dark night is, and how far the lantern reaches.
- [ ] How little can be seen in fog and blizzard.
- [ ] Survey, location and outlook reveal sizes, and how long surveying takes.
- [ ] Whether the position marker rules feel fair or frustrating.
- [ ] Backpack size.
- [ ] Cabin repair: number of steps, materials and time.
- [ ] Whether a collapse feels gentle enough.

## Lessons learned

After each phase, add what the play test taught, so the next spec starts from it.

### Phase one (signed off 15 November 2026)

- **Readable text matters as much as the pixel look.** The world stays pixel-perfect; text and menus draw at full resolution.
- **The first hour must not get the player lost.** Day one is clear and the home area starts mapped.
- **A place you can't see needs a hint.** A rough circle on the map works without becoming a quest marker.
- **Far trips need a fallback for the night.** The bedroll camp made distance feel like planning, not punishment.
- **An invitation helps.** The note board and job list gave the cabin trip a reason without ordering it.
