extends SceneTree

const MeshVisualSanitizer = preload("res://src/world/mesh_visual_sanitizer.gd")

var _failures: int = 0


func _init() -> void:
	_test_mobile_project_settings()
	_test_flat_quad_colors()
	_test_shipping_scene()

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


func _test_shipping_scene() -> void:
	var scene_text: String = FileAccess.get_file_as_string(
		"res://src/main/main.tscn"
	)
	_expect(
		scene_text.contains("mobile_shipping_main.gd"),
		"shipping scene enables mobile input and visual fixes"
	)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
