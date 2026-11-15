# Strange Ranger: Working Rules for the Lab

These rules tell the lab what it may decide alone and when it must stop and ask the designer. They apply to every phase.

## Which document wins

1. The current phase's build spec says what to build now.
2. The game bible says what the game is. If the spec is silent, the bible's standing rules decide, starting with "when in doubt, do it like Stardew Valley."
3. If the spec and the bible disagree, follow the spec for this phase and report the conflict in the next status email.
4. The lab never edits the bible, the roadmap or a spec. It proposes changes in a status email, and the designer makes them.

## Stay inside the phase

- Build only what the current spec lists. Anything on its "not in this phase" list waits, even if it would be easy.
- Build foundations so later phases can stand on them, but add no feature the player can see ahead of its phase.
- If a step proves much larger than expected, stop and say so before pushing on.

## Decide alone

The lab makes these choices without asking:

- How code is organized inside the structure the standards set.
- Names of functions, scenes and internal files.
- How a system works inside, as long as it behaves as the spec says.
- What placeholder images look like.
- Extra tests beyond those required.
- Wording of placeholder text, clearly marked as placeholder in the text table.
- Bug fixes that do not change designed behavior.

## Stop and ask

The lab stops and emails the designer before doing any of these:

- Changing anything the player would notice that the spec does not describe.
- Changing a tuning value's meaning, as opposed to its number.
- Adding an add-on, library or outside tool.
- Changing the engine version, the folder layout, the save format in a way that breaks old saves, or any technical standard.
- Dropping or weakening a required test.
- Deleting or altering anything in `art/raw/`.
- Anything where two readings of the spec would give clearly different games.

While waiting for an answer, the lab carries on with other work that does not depend on it.

## How work is done

- Work in small steps. Each step ends with all tests passing and a commit with a plain description.
- Never commit with failing tests. If a test is wrong, say why and fix the test in its own commit.
- Keep the main branch always playable.
- No number that affects play goes in code; it goes in the tuning file. No content or player-facing text goes in code; it goes in the content tables.
- Every new system gets its debug tools the day it is built.
- Report real results. Never describe something as working unless a test or a run has shown it.

## Status emails

One email at the end of each build step, and one whenever the lab stops to ask. Each contains:

- What was built, in a few lines.
- Test results: how many passed and failed, with the names of any failures.
- Anything that differs from the spec, and why.
- Questions for the designer, numbered, each with the lab's suggested answer.
- What comes next.
- How to run the current build.

## Hidden things

From the phase that says so, the lab invents secrets for each region that the designer has not asked for. These rules apply:

- Every secret obeys the bible's standing rules: cozy, weird, harmless, unexplained, no killing, nothing sinister.
- A secret never blocks progress, breaks a designed system or contradicts the bible.
- Secrets are kept in their own content tables and their own notes file, marked as spoilers, and are never described in status emails.
- Each secret has an automated test proving it can be found and works.
- The status email reports only how many secrets were added.

Phase one contains no hidden things.
