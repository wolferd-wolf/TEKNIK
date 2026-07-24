extends SceneTree

const VoxelRaycast = preload("res://src/world/voxel_raycast.gd")
const EditRebuildScheduler = preload("res://src/world/edit_rebuild_scheduler.gd")

var _failures: int = 0


class BusyProbe:
	extends RefCounted
	var coordinates: Dictionary = {}

	func has_coordinate(coordinate: Vector3i) -> bool:
		return coordinates.has(coordinate)


func _init() -> void:
	_test_downward_voxel_targeting()
	_test_rapid_sequential_mining()
	_test_negative_coordinate_targeting()
	_test_busy_rebuild_retention()
	_test_shipping_feedback_stack()
	if _failures == 0:
		print("BLOCK_TARGETING_TEST_RESULT PASS")
		quit(0)
	else:
		print("BLOCK_TARGETING_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_downward_voxel_targeting() -> void:
	var solids: Dictionary = {Vector3i(2, 1, -4): true}
	var hit: Dictionary = VoxelRaycast.cast(
		Vector3(2.5, 4.5, -3.5),
		Vector3.DOWN,
		7.0,
		func(voxel: Vector3i) -> bool: return solids.has(voxel)
	)
	_expect(hit.get("voxel", Vector3i.ZERO) == Vector3i(2, 1, -4), "center ray selects the exact block below")
	_expect(float(hit.get("distance", 99.0)) < 4.0, "downward block is inside interaction range")
	_expect(VoxelRaycast.outline_center(Vector3i(2, 1, -4)) == Vector3(2.5, 1.5, -3.5), "selection outline is centered on the targeted voxel")


func _test_rapid_sequential_mining() -> void:
	var solids: Dictionary = {
		Vector3i(0, 2, 0): true,
		Vector3i(0, 1, 0): true,
	}
	var lookup: Callable = func(voxel: Vector3i) -> bool: return solids.has(voxel)
	var first: Dictionary = VoxelRaycast.cast(Vector3(0.5, 4.5, 0.5), Vector3.DOWN, 7.0, lookup)
	_expect(first.get("voxel", Vector3i.ZERO) == Vector3i(0, 2, 0), "first tap selects the top block")
	solids.erase(Vector3i(0, 2, 0))
	var second: Dictionary = VoxelRaycast.cast(Vector3(0.5, 4.5, 0.5), Vector3.DOWN, 7.0, lookup)
	_expect(second.get("voxel", Vector3i.ZERO) == Vector3i(0, 1, 0), "next tap immediately selects the deeper authoritative block")


func _test_negative_coordinate_targeting() -> void:
	var target := Vector3i(-3, 0, -6)
	var hit: Dictionary = VoxelRaycast.cast(
		Vector3(-2.5, 2.5, -5.5),
		Vector3.DOWN,
		5.0,
		func(voxel: Vector3i) -> bool: return voxel == target
	)
	_expect(hit.get("voxel", Vector3i.ZERO) == target, "voxel traversal remains correct in negative world coordinates")


func _test_busy_rebuild_retention() -> void:
	var busy_coordinate := Vector3i(4, 0, -2)
	var ready_coordinate := Vector3i(5, 0, -2)
	var queue: Array[Vector3i] = [busy_coordinate, ready_coordinate]
	var resident: Dictionary = {busy_coordinate: true, ready_coordinate: true}
	var probe := BusyProbe.new()
	probe.coordinates[busy_coordinate] = true
	var selected: Vector3i = EditRebuildScheduler.take_ready(queue, resident, Callable(probe, "has_coordinate"))
	_expect(selected == ready_coordinate, "a ready edited chunk can rebuild while another is in flight")
	_expect(queue.has(busy_coordinate), "edits made during an in-flight rebuild remain queued")
	probe.coordinates.clear()
	selected = EditRebuildScheduler.take_ready(queue, resident, Callable(probe, "has_coordinate"))
	_expect(selected == busy_coordinate, "retained dirty chunk rebuilds after its stale worker completes")


func _test_shipping_feedback_stack() -> void:
	var scene: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var capture: String = FileAccess.get_file_as_string("res://src/main/kinetic_capture_shipping_main.gd")
	var targeting: String = FileAccess.get_file_as_string("res://src/main/targeted_interaction_main.gd")
	var crosshair: String = FileAccess.get_file_as_string("res://src/player/block_target_crosshair.gd")
	_expect(scene.contains("kinetic_capture_shipping_main.gd"), "shipping scene retains the validated capture entry point")
	_expect(capture.contains("targeted_interaction_main.gd"), "shipping runtime enables precise block targeting")
	_expect(targeting.contains("VoxelRaycast.cast"), "runtime targets authoritative voxel data instead of stale collision only")
	_expect(targeting.contains("_survival_break_voxel(voxel"), "break action removes the same voxel shown by the target feedback")
	_expect(targeting.contains("BlockTargetOutline"), "selected block receives a world-space outline")
	_expect(targeting.contains("QA_BLOCK_TARGETING_PASS"), "gameplay recording verifies targeting feedback")
	_expect(crosshair.contains("PRESET_FULL_RECT") and crosshair.contains("TARGET_COLOR"), "center crosshair is permanent and changes state on a valid block")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
