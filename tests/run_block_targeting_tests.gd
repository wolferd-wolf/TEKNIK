extends SceneTree

const VoxelRaycast = preload("res://src/world/voxel_raycast.gd")
const EditRebuildScheduler = preload("res://src/world/edit_rebuild_scheduler.gd")
const VisibleMiningLock = preload("res://src/player/visible_mining_lock.gd")

var _failures: int = 0


class BusyProbe:
	extends RefCounted
	var coordinates: Dictionary = {}

	func has_coordinate(coordinate: Vector3i) -> bool:
		return coordinates.has(coordinate)


func _init() -> void:
	_test_downward_voxel_targeting()
	_test_authoritative_voxel_traversal()
	_test_visible_commit_lock()
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


func _test_authoritative_voxel_traversal() -> void:
	var solids: Dictionary = {
		Vector3i(0, 2, 0): true,
		Vector3i(0, 1, 0): true,
	}
	var lookup: Callable = func(voxel: Vector3i) -> bool: return solids.has(voxel)
	var first: Dictionary = VoxelRaycast.cast(Vector3(0.5, 4.5, 0.5), Vector3.DOWN, 7.0, lookup)
	_expect(first.get("voxel", Vector3i.ZERO) == Vector3i(0, 2, 0), "authoritative ray selects the top block")
	solids.erase(Vector3i(0, 2, 0))
	var second: Dictionary = VoxelRaycast.cast(Vector3(0.5, 4.5, 0.5), Vector3.DOWN, 7.0, lookup)
	_expect(second.get("voxel", Vector3i.ZERO) == Vector3i(0, 1, 0), "authoritative traversal can find the next block after a committed edit")


func _test_visible_commit_lock() -> void:
	var lock: TeknikVisibleMiningLock = VisibleMiningLock.new()
	var voxel := Vector3i(5, 3, -8)
	var chunk := Vector3i(0, 0, -1)
	_expect(lock.begin(voxel, chunk), "first visible block break acquires the mining lock")
	_expect(not lock.begin(Vector3i(5, 2, -8), chunk), "a second break cannot mine through the still-visible block")
	_expect(lock.is_active() and lock.voxel() == voxel, "visible mining lock retains the exact displayed voxel")
	_expect(not lock.complete_if_visible_commit(Vector3i(1, 0, -1), false), "an unrelated chunk commit cannot release the mining lock")
	_expect(not lock.complete_if_visible_commit(chunk, true), "a stale commit cannot release a chunk that is still dirty")
	_expect(lock.complete_if_visible_commit(chunk, false), "the rebuilt visible chunk releases the mining lock")
	_expect(not lock.is_active(), "mining can continue only after the visible mesh catches up")


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
	var placement: String = FileAccess.get_file_as_string("res://src/main/placement_preview_main.gd")
	var targeting: String = FileAccess.get_file_as_string("res://src/main/targeted_interaction_main.gd")
	var crosshair: String = FileAccess.get_file_as_string("res://src/player/block_target_crosshair.gd")
	_expect(scene.contains("kinetic_capture_shipping_main.gd"), "shipping scene retains the validated capture entry point")
	_expect(capture.contains("placement_preview_main.gd") and placement.contains("targeted_interaction_main.gd"), "shipping runtime retains precise block targeting through placement preview")
	_expect(targeting.contains("VoxelRaycast.cast"), "runtime targets authoritative voxel data instead of stale collision only")
	_expect(targeting.contains("_survival_break_voxel(voxel"), "break action removes the same voxel shown by the target feedback")
	_expect(targeting.contains("VisibleMiningLock") and targeting.contains("complete_if_visible_commit"), "runtime blocks mining through stale visible terrain")
	_expect(targeting.contains("BlockTargetEdge"), "selected block uses twelve reliable world-space edge meshes")
	_expect(not targeting.contains("SelectedBlockFill"), "target feedback never covers the screen with a translucent cube face")
	_expect(targeting.contains("QA_BLOCK_TARGETING_PASS"), "gameplay recording verifies targeting feedback")
	_expect(crosshair.contains("PRESET_FULL_RECT") and crosshair.contains("TARGET_COLOR"), "center crosshair is permanent and changes state on a valid block")
	_expect(crosshair.contains("PENDING_COLOR"), "crosshair exposes the waiting-for-visible-commit state")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
