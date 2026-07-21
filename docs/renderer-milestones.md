# TEKNIK Vulkan packed-renderer milestones

Target runtime: Godot 4.7.1 Mobile renderer on Android ARM64, using RenderingDevice/Vulkan.

The existing Rust-generated `ArrayMesh` path remains the shipping fallback until the packed renderer passes every gameplay, traversal, Android, and physical-device gate.

## Milestone 1 — Reference, licensing and architecture record

**Status: complete**

Deliverables:

- Preserve the Vercidium MIT notice under `third_party/licenses/`.
- Record the exact public source files and blobs inspected.
- Distinguish reusable algorithmic ideas from original TEKNIK implementation.
- State what is explicitly not copied or included.
- Lock the Rust/C++/GDScript ownership boundaries.
- Lock validation and fallback requirements.

Evidence:

- `third_party/licenses/vercidium-meshing-MIT.txt`
- `docs/references/vercidium-meshing-notes.md`
- this milestone document

## Milestone 2 — Rust PackedFace output and exact decode parity

**Status: next**

Deliverables:

- Add an eight-byte, two-word `PackedFace` record.
- Emit six directional face streams from the Rust mesher.
- Retain the current conventional mesh output during migration.
- Add a Rust decoder that reconstructs conventional triangles.
- Compare packed-decoded output against the current native mesh for natural, river, upland, negative-coordinate, seam, sparse, solid and edited chunks.
- Record face counts and byte-size reduction.

Gate:

- Surface coverage, material, direction, winding and bounds must match.
- Existing native/GDScript parity must remain green.

## Milestone 3 — One-chunk Vulkan RenderingDevice prototype

**Status: pending**

Deliverables:

- Add a C++ `TeknikTerrainRenderer` service.
- Create a static six-vertex base quad.
- Upload one packed-face buffer and one chunk-origin record.
- Decode face records in a Vulkan-compatible shader.
- Render one chunk beside the existing ArrayMesh reference.
- Add renderer/API diagnostics that explicitly record Mobile/Vulkan or fallback mode.

Gate:

- Pixel and geometry comparison against the current chunk renderer.
- No gameplay runtime switch yet.

## Milestone 4 — Persistent region renderer

**Status: pending**

Deliverables:

- Allocate persistent GPU face-buffer pages.
- Add a chunk allocation table with capacity and relocation rules.
- Group terrain into 8×8 chunk rendering regions.
- Update only the changed chunk's buffer range after edits.
- Keep CPU copies only where required for recovery or debugging.

Gate:

- Streaming, breaking, placement and persistence work without rebuilding unrelated GPU data.
- No leaked RenderingDevice resources across repeated traversal/reload tests.

## Milestone 5 — Directional ranges, culling and indirect drawing

**Status: pending**

Deliverables:

- Store six face-direction ranges per chunk.
- CPU frustum-cull chunks.
- Remove direction groups that cannot face the camera.
- Build an indirect command buffer for visible ranges.
- Submit visible ranges in bulk through RenderingDevice.
- Record draw commands, visible faces, uploaded bytes, CPU submission time and GPU frame time.

Gate:

- No missing faces from all camera quadrants, heights and negative coordinates.
- Compatibility fallback remains available.

## Milestone 6 — Guarded terrain-renderer replacement

**Status: pending**

Deliverables:

- Make the packed Vulkan renderer the preferred terrain path on supported devices.
- Automatically retain or activate ArrayMesh fallback on initialization, shader, buffer or device failure.
- Remove duplicate terrain drawing while keeping collision and gameplay nodes intact.
- Add renderer selection and failure reasons to support logs.

Gate:

- Exact terrain/edit behavior.
- House-building test.
- 190-metre traversal.
- No seam gaps, terrain waits or fall recovery.
- Android ARM64 native library and shader resources packaged.
- Physical Vivo T3x A/B comparison before declaring the fallback removable.

## Milestone 7 — Rust collision-profile generation

**Status: pending**

Deliverables:

- Move heightfield and placed-block primitive-run generation into Rust.
- Return collision data in the same completed chunk result as rendering data.
- Remove the remaining GDScript worker-side collision-profile cost.
- Preserve main-thread Godot physics object creation.

Gate:

- Collision parity for natural terrain, removed surface blocks and placed stacks.
- No regression in traversal, jumping, breaking or placement.

## Optional later work — GPU-driven visibility

This is deliberately outside the initial seven milestones.

Potential additions after physical-device evidence:

- compute-shader frustum/occlusion culling;
- GPU-generated indirect commands;
- hierarchical Z or conservative software occlusion;
- chunk/section LOD;
- meshlet-style face grouping.

These are not accepted merely because desktop Vulkan supports them. Mobile driver stability and measured Vivo T3x benefit are required.
