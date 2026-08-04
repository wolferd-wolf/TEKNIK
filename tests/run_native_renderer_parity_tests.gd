extends SceneTree

const NativeChunkBackend = preload("res://src/world/native_chunk_backend.gd")
const NativeTerrainRenderer = preload("res://src/world/native_terrain_renderer.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const SEED: int = 73_421
const COORDINATE := Vector3i(-1, 0, 1)
const IMAGE_SIZE: int = 256

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var output_directory := "artifacts"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--renderer-artifacts="):
			output_directory = argument.trim_prefix("--renderer-artifacts=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))

	var backend := NativeChunkBackend.new()
	var renderer := NativeTerrainRenderer.new()
	_expect(backend.is_available(), "native chunk backend is loaded")
	_expect(renderer.is_available(), "native terrain renderer is loaded")
	if not backend.is_available() or not renderer.is_available():
		_finish()
		return

	var chunk: Dictionary = backend.build_chunk(SEED, COORDINATE, {})
	_expect(bool(chunk.get("success", false)), "native reference chunk builds")
	if not bool(chunk.get("success", false)):
		push_error(str(chunk.get("error", "unknown native chunk error")))
		_finish()
		return

	var arrays: Array = chunk.arrays
	var packed_faces: PackedInt32Array = chunk.packed_faces
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var report: Dictionary = renderer.render_chunk_parity_preview(
		packed_faces,
		vertices,
		normals,
		indices,
		COORDINATE * VoxelChunk.SIZE,
		IMAGE_SIZE
	)

	_expect(bool(report.get("success", false)), "one-chunk Vulkan parity render succeeds")
	_expect(bool(report.get("rendering_device_available", false)), "global RenderingDevice remains available")
	_expect(str(report.get("rendering_method", "")) == "mobile", "Vulkan preview uses Mobile renderer")
	_expect(str(report.get("rendering_driver", "")) == "vulkan", "Vulkan preview uses Vulkan driver")
	_expect(bool(report.get("exact_pixel_match", false)), "packed and conventional Vulkan pixels match exactly")
	_expect(int(report.get("mismatch_pixels", -1)) == 0, "Vulkan parity has zero differing pixels")
	_expect(int(report.get("covered_pixels", 0)) > 0, "packed Vulkan render contains visible terrain")
	_expect(int(report.get("face_count", 0)) == int(chunk.quads), "one packed instance is drawn per greedy quad")
	_expect(
		int(report.get("packed_upload_bytes", 0)) < int(report.get("legacy_upload_bytes", 0)),
		"packed preview uploads fewer bytes than conventional mesh"
	)

	var packed_image: Image = report.get("packed_image")
	var legacy_image: Image = report.get("legacy_image")
	_expect(packed_image != null and not packed_image.is_empty(), "packed preview image is readable")
	_expect(legacy_image != null and not legacy_image.is_empty(), "legacy preview image is readable")
	if packed_image != null and not packed_image.is_empty():
		_expect(
			packed_image.save_png(output_directory.path_join("packed-chunk.png")) == OK,
			"packed preview image is saved"
		)
	if legacy_image != null and not legacy_image.is_empty():
		_expect(
			legacy_image.save_png(output_directory.path_join("legacy-chunk.png")) == OK,
			"legacy preview image is saved"
		)

	var serializable := report.duplicate()
	serializable.erase("packed_image")
	serializable.erase("legacy_image")
	var report_file := FileAccess.open(
		output_directory.path_join("vulkan-chunk-parity.json"),
		FileAccess.WRITE
	)
	_expect(report_file != null, "Vulkan parity report file opens")
	if report_file != null:
		report_file.store_string(JSON.stringify(serializable, "\t"))
		report_file.close()

	print("NATIVE_RENDERER_PARITY ", JSON.stringify(serializable))
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("NATIVE_RENDERER_PARITY_TEST_RESULT PASS")
		quit(0)
	else:
		print("NATIVE_RENDERER_PARITY_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
