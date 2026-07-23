extends SceneTree

const Ecology = preload("res://src/world/procedural_ecology.gd")


var _failures: int = 0


func _init() -> void:
	_test_candidate_determinism()
	_test_blue_noise_spacing()
	_test_ecological_fields()
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


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL " + label)
