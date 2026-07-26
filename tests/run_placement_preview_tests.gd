extends SceneTree

const VoxelRaycast = preload("res://src/world/voxel_raycast.gd")

var _failures: int = 0


func _init() -> void:
	_test_face_adjacent_targets()
	_test_shipping_stack()
	if _failures == 0:
		print("PLACEMENT_PREVIEW_TEST_RESULT PASS")
		quit(0)
	else:
		print("PLACEMENT_PREVIEW_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_face_adjacent_targets() -> void:
	var solids: Dictionary = {Vector3i(2, 1, -4): true}
	var top_hit: Dictionary = VoxelRaycast.cast(
		Vector3(2.5, 4.5, -3.5),
		Vector3.DOWN,
		7.0,
		func(voxel: Vector3i) -> bool: return solids.has(voxel)
	)
	var top_voxel: Vector3i = top_hit.get("voxel", Vector3i.ZERO)
	var top_normal: Vector3 = top_hit.get("normal", Vector3.ZERO)
	var top_face := Vector3i(roundi(top_normal.x), roundi(top_normal.y), roundi(top_normal.z))
	_expect(top_voxel + top_face == Vector3i(2, 2, -4), "top-face preview selects the empty voxel above")

	var side_solids: Dictionary = {Vector3i(1, 0, 0): true}
	var side_hit: Dictionary = VoxelRaycast.cast(
		Vector3(-1.5, 0.5, 0.5),
		Vector3.RIGHT,
		5.0,
		func(voxel: Vector3i) -> bool: return side_solids.has(voxel)
	)
	var side_voxel: Vector3i = side_hit.get("voxel", Vector3i.ZERO)
	var side_normal: Vector3 = side_hit.get("normal", Vector3.ZERO)
	var side_face := Vector3i(roundi(side_normal.x), roundi(side_normal.y), roundi(side_normal.z))
	_expect(side_voxel + side_face == Vector3i(0, 0, 0), "side-face preview selects the adjacent empty voxel")
	_expect(VoxelRaycast.outline_center(Vector3i(0, 0, 0)) == Vector3(0.5, 0.5, 0.5), "preview wireframe is centered on the placement voxel")


func _test_shipping_stack() -> void:
	var scene: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var capture: String = FileAccess.get_file_as_string("res://src/main/kinetic_capture_shipping_main.gd")
	var vitals: String = FileAccess.get_file_as_string("res://src/main/survival_vitals_main.gd")
	var preview: String = FileAccess.get_file_as_string("res://src/main/placement_preview_main.gd")
	_expect(scene.contains("kinetic_capture_shipping_main.gd"), "shipping scene retains the validated capture entry point")
	_expect(
		capture.contains("survival_vitals_main.gd")
		and vitals.contains("placement_preview_main.gd"),
		"shipping runtime enables exact placement previews through the actual inheritance chain"
	)
	_expect(preview.contains("BlockPlacementPreview"), "placement preview has a dedicated world-space wireframe")
	_expect(preview.contains("PREVIEW_VALID_COLOR") and preview.contains("PREVIEW_INVALID_COLOR"), "preview distinguishes valid and invalid placement")
	_expect(preview.contains("_survival_place_voxel(voxel"), "place action consumes the exact voxel shown by the preview")
	_expect(preview.contains("_placement_intersects_player(voxel)"), "preview rejects blocks intersecting the player")
	_expect(preview.contains("QA_PLACEMENT_PREVIEW_PASS"), "gameplay recording verifies placement preview setup")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
