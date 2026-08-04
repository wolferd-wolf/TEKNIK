extends SceneTree

const SpawnPlanner = preload("res://src/world/spawn_planner.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const SEED: int = 73_421
var _failures: int = 0


func _init() -> void:
	var first: Vector3 = SpawnPlanner.find_spawn(SEED, 123456)
	var second: Vector3 = SpawnPlanner.find_spawn(SEED, 123456)
	var different: Vector3 = SpawnPlanner.find_spawn(SEED, 654321)
	_expect(first == second, "spawn planning is deterministic for a saved salt")
	_expect(first != different, "different new worlds are not forced to one hardcoded spawn")
	var world_x: int = floori(first.x)
	var world_z: int = floori(first.z)
	var height: int = TerrainGenerator.surface_height(SEED, world_x, world_z)
	_expect(is_equal_approx(first.y, float(height) + 2.5), "spawn height is derived from generated terrain")
	_expect(height > TerrainGenerator.WATER_LEVEL + 2, "spawn avoids submerged terrain")
	_expect(TerrainGenerator.surface_slope(SEED, world_x, world_z) <= 1, "spawn prefers walkable terrain")
	var coordinate: Vector3i = SpawnPlanner.chunk_coordinate(first, VoxelChunk.SIZE)
	_expect(coordinate.y == 0, "spawn maps into the horizontal chunk stream")
	if _failures == 0:
		print("SPAWN_PLANNER_TEST_RESULT PASS spawn=", first, " chunk=", coordinate)
		quit(0)
	else:
		print("SPAWN_PLANNER_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
