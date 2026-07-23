extends "res://src/main/procedural_world_main.gd"

const ProceduralFeaturePlanner = preload("res://src/world/procedural_feature_planner.gd")

const ECOLOGY_IDLE: int = 0
const ECOLOGY_GENERATING: int = 1
const ECOLOGY_COMMITTING: int = 2
const ECOLOGY_GROUPS_PER_FRAME: int = 1

var _ecology_state: int = ECOLOGY_IDLE
var _ecology_thread: Thread
var _ecology_planner: RefCounted
var _ecology_plan: Dictionary = {}
var _ecology_groups: Array[Dictionary] = []
var _ecology_group_index: int = 0
var _ecology_commit_frames: int = 0
var _ecology_commit_peak_usec: int = 0
var _ecology_last_generation_usec: int = 0
var _ecology_refresh_started_usec: int = 0


func _camera_position() -> Vector3:
	if not _qa_screenshot_path().is_empty():
		return super._camera_position()
	if _player != null:
		return _player.global_position
	return _planned_spawn


func _rebuild_streamed_features() -> void:
	if _feature_root != null:
		remove_child(_feature_root)
		_feature_root.queue_free()
		_render_instance_count -= _streamed_feature_instances
	_streamed_feature_instances = 0
	_feature_root = Node3D.new()
	_feature_root.name = "StreamedWorldFeatures"
	add_child(_feature_root)
	# Water is cheap and should be present immediately. Expensive ecology planning is
	# deferred until terrain and collision streaming are idle.
	_build_water()
	_feature_refresh_pending = true


func _process_environment_refresh_if_idle() -> void:
	if _ecology_state == ECOLOGY_GENERATING:
		_poll_ecology_generation()
		return
	if _ecology_state == ECOLOGY_COMMITTING:
		if _world_center != _feature_refresh_target:
			_cancel_ecology_commit("center_changed")
			_feature_refresh_pending = true
			return
		_commit_ecology_groups()
		return
	if not _feature_refresh_pending:
		return
	if Time.get_ticks_msec() - _last_center_change_ms < ENVIRONMENT_IDLE_DELAY_MS:
		return
	if (
		_chunk_work_budget.has_work()
		or not _edit_rebuild_queue.is_empty()
		or not _emergency_load_queue.is_empty()
		or _playable_pool.is_busy()
		or not _collision_add_queue.is_empty()
	):
		return
	_begin_ecology_generation()


func _begin_ecology_generation() -> void:
	_feature_refresh_target = _world_center
	_ecology_refresh_started_usec = Time.get_ticks_usec()
	_ecology_planner = ProceduralFeaturePlanner.new()
	_ecology_thread = Thread.new()
	var exclusion_position: Vector3 = _planned_spawn
	var start_result: Error = _ecology_thread.start(
		Callable(_ecology_planner, "build").bind(
			WORLD_SEED,
			_feature_refresh_target,
			CHUNK_RADIUS,
			VoxelChunk.SIZE,
			exclusion_position
		)
	)
	if start_result != OK:
		_runtime_log.event("error", "environment", "ecology_worker_start_failed", {
			"center": str(_feature_refresh_target),
			"error": error_string(start_result),
		})
		_ecology_thread = null
		_ecology_planner = null
		return
	_ecology_state = ECOLOGY_GENERATING
	_feature_refresh_pending = false
	_runtime_log.event("info", "environment", "ecology_generation_started", {
		"center": str(_feature_refresh_target),
		"old_features_visible": true,
	})


func _poll_ecology_generation() -> void:
	if _ecology_thread == null or _ecology_thread.is_alive():
		return
	var completed_plan: Variant = _ecology_thread.wait_to_finish()
	_ecology_thread = null
	_ecology_planner = null
	if not completed_plan is Dictionary:
		_ecology_state = ECOLOGY_IDLE
		_feature_refresh_pending = true
		_runtime_log.event("error", "environment", "ecology_generation_invalid", {
			"center": str(_feature_refresh_target),
		})
		return
	_ecology_plan = completed_plan
	_ecology_last_generation_usec = int(_ecology_plan.get("generation_usec", 0))
	if _world_center != _feature_refresh_target:
		_runtime_log.event("info", "environment", "ecology_generation_stale", {
			"generated_center": str(_feature_refresh_target),
			"current_center": str(_world_center),
			"generation_usec": _ecology_last_generation_usec,
		})
		_ecology_plan.clear()
		_ecology_state = ECOLOGY_IDLE
		_feature_refresh_pending = true
		return
	_begin_ecology_commit()


func _begin_ecology_commit() -> void:
	_feature_previous_root = _feature_root
	_feature_previous_instances = _streamed_feature_instances
	_feature_root = Node3D.new()
	_feature_root.name = "StreamedWorldFeaturesStaging"
	_feature_root.visible = false
	add_child(_feature_root)
	_streamed_feature_instances = 0
	_ecology_groups = _make_ecology_groups(_ecology_plan)
	_ecology_group_index = -1
	_ecology_commit_frames = 0
	_ecology_commit_peak_usec = 0
	_ecology_state = ECOLOGY_COMMITTING
	_runtime_log.event("info", "environment", "ecology_generation_complete", {
		"center": str(_feature_refresh_target),
		"generation_usec": _ecology_last_generation_usec,
		"groups": _ecology_groups.size() + 1,
		"trees": int(_ecology_plan.get("tree_count", 0)),
		"boulders": int(_ecology_plan.get("boulder_count", 0)),
		"ground_parts": int(_ecology_plan.get("ground_part_count", 0)),
	})


func _commit_ecology_groups() -> void:
	var groups_committed: int = 0
	var frame_started_usec: int = Time.get_ticks_usec()
	while groups_committed < ECOLOGY_GROUPS_PER_FRAME:
		if _ecology_group_index < 0:
			_build_water()
			_ecology_group_index = 0
			groups_committed += 1
			continue
		while (
			_ecology_group_index < _ecology_groups.size()
			and (_ecology_groups[_ecology_group_index]["transforms"] as Array).is_empty()
		):
			_ecology_group_index += 1
		if _ecology_group_index >= _ecology_groups.size():
			_finish_ecology_commit()
			return
		var group: Dictionary = _ecology_groups[_ecology_group_index]
		var transforms: Array = group["transforms"]
		var color: Color = group["color"]
		_add_tree_multimesh(
			_voxel_box_mesh(color, 1.0),
			transforms,
			bool(group["cast_shadows"])
		)
		_ecology_group_index += 1
		groups_committed += 1
	_ecology_commit_frames += 1
	var commit_usec: int = Time.get_ticks_usec() - frame_started_usec
	_ecology_commit_peak_usec = maxi(_ecology_commit_peak_usec, commit_usec)
	if commit_usec > 8_000:
		_runtime_log.event("warning", "environment", "ecology_commit_slow_frame", {
			"center": str(_feature_refresh_target),
			"group_index": _ecology_group_index,
			"usec": commit_usec,
		})


func _finish_ecology_commit() -> void:
	if _feature_previous_root != null:
		remove_child(_feature_previous_root)
		_feature_previous_root.queue_free()
		_render_instance_count -= _feature_previous_instances
	_feature_root.name = "StreamedWorldFeatures"
	_feature_root.visible = true
	_feature_center = _feature_refresh_target
	_tree_count = int(_ecology_plan.get("tree_count", 0))
	_boulder_count = int(_ecology_plan.get("boulder_count", 0))
	_grass_count = int(_ecology_plan.get("ground_part_count", 0))
	_last_environment_refresh_usec = Time.get_ticks_usec() - _ecology_refresh_started_usec
	_runtime_log.event("info", "environment", "playable_features_refreshed", {
		"center": str(_feature_center),
		"usec": _last_environment_refresh_usec,
		"generation_usec": _ecology_last_generation_usec,
		"commit_peak_usec": _ecology_commit_peak_usec,
		"commit_frames": _ecology_commit_frames,
		"instances": _streamed_feature_instances,
		"groups": _ecology_groups.size() + 1,
		"old_features_visible_during_build": true,
		"distant_refresh_deferred": _distant_refresh_pending,
	})
	_feature_previous_root = null
	_feature_previous_instances = 0
	_ecology_plan.clear()
	_ecology_groups.clear()
	_ecology_group_index = 0
	_ecology_state = ECOLOGY_IDLE
	_feature_refresh_stage = -1
	_feature_refresh_pending = _world_center != _feature_center


func _cancel_ecology_commit(reason: String) -> void:
	var discarded_instances: int = _streamed_feature_instances
	if _feature_root != null and _feature_root != _feature_previous_root:
		remove_child(_feature_root)
		_feature_root.queue_free()
		_render_instance_count -= discarded_instances
	_feature_root = _feature_previous_root
	_streamed_feature_instances = _feature_previous_instances
	_runtime_log.event("info", "environment", "ecology_commit_cancelled", {
		"reason": reason,
		"target": str(_feature_refresh_target),
		"current": str(_world_center),
		"discarded_instances": discarded_instances,
	})
	_feature_previous_root = null
	_feature_previous_instances = 0
	_ecology_plan.clear()
	_ecology_groups.clear()
	_ecology_group_index = 0
	_ecology_state = ECOLOGY_IDLE
	_feature_refresh_stage = -1


func _make_ecology_groups(plan: Dictionary) -> Array[Dictionary]:
	return [
		_group("trunks", plan, Color("5b4030"), true),
		_group("broadleaf_lower", plan, Color("2f5d38"), true),
		_group("broadleaf_upper", plan, Color("477a49"), true),
		_group("broadleaf_side", plan, Color("386c40"), true),
		_group("conifer_lower", plan, Color("244936"), true),
		_group("conifer_middle", plan, Color("2d5a3e"), true),
		_group("conifer_upper", plan, Color("3b6d48"), true),
		_group("fallen_logs", plan, Color("654733"), true),
		_group("cool_rock_primary", plan, Color("667471"), true),
		_group("cool_rock_secondary", plan, Color("7c8783"), true),
		_group("warm_rock_primary", plan, Color("756f63"), true),
		_group("warm_rock_secondary", plan, Color("8b8170"), true),
		_group("lush_tufts", plan, Color("315f31"), false),
		_group("dry_tufts", plan, Color("716a3b"), false),
		_group("shrubs_lower", plan, Color("2d5c36"), false),
		_group("shrubs_upper", plan, Color("3a7042"), false),
	]


func _group(
	key: String,
	plan: Dictionary,
	color: Color,
	cast_shadows: bool
) -> Dictionary:
	return {
		"name": key,
		"transforms": plan.get(key, []),
		"color": color,
		"cast_shadows": cast_shadows,
	}


func _diagnostic_context() -> Dictionary:
	var context: Dictionary = super._diagnostic_context()
	context["ecology_refresh_state"] = _ecology_state
	context["ecology_generation_active"] = (
		_ecology_thread != null and _ecology_thread.is_alive()
	)
	context["ecology_commit_group"] = _ecology_group_index
	context["ecology_commit_group_total"] = _ecology_groups.size()
	context["ecology_last_generation_usec"] = _ecology_last_generation_usec
	context["ecology_commit_peak_usec"] = _ecology_commit_peak_usec
	context["ecology_commit_frames"] = _ecology_commit_frames
	return context


func _notification(what: int) -> void:
	if (
		(what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE)
		and _ecology_thread != null
	):
		_ecology_thread.wait_to_finish()
		_ecology_thread = null
		_ecology_planner = null
	super._notification(what)
