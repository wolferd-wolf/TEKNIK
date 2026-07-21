extends SceneTree

const ControlMath = preload("res://src/player/mobile_control_math.gd")
const InteractionMath = preload("res://src/world/world_interaction_math.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

var _failures: int = 0


func _init() -> void:
	_test_face_targeting()
	_test_boundary_rebuilds()
	_test_mobile_action_zones()
	if _failures == 0:
		print("BLOCK_PLACEMENT_TEST_RESULT PASS")
		quit(0)
	else:
		print("BLOCK_PLACEMENT_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_face_targeting() -> void:
	var hit := Vector3(10.0, 5.4, -2.6)
	_expect(InteractionMath.removal_voxel(hit, Vector3.RIGHT) == Vector3i(9, 5, -3), "break targets voxel behind face")
	_expect(InteractionMath.placement_voxel(hit, Vector3.RIGHT) == Vector3i(10, 5, -3), "place targets empty voxel outside face")


func _test_boundary_rebuilds() -> void:
	var affected: Array[Vector3i] = InteractionMath.affected_chunk_coordinates(Vector3i(31, 8, 12), VoxelChunk.SIZE)
	_expect(affected.has(Vector3i.ZERO), "placement rebuild includes owning chunk")
	_expect(affected.has(Vector3i.RIGHT), "placement at boundary rebuilds neighbor")
	_expect(affected.size() == 2, "single-axis boundary rebuild remains minimal")


func _test_mobile_action_zones() -> void:
	var viewport := Vector2(1920.0, 1080.0)
	var break_point := Vector2(viewport.x * 0.79, viewport.y * 0.59)
	var place_point := Vector2(viewport.x * 0.91, viewport.y * 0.59)
	_expect(ControlMath.is_break_zone(break_point, viewport), "break control owns its touch zone")
	_expect(ControlMath.is_place_zone(place_point, viewport), "place control owns its touch zone")
	_expect(not ControlMath.is_place_zone(break_point, viewport), "break and place zones do not overlap")
	_expect(not ControlMath.is_look_zone(place_point, viewport), "place touch is not consumed by camera look")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1