extends SceneTree

const WorkBudget = preload("res://src/world/chunk_work_budget.gd")
const CollisionWindowPlan = preload("res://src/world/collision_window_plan.gd")
const MobileControlLayout = preload("res://src/player/mobile_control_layout.gd")
const MovementStreamingMain = preload("res://src/main/movement_streaming_main.gd")

var _failures: int = 0


func _init() -> void:
	_test_budgeted_queue_order()
	_test_queue_replacement()
	_test_negative_budgets()
	_test_directional_load_order()
	_test_directional_cache_guards()
	_test_collision_window_plan()
	_test_mobile_layout()
	if _failures == 0:
		print("STREAM_BUDGET_TEST_RESULT PASS")
		quit(0)
	else:
		print("STREAM_BUDGET_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_budgeted_queue_order() -> void:
	var budget := WorkBudget.new()
	var load_order: Array[Vector3i] = [Vector3i(2, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 0)]
	var unload_order: Array[Vector3i] = [Vector3i(-2, 0, 0), Vector3i(-1, 0, 0)]
	budget.replace(load_order, unload_order)
	var first_loads: Array[Vector3i] = []
	var first_unloads: Array[Vector3i] = []
	var first: Dictionary = budget.process(
		func(coordinate: Vector3i) -> void:
			first_loads.append(coordinate),
		func(coordinate: Vector3i) -> void:
			first_unloads.append(coordinate),
		2,
		1
	)
	_expect(first_loads == [Vector3i(2, 0, 0), Vector3i(1, 0, 0)], "load order is deterministic")
	_expect(first_unloads == [Vector3i(-2, 0, 0)], "unload order is deterministic")
	_expect(int(first.loads) == 2, "load work remains budgeted")
	_expect(int(first.unloads) == 1, "unload work remains budgeted")
	var second_loads: Array[Vector3i] = []
	var second_unloads: Array[Vector3i] = []
	var second: Dictionary = budget.process(
		func(coordinate: Vector3i) -> void:
			second_loads.append(coordinate),
		func(coordinate: Vector3i) -> void:
			second_unloads.append(coordinate),
		2,
		1
	)
	_expect(second_loads == [Vector3i(0, 0, 0)], "later frame drains remaining loads")
	_expect(second_unloads == [Vector3i(-1, 0, 0)], "later frame drains remaining unloads")
	_expect(bool(second.complete), "queue reports completion")


func _test_queue_replacement() -> void:
	var budget := WorkBudget.new()
	budget.replace([Vector3i(9, 0, 0)], [Vector3i(-9, 0, 0)])
	budget.replace([Vector3i(4, 0, 0)], [Vector3i(-4, 0, 0)])
	var loads: Array[Vector3i] = []
	var unloads: Array[Vector3i] = []
	budget.process(
		func(coordinate: Vector3i) -> void:
			loads.append(coordinate),
		func(coordinate: Vector3i) -> void:
			unloads.append(coordinate),
		1,
		1
	)
	_expect(loads == [Vector3i(4, 0, 0)], "new stream plan replaces stale loads")
	_expect(unloads == [Vector3i(-4, 0, 0)], "new stream plan replaces stale unloads")


func _test_negative_budgets() -> void:
	var budget := WorkBudget.new()
	budget.replace([Vector3i.ONE], [Vector3i(-1, -1, -1)])
	var report: Dictionary = budget.process(Callable(), Callable(), -1, -1)
	_expect(int(report.loads) == 0 and int(report.unloads) == 0, "negative budgets perform no work")
	_expect(budget.pending_load_count() == 1, "negative load budget preserves queue")
	_expect(budget.pending_unload_count() == 1, "negative unload budget preserves queue")


func _test_directional_load_order() -> void:
	var incoming: Array[Vector3i] = [
		Vector3i(-2, 0, 0),
		Vector3i(-1, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(2, 0, 0),
		Vector3i(3, 0, 0),
	]
	var eastward: Array[Vector3i] = MovementStreamingMain.directional_priority_order(
		incoming,
		Vector3i.ZERO,
		Vector2i.RIGHT
	)
	_expect(eastward.slice(0, 3) == [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)], "eastward motion prioritizes the leading terrain edge")
	var northward: Array[Vector3i] = MovementStreamingMain.directional_priority_order(
		[Vector3i(0, 0, -3), Vector3i(0, 0, -2), Vector3i(0, 0, 1)],
		Vector3i.ZERO,
		Vector2i(0, -1)
	)
	_expect(northward.slice(0, 2) == [Vector3i(0, 0, -2), Vector3i(0, 0, -3)], "northward motion prioritizes the leading terrain edge")
	var stationary: Array[Vector3i] = MovementStreamingMain.directional_priority_order(
		[Vector3i(3, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)],
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
	_expect(source.contains("CHUNK_CACHE_LIMIT: int = 16"), "chunk reuse cache retains both strips of a reversal")
	_expect(source.contains("CACHE_COMMITS_PER_FRAME: int = 1"), "cache commits remain frame budgeted")
	_expect(source.contains("snapshot_neighborhood(coordinate).is_empty()"), "edited neighborhoods bypass cached terrain")
	_expect(source.contains("_cache_chunk_before_unload(coordinate)"), "unloaded terrain is captured before destruction")
	var scene: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var kinetic: String = FileAccess.get_file_as_string("res://src/main/kinetic_machine_main.gd")
	var survival_shipping: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
	var engineering: String = FileAccess.get_file_as_string("res://src/main/engineering_progression_main.gd")
	var survival: String = FileAccess.get_file_as_string("res://src/main/survival_main.gd")
	var multi_lod: String = FileAccess.get_file_as_string("res://src/main/multi_lod_main.gd")
	var collision: String = FileAccess.get_file_as_string("res://src/main/incremental_collision_main.gd")
	_expect(
		scene.contains("kinetic_machine_main.gd")
		and kinetic.contains("survival_shipping_main.gd")
		and survival_shipping.contains("engineering_progression_main.gd")
		and engineering.contains("survival_main.gd")
		and survival.contains("multi_lod_main.gd")
		and multi_lod.contains("incremental_collision_main.gd")
		and collision.contains("movement_streaming_main.gd"),
		"shipping scene enables directional streaming through the kinetic survival stack"
	)


func _test_collision_window_plan() -> void:
	var desired: Array[Vector3i] = CollisionWindowPlan.desired(Vector3i.ZERO, 1)
	_expect(desired.size() == 9, "collision window limits physics to three by three chunks")
	_expect(desired.has(Vector3i.ZERO), "collision window includes player chunk")
	var active: Dictionary = {}
	for coordinate: Vector3i in desired:
		active[coordinate] = true
	var shifted: Array[Vector3i] = CollisionWindowPlan.desired(Vector3i.RIGHT, 1)
	var additions: Array[Vector3i] = CollisionWindowPlan.additions(active, shifted, Vector3i.RIGHT)
	var removals: Array[Vector3i] = CollisionWindowPlan.removals(active, shifted, Vector3i.RIGHT)
	_expect(additions.size() == 3, "one chunk shift adds only the leading collision edge")
	_expect(removals.size() == 3, "one chunk shift removes only the trailing edge")
	_expect(additions[0].distance_squared_to(Vector3i.RIGHT) <= additions[-1].distance_squared_to(Vector3i.RIGHT), "nearest new collision chunk is prioritized")


func _test_mobile_layout() -> void:
	var layout: Dictionary = MobileControlLayout.for_viewport(Vector2(1280.0, 720.0))
	var move_rect: Rect2 = layout.move_rect
	var look_rect: Rect2 = layout.look_rect
	var jump_rect: Rect2 = layout.jump_rect
	_expect(move_rect.end.x <= 640.0, "left screen is reserved for movement")
	_expect(look_rect.position.x >= 640.0, "right screen is reserved for camera look")
	_expect(jump_rect.position.x > 640.0 and jump_rect.position.y > 360.0, "jump button uses deterministic lower-right placement")
	_expect(MobileControlLayout.clamp_stick(Vector2(0.5, 0.0)) == Vector2(0.5, 0.0), "virtual stick preserves partial analog movement")
	_expect(MobileControlLayout.clamp_stick(Vector2(2.0, 0.0)).is_equal_approx(Vector2.RIGHT), "virtual stick clamps movement magnitude")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
