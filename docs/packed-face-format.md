# TEKNIK PackedFace format

This document defines the CPU/GPU contract introduced by Vulkan renderer Milestone 2.

The format is produced by the Rust greedy mesher and consumed by the independent Godot decoder during parity testing. A later Vulkan shader will decode the same words. The current `ArrayMesh` renderer remains the shipping path until the later renderer milestones pass.

## Record size

Each greedy rectangle is represented by two little-endian 32-bit words:

```text
PackedFace = 8 bytes
├── geometry   u32
└── appearance u32
```

There is one record per greedy quad. No vertex positions, normals, colours or indices are stored in this payload.

## Geometry word

```text
Bits  0–5   face-plane X         0–32
Bits  6–11  face-plane Y         0–32
Bits 12–17  face-plane Z         0–32
Bits 18–20  face direction       0–5
Bits 21–28  material ID          1–255
Bits 29–31  flags                currently zero
```

### Face-plane rule

The packed coordinate is the local origin of the rendered greedy rectangle itself.

Six coordinate bits are required even though chunks contain 32 blocks, because valid boundary planes range from 0 through 32. This also represents seam-safe faces owned by a sampled neighbour chunk. For example, an outside neighbour voxel can expose a `+Z` face on the current chunk's local plane `Z=0`; no owning voxel coordinate inside the current chunk can represent that face correctly.

For a face whose normal axis is `a`:

- the coordinate on axis `a` may be 0–32;
- the two tangent-axis origin coordinates remain 0–31;
- width and height extend from that origin along the two tangent axes.

Examples:

- a negative X boundary face stores plane `X=0`;
- a positive X boundary face stores plane `X=32`;
- a neighbour-owned positive Z seam face may store plane `Z=0` directly.

## Appearance word

```text
Bits  0–4   width minus one      stored 0–31, decoded 1–32
Bits  5–9   height minus one     stored 0–31, decoded 1–32
Bits 10–17  corner AO            reserved
Bits 18–25  light/tint           reserved
Bits 26–31  future data          reserved
```

Reserved bits must be written as zero until their semantics are versioned and covered by parity tests.

## Face direction values

```text
0 = -X
1 = +X
2 = -Y
3 = +Y
4 = -Z
5 = +Z
```

For axis `a`, the greedy rectangle dimensions follow the existing mesher axis order:

```text
u = (a + 1) mod 3
v = (a + 2) mod 3
```

The width extends along `u`; height extends along `v`.

## Winding

The decoder emits four logical corners:

```text
0 = origin
1 = origin + u
2 = origin + u + v
3 = origin + v
```

Positive faces use indices:

```text
0, 3, 2, 0, 2, 1
```

Negative faces use indices:

```text
0, 1, 2, 0, 2, 3
```

This preserves the current renderer's normals and front-face winding.

## Colour reconstruction

Milestone 2 does not store per-vertex colours. The independent decoder reproduces the current colour using:

- material ID;
- chunk world origin;
- reconstructed corner position;
- world seed;
- current deterministic face-light and micro-variation functions.

A later shader may replace this with a texture array and compact lighting fields, but that change requires a separately versioned visual-parity gate.

## Direction streams

The Rust result contains:

- exact-order faces, used to prove complete decoded-array parity;
- a second face array grouped into six contiguous direction streams;
- six offsets and six counts describing those streams.

The directional streams are the input contract for later camera-facing culling and indirect drawing.

## Required validation

A change to this format is not accepted unless all of the following remain true:

- packed decode reproduces vertex positions and normals exactly;
- packed decode reproduces index order and winding exactly;
- colours match within the established floating-point tolerance;
- one record exists per greedy quad;
- each record is exactly eight bytes;
- directional ranges are contiguous and cover every face exactly once;
- coordinates, dimensions, directions and materials are in range;
- local planes 0 and 32 reconstruct exactly;
- neighbour-owned seam faces reconstruct exactly;
- natural, river, upland, negative-coordinate, seam and edited chunks pass;
- existing gameplay, traversal, Android and fallback gates remain green.
