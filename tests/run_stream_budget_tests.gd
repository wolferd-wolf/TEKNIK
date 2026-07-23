extends SceneTree

const ChunkWorkBudget = preload("res://src/world/chunk_work_budget.gd")
const CollisionWindowPlan = preload("res://src/world/collision_window_plan.gd")
const MobileControlMath = preload("res://src/player/mobile_control_math.gd")
const ChunkStreamPlan = preload("res://src/world/chunk_stream_plan.gd")

var _failures: int = 0


func _init() -> void:
	_test_frame_budgeting()
	_test_replacement_cancels_stale_work()
	_test_negative_budgets_are_safe()
	_test_directional_chunk_priority()
	_test_directional_cache_guards()
	_test_collision_window_plan()
	_test_mobile_control_geometry()

	if _failures == 0:
		print("STREAM_BUDGET_TEST_RESULT PASS")
		quit(0)
	else:
		print("STREAM_BUDGET_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_frame_budgeting() -> void:
	var budget := ChunkWorkBudget.new()
	var loads: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)
	]
	var unloads: Array[Vector3i] = [Vector3i(-1, 0, 0), Vector3i(-2, 0, 0)]
	budget.replace(loads, unloads)

	var first: Dictionary = budget.take_frame(1, 1)
	_expect(first.load == [Vector3i(1, 0, 0)], "load order is deterministic")
	_expect(first.unload == [Vector3i(-1, 0, 0)], "unload order is deterministic")
	_expect(int(first.remaining_loads) == 2, "load work remains budgeted")
	_expect(int(first.remaining_unloads) == 1, "unload work remains budgeted")

	var second: Dictionary = budget.take_frame(2, 4)
	_expect(second.load == [Vector3i(2, 0, 0), Vector3i(3, 0, 0)], "later frame drains remaining loads")
	_expect(second.unload == [Vector3i(-2, 0, 0)], "later frame drains remaining unloads")
	_expect(not budget.has_work(), "queue reports completion")


func _test_replacement_cancels_stale_work() -> void:
	var budget := ChunkWorkBudget.new()
	budget.replace([Vector3i(10, 0, 0)], [Vector3i(-10, 0, 0)])
	budget.replace([Vector3i(20, 0, 0)], [])
	var frame: Dictionary = budget.take_frame(1, 1)
	_expect(frame.load == [Vector3i(20, 0, 0)], "new stream plan replaces stale loads")
	_expect(frame.unload.is_empty(), "new stream plan replaces stale unloads")


func _test_negative_budgets_are_safe() -> void:
	var budget := ChunkWorkBudget.new()
	budget.replace([Vector3i.ONE], [Vector3i.ZERO])
	var frame: Dictionary = budget.take_frame(-1, -1)
	_expect(frame.load.is_empty() and frame.unload.is_empty(), "negative budgets perform no work")
	_expect(budget.pending_load_count() == 1, "negative load budget preserves queue")
	_expect(budget.pending_unload_count() == 1, "negative unload budget preserves queue")


func _test_directional_chunk_priority() -> void:
	var coordinates: Array[Vector3i] = [
		Vector3i(-2, 0, 0), Vector3i(2, 0, 0),
		Vector3i(0, 0, -2), Vector3i(0, 0, 2),
	]
	var east: Array[Vector3i] = ChunkStreamPlan.sort_directional(
		coordinates, Vector3i.ZERO, Vector3i.ZERO, Vector2i.RIGHT
	)
	_expect(
		east.find(Vector3i(2, 0, 0)) < east.find(Vector3i(-2, 0, 0)),
		"eastward motion prioritizes the leading terrain edge"
	)
	var north: Array[Vector3i] = ChunkStreamPlan.sort_directional(
		coordinates, Vector3i.ZERO, Vector3i.ZERO, Vector2i(0, -1)
	)
	_expect(
		north.find(Vector3i(0, 0, -2)) < north.find(Vector3i(0, 0, 2)),
		"northward motion prioritizes the leading terrain edge"
	)
	var stationary: Array[Vector3i] = ChunkStreamPlan.sort_directional(
		[Vector3i(3, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)],
		Vector3i.ZERO,
		Vector3i.ZERO,
		Vector2i.ZERO
	)
	_expect(
		stationary == [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)],
		"stationary streaming remains nearest first"
	)


func _test_directional_cache_guards() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://src/main/movement_streaming_main.gd"
	)
	_expect(source.contains("CHUNK_CACHE_LIMIT: int = 8"), "chunk reuse cache is bounded")
	_expect(source.contains("CACHE_COMMITS_PER_FRAME: int = 1"), "cache commits remain frame budgeted")
	_expect(source.contains("snapshot_neighborhood(coordinate).is_empty()"), "edited neighborhoods bypass cached terrain")
	_expect(source.contains("_cache_chunk_before_unload(coordinate)"), "unloaded terrain is captured before destruction")
	var scene: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	_expect(scene.contains("movement_streaming_main.gd"), "shipping scene enables directional streaming")


func _test_collision_window_plan() -> void:
	var desired: Array[Vector3i] = CollisionWindowPlan.desired(Vector3i.ZERO, 1)
	_expect(desired.size() == 9, "collision window limits physics to three by three chunks")
	_expect(desired.has(Vector3i.ZERO), "collision window includes player chunk")
	var active: Dictionary = {}
	for coordinate: Vector3i in desired:
		active[coordinate] = true
	var shifted: Dictionary = CollisionWindowPlan.reconcile(active, Vector3i(1, 0, 0), 1)
	_expect(shifted.add.size() == 3, "one chunk shift adds only the leading collision edge")
	_expect(shifted.remove.size() == 3, "one chunk shift removes only the trailing collision edge")
	_expect(shifted.add[0] == Vector3i(2, 0, 0), "nearest new collision chunk is prioritized")


func _test_mobile_control_geometry() -> void:
	var viewport := Vector2(1280.0, 720.0)
	_expect(MobileControlMath.is_movement_zone(Vector2(120.0, 600.0), viewport), "left screen is reserved for movement")
	_expect(MobileControlMath.is_look_zone(Vector2(760.0, 300.0), viewport), "right screen is reserved for camera look")
	_expect(MobileControlMath.is_jump_zone(Vector2(1113.6, 561.6), viewport), "jump button uses deterministic lower-right placement")
	var half_stick: Vector2 = MobileControlMath.stick_vector(Vector2.ZERO, Vector2(46.0, 0.0), 92.0)
	_expect(is_equal_approx(half_stick.x, 0.5), "virtual stick preserves partial analog movement")
	var clamped: Vector2 = MobileControlMath.stick_vector(Vector2.ZERO, Vector2(400.0, 0.0), 92.0)
	_expect(is_equal_approx(clamped.length(), 1.0), "virtual stick clamps movement magnitude")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		_failures += 1
		push_error("FAIL %s" % message)
