extends SceneTree

const AutoJumpAssistant = preload("res://src/player/auto_jump_assistant.gd")
const MeshVisualSanitizer = preload("res://src/world/mesh_visual_sanitizer.gd")
const FeaturePlanner = preload("res://src/world/procedural_feature_planner.gd")
const DistantPlanner = preload("res://src/world/distant_terrain_planner.gd")

var _failures: int = 0


func _init() -> void:
	_test_mobile_project_settings()
	_test_flat_quad_colors()
	_test_auto_jump_evidence_signal()
	_test_shipping_scene()
	_test_feature_planner()
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
	_expect(
		scene_text.contains("procedural_gameplay_main.gd"),
		"shipping scene enables procedural mobile gameplay"
	)
	_expect(
		scene_text.contains("gd_stream.gd"),
		"shipping scene enables player-following ecology streaming"
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
		"old vegetation remains visible during replacement"
	)
	_expect(
		stream_source.contains("_player.global_position"),
		"ground detail follows the moving player instead of the original spawn"
	)


func _test_distant_terrain_planner() -> void:
	var planner := DistantPlanner.new()
	var first: Dictionary = planner.build(73_421, Vector3i.ZERO, 32, 1, 64, 4)
	var second: Dictionary = planner.build(73_421, Vector3i.ZERO, 32, 1, 64, 4)
	var quads: int = int(first.get("quads", 0))
	var vertices: PackedVector3Array = first.get("vertices", PackedVector3Array())
	var indices: PackedInt32Array = first.get("indices", PackedInt32Array())
	_expect(quads > 0, "background distant terrain planner produces geometry")
	_expect(vertices.size() == quads * 4, "distant terrain emits four vertices per quad")
	_expect(indices.size() == quads * 6, "distant terrain emits six indices per quad")
	_expect(
		vertices == second.get("vertices", PackedVector3Array())
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
