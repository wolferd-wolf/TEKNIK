extends SceneTree

const VoxelRaycast = preload("res://src/world/voxel_raycast.gd")
const EditRebuildScheduler = preload("res://src/world/edit_rebuild_scheduler.gd")
const MiningController = preload("res://src/player/mining_controller.gd")

var _failures: int = 0


class BusyProbe:
	extends RefCounted
	var coordinates: Dictionary = {}

	func has_coordinate(coordinate: Vector3i) -> bool:
		return coordinates.has(coordinate)


func _init() -> void:
	_test_downward_voxel_targeting()
	_test_press_does_not_instantly_break()
	_test_release_and_target_change_cancel_progress()
	_test_one_completion_waits_for_visible_commit()
	_test_material_hardness()
	_test_negative_coordinate_targeting()
	_test_busy_rebuild_retention()
	_test_shipping_mining_stack()
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
	_expect(VoxelRaycast.outline_center(Vector3i(2, 1, -4)) == Vector3(2.5, 1.5, -3.5), "selection visual is centered on the targeted voxel")


func _test_press_does_not_instantly_break() -> void:
	var controller: TeknikMiningController = MiningController.new()
	var voxel := Vector3i(4, 6, -2)
	controller.set_target(voxel, 1, 1.0)
	controller.set_pressed(true)
	_expect(controller.is_mining(), "held input enters mining state")
	_expect(controller.update(0.0).is_empty(), "button-down never removes a block instantly")
	_expect(controller.update(0.45).is_empty(), "partial hold does not complete the block")
	_expect(controller.progress() > 0.44 and controller.progress() < 0.46, "held progress advances continuously")
	var completed: Dictionary = controller.update(0.55)
	_expect(completed.get("voxel", Vector3i.ZERO) == voxel, "the locked block completes exactly at full duration")


func _test_release_and_target_change_cancel_progress() -> void:
	var controller: TeknikMiningController = MiningController.new()
	controller.set_target(Vector3i(1, 2, 3), 2, 1.0)
	controller.set_pressed(true)
	controller.update(0.6)
	controller.set_pressed(false)
	_expect(is_zero_approx(controller.progress()), "releasing BREAK resets unfinished progress")
	controller.set_pressed(true)
	controller.update(0.4)
	controller.set_target(Vector3i(1, 2, 4), 2, 1.0)
	_expect(is_zero_approx(controller.progress()), "moving the crosshair to another block resets progress")
	_expect(controller.target_voxel() == Vector3i(1, 2, 4), "target switch locks the newly visible block")


func _test_one_completion_waits_for_visible_commit() -> void:
	var controller: TeknikMiningController = MiningController.new()
	controller.set_target(Vector3i(0, 2, 0), 3, 0.5)
	controller.set_pressed(true)
	var first: Dictionary = controller.update(0.5)
	_expect(not first.is_empty(), "one held mining cycle emits one completion")
	_expect(controller.is_waiting_for_commit(), "completion waits for the visible terrain rebuild")
	_expect(controller.update(5.0).is_empty(), "continued holding cannot mine hidden deeper blocks")
	_expect(not controller.set_target(Vector3i(0, 1, 0), 3, 0.5), "target cannot advance while the old block is still visible")
	controller.notify_visible_commit()
	_expect(not controller.is_waiting_for_commit() and not controller.has_target(), "visible commit unlocks targeting")
	controller.set_target(Vector3i(0, 1, 0), 3, 0.5)
	_expect(controller.is_mining() and is_zero_approx(controller.progress()), "next exposed block starts a new zero-progress cycle")


func _test_material_hardness() -> void:
	var stone: float = MiningController.duration_for_material(1)
	var soil: float = MiningController.duration_for_material(2)
	var grass: float = MiningController.duration_for_material(3)
	var sand: float = MiningController.duration_for_material(4)
	_expect(stone > soil and stone > grass and stone > sand, "stone takes longer to mine than loose terrain")
	_expect(sand < soil, "sand has the shortest base hand-mining duration")
	_expect(stone >= 1.0 and sand >= 0.35, "base durations remain visibly readable on a phone")


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


func _test_shipping_mining_stack() -> void:
	var scene: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var capture: String = FileAccess.get_file_as_string("res://src/main/kinetic_capture_shipping_main.gd")
	var placement: String = FileAccess.get_file_as_string("res://src/main/placement_preview_main.gd")
	var targeting: String = FileAccess.get_file_as_string("res://src/main/targeted_interaction_main.gd")
	var controller: String = FileAccess.get_file_as_string("res://src/player/mining_controller.gd")
	var visual: String = FileAccess.get_file_as_string("res://src/player/mining_block_visual.gd")
	var crosshair: String = FileAccess.get_file_as_string("res://src/player/block_target_crosshair.gd")
	var machines: String = FileAccess.get_file_as_string("res://src/main/interactive_kinetic_main.gd")
	_expect(scene.contains("kinetic_capture_shipping_main.gd"), "shipping scene retains the validated capture entry point")
	_expect(capture.contains("placement_preview_main.gd") and placement.contains("targeted_interaction_main.gd"), "shipping runtime reaches the replacement mining controller")
	_expect(targeting.contains("MiningController") and targeting.contains("_process_mining"), "runtime uses one mining state machine")
	_expect(targeting.contains("mining_completed_waiting_for_mesh") and targeting.contains("mining_visible_commit"), "runtime waits for the edited block to disappear visibly")
	_expect(not targeting.contains("VisibleMiningLock") and not targeting.contains("MiningHoldState"), "obsolete layered mining patches are removed from shipping")
	_expect(controller.contains("WAITING_FOR_COMMIT") and controller.contains("button-down"), "controller encodes hold, cancel and visible-commit phases")
	_expect(visual.contains("Mesh.PRIMITIVE_LINES") and visual.contains("MiningCrackOverlay"), "one thin outline and one crack overlay provide block feedback")
	_expect(visual.contains("Original procedural crack pattern") and not visual.contains("SelectedBlockFill"), "cracks are original and no filled selection cube remains")
	_expect(placement.contains("idle_hidden") and not placement.contains("_refresh_placement_preview"), "placement preview cannot compete with mining while aiming")
	_expect(machines.contains("_interaction_hint.visible = has_target"), "machine help text stays out of the crosshair unless a machine is targeted")
	_expect(crosshair.contains("RETICLE_COLOR") and not crosshair.contains("TARGET_COLOR") and not crosshair.contains("PENDING_COLOR"), "crosshair remains small and visually stable")
	_expect(targeting.contains("QA_MINING_SYSTEM_PASS"), "gameplay recording exposes the replacement mining visual")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
