extends SceneTree

const Scheduler = preload("res://src/world/collision_stream_scheduler.gd")

var _failures: int = 0


func _init() -> void:
	_test_directional_add_order()
	_test_remove_order()
	_test_adaptive_budget()
	_test_shipping_scene()
	if _failures == 0:
		print("COLLISION_STREAM_SCHEDULER_RESULT PASS")
		quit(0)
	else:
		print("COLLISION_STREAM_SCHEDULER_RESULT FAIL count=", _failures)
		quit(1)


func _test_directional_add_order() -> void:
	var center := Vector3i.ZERO
	var coordinates: Array[Vector3i] = [
		Vector3i(-1, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(0, 0, 1),
		Vector3i(0, 0, -1),
	]
	var ordered: Array[Vector3i] = Scheduler.ordered_adds(coordinates, center, Vector2i.RIGHT)
	_expect(ordered[0] == Vector3i(1, 0, 0), "collision adds prioritize the movement direction")
	_expect(ordered == Scheduler.ordered_adds(coordinates, center, Vector2i.RIGHT), "collision add ordering is deterministic")


func _test_remove_order() -> void:
	var coordinates: Array[Vector3i] = [
		Vector3i(1, 0, 0),
		Vector3i(3, 0, 0),
		Vector3i(2, 0, 0),
	]
	var ordered: Array[Vector3i] = Scheduler.ordered_removes(coordinates, Vector3i.ZERO)
	_expect(ordered[0] == Vector3i(3, 0, 0), "collision removals release the farthest body first")


func _test_adaptive_budget() -> void:
	var reduced: int = Scheduler.next_budget_usec(1600, 2200)
	var increased: int = Scheduler.next_budget_usec(1600, 400)
	_expect(reduced < 1600 and reduced >= Scheduler.MIN_BUDGET_USEC, "slow collision commits reduce the next frame budget")
	_expect(increased > 1600 and increased <= Scheduler.MAX_BUDGET_USEC, "cheap collision commits cautiously grow the next frame budget")
	_expect(Scheduler.next_budget_usec(Scheduler.MIN_BUDGET_USEC, 9999) == Scheduler.MIN_BUDGET_USEC, "collision budget respects its minimum")


func _test_shipping_scene() -> void:
	var scene: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var kinetic: String = FileAccess.get_file_as_string("res://src/main/kinetic_machine_main.gd")
	var survival_shipping: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
	var engineering: String = FileAccess.get_file_as_string("res://src/main/engineering_progression_main.gd")
	var survival: String = FileAccess.get_file_as_string("res://src/main/survival_main.gd")
	var multi_lod: String = FileAccess.get_file_as_string("res://src/main/multi_lod_main.gd")
	var source: String = FileAccess.get_file_as_string("res://src/main/incremental_collision_main.gd")
	_expect(
		scene.contains("kinetic_machine_main.gd")
		and kinetic.contains("survival_shipping_main.gd")
		and survival_shipping.contains("engineering_progression_main.gd")
		and engineering.contains("survival_main.gd")
		and survival.contains("multi_lod_main.gd")
		and multi_lod.contains("incremental_collision_main.gd"),
		"shipping scene enables incremental collision streaming through the kinetic survival stack"
	)
	_expect(source.contains("_collision_frame_budget_usec") and source.contains("incremental_frame"), "shipping collision work is measured and frame-budgeted")
	_expect(source.contains("extends \"res://src/main/movement_streaming_main.gd\""), "incremental collision keeps directional streaming and chunk-local vegetation")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		_failures += 1
		push_error("FAIL %s" % message)
