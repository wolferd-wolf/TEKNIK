# Playable World Architecture

## Scope

This milestone owns only the terrain and basic player loop. Advanced engineering physics is deliberately deferred.

## Runtime flow

1. The world calculates the player's chunk coordinate.
2. Missing chunks enter a priority queue.
3. Collision-band chunks are ordered before visual-only chunks.
4. A bounded amount of chunk work is committed each frame.
5. Each chunk becomes one `ArrayMesh`, not one node per block.
6. Only chunks near the player receive concave static collision.
7. Block edits invalidate only their owning chunk and directly adjacent border chunks.
8. Edits are persisted separately from the deterministic base terrain.

## Current implementation boundary

Godot owns presentation, Android input, scene composition and the temporary world implementation. The chunk API is intentionally narrow so generation and meshing can move into the planned C++ native core after the target-device benchmark.

## Optimization doctrine retained from earlier experiments

The old gameplay code is not reused. The successful principles are retained independently:

- packed exposed-face meshes;
- no internal faces;
- no per-block nodes;
- priority streaming;
- collision-first safety ring;
- incremental commit budget;
- bounded render and unload radii;
- local dirty rebuilds;
- physical-device telemetry as the authority.
