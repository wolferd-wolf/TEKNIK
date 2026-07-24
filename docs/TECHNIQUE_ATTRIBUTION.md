# Technique attribution

## Fast voxel traversal

TEKNIK's precise block-selection ray uses the grid-stepping method described by John Amanatides and Andrew Woo in **“A Fast Voxel Traversal Algorithm for Ray Tracing” (1987)**.

The implementation in `src/world/voxel_raycast.gd` was written specifically for TEKNIK and does not copy third-party source code. The paper describes the traversal technique; TEKNIK supplies its own Godot/GDScript implementation, tests, and integration.
