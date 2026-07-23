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

# Vegetation is resident per terrain chunk. A center change no longer destroys
# the complete ecology window; only _unload_terrain_chunk() removes the matching
# chunk root. The newly exposed strip is generated after terrain streaming is idle.
var _ecology_chunk_roots: Dictionary = {}
var _ecology_ready_chunks: Dictionary = {}
var _ecology_commit_plan_by_chunk: Dictionary = {}
var _ecology_commit_chunks: Array[Vector3i] = []
var _ecology_commit_chunk_index: int = 0
var _ecology_commit_parent: Node3D
var _ecology_commit_coordinate: Vector3i = Vector3i.ZERO
var _ecology_mesh_cache: Dictionary = {}
var _ecology_chunk_unload_count: int = 0


func _refresh_world_window(center: Vector3i, priority: Vector3i) -> void:
	var previous_center: Vector3i = _world_center
	super._refresh_world_window(center, priority)
	if center == previous_center:
		return
	# Request only the missing strip. Existing overlapping chunk roots remain visible.
	_feature_refresh_pending = true
	if _ecology_state == ECOLOGY_COMMITTING and _feature_refresh_target != center:
		_cancel_ecology_commit("center_changed")
	_runtime_log.event("info", "environment", "ecology_center_shifted", {
		"old_center": str(previous_center),
		"target_center": str(center),
		"resident_chunks": _ecology_ready_chunks.size(),
		"visible_instances": _streamed_feature_instances,
		"whole_window_preserved": true,
	})


func _rebuild_streamed_features() -> void:
	# Create the persistent feature container once. Chunk vegetation lives below it
	# and is removed individually by _unload_terrain_chunk().
	if _feature_root == null:
		_feature_root = Node3D.new()
		_feature_root.name = "StreamedWorldFeatures"
		add_child(_feature_root)
		_streamed_feature_instances = 0
		_build_water()
	_feature_refresh_pending = true


func _unload_terrain_chunk(coordinate: Vector3i) -> void:
	super._unload_terrain_chunk(coordinate)
	_remove_ecology_chunk(coordinate)


func _remove_ecology_chunk(coordinate: Vector3i) -> void:
	var was_ready: bool = _ecology_ready_chunks.has(coordinate)
	_ecology_ready_chunks.erase(coordinate)
	var root: Node3D = _ecology_chunk_roots.get(coordinate)
	if root == null:
		if was_ready:
			_ecology_chunk_unload_count += 1
			_runtime_log.event("info", "environment", "ecology_chunk_unloaded", {
				"coordinate": str(coordinate),
				"removed_instances": 0,
				"resident_chunks": _ecology_ready_chunks.size(),
				"remaining_instances": _streamed_feature_instances,
			})
		return
	var instance_count: int = int(root.get_meta("render_instances", 0))
	if root.get_parent() != null:
		root.get_parent().remove_child(root)
	root.queue_free()
	_ecology_chunk_roots.erase(coordinate)
	_streamed_feature_instances = maxi(1, _streamed_feature_instances - instance_count)
	_render_instance_count = maxi(0, _render_instance_count - instance_count)
	_ecology_chunk_unload_count += 1
	_runtime_log.event("info", "environment", "ecology_chunk_unloaded", {
		"coordinate": str(coordinate),
		"removed_instances": instance_count,
		"resident_chunks": _ecology_ready_chunks.size(),
		"remaining_instances": _streamed_feature_instances,
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
	# Keep chunk content deterministic across refreshes. Only the original spawn
	# receives an exclusion zone; the player's current position must not punch
	# moving holes into already generated vegetation.
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
		"exclusion": str(exclusion_position),
		"resident_chunks_preserved": _ecology_ready_chunks.size(),
	})


func _begin_ecology_commit() -> void:
	_ecology_commit_plan_by_chunk = _partition_ecology_plan(
		_ecology_plan,
		_feature_refresh_target
	)
	_ecology_commit_chunks.clear()
	for coordinate: Vector3i in _active_ecology_coordinates(_feature_refresh_target):
		if _ecology_ready_chunks.has(coordinate):
			continue
		_ecology_commit_chunks.append(coordinate)
	_ecology_commit_chunk_index = 0
	_ecology_commit_frames = 0
	_ecology_commit_peak_usec = 0
	_ecology_state = ECOLOGY_COMMITTING
	_runtime_log.event("info", "environment", "ecology_generation_complete", {
		"center": str(_feature_refresh_target),
		"generation_usec": _ecology_last_generation_usec,
		"missing_chunks": _ecology_commit_chunks.size(),
		"preserved_chunks": _ecology_ready_chunks.size(),
		"trees": int(_ecology_plan.get("tree_count", 0)),
		"boulders": int(_ecology_plan.get("boulder_count", 0)),
		"ground_parts": int(_ecology_plan.get("ground_part_count", 0)),
	})
	if _ecology_commit_chunks.is_empty():
		_finish_ecology_commit()


func _commit_ecology_groups() -> void:
	if _feature_refresh_target != _world_center:
		_cancel_ecology_commit("center_changed")
		return
	if _ecology_commit_chunk_index >= _ecology_commit_chunks.size():
		_finish_ecology_commit()
		return
	var frame_started_usec: int = Time.get_ticks_usec()
	var coordinate: Vector3i = _ecology_commit_chunks[_ecology_commit_chunk_index]
	_ecology_commit_chunk_index += 1

	# A safety-retained or stale coordinate may no longer be resident by commit time.
	if not _terrain_nodes.has(coordinate):
		_ecology_commit_frames += 1
		return
	if _ecology_ready_chunks.has(coordinate):
		_ecology_commit_frames += 1
		return

	var chunk_root := Node3D.new()
	chunk_root.name = "Ecology_%d_%d" % [coordinate.x, coordinate.z]
	_feature_root.add_child(chunk_root)
	_ecology_commit_parent = chunk_root
	_ecology_commit_coordinate = coordinate
	var instances_before: int = _streamed_feature_instances
	var chunk_plan: Dictionary = _ecology_commit_plan_by_chunk.get(coordinate, {})
	for group: Dictionary in _make_ecology_groups(chunk_plan):
		var transforms: Array = group["transforms"]
		if transforms.is_empty():
			continue
		_add_tree_multimesh(
			_ecology_mesh_for_group(group),
			transforms,
			bool(group["cast_shadows"])
		)
	_ecology_commit_parent = null
	var added_instances: int = _streamed_feature_instances - instances_before
	chunk_root.set_meta("render_instances", added_instances)
	if added_instances > 0:
		_ecology_chunk_roots[coordinate] = chunk_root
	else:
		_feature_root.remove_child(chunk_root)
		chunk_root.queue_free()
	_ecology_ready_chunks[coordinate] = true
	_ecology_commit_frames += 1
	var commit_usec: int = Time.get_ticks_usec() - frame_started_usec
	_ecology_commit_peak_usec = maxi(_ecology_commit_peak_usec, commit_usec)
	if commit_usec > 8_000:
		_runtime_log.event("warning", "environment", "ecology_chunk_commit_slow", {
			"coordinate": str(coordinate),
			"usec": commit_usec,
			"instances": added_instances,
		})


func _finish_ecology_commit() -> void:
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
		"resident_chunks": _ecology_ready_chunks.size(),
		"instances": _streamed_feature_instances,
		"chunk_local_residency": true,
	})
	_feature_previous_root = null
	_feature_previous_instances = 0
	_ecology_plan.clear()
	_ecology_groups.clear()
	_ecology_commit_plan_by_chunk.clear()
	_ecology_commit_chunks.clear()
	_ecology_commit_chunk_index = 0
	_ecology_commit_parent = null
	_ecology_state = ECOLOGY_IDLE
	_feature_refresh_stage = -1
	_feature_refresh_pending = (
		_world_center != _feature_center
		or _missing_ecology_chunks(_world_center) > 0
	)


func _cancel_ecology_commit(reason: String) -> void:
	_runtime_log.event("info", "environment", "ecology_commit_cancelled", {
		"reason": reason,
		"target": str(_feature_refresh_target),
		"current": str(_world_center),
		"committed_chunks_retained": _ecology_ready_chunks.size(),
	})
	_ecology_plan.clear()
	_ecology_groups.clear()
	_ecology_commit_plan_by_chunk.clear()
	_ecology_commit_chunks.clear()
	_ecology_commit_chunk_index = 0
	_ecology_commit_parent = null
	_ecology_state = ECOLOGY_IDLE
	_feature_refresh_stage = -1
	_feature_refresh_pending = true


func _partition_ecology_plan(plan: Dictionary, center: Vector3i) -> Dictionary:
	var result: Dictionary = {}
	var active: Dictionary = {}
	for coordinate: Vector3i in _active_ecology_coordinates(center):
		active[coordinate] = true
	for key: String in _ecology_group_keys():
		var transforms: Array = plan.get(key, [])
		for value: Variant in transforms:
			if not value is Transform3D:
				continue
			var transform: Transform3D = value
			var coordinate := Vector3i(
				floori(transform.origin.x / float(VoxelChunk.SIZE)),
				0,
				floori(transform.origin.z / float(VoxelChunk.SIZE))
			)
			if not active.has(coordinate):
				continue
			var chunk_plan: Dictionary = result.get(coordinate, {})
			var chunk_transforms: Array = chunk_plan.get(key, [])
			chunk_transforms.append(transform)
			chunk_plan[key] = chunk_transforms
			result[coordinate] = chunk_plan
	return result


func _active_ecology_coordinates(center: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z: int in range(center.z - CHUNK_RADIUS, center.z + CHUNK_RADIUS + 1):
		for x: int in range(center.x - CHUNK_RADIUS, center.x + CHUNK_RADIUS + 1):
			result.append(Vector3i(x, 0, z))
	return result


func _missing_ecology_chunks(center: Vector3i) -> int:
	var missing: int = 0
	for coordinate: Vector3i in _active_ecology_coordinates(center):
		if _terrain_nodes.has(coordinate) and not _ecology_ready_chunks.has(coordinate):
			missing += 1
	return missing


func _ecology_group_keys() -> Array[String]:
	return [
		"trunks",
		"broadleaf_lower",
		"broadleaf_upper",
		"broadleaf_side",
		"conifer_lower",
		"conifer_middle",
		"conifer_upper",
		"fallen_logs",
		"cool_rock_primary",
		"cool_rock_secondary",
		"warm_rock_primary",
		"warm_rock_secondary",
		"lush_tufts",
		"dry_tufts",
		"shrubs_lower",
		"shrubs_upper",
	]


func _ecology_mesh_for_group(group: Dictionary) -> Mesh:
	var key: String = str(group["name"])
	var cached: Mesh = _ecology_mesh_cache.get(key)
	if cached != null:
		return cached
	var color: Color = group["color"]
	var mesh: Mesh = _voxel_box_mesh(color, 1.0)
	_ecology_mesh_cache[key] = mesh
	return mesh


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
	if streamed and _ecology_commit_parent != null:
		var min_world := Vector3(
			float(_ecology_commit_coordinate.x * VoxelChunk.SIZE) - 6.0,
			-8.0,
			float(_ecology_commit_coordinate.z * VoxelChunk.SIZE) - 6.0
		)
		multimesh.custom_aabb = AABB(
			min_world,
			Vector3(float(VoxelChunk.SIZE) + 12.0, 128.0, float(VoxelChunk.SIZE) + 12.0)
		)
	else:
		multimesh.custom_aabb = _transform_origin_bounds(transforms, 18.0)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	if streamed:
		var parent: Node3D = _ecology_commit_parent if _ecology_commit_parent != null else _feature_root
		parent.add_child(instance)
		_streamed_feature_instances += 1
	else:
		add_child(instance)
	_render_instance_count += 1


func _transform_origin_bounds(transforms: Array, margin: float) -> AABB:
	var first: Transform3D = transforms[0]
	var minimum: Vector3 = first.origin
	var maximum: Vector3 = first.origin
	for value: Variant in transforms:
		if not value is Transform3D:
			continue
		var item: Transform3D = value
		var origin: Vector3 = item.origin
		minimum = minimum.min(origin)
		maximum = maximum.max(origin)
	var padding := Vector3.ONE * margin
	return AABB(minimum - padding, maximum - minimum + padding * 2.0)


func qa_ecology_ready_chunk_count() -> int:
	return _ecology_ready_chunks.size()


func qa_ecology_chunk_unload_count() -> int:
	return _ecology_chunk_unload_count


func qa_world_idle() -> bool:
	return (
		super.qa_world_idle()
		and _ecology_state == ECOLOGY_IDLE
		and not _feature_refresh_pending
	)


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
	context["ecology_resident_chunks"] = _ecology_ready_chunks.size()
	context["ecology_chunk_roots"] = _ecology_chunk_roots.size()
	context["ecology_chunk_unloads"] = _ecology_chunk_unload_count
	context["ecology_missing_chunks"] = _missing_ecology_chunks(_world_center)
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
