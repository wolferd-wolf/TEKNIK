extends "res://src/main/procedural_gameplay_main.gd"

const DistantTerrainPlanner = preload("res://src/world/distant_terrain_planner.gd")

const DISTANT_IDLE: int = 0
const DISTANT_GENERATING: int = 1
const DISTANT_READY: int = 2

var _distant_state: int = DISTANT_IDLE
var _distant_thread: Thread
var _distant_planner: RefCounted
var _distant_plan: Dictionary = {}
var _distant_target: Vector3i = Vector3i.ZERO
var _distant_generation_usec: int = 0
var _distant_commit_usec: int = 0


func _refresh_world_window(center: Vector3i, priority: Vector3i) -> void:
	var previous_center: Vector3i = _world_center
	super._refresh_world_window(center, priority)
	# Ecology must track the same residency center as terrain. The previous design
	# refreshed only every three chunks and kept the old batch visible, leaving
	# trees and ground cover floating after their supporting chunks unloaded.
	if center != previous_center and center != _feature_center:
		_rebuild_streamed_features()


func _rebuild_streamed_features() -> void:
	# Never retain an ecology batch whose terrain window is no longer resident.
	# Its detached shadows were also the source of the long triangular artifacts
	# seen in physical-device gameplay.
	if _ecology_state == ECOLOGY_COMMITTING:
		_cancel_ecology_commit("terrain_center_changed")
	if _feature_root != null:
		remove_child(_feature_root)
		_feature_root.queue_free()
		_render_instance_count -= _streamed_feature_instances
	_feature_previous_root = null
	_feature_previous_instances = 0
	_streamed_feature_instances = 0
	_feature_root = Node3D.new()
	_feature_root.name = "StreamedWorldFeatures"
	add_child(_feature_root)
	_build_water()
	_feature_refresh_pending = true
	_runtime_log.event("info", "environment", "ecology_invalidated_with_terrain", {
		"old_center": str(_feature_center),
		"target_center": str(_world_center),
		"stale_features_removed": true,
		"visible_instances": _streamed_feature_instances,
	})


func _process_environment_refresh_if_idle() -> void:
	if _distant_state == DISTANT_GENERATING:
		_poll_distant_generation()
		return
	if _distant_state == DISTANT_READY:
		if _can_start_background_environment_work():
			_commit_distant_plan()
		return
	super._process_environment_refresh_if_idle()
	if _ecology_state != ECOLOGY_IDLE or _feature_refresh_pending:
		return
	if not _distant_refresh_pending:
		return
	if not _can_start_background_environment_work():
		return
	_begin_distant_generation()


func _can_start_background_environment_work() -> bool:
	if Time.get_ticks_msec() - _last_center_change_ms < ENVIRONMENT_IDLE_DELAY_MS:
		return false
	return (
		not _chunk_work_budget.has_work()
		and _edit_rebuild_queue.is_empty()
		and _emergency_load_queue.is_empty()
		and not _playable_pool.is_busy()
		and _collision_add_queue.is_empty()
	)


func _begin_ecology_generation() -> void:
	_feature_refresh_target = _world_center
	_ecology_refresh_started_usec = Time.get_ticks_usec()
	_ecology_planner = ProceduralFeaturePlanner.new()
	_ecology_thread = Thread.new()
	var observer_position: Vector3 = (
		_player.global_position if _player != null else _planned_spawn
	)
	var start_result: Error = _ecology_thread.start(
		Callable(_ecology_planner, "build").bind(
			WORLD_SEED,
			_feature_refresh_target,
			CHUNK_RADIUS,
			VoxelChunk.SIZE,
			observer_position
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
		"observer": str(observer_position),
		"old_features_visible": false,
	})


func _add_tree_multimesh(
	mesh: Mesh,
	transforms: Array,
	cast_shadows: bool = true,
	streamed: bool = true
) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		var transform: Variant = transforms[index]
		if not transform is Transform3D:
			push_error("Ecology transform is not Transform3D at index %d" % index)
			return
		multimesh.set_instance_transform(index, transform)
	var half_span: float = float((CHUNK_RADIUS + 1) * VoxelChunk.SIZE)
	var center_world := Vector3(
		float(_feature_refresh_target.x * VoxelChunk.SIZE),
		48.0,
		float(_feature_refresh_target.z * VoxelChunk.SIZE)
	)
	multimesh.custom_aabb = AABB(
		center_world - Vector3(half_span, 64.0, half_span),
		Vector3(half_span * 2.0, 128.0, half_span * 2.0)
	)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	if streamed:
		_feature_root.add_child(instance)
		_streamed_feature_instances += 1
	else:
		add_child(instance)
	_render_instance_count += 1


func _begin_distant_generation() -> void:
	_distant_target = _world_center
	_distant_planner = DistantTerrainPlanner.new()
	_distant_thread = Thread.new()
	var start_result: Error = _distant_thread.start(
		Callable(_distant_planner, "build").bind(
			WORLD_SEED,
			_distant_target,
			VoxelChunk.SIZE,
			CHUNK_RADIUS,
			DISTANT_WORLD_RADIUS,
			DISTANT_TERRAIN_STEP
		)
	)
	if start_result != OK:
		_runtime_log.event("error", "environment", "distant_worker_start_failed", {
			"center": str(_distant_target),
			"error": error_string(start_result),
		})
		_distant_thread = null
		_distant_planner = null
		return
	_distant_state = DISTANT_GENERATING
	_distant_refresh_pending = false
	_runtime_log.event("info", "environment", "distant_generation_started", {
		"center": str(_distant_target),
		"old_distant_visible": _distant_terrain != null,
	})


func _poll_distant_generation() -> void:
	if _distant_thread == null or _distant_thread.is_alive():
		return
	var completed_plan: Variant = _distant_thread.wait_to_finish()
	_distant_thread = null
	_distant_planner = null
	if not completed_plan is Dictionary:
		_distant_state = DISTANT_IDLE
		_distant_refresh_pending = true
		_runtime_log.event("error", "environment", "distant_generation_invalid", {
			"center": str(_distant_target),
		})
		return
	_distant_plan = completed_plan
	_distant_generation_usec = int(_distant_plan.get("generation_usec", 0))
	if _world_center != _distant_target:
		_runtime_log.event("info", "environment", "distant_generation_stale", {
			"generated_center": str(_distant_target),
			"current_center": str(_world_center),
			"generation_usec": _distant_generation_usec,
		})
		_distant_plan.clear()
		_distant_state = DISTANT_IDLE
		_distant_refresh_pending = true
		return
	_distant_state = DISTANT_READY


func _commit_distant_plan() -> void:
	var commit_started_usec: int = Time.get_ticks_usec()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _distant_plan.get("vertices", PackedVector3Array())
	arrays[Mesh.ARRAY_NORMAL] = _distant_plan.get("normals", PackedVector3Array())
	arrays[Mesh.ARRAY_COLOR] = _distant_plan.get("colors", PackedColorArray())
	arrays[Mesh.ARRAY_INDEX] = _distant_plan.get("indices", PackedInt32Array())
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh.surface_set_material(0, material)
	var distant := MeshInstance3D.new()
	distant.mesh = mesh
	distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(distant)
	var old_distant: MeshInstance3D = _distant_terrain
	_distant_terrain = distant
	_distant_center = _distant_target
	_distant_quads = int(_distant_plan.get("quads", 0))
	if old_distant != null:
		remove_child(old_distant)
		old_distant.queue_free()
	else:
		_render_instance_count += 1
	_distant_commit_usec = Time.get_ticks_usec() - commit_started_usec
	_last_environment_refresh_usec = _distant_generation_usec + _distant_commit_usec
	_runtime_log.event("info", "environment", "distant_refreshed", {
		"center": str(_distant_center),
		"generation_usec": _distant_generation_usec,
		"commit_usec": _distant_commit_usec,
		"quads": _distant_quads,
		"old_distant_visible_during_build": old_distant != null,
	})
	if _distant_commit_usec > 8_000:
		_runtime_log.event("warning", "environment", "distant_commit_slow_frame", {
			"center": str(_distant_center),
			"commit_usec": _distant_commit_usec,
			"quads": _distant_quads,
		})
	_distant_plan.clear()
	_distant_state = DISTANT_IDLE
	_distant_refresh_pending = _world_center != _distant_center


func _diagnostic_context() -> Dictionary:
	var context: Dictionary = super._diagnostic_context()
	context["distant_refresh_state"] = _distant_state
	context["distant_generation_active"] = (
		_distant_thread != null and _distant_thread.is_alive()
	)
	context["distant_generation_usec"] = _distant_generation_usec
	context["distant_commit_usec"] = _distant_commit_usec
	context["distant_target"] = str(_distant_target)
	return context


func _notification(what: int) -> void:
	if (
		(what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE)
		and _distant_thread != null
	):
		_distant_thread.wait_to_finish()
		_distant_thread = null
		_distant_planner = null
	super._notification(what)
