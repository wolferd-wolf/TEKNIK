extends SceneTree

const Ecology = preload("res://src/world/procedural_ecology.gd")
const Terrain = preload("res://src/world/voxel_terrain_generator.gd")
const SpawnPlanner = preload("res://src/world/spawn_planner.gd")


var _failures: int = 0


func _init() -> void:
	_test_candidate_determinism()
	_test_blue_noise_spacing()
	_test_ecological_fields()
	_test_seed_diversity_and_terrain_continuity()
	_test_river_continuity()
	_test_spawn_suitability()
	if _failures == 0:
		print("PROCEDURAL_ECOLOGY_TEST_RESULT PASS")
		quit(0)
	else:
		print("PROCEDURAL_ECOLOGY_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_candidate_determinism() -> void:
	var first: Vector2 = Ecology.candidate_position(73_421, -7, 11, Ecology.TREE_CELL_SIZE)
	var second: Vector2 = Ecology.candidate_position(73_421, -7, 11, Ecology.TREE_CELL_SIZE)
	_expect(first == second, "surface scatter candidates are deterministic")
	_expect(
		Ecology.blue_noise_accept(
			73_421,
			-7,
			11,
			Ecology.TREE_CELL_SIZE,
			Ecology.TREE_MIN_DISTANCE
		)
		== Ecology.blue_noise_accept(
			73_421,
			-7,
			11,
			Ecology.TREE_CELL_SIZE,
			Ecology.TREE_MIN_DISTANCE
		),
		"blue-noise acceptance is deterministic"
	)


func _test_blue_noise_spacing() -> void:
	var accepted: Array[Vector2] = []
	for cell_z: int in range(-12, 13):
		for cell_x: int in range(-12, 13):
			if Ecology.blue_noise_accept(
				91_777,
				cell_x,
				cell_z,
				Ecology.TREE_CELL_SIZE,
				Ecology.TREE_MIN_DISTANCE
			):
				accepted.append(Ecology.candidate_position(
					91_777,
					cell_x,
					cell_z,
					Ecology.TREE_CELL_SIZE
				))
	var minimum_seen: float = INF
	for first_index: int in range(accepted.size()):
		for second_index: int in range(first_index + 1, accepted.size()):
			minimum_seen = minf(
				minimum_seen,
				accepted[first_index].distance_to(accepted[second_index])
			)
	_expect(accepted.size() > 40, "blue-noise scatter keeps useful surface density")
	_expect(
		minimum_seen + 0.0001 >= Ecology.TREE_MIN_DISTANCE,
		"accepted tree candidates preserve minimum spacing"
	)


func _test_ecological_fields() -> void:
	var minimum_patch: float = 1.0
	var maximum_patch: float = 0.0
	var minimum_cover: float = 1.0
	var maximum_cover: float = 0.0
	var fields_normalized: bool = true
	for world_z: int in range(-320, 321, 32):
		for world_x: int in range(-320, 321, 32):
			var patch: float = Ecology.forest_patch(73_421, world_x, world_z)
			minimum_patch = minf(minimum_patch, patch)
			maximum_patch = maxf(maximum_patch, patch)
			var cover: float = Ecology.ground_cover_density(
				73_421,
				world_x,
				world_z,
				0.62,
				0.57,
				0.28,
				patch * 0.72
			)
			minimum_cover = minf(minimum_cover, cover)
			maximum_cover = maxf(maximum_cover, cover)
			fields_normalized = fields_normalized and (
				patch >= 0.0 and patch <= 1.0
				and cover >= 0.0 and cover <= 1.0
			)
	_expect(fields_normalized, "ecological fields remain normalized")
	_expect(
		maximum_patch - minimum_patch > 0.28,
		"domain-warped forest field creates large clearings and dense patches"
	)
	_expect(
		maximum_cover - minimum_cover > 0.16,
		"understory field varies across the world"
	)
	var conifer: float = Ecology.conifer_probability(
		73_421, -112, 208, 0.42, 0.28, 0.78
	)
	_expect(
		conifer >= 0.06 and conifer <= 0.78,
		"species probability stays inside ecological bounds"
	)


func _test_seed_diversity_and_terrain_continuity() -> void:
	var changed_samples: int = 0
	var maximum_neighbor_step: int = 0
	for world_z: int in range(-192, 193, 16):
		for world_x: int in range(-192, 193, 16):
			var first_height: int = Terrain.surface_height(73_421, world_x, world_z)
			var second_height: int = Terrain.surface_height(91_777, world_x, world_z)
			if first_height != second_height:
				changed_samples += 1
			var east_step: int = absi(first_height - Terrain.surface_height(73_421, world_x + 1, world_z))
			var south_step: int = absi(first_height - Terrain.surface_height(73_421, world_x, world_z + 1))
			maximum_neighbor_step = maxi(maximum_neighbor_step, maxi(east_step, south_step))
	_expect(changed_samples > 180, "different seeds produce materially different terrain")
	_expect(maximum_neighbor_step <= 8, "terrain remains locally continuous without broken vertical spikes")


func _test_river_continuity() -> void:
	var maximum_center_step: float = 0.0
	var previous_center: float = Terrain.river_center_z(73_421, -512)
	for world_x: int in range(-511, 513):
		var center: float = Terrain.river_center_z(73_421, world_x)
		maximum_center_step = maxf(maximum_center_step, absf(center - previous_center))
		previous_center = center
	_expect(maximum_center_step < 2.5, "river center remains continuous across neighboring columns")


func _test_spawn_suitability() -> void:
	var suitable_spawns: int = 0
	for salt: int in range(8):
		var spawn: Vector3 = SpawnPlanner.find_spawn(73_421, salt * 97 + 11)
		var world_x: int = floori(spawn.x)
		var world_z: int = floori(spawn.z)
		var height: int = Terrain.surface_height(73_421, world_x, world_z)
		var slope: int = Terrain.surface_slope(73_421, world_x, world_z)
		var river_gap: float = Terrain.river_distance(73_421, world_x, world_z)
		var y_matches_surface: bool = absf(spawn.y - (float(height) + 2.5)) < 0.01
		if (
			y_matches_surface
			and height > Terrain.WATER_LEVEL + 2
			and slope <= 1
			and river_gap >= 10.0
		):
			suitable_spawns += 1
	_expect(suitable_spawns >= 7, "procedural spawn search consistently chooses safe walkable ground")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL " + label)
