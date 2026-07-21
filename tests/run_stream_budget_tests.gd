extends SceneTree

const ChunkWorkBudget = preload("res://src/world/chunk_work_budget.gd")
const CollisionWindowPlan = preload("res://src/world/collision_window_plan.gd")
const MobileControlMath = preload("res://src/player/mobile_control_math.gd")

var _failures: int = 0


func _init() -> void:
	_test_frame_budgeting()
	_test_replacement_cancels_stale_work()
	_test_negative_budgets_are_safe()
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
