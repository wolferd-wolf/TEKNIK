extends SceneTree

const NativeTerrainRenderer = preload("res://src/world/native_terrain_renderer.gd")

var _failures: int = 0


func _init() -> void:
	var expect_rendering_device := "--expect-rendering-device" in OS.get_cmdline_user_args()
	var output_path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--renderer-report="):
			output_path = argument.trim_prefix("--renderer-report=")

	var renderer := NativeTerrainRenderer.new()
	_expect(renderer.is_available(), "native terrain renderer service is registered")
	var report: Dictionary = renderer.probe_renderer()
	_expect(bool(report.get("success", false)), "renderer probe succeeds")
	_expect(not str(report.get("rendering_method", "")).is_empty(), "rendering method is recorded")
	_expect(not str(report.get("rendering_driver", "")).is_empty(), "rendering driver is recorded")

	if expect_rendering_device:
		_expect(bool(report.get("rendering_device_available", false)), "global RenderingDevice is available")
		_expect(str(report.get("rendering_method", "")) == "mobile", "Mobile rendering method is active")
		_expect(str(report.get("rendering_driver", "")) == "vulkan", "Vulkan rendering driver is active")
		_expect(bool(report.get("packed_renderer_supported", false)), "packed renderer support gate passes")

	if not output_path.is_empty():
		var directory := output_path.get_base_dir()
		if not directory.is_empty():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		_expect(file != null, "renderer report file opens")
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()

	print("NATIVE_RENDERER_PROBE ", JSON.stringify(report))
	if _failures == 0:
		print("NATIVE_RENDERER_PROBE_TEST_RESULT PASS")
		quit(0)
	else:
		print("NATIVE_RENDERER_PROBE_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
