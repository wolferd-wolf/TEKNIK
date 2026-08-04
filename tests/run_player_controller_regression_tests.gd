extends SceneTree

const ExplorationController = preload("res://src/player/exploration_controller.gd")
const VoxelPlayerMotion = preload("res://src/player/voxel_player_motion.gd")

var _failures: int = 0


class SolidProbe:
	extends RefCounted
	var solids: Dictionary = {}

	func is_solid(voxel: Vector3i) -> bool:
		return solids.has(voxel)


func _init() -> void:
	_test_minecraft_scale_contract()
	_test_ground_state_persists()
	_test_one_block_shaft_entry()
	_test_corner_slide_without_sticking()
	_test_two_block_tunnel_traversal()
	_test_real_controller_jump()
	_test_single_collision_authority()
	if _failures == 0:
		print("PLAYER_CONTROLLER_REGRESSION_TEST_RESULT PASS")
		quit(0)
	else:
		print("PLAYER_CONTROLLER_REGRESSION_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_minecraft_scale_contract() -> void:
	_expect(is_equal_approx(VoxelPlayerMotion.BLOCK_SIZE, 1.0), "one TEKNIK voxel is one movement block")
	_expect(is_equal_approx(VoxelPlayerMotion.BODY_WIDTH, 0.60), "standing player width is 0.6 blocks")
	_expect(is_equal_approx(VoxelPlayerMotion.BODY_HEIGHT, 1.80), "standing player height is 1.8 blocks")
	_expect(is_equal_approx(VoxelPlayerMotion.EYE_HEIGHT, 1.62), "standing eye height is 1.62 blocks")
	_expect(is_equal_approx(VoxelPlayerMotion.STEP_HEIGHT, 0.60), "player step height is 0.6 blocks")


func _test_ground_state_persists() -> void:
	var probe := SolidProbe.new()
	probe.solids[Vector3i(0, 0, 0)] = true
	var query := Callable(probe, "is_solid")
	var position := Vector3(0.5, 1.0, 0.5)
	_expect(VoxelPlayerMotion.is_supported(position, query), "floor support is detected without triangle-mesh contact")
	var result: Dictionary = VoxelPlayerMotion.solve_motion(
		position,
		Vector3(0.0, -0.05, 0.0),
		query
	)
	var motion: Vector3 = result.get("motion", Vector3.ZERO)
	_expect(is_zero_approx(motion.y), "ground probe clips downward stick motion")
	_expect(bool(result.get("grounded", false)), "grounded state remains true after clipped downward motion")


func _test_one_block_shaft_entry() -> void:
	var probe := SolidProbe.new()
	for y: int in range(-1, 5):
		for z: int in range(-1, 2):
			for x: int in range(-1, 2):
				if x == 0 and z == 0:
					continue
				probe.solids[Vector3i(x, y, z)] = true
	var query := Callable(probe, "is_solid")
	var centered: Dictionary = VoxelPlayerMotion.solve_motion(
		Vector3(0.5, 3.0, 0.5),
		Vector3(0.0, -2.4, 0.0),
		query
	)
	var centered_motion: Vector3 = centered.get("motion", Vector3.ZERO)
	_expect(is_equal_approx(centered_motion.y, -2.4), "centered standing player falls through a one-block shaft")
	_expect(is_zero_approx(centered_motion.x) and is_zero_approx(centered_motion.z), "shaft fall preserves the horizontal column")
	var near_edge: Vector3 = VoxelPlayerMotion.clip_motion(
		Vector3(0.70, 3.0, 0.5),
		Vector3(0.0, -2.4, 0.0),
		query
	)
	_expect(is_equal_approx(near_edge.y, -2.4), "full 0.6-wide body fits through the valid shaft tolerance")
	var outside_edge: Vector3 = VoxelPlayerMotion.clip_motion(
		Vector3(0.80, 3.0, 0.5),
		Vector3(0.0, -2.4, 0.0),
		query
	)
	_expect(is_zero_approx(outside_edge.y), "body remains supported when it genuinely does not fit")


func _test_corner_slide_without_sticking() -> void:
	var probe := SolidProbe.new()
	for y: int in range(1, 3):
		for z: int in range(0, 3):
			probe.solids[Vector3i(1, y, z)] = true
	var query := Callable(probe, "is_solid")
	var motion: Vector3 = VoxelPlayerMotion.clip_motion(
		Vector3(0.5, 1.0, 0.5),
		Vector3(0.8, 0.0, 0.8),
		query
	)
	_expect(motion.x > 0.19 and motion.x < 0.22, "wall clips only the blocked horizontal axis")
	_expect(is_equal_approx(motion.z, 0.8), "unblocked axis continues along the wall instead of sticking")


func _test_two_block_tunnel_traversal() -> void:
	var probe := SolidProbe.new()
	for z: int in range(-1, 6):
		probe.solids[Vector3i(0, 0, z)] = true
		probe.solids[Vector3i(0, 3, z)] = true
		for y: int in range(1, 3):
			probe.solids[Vector3i(-1, y, z)] = true
			probe.solids[Vector3i(1, y, z)] = true
	var query := Callable(probe, "is_solid")
	var motion: Vector3 = VoxelPlayerMotion.clip_motion(
		Vector3(0.5, 1.0, 0.5),
		Vector3(0.0, 0.0, 3.0),
		query
	)
	_expect(is_equal_approx(motion.z, 3.0), "1.8-block player traverses a two-block-high tunnel")
	_expect(is_zero_approx(motion.x) and is_zero_approx(motion.y), "tunnel travel does not acquire random drift")


func _test_real_controller_jump() -> void:
	var probe := SolidProbe.new()
	probe.solids[Vector3i(0, 0, 0)] = true
	var query := Callable(probe, "is_solid")
	var controller = ExplorationController.new()
	controller.set_physics_process(false)
	root.add_child(controller)
	controller.global_position = Vector3(0.5, 1.0, 0.5)
	controller.set_voxel_solid_query(query)
	_expect(controller.is_grounded(), "controller establishes authoritative grounded state")
	controller.request_jump()
	controller._physics_process(1.0 / 30.0)
	_expect(controller.global_position.y > 1.1, "buffered jump moves the player upward on the first physics tick")
	_expect(controller.velocity.y > 0.0, "jump keeps positive vertical velocity after leaving the floor")
	controller.free()


func _test_single_collision_authority() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/player/exploration_controller.gd")
	_expect(not source.contains("move_and_slide()"), "voxel movement is not resolved a second time by Godot terrain collision")
	_expect(not source.contains("is_on_floor()"), "jumping no longer depends on a lost Godot floor flag")
	_expect(source.contains("collision_mask = 0"), "player ignores chunk triangle collision while voxel AABBs are authoritative")
	_expect(source.contains("JUMP_BUFFER_SECONDS") and source.contains("request_jump"), "mobile jump presses use a persistent input buffer")
	_expect(source.contains("VoxelPlayerMotion.solve_motion"), "runtime consumes authoritative grounded and step results")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
