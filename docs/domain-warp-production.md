# Production terrain domain warp

The production terrain generator now applies the same deterministic coordinate warp in both GDScript and Rust before sampling continental, rolling, detail, ridge, basin, and escarpment fields.

The river centre and river-distance calculations intentionally remain in unwarped world coordinates. This preserves continuous river flow and stable riverbank placement while the surrounding uplands gain less repetitive large-scale shapes.

Validation requirements:

- Rust and GDScript voxel output must remain byte-identical across positive and negative chunk coordinates.
- Adjacent terrain columns must remain locally continuous.
- The procedural spawn must remain dry and walkable.
- Native generation and Android export must pass through the single TEKNIK CI workflow.
