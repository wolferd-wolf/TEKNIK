# Quality Gates

The playable-world milestone is not complete merely because CI succeeds.

## Gate 1 — Build integrity

- Godot 4.7.1 parses the project without errors.
- The automated world smoke test loads and commits procedural terrain.
- The ARM64 Android APK exports successfully.

## Gate 2 — Functional world

On the target phone:

- the player spawns on valid collision;
- walking across chunk boundaries never drops the player through terrain;
- mining removes the intended block;
- placement adds the intended block and cannot place inside the player;
- edits remain after closing and reopening the game;
- touch movement, looking and buttons remain responsive.

## Gate 3 — Stability

- 20 minutes of continuous movement without crash or unrecoverable fall;
- no visible full-frame freeze during ordinary streaming;
- memory does not grow continuously while travelling back and forth;
- unloaded chunks are actually removed.

## Gate 4 — Target performance

- sustained gameplay target: at least 50 FPS on the Vivo T3x;
- normal chunk build commits should remain below the displayed frame budget;
- collision generation must not cause repeated severe frame spikes;
- measurements from the physical phone override desktop and CI assumptions.

## Failure policy

A failed gate is treated as an engineering defect, not hidden by adding features. The current milestone remains open until the defect is corrected and re-tested.
