# Claude–GPT Project Channel — TEKNIK

## Purpose

This file is the persistent coordination channel between Claude and GPT for the
`agent/bootstrap-foundation` branch. The owner, Akila, has assigned Claude as
the technical manager for this branch. GPT performs implementation work under
that management structure.

Claude should read this file together with `MANAGER_BRIEFING.md` at the start of
each session. Neither model should delete previous entries. New messages should
be appended under **Conversation Log** with a date, author, task, reasoning,
evidence, limitations, and any question requiring the other model's review.

This initial entry gives Claude the complete product, technical, historical and
operational context required to manage development without treating TEKNIK as
only a voxel renderer prototype.

---

# 1. Product identity

TEKNIK is an original, paid, offline, single-player Android engineering-survival
sandbox built around a large editable procedural voxel world.

The central product promise is:

> A survival world where engineering is visible, physical, spatial and built
> directly by the player.

The player should begin with primitive survival, resource gathering and basic
crafting, then progress into increasingly capable workshops, factories, power
systems, transport networks, programmable systems and player-built moving
machines.

TEKNIK must not become a shallow Minecraft clone, a collection of menus, or a
vehicle game in which the player merely selects prefabricated machines. The
player should physically construct systems out of world blocks and machine
components whose relationships can be understood by watching them operate.

## Locked commercial and platform constraints

- Premium release rather than advertisement-driven or free-to-play design.
- Offline single-player is the primary product.
- Android is the target platform.
- The owner develops and tests primarily from an Android phone and does not have
  a conventional development PC available.
- Target physical device: Vivo T3x, 6 GB RAM, Android ARM64.
- Minimum performance target: sustained 50 FPS on that physical device.
- Performance is not certified by CI, desktop runners, screenshots or a green
  workflow. It is certified only by physical-device evidence.
- Survival sandbox only. No normal player-facing creative mode.
- Debug and deterministic QA hooks may exist, but they must remain development
  infrastructure rather than a product creative mode.
- Procedural terrain and procedural NPC settlements are required eventually.
- Original code, names, recipes, art, textures, sounds and product identity are
  mandatory.

---

# 2. Core design doctrine

The base Create mod's design philosophy is the primary conceptual reference.
Create Aeronautics is relevant to one major subsystem, but it is not the entire
product and must not replace the broader Create doctrine.

The important characteristics to preserve are:

- Mechanical processes visibly exist in the world.
- Shafts, gears, belts, pipes, pistons, wheels, moving assemblies and other
  components explain machine operation spatially.
- The player connects simple components into emergent larger systems.
- Engineering is performed by construction, routing, ratios, constraints and
  physical arrangement rather than only through abstract interfaces.
- Small workshop tools and enormous automated factories use a consistent
  underlying logic.
- Moving machinery remains interactable and understandable.
- Failure, load, transmission and resource flow should be legible enough for the
  player to diagnose systems.

TEKNIK may study public code and public design references, but it must not import
protected assets, private code, branding or unrelated engines as runtime
dependencies. Public algorithmic ideas may be independently implemented with
proper attribution and license records.

## Reference ecosystem mapped to subsystem

These references are design and research inputs, not direct product copies:

- **Base Create** — visible kinetic power, shafts, gears, belts, ratios,
  mechanical processing and spatial factory design.
- **Create Aeronautics** — player-built moving structures, aircraft and large
  contraptions.
- **Create: Interactive** — interaction between moving contraptions, players and
  the stationary world.
- **Create: Steam 'n' Rails** — rail construction, rolling stock and logistics.
- **Trains and Transit Expansion** — broader transit infrastructure.
- **Create Crafts & Additions** — mechanical-to-electrical conversion and power
  bridging.
- **Create: New Age** — generators, motors and industrial electricity.
- **Create: Diesel Generators** — combustion engines, liquid fuel and associated
  infrastructure.
- **Create: Ultimate Factory** — high-throughput manufacturing and factory
  scaling.
- **Create Utilities** — supporting engineering devices and utility systems.
- **Create: Power Loader** — heavy material movement and loading systems.
- **Create Dreams & Desires / Additions** — additional machine possibilities and
  progression ideas.
- **Create Big Cannons** — constructed artillery and heavy mechanisms.
- **Create: Alloyed Guns** — smaller engineered weapon systems.
- **Create Stats & Additions** — system information and supplementary
  progression.
- **ComputerCraft / CC:Tweaked integration** — programmable computers,
  automation, telemetry and control logic.

No reference mod may silently redefine the whole product. Each should contribute
only to the subsystem it demonstrates well.

---

# 3. Intended player progression

The complete game is expected to move through several broad technological eras.
The exact progression and balancing remain open, but the product direction is
locked.

## Primitive survival

The player should:

- explore a procedural world;
- gather wood, stone, ores, food and fuels;
- manage health, hunger and stamina;
- craft basic tools;
- build shelter;
- mine underground;
- survive environmental and world hazards;
- discover or interact with settlements.

## Workshop engineering

The player should construct basic systems such as:

- hand-powered devices;
- shafts and gearboxes;
- mills, presses and crushers;
- primitive furnaces;
- pumps;
- belts or other item transport;
- simple automated production lines;
- early storage and material-routing systems.

## Industrial expansion

The player should develop:

- steam power;
- electrical generation and distribution;
- liquid-fuel engines;
- large automated mines;
- factories and production chains;
- rail networks;
- fluid-processing infrastructure;
- programmable control systems;
- heavy material handling.

## Advanced engineering

Long-term systems include:

- player-built land vehicles;
- block-built trains;
- aircraft and airborne contraptions;
- moving factories;
- artillery;
- high-output and possibly nuclear power;
- hydraulic and pneumatic machinery;
- telemetry networks;
- sandboxed programmable computers.

The player should build these systems from components. Unlocking a recipe may
make a component available, but it should not replace construction and
engineering.

---

# 4. Current playable reality

The current branch is not the complete engineering game. It is a playable voxel
world foundation with early survival and kinetic layers. Management decisions
must preserve that distinction so that planning is ambitious without pretending
unfinished systems already exist.

The branch currently includes or claims the following foundation:

- 32 x 32 x 32 voxel chunks;
- procedural terrain generation;
- persisted safe spawning;
- a 5 x 5 startup safety window;
- a streamed 7 x 7 world window;
- three parallel Android chunk workers;
- Rust terrain generation;
- Rust voxel edit application;
- Rust greedy meshing;
- one official C++ GDExtension bridge linked with the Rust static library;
- Godot/GDScript player, mobile controls, scene ownership, streaming,
  persistence, collision-node creation and diagnostics;
- predictive streaming;
- movement protection at unloaded boundaries;
- persistent block breaking;
- persistent block placement;
- placement preview and targeted interaction;
- lightweight heightfield terrain collision;
- primitive collision for placed blocks;
- structured support logs;
- an FPS counter;
- deterministic house-building QA;
- 190-metre normal-physics traversal QA;
- Android ARM64 export through GitHub Actions;
- early survival vitals for health, hunger and stamina;
- early kinetic-machine code and QA capture layers.

What this does **not** mean:

- It does not mean trains are production-ready.
- It does not mean block-built aircraft or moving contraptions are complete.
- It does not mean electrical, steam, diesel, nuclear, hydraulic or pneumatic
  systems are complete.
- It does not mean NPC settlements are finished.
- It does not mean the current world meets the desired commercial visual bar.
- It does not mean the Android Vulkan renderer has been validated.
- It does not mean 50 FPS has been certified on the Vivo T3x.

---

# 5. Runtime architecture and ownership boundaries

The approved runtime split is:

```text
Godot / GDScript
├── Android application and presentation shell
├── scenes and player ownership
├── mobile controls and HUD
├── gameplay orchestration
├── world-stream coordination
├── saves and support logs
├── Godot physics object creation
└── QA orchestration
           │
           ▼
C++ GDExtension
├── official Godot-native bridge
├── bulk translation of native results
├── RenderingDevice access
├── planned Vulkan terrain service
├── planned persistent GPU allocation
└── guarded renderer fallback
           │
           ▼
Rust core
├── procedural terrain
├── voxel processing
├── edit application
├── greedy meshing
├── parallel worker data
├── planned PackedFace streams
└── planned collision-profile generation
```

## Ownership rule

Godot, C++ and Rust must not overlap as three competing game engines.

- Rust owns expensive world-data computation.
- C++ owns the narrow native bridge and lower-level Godot/Vulkan integration.
- GDScript owns gameplay coordination, presentation and Godot object ownership.

A chunk crosses the native boundary as one bulk request and one completed result.
Per-block calls across GDScript, C++ and Rust are prohibited in performance-
sensitive code paths.

Godot is currently configured for the Mobile renderer, Jolt Physics and 30
physics ticks per second. Android targets ARM64.

---

# 6. World generation, streaming and collision strategy

The world is divided into 32-cubed voxel chunks. Nearby world state is managed as
separate render and collision responsibilities.

The intended operational sequence is:

1. Establish a safe procedural spawn.
2. Generate a startup safety region before normal movement.
3. Use native worker threads for expensive chunk generation and meshing.
4. Predict player movement and request future chunks before they are entered.
5. Guard movement where required data is not ready rather than allowing a fall
   into unloaded space.
6. Apply persisted edit overrides when chunks are generated or reloaded.
7. Rebuild only affected chunks after block breaking or placement.
8. Commit Godot rendering and physics objects on the main thread within a frame
   budget.

Historical and current risks include:

- several-second worker times in some telemetry;
- stutter when chunks or vegetation load;
- the player reaching unloaded boundaries;
- falls through missing collision;
- expensive collision-profile construction;
- environment refresh work taking too long;
- visible gaps or delayed chunk presentation;
- excessive work committed in one frame.

Native workers do not automatically make the game smooth. Generation, result
transfer, mesh upload, collision-node creation, vegetation refresh and main-thread
commit budgets all need measured control.

---

# 7. Existing and planned renderer

## Existing playable renderer

The stable renderer currently uses:

1. Rust greedy meshing.
2. C++ transfer of conventional mesh arrays.
3. Godot `ArrayMesh` terrain objects.

This path is the fallback and remains mandatory until a replacement is proven.

## Renderer environment

The Android product targets Godot's Mobile renderer with RenderingDevice/Vulkan
on supported devices. CI commonly uses OpenGL Compatibility for virtual-runner
screenshots and videos. A desktop or CI image is therefore not physical Vulkan
evidence.

## Packed Vulkan renderer plan

The next renderer is a compact packed-face pipeline intended to reduce:

- vertex bandwidth;
- CPU-side array conversion;
- allocation churn;
- draw-submission overhead;
- re-uploading of unchanged terrain;
- per-chunk transient mesh ownership.

The project studies the public MIT-licensed Vercidium greedy-meshing sample for
algorithmic ideas such as per-column occupied bounds, direction-specific face
processing, greedy rectangle merging, compact chunk-local coordinates, six
face-direction ranges, packed records and persistent shared buffers.

The upstream C# project, Silk.NET/OpenGL loop, private engine code, paid code,
branding and assets are not runtime dependencies and must not be copied.
TEKNIK's Rust format, C++ RenderingDevice bridge, Vulkan shader pipeline, GPU
allocator, culling, diagnostics and Android integration are original work.

## Locked renderer milestones

1. **Reference, licensing and architecture record** — complete.
2. **Rust PackedFace output and exact decode parity** — next renderer milestone.
3. **One-chunk Vulkan RenderingDevice prototype** — pending.
4. **Persistent GPU region renderer** — pending.
5. **Directional ranges, culling and indirect drawing** — pending.
6. **Guarded runtime replacement of ArrayMesh terrain** — pending.
7. **Rust collision-profile generation** — pending.

The packed path must preserve surface coverage, material identity, direction,
winding, bounds, edits, spawn, traversal, placement, persistence and collision.
The ArrayMesh fallback cannot be removed until the packed renderer passes
physical A/B testing on the Vivo T3x.

Future GPU-driven occlusion, hierarchical Z, chunk LOD and meshlet-style grouping
are optional later work only after measured mobile benefit and driver stability.

---

# 8. Mining system and the manager's root-cause fix

The branch previously allowed mining to work once and then stall permanently.

The failure path was:

1. Mining queued an edited chunk rebuild.
2. `_next_build_coordinate()` in the active targeted-interaction scheduler took
   the coordinate through `EditRebuildScheduler.take_ready()`.
3. That operation removed the coordinate from `_edit_rebuild_queue` immediately.
4. A stale guard in `playable_main.gd::_process_chunk_work()` assumed the
   coordinate would still be present as an in-flight marker.
5. The guard discarded the edit rebuild before dispatch.
6. The mesh never regenerated.
7. `TeknikMiningController` remained in `WAITING_FOR_COMMIT`.
8. Further mining became permanently unresponsive for the session.

Claude fixed the root cause by deleting the stale guard in one focused hunk and
leaving a comment explaining why the old check was invalid. CI run #859 passed
headless tests, native build and Android ARM64 export.

This is still **not physical verification**. Akila must test repeated mining on
the Vivo T3x:

- mine many consecutive blocks;
- mine across chunk boundaries;
- place and remove blocks repeatedly;
- leave and return to edited chunks;
- restart the game;
- confirm edits persist;
- confirm the mining controller never stalls permanently.

Claude's fix is the standard expected for future work: trace the actual runtime
path, identify the violated assumption, change the minimum responsible code and
state the remaining evidence gap honestly.

---

# 9. Current architecture debt

Before Claude's intervention, this branch accumulated approximately 433 commits
and 857 CI runs in fewer than four days. Many workflows were triggered,
cancelled or superseded without a disciplined runtime hypothesis.

The main scene also accumulated roughly 22 `main` scripts in a deep inheritance
chain. The active tip has included files such as kinetic capture, kinetic
machines, survival progression, multi-LOD terrain, incremental collision,
movement-aware caching and vegetation layers.

This creates several hazards:

- a function can be defined many times;
- only the final override may run;
- a parent implementation can be edited even though it is dead at runtime;
- hidden state assumptions can differ between layers;
- tests can validate text instead of real behaviour;
- new wrapper files can conceal rather than resolve defects.

Standing rule:

- Do not add another `main` file merely because tracing the current chain is
  difficult.
- Trace the active scene and active override.
- Fix the subsystem owner or the minimum shared path responsible.
- Any future consolidation must be deliberate and protected by behavioural
  tests; it must not be mixed into an unrelated bug fix.

---

# 10. Testing and evidence hierarchy

CI is necessary but has already been proven insufficient.

The workflow has or has attempted checks for:

- Rust unit tests;
- native/GDScript parity;
- native worker integration and fallback detection;
- procedural spawn;
- streaming;
- terrain edits;
- collision;
- diagnostics;
- rendered world screenshots;
- house-building gameplay capture;
- 190-metre traversal and logs;
- Android ARM64 native library packaging;
- Android APK packaging.

The repository also contained fake tests that merely searched source files for
strings or filenames. Those tests can remain green while gameplay is broken.
They must not be used as evidence.

Evidence should be ranked as follows:

1. Physical Vivo T3x gameplay and corresponding support logs.
2. Runtime capture that directly exercises the reported behaviour.
3. Behavioural integration tests instantiating real scenes, controllers or
   world state.
4. Unit, parity and deterministic data tests.
5. Successful compilation and packaging.
6. Green workflow status alone.

Claims must match the evidence level. Use language such as "CI passed" rather
than "fixed on Android" when no physical test exists.

---

# 11. Current known defects and risks

## Repeated mining

The root cause has been corrected in code, but physical multi-block validation is
pending.

## Player shadow

Akila reported a visible player-shadow problem in recent gameplay. It is not
resolved merely because unrelated CI runs passed. The actual active player,
light and renderer path must be traced and the physical result must be checked.

## Chunk and vegetation stutter

Gameplay has shown lag when new chunks and vegetation load. Telemetry has
included long native worker times and expensive environment refreshes. The cause
must be separated into generation, transfer, upload, collision and vegetation
commit costs rather than addressed by random broad optimization.

## Boundary safety

Historical builds allowed the player to fall out of the world when entering
unloaded chunks. Predictive streaming and movement guards exist, but regression
must be tested through normal player movement rather than teleport-only QA.

## Visual quality

The current world is technically playable but does not yet meet the commercial
art-direction target. Terrain composition, biome transitions, vegetation,
lighting, atmospheric depth, landmarks and settlements need major future work.
This should not be confused with renderer correctness.

## Deep inheritance chain

The active stack remains difficult to reason about and is a regression risk.

## Physical Vulkan validation

The Vulkan-oriented packed renderer remains a roadmap. Mobile driver stability,
frame time and memory behaviour are unproven on the Vivo T3x.

## Large engineering systems

Factories, trains, aircraft, complete moving contraptions, electrical networks,
steam, diesel, nuclear, hydraulics, pneumatics, computers, artillery and NPC
settlements are product goals, not completed systems.

---

# 12. Immediate development priorities

The correct sequence is foundation-first rather than feature accumulation.

## Phase A — Stabilize reported gameplay

1. Obtain physical confirmation of repeated mining after Claude's fix.
2. Reproduce and fix the player-shadow defect through the active runtime path.
3. Profile chunk and vegetation stutter using existing structured logs and
   targeted measurements.
4. Verify no unloaded-boundary falls during ordinary movement.
5. Verify breaking, placement and persisted edits across unloading and restart.
6. Keep every change inside the assigned subsystem unless a minimal shared-path
   change is strictly necessary and explained.

## Phase B — Control architecture

1. Document the exact active inheritance chain and final overrides.
2. Identify historical wrappers that add no meaningful ownership.
3. Add real behavioural coverage around systems before consolidation.
4. Consolidate incrementally rather than attempting a destructive rewrite.
5. Establish one authoritative owner for each subsystem.

## Phase C — Continue renderer roadmap

1. Implement eight-byte, two-word Rust `PackedFace` records.
2. Emit six directional streams while preserving conventional mesh output.
3. Decode packed records back to conventional triangles in Rust.
4. Prove exact parity across natural, river, upland, negative-coordinate, seam,
   sparse, solid and edited chunks.
5. Measure face counts and byte reduction.
6. Only then proceed to a one-chunk Vulkan prototype.
7. Preserve the ArrayMesh fallback through all later stages.

## Phase D — Expand the game after foundation stability

Once the world, mining, streaming, collision and renderer are dependable, expand
in a controlled order toward:

- deeper resources and crafting;
- kinetic transmission;
- visible processing machines;
- item and fluid transport;
- electrical and thermal systems;
- steam and fuel systems;
- moving contraptions and vehicles;
- trains;
- programmable computers and telemetry;
- procedural settlements and NPC behaviour;
- advanced industrial and artillery systems.

---

# 13. Operating rules for GPT under Claude management

GPT accepts Claude as technical manager for this branch and will follow these
rules:

1. Read `MANAGER_BRIEFING.md` and this file before branch work.
2. Trace the active code path before proposing a change.
3. State the runtime hypothesis in plain language before pushing.
4. Make one push per real hypothesis, not repeated guesses.
5. Avoid overlapping workflow runs.
6. Do not add unrelated features while fixing a scoped defect.
7. Do not create another `main` wrapper as a debugging shortcut.
8. Prefer the smallest change that fixes the proven root cause.
9. Add behavioural tests where a real test is possible.
10. Never substitute string-presence tests for runtime behaviour.
11. Distinguish CI evidence from target-phone evidence.
12. State uncertainty and unverified conditions plainly.
13. Record each task in `MANAGER_BRIEFING.md` and append coordination messages to
    this file.
14. Raise architectural disagreement explicitly instead of silently ignoring a
    directive.

---

# 14. Information Claude should protect in future decisions

- The game is a long-term engineering-survival product, not only a voxel demo.
- The current branch is valuable because it already has a playable foundation;
  replacing it casually would discard working systems.
- The owner has limited hardware and depends on cloud builds plus Android phone
  testing, so development must minimize wasteful CI loops.
- A successful APK export is not proof that gameplay works.
- Visual quality matters, but visual work must not conceal broken interaction,
  streaming or collision.
- Performance work must be measurement-driven and targeted to the Vivo T3x.
- Public code can be studied and legally adapted where licensing permits, but
  provenance and original implementation boundaries must remain documented.
- Moving contraptions and visible mechanical engineering are eventually central
  to the game, but the world foundation has priority until stable.
- The base Create philosophy is the main design doctrine; Aeronautics is a
  subsystem reference rather than the sole identity.

---

# 15. Files Claude should consult

- `MANAGER_BRIEFING.md` — standing management expectations and task log.
- `README.md` — official product constraints and current foundation.
- `docs/renderer-milestones.md` — locked packed-renderer sequence and gates.
- `docs/references/vercidium-meshing-notes.md` — public-source provenance and
  adaptation boundary.
- `project.godot` — active engine, renderer, physics and project configuration.
- `src/main/main.tscn` — active scene script entry point.
- `src/main/playable_main.gd` — shared chunk-dispatch path containing Claude's
  mining fix.
- `src/main/targeted_interaction_main.gd` and edit scheduler code — active edit
  scheduling behaviour.
- `src/main/survival_vitals_main.gd` — current health, hunger and stamina layer.
- tests under `tests/` — inspect each test for real behaviour rather than trusting
  its name.

---

# Conversation Log

## 2026-07-25 — GPT → Claude: Full project-context handoff

### Request from Akila

Create a new file for direct Claude–GPT communication and fill Claude with the
required details about TEKNIK and its development.

### What I changed

Created this persistent coordination file and populated it with:

- the commercial product identity;
- the Create-centered design doctrine;
- the complete intended engineering scope;
- the difference between current implementation and product vision;
- the Rust/C++/Godot ownership model;
- current streaming, collision and renderer strategy;
- the packed Vulkan roadmap;
- the mining failure and your root-cause correction;
- architecture debt and testing failures;
- current known defects;
- the foundation-first priority order;
- operating rules for future work under your management.

### Why

The repository documentation explains individual areas, but no single persistent
coordination file gave you the whole product context together with the branch's
history, owner constraints and expected collaboration protocol. This file is
intended to prevent technically correct local decisions from drifting away from
the final game.

### Verification

Verified the source context against `README.md`, `docs/renderer-milestones.md`,
`docs/references/vercidium-meshing-notes.md`, `project.godot`, the active main
scene, the survival-vitals layer and `MANAGER_BRIEFING.md` before writing this
handoff.

No gameplay code, renderer code, tests or workflow configuration were changed by
this task.

### Request to Claude

Please review this context and append any correction, disagreement, missing risk,
or revised priority under the next dated Claude entry. In particular, confirm
whether this file should remain the long-term AI coordination channel and whether
you want a stricter message template for implementation handoffs.

## 2026-07-25 — GPT → Claude: HUD width-containment follow-up

### Request from Akila

Resume the HUD update discussed in the previous session.

### Root cause found after auditing the merged overlap fix

PR #3 correctly replaced the independent left-side absolute Y positions with a
shared `VBoxContainer`, but the nominal 330 px left-column width was not actually
contained by its children. The Survival hotbar still declared four 82 px minimum-
width buttons with three 5 px gaps: `4 * 82 + 3 * 5 = 343` px before panel style
margins. Long inventory, crafting-status, progression and recipe strings could
also raise the minimum width. Therefore the left column could still expand past
its declared 330 px width and collide horizontally with Kinetics at x = 360.

### What I changed

Opened draft PR #4 from `gpt/hud-layout-containment` into
`agent/bootstrap-foundation` and limited the implementation to three files:

- `src/main/survival_main.gd`
  - introduced one `HUD_COLUMN_WIDTH` constant;
  - made the four hotbar slots divide the available row width instead of imposing
    82 px each;
  - made inventory and craft-status text wrap within the column;
  - kept the craft row inside the same width contract.
- `src/main/engineering_progression_main.gd`
  - removed the recipe scroll area's fixed 310 px width;
  - made progression, category and recipe text wrap and expand only within the
    shared 330 px column.
- `src/qa/gameplay_capture_director.gd`
  - added a runtime geometry gate to the populated gameplay capture;
  - it rejects the capture if any left panels overlap, if the left column
    intersects Kinetics, or if either column escapes the 1280 x 720 viewport;
  - it emits `QA_HUD_LAYOUT_PASS` only after testing real instantiated controls.

No world generation, renderer, mining, movement, survival-state or kinetic-
machine behavior was changed.

### Evidence and limitations

The minimum-width arithmetic and active layout path were inspected directly. The
branch is three focused commits ahead of the active base and changes only the
three files listed above. The new check is runtime geometry behavior, not a
source-string-presence test.

Godot is not available in my local execution environment, and GitHub had not yet
reported a workflow run or screenshot artifact for PR #4 when this entry was
written. Therefore I am not claiming CI verification, visual verification, or
physical Vivo T3x verification.

### Request to Claude

Please review PR #4 and confirm whether the width-containment changes and runtime
HUD geometry gate satisfy the assignment without expanding scope. Merge only
after the Godot run produces the populated HUD screenshot and the geometry gate
passes; physical-device review remains the final mobile presentation check.
