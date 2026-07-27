extends "res://src/main/playable_main.gd"

const PlayabilityTraversalDirector = preload("res://src/qa/playability_traversal_director.gd")
const ShippingNativeChunkBackend = preload("res://src/world/native_chunk_backend.gd")

const FEATURE_STAGE_WATER: int = 0
const FEATURE_STAGE_FOREST: int = 1
const FEATURE_STAGE_BOULDERS: int = 2
const FEATURE_STAGE_GROUND: int = 3
const FEATURE_STAGE_COMPLETE: int = 4

var _native_initial_chunk_count: int = 0
var _native_streamed_chunk_count: int = 0
var _native_fallback_count: int = 0
var _native_core_version: String = "unavailable"
var _feature_refresh_stage: int = -1
var _feature_refresh_started_usec: int = 0
var _feature_refresh_target: Vector3i = Vector3i.ZERO
var _feature_previous_root: Node3D
var _feature_previous_instances: int = 0


func _ready() -> void:
	super._ready()
	if "--qa-playability" in OS.get_cmdline_user_args() and _player != null:
		var director: TeknikPlayabilityTraversalDirector = PlayabilityTraversalDirector.new()
		director.name = "PlayabilityTraversalDirector"
		add_child(director)
		director.begin(self, _player)


func _process_environment_refresh_if_idle() -> void:
	if _feature_refresh_stage >= 0:
		if _world_center != _feature_refresh_target:
			_cancel_staged_feature_refresh("center_changed")
			_feature_refresh_pending = true
			return
		_process_staged_feature_refresh()
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
	_begin_staged_feature_refresh()


func _begin_staged_feature_refresh() -> void:
	_feature_previous_root = _feature_root
	_feature_previous_instances = _streamed_feature_instances
	_feature_root = Node3D.new()
	_feature_root.name = "StreamedWorldFeaturesStaging"
	_feature_root.visible = false
	add_child(_feature_root)
	_streamed_feature_instances = 0
	_feature_refresh_target = _world_center
	_feature_refresh_stage = FEATURE_STAGE_WATER
	_feature_refresh_started_usec = Time.get_ticks_usec()
	_runtime_log.event("info", "environment", "feature_refresh_started", {
		"center": str(_feature_refresh_target),
		"previous_instances": _feature_previous_instances,
	})


func _process_staged_feature_refresh() -> void:
	var stage_started_usec: int = Time.get_ticks_usec()
	var stage_name: String = "unknown"
	match _feature_refresh_stage:
		FEATURE_STAGE_WATER:
			stage_name = "water"
			_build_water()
		FEATURE_STAGE_FOREST:
			stage_name = "forest"
			_build_forest()
		FEATURE_STAGE_BOULDERS:
			stage_name = "boulders"
			_build_boulders()
		FEATURE_STAGE_GROUND:
			stage_name = "ground"
			_build_ground_detail()
		FEATURE_STAGE_COMPLETE:
			_finish_staged_feature_refresh()
			return
		_:
			_cancel_staged_feature_refresh("invalid_stage")
			return
	_runtime_log.event("info", "environment", "feature_refresh_stage_complete", {
		"center": str(_feature_refresh_target),
		"stage": stage_name,
		"usec": Time.get_ticks_usec() - stage_started_usec,
		"new_instances": _streamed_feature_instances,
	})
	_feature_refresh_stage += 1


func _finish_staged_feature_refresh() -> void:
	if _feature_previous_root != null:
		remove_child(_feature_previous_root)
		_feature_previous_root.queue_free()
		_render_instance_count -= _feature_previous_instances
	_feature_root.name = "StreamedWorldFeatures"
	_feature_root.visible = true
	_feature_center = _feature_refresh_target
	_feature_refresh_pending = false
	_last_environment_refresh_usec = Time.get_ticks_usec() - _feature_refresh_started_usec
	_runtime_log.event("info", "environment", "playable_features_refreshed", {
		"center": str(_feature_center),
		"usec": _last_environment_refresh_usec,
		"instances": _streamed_feature_instances,
		"frames": FEATURE_STAGE_COMPLETE,
		"distant_refresh_deferred": _distant_refresh_pending,
	})
	_feature_previous_root = null
	_feature_previous_instances = 0
	_feature_refresh_stage = -1


func _cancel_staged_feature_refresh(reason: String) -> void:
	var staged_instances: int = _streamed_feature_instances
	if _feature_root != null and _feature_root != _feature_previous_root:
		remove_child(_feature_root)
		_feature_root.queue_free()
		_render_instance_count -= staged_instances
	_feature_root = _feature_previous_root
	_streamed_feature_instances = _feature_previous_instances
	_runtime_log.event("info", "environment", "feature_refresh_cancelled", {
		"reason": reason,
		"target": str(_feature_refresh_target),
		"current": str(_world_center),
		"discarded_instances": staged_instances,
	})
	_feature_previous_root = null
	_feature_previous_instances = 0
	_feature_refresh_stage = -1


func _refresh_terrain(center: Vector3i, priority: Vector3i) -> void:
	if not _qa_screenshot_path().is_empty() and _terrain_nodes.is_empty() and _chunk_stream.active_count() == 0:
		var coordinates: Array[Vector3i] = ChunkStreamPlanPlayable.ordered_square(
			center,
			CHUNK_RADIUS,
			priority
		)
		for coordinate: Vector3i in coordinates:
			_build_initial_chunk(coordinate)
		_set_desired_chunks(center, CHUNK_RADIUS, priority)
		return
	super._refresh_terrain(center, priority)


func _process_chunk_work() -> void:
	var discarded: Array[Vector3i] = _playable_pool.discard_buffered_outside(
		_desired_chunks,
		_terrain_nodes
	)
	if not discarded.is_empty():
		var coordinate_labels: Array[String] = []
		for coordinate: Vector3i in discarded:
			coordinate_labels.append(str(coordinate))
		_runtime_log.event("info", "stream", "stale_buffered_results_discarded", {
			"count": discarded.size(),
			"coordinates": coordinate_labels,
			"center": str(_world_center),
			"pipeline_remaining": _playable_pool.pipeline_count(),
		})
	super._process_chunk_work()


func _build_initial_chunk(coordinate: Vector3i) -> void:
	var backend := ShippingNativeChunkBackend.new()
	if not backend.is_available():
		_native_fallback_count += 1
		super._build_initial_chunk(coordinate)
		return

	_native_core_version = backend.core_version()
	var snapshots: Dictionary = _world_edits.snapshot_neighborhood(coordinate)
	var report: Dictionary = backend.build_chunk(WORLD_SEED, coordinate, snapshots)
	var voxels: PackedByteArray = report.get("voxels", PackedByteArray())
	if not bool(report.get("success", false)) or voxels.size() != PlayableVoxelChunk.VOLUME:
		_native_fallback_count += 1
		_runtime_log.event("error", "native", "initial_chunk_fallback", {
			"coordinate": str(coordinate),
			"error": str(report.get("error", "invalid native voxel buffer")),
		})
		super._build_initial_chunk(coordinate)
		return

	var chunk: TeknikVoxelChunk = PlayableVoxelChunk.new()
	chunk.voxels = voxels
	chunk.revision = 1 + int(int(report.get("applied_edits", 0)) > 0)
	var terrain := MeshInstance3D.new()
	terrain.mesh = PlayableGreedyMesher.mesh_from_arrays(report.arrays)
	terrain.position = Vector3(
		coordinate.x * PlayableVoxelChunk.SIZE,
		0.0,
		coordinate.z * PlayableVoxelChunk.SIZE
	)
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.set_meta("quad_count", int(report.quads))
	terrain.set_meta("collision_profile", PlayableCollisionProfile.build_from_chunk(
		WORLD_SEED,
		coordinate,
		snapshots,
		chunk
	))
	terrain.set_meta("native_backend", true)
	terrain.set_meta("native_core_version", _native_core_version)
	# Preserve the compact material stream until the biome/texture pass recolors
	# the newly created mesh. It is removed immediately after that pass.
	terrain.set_meta("packed_faces", report.get("packed_faces", PackedInt32Array()))
	add_child(terrain)
	_terrain_nodes[coordinate] = terrain
	_chunk_stream.mark_loaded(coordinate)
	_total_quads += int(report.quads)
	_render_instance_count += 1
	_native_initial_chunk_count += 1
	_runtime_log.event("info", "native", "initial_chunk_built", {
		"coordinate": str(coordinate),
		"core": _native_core_version,
		"generation_usec": int(report.get("generation_usec", 0)),
		"mesh_usec": int(report.get("mesh_worker_usec", 0)),
		"quads": int(report.get("quads", 0)),
	})


func _commit_terrain_chunk(report: Dictionary) -> void:
	if bool(report.get("native_backend", false)):
		_native_streamed_chunk_count += 1
		_native_core_version = str(report.get("native_core_version", _native_core_version))
	else:
		_native_fallback_count += 1
		_runtime_log.event("error", "native", "streamed_chunk_fallback", {
			"coordinate": str(report.get("coordinate", Vector3i.ZERO)),
			"reason": str(report.get("native_fallback_reason", "unknown")),
		})
	super._commit_terrain_chunk(report)


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["native_initial_chunks"] = _native_initial_chunk_count
	snapshot["native_streamed_chunks"] = _native_streamed_chunk_count
	snapshot["native_fallbacks"] = _native_fallback_count
	snapshot["native_core_version"] = _native_core_version
	snapshot["feature_center"] = _feature_center
	snapshot["feature_refresh_pending"] = _feature_refresh_pending
	snapshot["feature_refresh_stage"] = _feature_refresh_stage
	return snapshot


func _diagnostic_context() -> Dictionary:
	var context: Dictionary = super._diagnostic_context()
	context["native_initial_chunks"] = _native_initial_chunk_count
	context["native_streamed_chunks"] = _native_streamed_chunk_count
	context["native_fallbacks"] = _native_fallback_count
	context["native_core_version"] = _native_core_version
	context["feature_refresh_stage"] = _feature_refresh_stage
	return context


func _next_build_coordinate() -> Vector3i:
	while not _emergency_load_queue.is_empty():
		var emergency: Vector3i = _emergency_load_queue.pop_front()
		if not _terrain_nodes.has(emergency) and not _playable_pool.has_coordinate(emergency):
			return emergency
	while not _edit_rebuild_queue.is_empty():
		var rebuild: Vector3i = _edit_rebuild_queue.pop_front()
		if _terrain_nodes.has(rebuild) and not _playable_pool.has_coordinate(rebuild):
			# Keep the marker until the parent dispatches it. The next pool slot
			# removes this marker after seeing the coordinate already in flight.
			_edit_rebuild_queue.push_front(rebuild)
			return rebuild
	var load_work: Dictionary = _chunk_work_budget.take_frame(1, 0)
	var loads: Array[Vector3i] = load_work.load
	if loads.is_empty():
		return Vector3i(2_147_483_647, 0, 2_147_483_647)
	var coordinate: Vector3i = loads[0]
	if _terrain_nodes.has(coordinate) or _playable_pool.has_coordinate(coordinate):
		return _next_build_coordinate()
	return coordinate
