# TEKNIK Build Roadmap

## Phase 0 — Clean foundation

- [x] Create isolated rebuild branch.
- [x] Record architecture and quality gates.
- [x] Create a fresh Godot 4.7.1 mobile project.
- [x] Implement deterministic block terrain.
- [x] Implement bounded priority streaming.
- [x] Implement collision-first chunk loading.
- [x] Implement player movement and mobile controls.
- [x] Implement mining, placement and edit persistence.
- [ ] Pass CI parse, smoke test and ARM64 export.
- [ ] Pass target-phone functional test.
- [ ] Pass target-phone stability and 50 FPS gates.

## Phase 1 — World quality

Begins only after Phase 0 passes.

- terrain palette and texture atlas;
- biome transitions;
- rocks and vegetation through batched instances;
- safe procedural spawn selection;
- improved water presentation;
- world save versioning and corruption recovery;
- profiling-led move of generation/meshing into the C++ native core.

## Phase 2 — Survival loop

- inventory and hotbar;
- block drops;
- tools and mining speed;
- crafting foundation;
- health, hunger and environmental exposure.

## Phase 3 — Visible engineering foundation

- connected structure detection;
- kinetic network graph;
- shafts, gears, bearings and belts;
- stress and load feedback;
- original TEKNIK terminology and assets.

## Phase 4 — Physical contraptions

Only after the static engineering loop is stable:

- assembled moving structures;
- Jolt rigid bodies and constraints;
- moving reference-frame player controller;
- vehicles, trains and later aircraft.
