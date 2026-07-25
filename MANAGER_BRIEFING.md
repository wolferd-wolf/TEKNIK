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
