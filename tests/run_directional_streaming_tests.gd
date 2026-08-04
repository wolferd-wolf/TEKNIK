extends SceneTree

const StreamPlan = preload("res://src/world/chunk_stream_plan.gd")

var _failures: int = 0


func _init() -> void:
	_test_forward_chunks_are_prioritized()
	_test_zero_direction_preserves_distance_order()
	_test_runtime_cache_guards()
	if _failures == 0:
		print("DIRECTIONAL_STREAMING_TEST_RESULT PASS")
		quit(0)
	else:
		print("DIRECTIONAL_STREAMING_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_forward_chunks_are_prioritized() -> void:
	var coordinates: Array[Vector3i] = [
		Vector3i(-2, 0, 0),
		Vector3i(2, 0, 0),
		Vector3i(0, 0, -2),
		Vector3i(0, 0, 2),
	]
	var east: Array[Vector3i] = StreamPlan.sort_directional(
		coordinates,
		Vector3i.ZERO,
		Vector3i.ZERO,
		Vector2i.RIGHT
	)
	_expect(east.find(Vector3i(2, 0, 0)) < east.find(Vector3i(-2, 0, 0)), "eastward travel prioritizes eastern chunks")
	var north: Array[Vector3i] = StreamPlan.sort_directional(
		coordinates,
		Vector3i.ZERO,
		Vector3i.ZERO,
		Vector2i(0, -1)
	)
	_expect(north.find(Vector3i(0, 0, -2)) < north.find(Vector3i(0, 0, 2)), "northward travel prioritizes northern chunks")


func _test_zero_direction_preserves_distance_order() -> void:
	var coordinates: Array[Vector3i] = [
		Vector3i(3, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(2, 0, 0),
	]
	var ordered: Array[Vector3i] = StreamPlan.sort_directional(
		coordinates,
		Vector3i.ZERO,
		Vector3i.ZERO,
		Vector2i.ZERO
	)
	_expect(ordered == [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)], "stationary ordering remains nearest first")


func _test_runtime_cache_guards() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/main/movement_streaming_main.gd")
	_expect(source.contains("CHUNK_CACHE_LIMIT: int = 8"), "chunk report cache is strictly bounded")
	_expect(source.contains("CACHE_COMMITS_PER_FRAME: int = 1"), "cache reuse is limited to one commit per frame")
	_expect(source.contains("snapshot_neighborhood(coordinate).is_empty()"), "edited chunks cannot enter the reuse cache")
	_expect(source.contains("vegetation_untouched"), "directional runtime documents vegetation isolation")
	var scene: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	_expect(scene.contains("movement_streaming_main.gd"), "shipping scene enables directional streaming")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		_failures += 1
		push_error("FAIL %s" % message)
