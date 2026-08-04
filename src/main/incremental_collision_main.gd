extends "res://src/main/movement_streaming_main.gd"

const CollisionStreamScheduler = preload("res://src/world/collision_stream_scheduler.gd")
const COLLISION_MAX_ADDS_PER_FRAME: int = 2
const COLLISION_MAX_REMOVES_PER_FRAME: int = 2

var _collision_frame_budget_usec: int = CollisionStreamScheduler.DEFAULT_BUDGET_USEC
var _collision_budget_exhaustions: int = 0
var _collision_stream_frames: int = 0
var _collision_adds_completed: int = 0
var _collision_removes_completed: int = 0


func _ready() -> void:
	super._ready()
	_runtime_log.event("info", "collision", "incremental_streaming_ready", {
		"budget_usec": _collision_frame_budget_usec,
		"max_adds_per_frame": COLLISION_MAX_ADDS_PER_FRAME,
		"max_removes_per_frame": COLLISION_MAX_REMOVES_PER_FRAME,
		"vegetation_untouched": true,
	})


func _queue_collision_window(center: Vector3i) -> void:
	_collision_center = center
	var delta: Dictionary = CollisionWindowPlan.reconcile(_collision_bodies, center, COLLISION_RADIUS)
	var adds: Array[Vector3i] = delta.add
	var removes: Array[Vector3i] = delta.remove
	_collision_add_queue = CollisionStreamScheduler.ordered_adds(
		adds,
		center,
		_movement_chunk_direction
	)
	_collision_remove_queue = CollisionStreamScheduler.ordered_removes(removes, center)
	_runtime_log.event("info", "collision", "incremental_window_queued", {
		"center": str(center),
		"direction": str(_movement_chunk_direction),
		"adds": _collision_add_queue.size(),
		"removes": _collision_remove_queue.size(),
		"budget_usec": _collision_frame_budget_usec,
	})


func _process_collision_work() -> void:
	if _collision_add_queue.is_empty() and _collision_remove_queue.is_empty():
		return
	var frame_started_usec: int = Time.get_ticks_usec()
	var changed: bool = false
	var removes: int = 0
	while removes < COLLISION_MAX_REMOVES_PER_FRAME and not _collision_remove_queue.is_empty():
		_remove_chunk_collision(_collision_remove_queue.pop_front())
		removes += 1
		_collision_removes_completed += 1
		changed = true
		if Time.get_ticks_usec() - frame_started_usec >= _collision_frame_budget_usec:
			break

	var adds: int = 0
	while adds < COLLISION_MAX_ADDS_PER_FRAME and not _collision_add_queue.is_empty():
		if Time.get_ticks_usec() - frame_started_usec >= _collision_frame_budget_usec:
			break
		var coordinate: Vector3i = _collision_add_queue.pop_front()
		var commit_started_usec: int = Time.get_ticks_usec()
		if not _add_chunk_collision(coordinate) and _terrain_nodes.has(coordinate):
			_collision_add_queue.append(coordinate)
		else:
			adds += 1
			_collision_adds_completed += 1
			changed = true
		var commit_usec: int = Time.get_ticks_usec() - commit_started_usec
		_collision_frame_budget_usec = CollisionStreamScheduler.next_budget_usec(
			_collision_frame_budget_usec,
			commit_usec
		)

	var frame_usec: int = Time.get_ticks_usec() - frame_started_usec
	_collision_stream_frames += 1
	if frame_usec >= _collision_frame_budget_usec and (
		not _collision_add_queue.is_empty() or not _collision_remove_queue.is_empty()
	):
		_collision_budget_exhaustions += 1
	if changed:
		_performance_telemetry.record_collision(frame_usec)
	_runtime_log.event("info", "collision", "incremental_frame", {
		"usec": frame_usec,
		"budget_usec": _collision_frame_budget_usec,
		"adds": adds,
		"removes": removes,
		"pending_adds": _collision_add_queue.size(),
		"pending_removes": _collision_remove_queue.size(),
		"budget_exhaustions": _collision_budget_exhaustions,
	})


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["collision_budget_usec"] = _collision_frame_budget_usec
	snapshot["collision_stream_frames"] = _collision_stream_frames
	snapshot["collision_budget_exhaustions"] = _collision_budget_exhaustions
	snapshot["collision_adds_completed"] = _collision_adds_completed
	snapshot["collision_removes_completed"] = _collision_removes_completed
	return snapshot


func _diagnostic_context() -> Dictionary:
	var context: Dictionary = super._diagnostic_context()
	context["collision_budget_usec"] = _collision_frame_budget_usec
	context["collision_stream_frames"] = _collision_stream_frames
	context["collision_budget_exhaustions"] = _collision_budget_exhaustions
	context["collision_adds_completed"] = _collision_adds_completed
	context["collision_removes_completed"] = _collision_removes_completed
	return context
