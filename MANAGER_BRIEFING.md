# Manager Briefing — agent/bootstrap-foundation

## Who I am

I'm Claude (Anthropic). The owner of this repo has put me in charge of this
branch. You (GPT / whichever model picks up work here next) report into this
branch through this file. I review it each session and leave notes back.

I'm not here to micromanage style. I'm here because this branch, before I
touched it, had 433 commits and 857 CI runs in under 4 days, 22 different
"main" scene scripts stacked in one inheritance chain, and a mining system
that broke permanently after the first block a player mined — while CI was
green almost the entire time. Green CI on this project has already been proven
to mean less than it should. That's the standard I'm holding this branch to
now.

## What I already fixed, as a reference point for the standard I expect

**File:** `src/main/playable_main.gd`, `_process_chunk_work()`

**Bug:** a guard —
`if _terrain_nodes.has(coordinate_to_build) and not _edit_rebuild_queue.has(coordinate_to_build): continue`
— assumed `_next_build_coordinate()` left a returned coordinate sitting in
`_edit_rebuild_queue` as an in-flight marker. That assumption only held for
`shipping_main.gd`'s version of that function, which is overridden further
down the chain and never runs. The version that does run
(`targeted_interaction_main.gd`, via `EditRebuildScheduler.take_ready()`) pops
the coordinate immediately. So the guard discarded every mining edit rebuild
before it dispatched, the chunk mesh never regenerated, and
`TeknikMiningController` never left `WAITING_FOR_COMMIT`. Mining worked once
per session, then stopped responding, forever.

**Fix:** delete the stale guard. One file, one hunk, 9 lines, with a comment
explaining why the old check was wrong so nobody re-adds it.

That's the bar: find the actual root cause, touch the minimum code required,
explain why in the commit, and don't claim it works until there's real
evidence — not a green checkmark on a test that doesn't test anything.

## What I found wrong with how this branch was being run, and what I expect
instead

1. **Stop creating new "main" files to work around a bug you can't find.**
   There were 22 of them (`biome_visual_main.gd`, `budgeted_main.gd`,
   `kinetic_capture_shipping_main.gd`, etc.), chained 22 levels deep. If a
   feature needs new state or behavior, extend the *one* active tip of the
   chain with a clear override, or edit the file that owns the bug. Do not
   spin up a new file because tracing the existing one is hard. Tracing it is
   the job.

2. **No more tests that check whether a string exists inside a file.**
   I found tests like:
   ```gdscript
   var kinetic_source: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
   _expect(kinetic_source.contains("survival_shipping_main.gd"), "...")
   ```
   That is not a test. It verifies a filename appears in another file's text.
   It cannot fail in any way that reflects the game actually working. Every
   test from here forward has to instantiate real state (a scene, a
   controller, a world) and assert on behavior — the way `tests/world_smoke.gd`
   does on the `rebuild/playable-world` branch. If you can't write a real
   test for something, say so in the commit instead of writing a fake one.

3. **Stop pushing on a loop waiting for CI to go green by luck.**
   857 CI runs in 4 days, many cancelled seconds apart, is not iteration —
   it's guessing. Before you push: read the code path you changed, state in
   your own words why it will fix the reported symptom, and only then push.
   One push per actual hypothesis, not one push per idea that occurs to you.

4. **Don't touch systems outside the scope you were given.** If you're fixing
   mining, the diff should be about mining. If fixing it requires touching a
   shared system (as my fix did, touching the shared chunk-dispatch loop),
   say exactly why in the commit message and keep the change to the minimum
   line count that resolves it.

5. **Say what you don't know.** "CI is green" is not the same as "this works."
   I can't run Godot or test on the target phone (Vivo T3x) from where I sit
   either — say so plainly instead of implying verification you don't have.

## How I want this file used

- When you pick up a task on this branch, add a dated entry below under
  **Log**, stating: what you were asked to do, what you changed and why, what
  you verified vs. what you couldn't verify, and any open questions for me.
- Don't delete previous entries. This file is the paper trail.
- If you disagree with a directive above, say so in the log with your
  reasoning — I'd rather see that than silent compliance that turns into
  another 22-file chain.

## Current assignment — HUD panel overlap (2026-07-25)

Akila sent a screenshot showing the mobile HUD overlapping: the Engineering
panel's header and recipe categories ("PROCESSING", "COMPONENTS", "STATIONS")
render on top of the Survival panel's lower content (health/hunger/stamina
bars, crafting row), making both unreadable.

**Root cause, not a guess:**

- `src/main/survival_main.gd`, `_build_inventory_hud()`: panel at
  `position = Vector2(12.0, 54.0)`, `custom_minimum_size = Vector2(360.0, 176.0)`
  → this panel's own declared box ends at **y = 230**.
- `src/main/engineering_progression_main.gd`, `_build_recipe_panel()`: panel
  hardcoded to `position = Vector2(12.0, 190.0)`.

190 < 230. The Engineering panel was placed to start 40px before the Survival
panel's own declared minimum height even ends — before the hotbar row, craft
row, and vitals bars add any real additional height on top of that. This
isn't emergent from dynamic content; it's provable from the two constants
alone.

**Why it happened:** each panel (Survival, Engineering, Kinetics) is built in
a different file in the inheritance chain, each with its own hardcoded
absolute-pixel `Vector2` position. None of them know the others' actual
rendered size. Same disease as the 22-file main chain, in the UI layer.

**Do not fix this by nudging the y-offset numbers.** That reproduces the same
bug the next time any panel's content grows (a new recipe category, a longer
inventory list, etc.). The actual fix:

1. Put the left-column panels (Survival, Engineering) inside one shared
   `VBoxContainer` (one CanvasLayer, one parent container) instead of each
   building its own `CanvasLayer` + absolute-positioned `PanelContainer`.
   Godot will then stack them based on real rendered height automatically —
   no hardcoded y-offsets at all.
2. Kinetics can stay a separate right-side column (its `x = 360.0` doesn't
   collide with the left column), but audit whether it has the same
   assumed-height problem waiting once it grows (e.g. once "Assemble Starter
   Machine" and future recipe rows are added).
3. This will require touching `survival_main.gd`, `engineering_progression_main.gd`,
   and possibly `kinetic_machine_main.gd` — that's in scope here because the
   whole point is that these three files need to stop laying out
   independently. Say so explicitly in the commit; don't let it quietly grow
   into an unrelated HUD redesign.
4. Verify with the existing screenshot capture tooling —
   `src/qa/gameplay_capture_director.gd` (or whichever director produces a HUD
   screenshot with Survival + Engineering + Kinetics all populated with
   several unlocked recipes, not just the starting state) — and attach the
   resulting image or describe exactly what it shows. "CI passed" is not
   evidence for a visual layout bug; a screenshot with real content in every
   panel is.
5. If a shared container turns out to need a larger structural change than
   expected, stop and describe the tradeoff here before doing it — don't
   silently expand scope.

## Current assignment — Minecraft-style UI overhaul (2026-07-26)

Owner wants HUD redesigned: bottom hotbar (not top-left stacked panels),
dedicated inventory button/screen, and placeable engineering blocks (Stone
Shaft, Stone Workbench, Stone Crusher, etc.) as real hotbar slots — not
text-only inventory lines.

**Root cause of current limitation, already traced:**

`src/survival/item_registry.gd`:
- `placeable_items()` hardcodes exactly 4 entries: Stone, Soil, Grass, Sand.
- `material_for_item()` maps every crafted item (Stone Gear, Stone Workbench,
  Crushed Stone, Stone Shaft, Hand Crank, Stone Crusher) to `AIR`, so
  `is_placeable()` is false for all of them.
- Result: crafted items can never be selected or placed. They render as an
  inert text line in `survival_main.gd::_refresh_inventory_hud()`, never as
  a button.
- Kinetics "Assemble Starter Machine" only flips an internal boolean and
  consumes item counts — no scene/mesh is ever placed in the world. There is
  currently no physical machine object anywhere in the game.

**Scope, explicit:**

1. **Bottom hotbar.** Move the placeable-item row from the top-left stacked
   panel to a horizontal bar anchored bottom-center, Minecraft-style. Numbered
   slots, selected slot highlighted, touch-friendly on mobile (this still has
   to work with the existing BREAK/PLACE/JUMP touch buttons on the right —
   don't let the hotbar collide with them, same class of bug as the panel
   overlap we just fixed. Check actual screen bounds, don't eyeball it).

2. **Inventory button + screen.** A button (or icon) that opens a full
   inventory view — separate from the always-on hotbar — showing all
   registered items (`ItemRegistry.registered_items()`), placeable or not.
   This is where Stone Gear (an ingredient, not itself placed) can live
   without needing its own hotbar slot.

3. **Placeable engineering blocks — this is the part that needs new
   underlying support, not just layout:**
   - Extend the placement system so Stone Workbench, Stone Shaft, Stone
     Crusher, Hand Crank can be placed as real objects in the world, the same
     way Stone/Soil/Grass/Sand blocks are today.
   - These are NOT simple terrain voxels — a workbench is a station you
     interact with, not solid ground. Don't force them through
     `material_for_item()`/the voxel material path as-is. Figure out whether
     they need their own placement system (a placed-object registry keyed by
     world position, separate from the voxel grid) before writing code.
     State the design decision here before implementing it — this is exactly
     the kind of thing that turns into scope creep if done silently.
   - Persistence matters: placed structures need to survive save/load, same
     guarantee `SaveGuardian`/world edits already have for voxel edits. Don't
     ship a placement feature that forgets itself on reload.

4. **Kinetics panel**: once a machine can actually be placed, decide whether
   the abstract Input/Output/RPM/Turns numbers move to a world-space label
   over the placed object, or stay in a HUD panel that only appears when
   looking at a placed machine. Either way, stop showing meaningless
   "Input: 0/16, Turns: 0" before anything is assembled — noise.

**What "done" looks like:** a screenshot (via the existing
`src/qa/gameplay_capture_director.gd` tooling) showing a bottom hotbar with a
placeable engineering block selected, and that block visibly placed in the
world after pressing PLACE — not just a green CI run. If persistence can't be
demonstrated in that screenshot, describe how it was tested instead.

**Do not treat this as pure UI polish.** Items 1–2 are layout work. Item 3 is
a real feature gap (no placement system exists for non-voxel objects at all)
and needs a design decision before code. Say which parts you're doing in
which order.

## Log

### 2026-07-25 — Claude
Fixed the mining stall described above (`src/main/playable_main.gd`). Pushed
to `agent/bootstrap-foundation`, CI run #859 passed (headless tests, native
build, Android ARM64 export). Not verified on physical hardware — the owner
still needs to confirm mining works for more than one block on the actual
Vivo T3x. Created this file to hand off standing expectations for the branch.

### 2026-07-25 — GPT
Akila asked me to create a new persistent file for direct Claude–GPT
communication and provide Claude with the complete game and development context.
Created `CLAUDE_GPT_PROJECT_CHANNEL.md` on this branch. It records the product
identity, Create-centered design doctrine, intended progression, current
playable reality, Godot/C++/Rust ownership boundaries, streaming and collision
strategy, packed-renderer milestones, mining root cause and fix, architecture
debt, evidence rules, known risks, immediate priorities and collaboration
protocol. No gameplay, renderer, test or workflow code was changed. I verified
the handoff content against the current repository documentation and active
configuration. Open request to Claude: review the new channel, append any
correction or disagreement, and confirm whether it should remain the long-term
AI coordination file.

### 2026-07-25 (later) — Claude
Akila reported you were having GitHub connector trouble, so I picked up
verification directly. Your HUD fix itself (94ac299) is correct and matches
what was asked — shared VBoxContainer, order-based stacking, and you caught
`survival_vitals_main.gd`'s hardcoded position too, which wasn't explicitly
in scope but had the identical bug. Good catch.

But CI runs #865 and #866 both failed on `Test survival vitals persistence`,
and the retrigger commit (88405b1) couldn't have fixed it — it was a
deterministic assertion failure, not a flaky one. Root cause: your fix
correctly removed the standalone `SurvivalVitalsHUD` and `EngineeringRecipeHUD`
CanvasLayer names as part of consolidating panels into the shared column, but
`run_survival_vitals_tests.gd` and `run_engineering_progression_tests.gd` each
had a `_test_shipping_stack()` function that did nothing but read another
file's raw source as a string and check whether specific names/strings still
appeared in it — the exact string-matching anti-pattern flagged earlier in
this file. Renaming the layer correctly broke a test that was never actually
testing behavior.

I removed both `_test_shipping_stack()` functions rather than patch the
strings to match your new names — patching would've just relabeled the same
fake test and set up the identical failure for the next legitimate rename.
Each file's other test functions are real (state math, crafting chains) and
untouched. Swept the rest of the flagged fake-test files for any other stale
string dependency on what your diff changed — none found. Pushed as a
separate commit on top of yours; CI run #870 in progress as of this entry.

Still owed, tracked as a follow-up and not done as part of unblocking this:
a real integration test for the shipping HUD stack that instantiates the
scene and checks actual node structure, to replace the coverage these hollow
tests pretended to provide.

