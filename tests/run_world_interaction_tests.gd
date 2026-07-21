extends SceneTree

const InteractionMath = preload("res://src/world/world_interaction_math.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

var _failures: int = 0


func _init() -> void:
	_expect(InteractionMath.removal_voxel(Vector3(4.0, 8.4, -2.6), Vector3.RIGHT) == Vector3i(3, 8, -3), "removal targets voxel behind hit face")
	_expect(InteractionMath.placement_voxel(Vector3(4.0, 8.4, -2.6), Vector3.RIGHT) == Vector3i(4, 8, -3), "placement targets voxel outside hit face")
	var interior: Array[Vector3i] = InteractionMath.affected_chunk_coordinates(Vector3i(7, 4, 9), VoxelChunk.SIZE)
	_expect(interior == [Vector3i.ZERO], "interior edit rebuilds one chunk")
	var edge: Array[Vector3i] = InteractionMath.affected_chunk_coordinates(Vector3i(31, 4, 0), VoxelChunk.SIZE)
	_expect(edge.has(Vector3i.ZERO), "boundary edit includes owning chunk")
	_expect(edge.has(Vector3i.RIGHT), "positive x boundary includes neighbor")
	_expect(edge.has(Vector3i(0, 0, -1)), "negative z boundary includes neighbor")
	var negative: Array[Vector3i] = InteractionMath.affected_chunk_coordinates(Vector3i(-32, 3, -1), VoxelChunk.SIZE)
	_expect(negative.has(Vector3i(-1, 0, -1)), "negative coordinate maps to floor chunk")
	_expect(negative.has(Vector3i(-2, 0, -1)), "negative boundary includes previous chunk")
	if _failures == 0:
		print("WORLD_INTERACTION_TEST_RESULT PASS")
		quit(0)
	else:
		print("WORLD_INTERACTION_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		_failures += 1
		push_error("FAIL %s" % message)
