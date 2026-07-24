# TEKNIK — Clean Rebuild

This branch is a fresh implementation of TEKNIK's playable-world foundation. It does not import or copy the previous prototype's gameplay code.

## Current target

Deliver a stable Android survival sandbox foundation before any engineering physics is introduced:

- deterministic procedural block terrain;
- bounded chunk streaming;
- collision-first loading around the player;
- walking, jumping and recovery from falls;
- block mining and placement;
- persistent block edits;
- touch controls and desktop controls;
- frame, queue and chunk telemetry;
- ARM64-only Android export.

## Architecture rule

The world is data-oriented. Blocks are not Godot nodes. Each chunk is one generated mesh, with collision limited to the nearby safety band. Scene-tree changes are budgeted and performed incrementally.

## Branch policy

Physics contraptions, machines, settlements, vegetation and decorative systems are blocked until the playable-world quality gates in `docs/QUALITY_GATES.md` pass on the target Vivo T3x.

## Planning documents

- `docs/ARCHITECTURE.md` — how the current world pipeline works;
- `docs/DECISIONS.md` — binding architecture decisions and exit conditions;
- `docs/QUALITY_GATES.md` — the evidence required before the milestone is accepted;
- `docs/ROADMAP.md` — ordered future development phases;
- `docs/REFERENCE_MOD_MAP.md` — which reference informs each future subsystem.

## Controls

Desktop: WASD, Shift, Space, mouse look, left-click mine, right-click place.

Android: left joystick, drag the right side to look, and use JUMP, MINE and PLACE.

## Truth policy

A successful CI build proves only that the project parses, runs its smoke test and exports. The milestone is accepted only after gameplay and performance are verified on the physical target phone.
