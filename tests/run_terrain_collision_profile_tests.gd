extends SceneTree

const CollisionProfile = preload("res://src/world/terrain_collision_profile.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const WorldEditStore = preload("res://src/world/world_edit_store.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const SEED: int = 73_421
var _failures: int = 0


func _init() -> void:
	_test_base_heightfield()
	_test_removed_surface_lowers_heightfield()
	_test_placed_blocks_use_merged_primitive_runs()
	if _failures == 0:
		print("TERRAIN_COLLISION_PROFILE_TEST_RESULT PASS")
		quit(0)
	else:
		print("TERRAIN_COLLISION_PROFILE_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_base_heightfield() -> void:
	var coordinate := Vector3i.ZERO
	var profile: Dictionary = CollisionProfile.build(SEED, coordinate, {})
	var data: PackedFloat32Array = profile.get("height_data", PackedFloat32Array())
	_expect(data.size() == CollisionProfile.GRID_SIZE * CollisionProfile.GRID_SIZE, "heightfield uses a 33 by 33 border grid")
	var x: int = 6
	var z: int = 9
	var expected: float = float(TerrainGenerator.surface_height(SEED, x, z) + 1)
	_expect(is_equal_approx(data[z * CollisionProfile.GRID_SIZE + x], expected), "base heightfield matches generated block tops")
	var body: StaticBody3D = CollisionProfile.create_body(profile, "TestTerrain")
	_expect(body != null and body.get_child_count() == 1, "base terrain creates one heightfield shape")


func _test_removed_surface_lowers_heightfield() -> void:
	var store: TeknikWorldEditStore = WorldEditStore.new()
	var x: int = 8
	var z: int = 11
	var top: int = TerrainGenerator.surface_height(SEED, x, z)
	store.set_override(Vector3i(x, top, z), VoxelChunk.AIR)
	var profile: Dictionary = CollisionProfile.build(SEED, Vector3i.ZERO, store.snapshot_neighborhood(Vector3i.ZERO))
	var data: PackedFloat32Array = profile.get("height_data", PackedFloat32Array())
	_expect(is_equal_approx(data[z * CollisionProfile.GRID_SIZE + x], float(top)), "breaking the top block lowers collision by one block")


func _test_placed_blocks_use_merged_primitive_runs() -> void:
	var store: TeknikWorldEditStore = WorldEditStore.new()
	var x: int = 12
	var z: int = 7
	var top: int = TerrainGenerator.surface_height(SEED, x, z)
	store.set_override(Vector3i(x, top + 1, z), TerrainGenerator.STONE)
	store.set_override(Vector3i(x, top + 2, z), TerrainGenerator.STONE)
	var profile: Dictionary = CollisionProfile.build(SEED, Vector3i.ZERO, store.snapshot_neighborhood(Vector3i.ZERO))
	var data: PackedFloat32Array = profile.get("height_data", PackedFloat32Array())
	_expect(is_equal_approx(data[z * CollisionProfile.GRID_SIZE + x], float(top + 1)), "placed blocks do not turn the terrain heightfield into a solid roof")
	var runs: Array = profile.get("box_runs", [])
	_expect(runs.size() == 1, "contiguous placed blocks merge into one primitive collision run")
	if runs.size() == 1:
		var run: Dictionary = runs[0]
		var size: Vector3 = run.get("size", Vector3.ZERO)
		_expect(is_equal_approx(size.y, 2.0), "merged primitive run preserves placed stack height")
	var body: StaticBody3D = CollisionProfile.create_body(profile, "TestPlaced")
	_expect(body != null and body.get_child_count() == 2, "placed stack adds one box beside the heightfield")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
