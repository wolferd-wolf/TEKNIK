extends SceneTree

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")

var _failures: int = 0


func _init() -> void:
	_test_surface_profiles()
	_test_surface_color_language()
	if _failures == 0:
		print("SURFACE_LANGUAGE_TEST_RESULT PASS")
		quit(0)
	else:
		print("SURFACE_LANGUAGE_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_surface_profiles() -> void:
	var first: Vector3 = TerrainGenerator.terrain_surface_profile(99, -48, 16)
	var second: Vector3 = TerrainGenerator.terrain_surface_profile(99, -48, 16)
	_expect(first == second, "surface language remains deterministic")
	_expect(
		first.x >= 0.0 and first.x <= 1.0
		and first.y >= 0.0 and first.y <= 1.0
		and first.z >= 0.0 and first.z <= 1.0,
		"surface masks remain normalized"
	)
	var near_wet: float = 0.0
	var far_wet: float = 0.0
	for world_x: int in range(-96, 97, 24):
		var river_z: int = roundi(TerrainGenerator.river_center_z(99, world_x))
		near_wet += TerrainGenerator.terrain_surface_profile(99, world_x, river_z + 7).y
		far_wet += TerrainGenerator.terrain_surface_profile(99, world_x, river_z + 48).y
	_expect(near_wet > far_wet, "river margins are wetter than distant uplands")


func _test_surface_color_language() -> void:
	var sample_height: int = TerrainGenerator.surface_height(99, 24, 40)
	var color_a: Color = TerrainGenerator.surface_color(
		99, TerrainGenerator.GRASS, Vector3i(24, sample_height, 40)
	)
	var color_b: Color = TerrainGenerator.surface_color(
		99, TerrainGenerator.GRASS, Vector3i(31, sample_height, 40)
	)
	_expect(color_a != color_b, "nearby terrain receives subtle world-space color variation")
	var stone_low: Color = TerrainGenerator.surface_color(
		99, TerrainGenerator.STONE, Vector3i(64, 15, -24)
	)
	var stone_high: Color = TerrainGenerator.surface_color(
		99, TerrainGenerator.STONE, Vector3i(64, 19, -24)
	)
	_expect(stone_low != stone_high, "rock faces expose vertical strata variation")
	var river_z: int = roundi(TerrainGenerator.river_center_z(99, -36))
	var near_sand: Color = TerrainGenerator.surface_color(
		99, TerrainGenerator.SAND, Vector3i(-36, TerrainGenerator.WATER_LEVEL + 1, river_z + 7)
	)
	var far_sand: Color = TerrainGenerator.surface_color(
		99, TerrainGenerator.SAND, Vector3i(-36, TerrainGenerator.WATER_LEVEL + 1, river_z + 15)
	)
	_expect(near_sand != far_sand, "shore sand darkens toward wet margins")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		_failures += 1
		push_error("FAIL %s" % message)
