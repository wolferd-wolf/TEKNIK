# Vercidium meshing reference notes

## Purpose

TEKNIK uses the public `vercidium-patreon/meshing` repository and the accompanying optimization video as research references for a new Vulkan-oriented packed voxel renderer.

The upstream repository is a standalone greedy-meshing voxel renderer written in C# with Silk.NET/OpenGL. It is not a runtime dependency of TEKNIK. TEKNIK does not embed Silk.NET, C#, the upstream executable, or the private/full Vercidium engine.

Upstream repository:

- `https://github.com/vercidium-patreon/meshing`
- License: MIT
- Required notice: `third_party/licenses/vercidium-meshing-MIT.txt`

## Public source snapshot used during research

The following upstream file blobs were inspected while defining the TEKNIK renderer plan:

| Upstream file | Observed blob SHA | Relevant concept |
|---|---|---|
| `README.md` | `bd6169ba5554e1dee68880900d384897fbcdac9d` | Scope of the public Part 1 renderer |
| `LICENSE` | `fca565cfc4dd4225f443628f035de00beacdf803` | MIT terms and attribution |
| `Constants.cs` | `3508ef75e9d6458920db512de08669d6db68745b` | 32×32×32 chunk layout and masks |
| `ChunkMeshActual.cs` | `71be8c62a025632a62f3e5622753475e0741abe4` | Column bounds, directional visited data, face merging |
| `VoxelVertex.cs` | `4feaa9b026bbb9b7cfcccfb2a45e499f8c74dfde` | Conventional 36-byte upstream vertex layout |
| `MapRenderer.cs` | `b1efc5c16bd0356af0e756d0f53f8aa025016069` | Per-chunk meshing and draw submission |
| `Client.cs` | `e88e17275ddd27807477287c55c457b9773dd622` | OpenGL render loop used by the public sample |

Blob SHAs are recorded for provenance. A future upstream change must not silently redefine the reference implementation used by TEKNIK.

## Ideas adapted or benchmarked

TEKNIK may implement independently in Rust:

1. Per-column minimum and maximum occupied Y bounds.
2. Direction-specific face visibility and visited state.
3. Greedy rectangle merging across the two axes appropriate for each face direction.
4. Chunk-local coordinates for compact storage.
5. Six independent face-direction ranges per chunk.
6. Packed face records decoded in a GPU shader.
7. Persistent shared GPU buffers rather than one transient mesh allocation per chunk update.
8. Bulk or indirect draw submission for many visible chunk ranges.

These are algorithmic and architectural concepts. TEKNIK's implementation, data format, Rust APIs, C++ bridge, Vulkan shaders, memory allocator, culling, logging, tests, and Android integration remain original project code.

## What is not copied

TEKNIK will not copy or ship:

- the upstream C# project structure;
- Silk.NET or the upstream OpenGL application loop;
- private/full Vercidium engine source;
- Patreon-only code;
- upstream branding, artwork, textures, videos, or binary assets;
- a direct translation that preserves unnecessary engine-specific types or ownership patterns.

The public sample still emits conventional positions, normals, barycentric data, and texture IDs and still performs per-chunk draw submission. TEKNIK's packed-face Vulkan renderer must therefore be designed and implemented independently.

## TEKNIK integration boundary

The planned runtime split is:

```text
Rust core
├── terrain generation
├── voxel/edit application
├── occupancy metadata
├── greedy face extraction
├── PackedFace output
└── collision-profile data

C++ GDExtension
├── Godot RenderingDevice access
├── Vulkan-oriented GPU buffer pages
├── chunk allocation table
├── shader/pipeline creation
├── culling and indirect command preparation
└── guarded fallback to the existing ArrayMesh renderer

GDScript
├── gameplay and controls
├── world-stream coordination
├── persistence and diagnostics
└── validation orchestration
```

No per-block call is allowed across the Rust/C++/Godot boundary. A chunk crosses the boundary as one request and one completed result.

## Validation rule

Reference-inspired code is not accepted merely because it is faster. Each renderer milestone must preserve:

- exact voxel and edit behavior;
- decoded surface coverage, material identity, orientation, winding, and bounds;
- procedural spawn and safe startup window;
- breaking, placement, persistence, and logs;
- the house-building QA sequence;
- the 190-metre normal-physics traversal;
- zero unloaded-world falls;
- Android ARM64 packaging;
- a working fallback to the current ArrayMesh renderer until the packed path is certified on the Vivo T3x.
