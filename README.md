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

The repository is at the technical-bootstrap stage. The first runnable scene proves:

- a Godot Mobile-renderer project;
- deterministic seeded data generation;
- a batched `MultiMesh` terrain preview;
- a data-oriented kinetic stress calculation;
- an automated rendered screenshot path; and
- headless tests plus an Android debug export in GitHub Actions.

The mechanical display in the bootstrap scene is a QA fixture, not final art or final gameplay.

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

