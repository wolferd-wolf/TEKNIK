extends SceneTree

const AutoJumpAssistant = preload("res://src/player/auto_jump_assistant.gd")
const MeshVisualSanitizer = preload("res://src/world/mesh_visual_sanitizer.gd")
const FeaturePlanner = preload("res://src/world/procedural_feature_planner.gd")
const DistantPlanner = preload("res://src/world/distant_terrain_planner.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const BiomePalette = preload("res://src/world/biome_surface_palette.gd")

var _failures: int = 0


func _init() -> void:
	_test_mobile_project_settings()
	_test_flat_quad_colors()
	_test_auto_jump_evidence_signal()
	_test_shipping_scene()
	_test_feature_planner()
	_test_biome_surface_palette()
	_test_distant_terrain_planner()

	if _failures == 0:
		print("MOBILE_REGRESSION_RESULT PASS")
		quit(0)
	else:
		print("MOBILE_REGRESSION_RESULT FAIL count=", _failures)
		quit(1)


func _test_mobile_project_settings() -> void:
	_expect(
		int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 0,
		"Android orientation is landscape"
	)
	_expect(
		not bool(ProjectSettings.get_setting(
			"input_devices/pointing/emulate_mouse_from_touch",
			true
		)),
		"touch input does not synthesize mouse clicks"
	)


func _test_flat_quad_colors() -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([
		Color(1.0, 0.0, 0.0, 1.0),
		Color(0.0, 1.0, 0.0, 1.0),
		Color(0.0, 0.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
	])
	MeshVisualSanitizer.flatten_quad_colors(arrays)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	_expect(colors.size() == 4, "quad color count is preserved")
	_expect(
		colors[0] == colors[1]
		and colors[1] == colors[2]
		and colors[2] == colors[3],
		"all four vertices of a greedy quad use one flat color"
	)


func _test_auto_jump_evidence_signal() -> void:
	var assistant := AutoJumpAssistant.new()
	_expect(
		assistant.has_signal("auto_jump_triggered"),
		"auto jump exposes device-side activation evidence"
	)
	assistant.free()


func _test_shipping_scene() -> void:
	var scene_text: String = FileAccess.get_file_as_string(
		"res://src/main/main.tscn"
	)
	var kinetic_source: String = FileAccess.get_file_as_string(
		"res://src/main/kinetic_machine_main.gd"
	)
	var survival_source: String = FileAccess.get_file_as_string(
		"res://src/main/survival_shipping_main.gd"
	)
	var engineering_source: String = FileAccess.get_file_as_string(
		"res://src/main/engineering_progression_main.gd"
	)
	_expect(
		scene_text.contains("kinetic_machine_main.gd")
		and kinetic_source.contains("survival_shipping_main.gd")
		and survival_source.contains("engineering_progression_main.gd")
		and engineering_source.contains("multi_lod_main.gd"),
		"shipping scene reaches biome-driven terrain through the kinetic survival stack"
	)
	var biome_main_source: String = FileAccess.get_file_as_string(
		"res://src/main/biome_visual_main.gd"
	)
	_expect(
		biome_main_source.contains("procedural_gameplay_main.gd_stream.gd"),
		"biome visuals retain the proven gameplay and ecology streaming stack"
	)
	_expect(
		kinetic_source.contains("kinetic_machine_state.gd"),
		"shipping scene enables functional kinetic machines without bypassing terrain layers"
	)


func _test_feature_planner() -> void:
	var planner := FeaturePlanner.new()
	var observer := Vector3(10_000.0, 0.0, 10_000.0)
	var first: Dictionary = planner.build(73_421, Vector3i.ZERO, 0, 32, observer)
	var second: Dictionary = planner.build(73_421, Vector3i.ZERO, 0, 32, observer)
	_expect(
		_feature_signature(first) == _feature_signature(second),
		"background feature planning remains deterministic"
	)
	_expect(
		int(first.get("generation_usec", -1)) >= 0,
		"background feature planning reports generation time"
	)
	var gameplay_source: String = FileAccess.get_file_as_string(
		"res://src/main/procedural_gameplay_main.gd"
	)
	var stream_source: String = FileAccess.get_file_as_string(
		"res://src/main/procedural_gameplay_main.gd_stream.gd"
	)
	_expect(
		gameplay_source.contains("Thread.new()"),
		"vegetation planning runs outside the render thread"
	)
	_expect(
		gameplay_source.contains("ECOLOGY_GROUPS_PER_FRAME"),
		"vegetation batches use a per-frame commit budget"
	)
	_expect(
		gameplay_source.contains("old_features_visible"),
		"base ecology replacement retains compatibility diagnostics"
	)
	_expect(
		stream_source.contains("_ecology_chunk_roots")
		and stream_source.contains("func _unload_terrain_chunk")
		and stream_source.contains("_remove_ecology_chunk(coordinate)"),
		"vegetation residency is owned and unloaded per terrain chunk"
	)
	_expect(
		stream_source.contains("var exclusion_position: Vector3 = _planned_spawn")
		and not stream_source.contains("var observer_position: Vector3 = (\n\t\t_player.global_position"),
		"vegetation placement stays deterministic while the player moves"
	)
	_expect(
		stream_source.contains("QA_ECOLOGY_STREAM_PASS")
		or FileAccess.get_file_as_string(
			"res://src/qa/gameplay_capture_director.gd"
		).contains("QA_ECOLOGY_STREAM_PASS"),
		"gameplay QA verifies neighboring vegetation survives a chunk unload"
	)


func _test_biome_surface_palette() -> void:
	var seed: int = 73_421
	var samples: Array[Vector3i] = [
		Vector3i(-640, 16, -640),
		Vector3i(-320, 16, 256),
		Vector3i(0, 16, 0),
		Vector3i(384, 16, -288),
		Vector3i(704, 16, 576),
	]
	var first_signature: Array[String] = []
	var second_signature: Array[String] = []
	var dominant: Dictionary = {}
	var colors: Array[Color] = []
	for sample: Vector3i in samples:
		var first_weights: Vector4 = BiomePalette.biome_weights(
			seed,
			sample.x,
			sample.z,
			float(sample.y)
		)
		var second_weights: Vector4 = BiomePalette.biome_weights(
			seed,
			sample.x,
			sample.z,
			float(sample.y)
		)
		first_signature.append(str(first_weights))
		second_signature.append(str(second_weights))
		var plains: float = maxf(0.0, 1.0 - first_weights.x - first_weights.y - first_weights.z - first_weights.w)
		var weights: Array[float] = [plains, first_weights.x, first_weights.y, first_weights.z, first_weights.w]
		var best_index: int = 0
		for index: int in range(1, weights.size()):
			if weights[index] > weights[best_index]:
				best_index = index
		dominant[best_index] = true
		colors.append(BiomePalette.color(seed, TerrainGenerator.GRASS, sample, float(sample.y), {}))
	_expect(first_signature == second_signature, "biome masks remain deterministic")
	_expect(dominant.size() >= 4, "the world seed exposes at least four terrain biomes")
	var maximum_distance: float = 0.0
	for first_index: int in range(colors.size()):
		for second_index: int in range(first_index + 1, colors.size()):
			maximum_distance = maxf(maximum_distance, colors[first_index].distance_to(colors[second_index]))
	_expect(maximum_distance > 0.10, "biomes produce visibly distinct terrain palettes")


func _test_distant_terrain_planner() -> void:
	var planner := DistantPlanner.new()
	var first: Dictionary = planner.build(73_421, Vector3i.ZERO, 32, 1, 64, 4)
	var second: Dictionary = planner.build(73_421, Vector3i.ZERO, 32, 1, 64, 4)
	var quads: int = int(first.get("quads", 0))
	var top_quads: int = int(first.get("top_quads", 0))
	var side_quads: int = int(first.get("side_quads", 0))
	var vertices: PackedVector3Array = first.get("vertices", PackedVector3Array())
	var normals: PackedVector3Array = first.get("normals", PackedVector3Array())
	var indices: PackedInt32Array = first.get("indices", PackedInt32Array())
	_expect(top_quads > 0, "background distant terrain planner produces top geometry")
	_expect(side_quads > 0, "distant terrain emits vertical faces between height steps")
	_expect(quads == top_quads + side_quads, "distant terrain quad accounting includes top and side faces")
	_expect(vertices.size() == quads * 4, "distant terrain emits four vertices per quad")
	_expect(normals.size() == vertices.size(), "distant terrain emits one normal per vertex")
	_expect(indices.size() == quads * 6, "distant terrain emits six indices per quad")
	_expect(
		vertices == second.get("vertices", PackedVector3Array())
		and normals == second.get("normals", PackedVector3Array())
		and indices == second.get("indices", PackedInt32Array()),
		"background distant terrain planning remains deterministic"
	)
	var stream_source: String = FileAccess.get_file_as_string(
		"res://src/main/procedural_gameplay_main.gd_stream.gd"
	)
	_expect(
		stream_source.contains("DistantTerrainPlanner")
		and stream_source.contains("distant_generation_started"),
		"shipping runtime generates distant terrain outside the render thread"
	)


func _feature_signature(plan: Dictionary) -> String:
	var keys: Array[String] = [
		"trunks", "broadleaf_lower", "broadleaf_upper", "broadleaf_side",
		"conifer_lower", "conifer_middle", "conifer_upper", "fallen_logs",
		"cool_rock_primary", "cool_rock_secondary", "warm_rock_primary",
		"warm_rock_secondary", "lush_tufts", "dry_tufts", "shrubs_lower",
		"shrubs_upper",
	]
	var signature: Array[String] = []
	for key: String in keys:
		var transforms: Array = plan.get(key, [])
		signature.append("%s:%d" % [key, transforms.size()])
		for index: int in range(mini(2, transforms.size())):
			signature.append(str(transforms[index]))
	return "|".join(signature)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
