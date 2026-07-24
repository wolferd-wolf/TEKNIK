# Technique attribution

## Fast voxel traversal

TEKNIK's precise block-selection ray uses the grid-stepping method described by John Amanatides and Andrew Woo in **“A Fast Voxel Traversal Algorithm for Ray Tracing” (1987)**.

The implementation in `src/world/voxel_raycast.gd` was written specifically for TEKNIK and does not copy third-party source code. The paper describes the traversal technique; TEKNIK supplies its own Godot/GDScript implementation, tests, and integration.

## Editable voxel mining lifecycle

The replacement mining system was informed by the separation used in Zylann's MIT-licensed **godot_voxel** project between authoritative voxel edits, asynchronous chunk remeshing, and the final visible terrain result. TEKNIK does not import or copy godot_voxel source code; it keeps its existing terrain engine and implements its own GDScript state machine around the same safe architectural principle.

TEKNIK's `src/player/mining_controller.gd`, block-hardness timings, mobile input integration, thin selection outline, and procedural crack shader are original project code. The crack pattern is generated mathematically and does not use Minecraft textures or other copyrighted game assets.
