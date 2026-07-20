# TEKNIK

TEKNIK is an original, paid, single-player Android engineering sandbox built with Godot. It is inspired by the pleasure of visible mechanical automation, player-built vehicles, and large procedural worlds, while using original code, terminology, visuals, recipes, and assets.

## Product constraints

- Survival sandbox only. There is no player-facing creative mode.
- Procedural voxel world and procedural NPC settlements.
- Distinct kinetic, electrical, thermal, steam, liquid-fuel, nuclear, hydraulic, and pneumatic systems.
- Editable physics contraptions, aircraft, land vehicles, trains, factories, artillery, telemetry, and sandboxed computers.
- Offline single-player premium release.
- Minimum target: sustained 50 FPS on a Vivo T3x with 6 GB RAM. Performance is not considered verified until measured on physical target hardware.

## Current milestone

The active milestone is the procedural world foundation. Other gameplay systems remain secondary until the world presentation is coherent, navigable, and visually convincing. The runnable scene currently targets:

- a Godot Mobile-renderer project;
- a deterministic seven-by-seven preview of 32×32×32 voxel chunks;
- broad seeded landforms, a continuous river valley, shore material transitions, and restrained instanced forest placement;
- mobile-budgeted MultiMesh ground detail, boulders, and a low-poly cloud layer;
- deterministic nearest-first chunk scheduling and unload planning;
- temporary chunk-edge sample caching to avoid redundant procedural-noise work;
- greedy chunk meshes that collapse a solid chunk to six quads;
- a texture-free original material palette, procedural sky, water, directional shadows, and distance fog;
- an automated rendered screenshot path; and
- headless tests plus an Android debug export in GitHub Actions.

The three original visual targets used to judge this work are in [`docs/visual-targets`](docs/visual-targets). They are aspirational art-direction references; the automated screenshot is the evidence for what the current real-time build actually renders.

## Local validation

With Godot 4.7.1 available as `godot`:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
```

Rendered QA capture on Linux:

```bash
xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy -- --qa-screenshot=artifacts/bootstrap.png
```

## CI outputs

The `TEKNIK CI` workflow uploads:

- the Android debug APK;
- the deterministic bootstrap screenshot; and
- test/build logs exposed by GitHub Actions.

Debug-only QA hooks are excluded from the product design and do not constitute a creative mode.
