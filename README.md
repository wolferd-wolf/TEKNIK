# TEKNIK

TEKNIK is an original, paid, single-player Android engineering sandbox built with Godot. It is inspired by the pleasure of visible mechanical automation, player-built vehicles, and large procedural worlds, while using original code, terminology, visuals, recipes, and assets.

## Product constraints

- Survival sandbox only. There is no player-facing creative mode.
- Procedural voxel world and procedural NPC settlements.
- Distinct kinetic, electrical, thermal, steam, liquid-fuel, nuclear, hydraulic, and pneumatic systems.
- Editable physics contraptions, aircraft, land vehicles, trains, factories, artillery, telemetry, and sandboxed computers.
- Offline single-player premium release.
- Minimum target: sustained 50 FPS on a Vivo T3x with 6 GB RAM. Performance is not considered verified until measured on physical target hardware.

## Current playable foundation

The current Android build provides:

- 32×32×32 voxel chunks;
- procedural and persisted safe player spawning;
- a 5×5 startup safety window and a streamed 7×7 world window;
- three parallel Android chunk workers;
- Rust terrain generation, edit application and greedy meshing;
- one official C++ GDExtension bridge linked with the Rust static library;
- Godot/GDScript gameplay, controls, persistence, collision-node creation and diagnostics;
- predictive streaming and guarded movement at unloaded boundaries;
- persistent block breaking and placement;
- lightweight heightfield terrain collision with primitive collision for placed blocks;
- structured support logs;
- deterministic house-building and 190-metre normal-physics traversal QA; and
- Android ARM64 export through GitHub Actions.

The Android product targets Godot's **Mobile renderer**, using RenderingDevice/Vulkan on supported devices. CI uses OpenGL Compatibility for reliable virtual-runner screenshots and gameplay videos, so physical Vulkan validation remains a separate required gate.

## Active renderer milestone

The next foundation is a Vulkan-oriented packed voxel renderer that reduces terrain geometry bandwidth and draw-submission overhead while preserving the current playable fallback.

The locked implementation order and acceptance gates are documented in:

- [`docs/renderer-milestones.md`](docs/renderer-milestones.md)

The existing Rust-generated `ArrayMesh` path remains available until the packed renderer passes exact decode parity, house-building, traversal, Android packaging and physical Vivo T3x comparison.

## Reference and attribution policy

TEKNIK studies public implementations but does not import unrelated engines or protected assets as runtime dependencies.

The public Vercidium greedy-meshing sample is used as an MIT-licensed research reference for occupancy bounds, directional face processing and greedy merging. Source provenance, adaptation boundaries and excluded material are recorded in:

- [`docs/references/vercidium-meshing-notes.md`](docs/references/vercidium-meshing-notes.md)
- [`third_party/licenses/vercidium-meshing-MIT.txt`](third_party/licenses/vercidium-meshing-MIT.txt)

TEKNIK's Rust packed-face format, C++ RenderingDevice bridge, Vulkan shader pipeline, GPU allocator, culling, diagnostics, gameplay and Android integration are original project implementations.

## Architecture

```text
Godot / GDScript
├── gameplay, player and mobile controls
├── stream coordination
├── saves and support logs
└── scene and physics object ownership
           │
           ▼
C++ GDExtension
├── Godot-native bridge
├── current packed-array translation
└── planned RenderingDevice/Vulkan terrain service
           │
           ▼
Rust core
├── procedural terrain
├── voxel and edit processing
├── greedy meshing
├── planned PackedFace streams
└── parallel worker data
```

Chunk requests and results cross the native boundary in bulk. Per-block calls across GDScript, C++ and Rust are prohibited in performance-sensitive paths.

## Visual targets

The original visual targets used to judge world composition are in [`docs/visual-targets`](docs/visual-targets). They are aspirational art-direction references; automated screenshots and physical gameplay captures are evidence for what the current real-time build actually renders.

## Local validation

With Godot 4.7.1 and the native extension already built:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/run_native_chunk_parity_tests.gd
godot --headless --path . --script res://tests/run_native_worker_integration_tests.gd
```

Rendered QA capture on Linux:

```bash
xvfb-run -a godot --path . --rendering-method gl_compatibility --audio-driver Dummy -- --qa-screenshot=artifacts/bootstrap.png
```

## CI outputs

The `TEKNIK CI` workflow validates and publishes:

- Rust unit tests and exact native/GDScript parity;
- threaded native-worker integration with fallback detection;
- procedural spawn, streaming, edits, collision and diagnostics tests;
- rendered world screenshots;
- house-building gameplay video;
- 190-metre traversal video and support logs;
- the Android ARM64 native shared library; and
- the Android debug APK with the native library verified inside it.

Debug-only QA hooks are excluded from the product design and do not constitute a creative mode.
