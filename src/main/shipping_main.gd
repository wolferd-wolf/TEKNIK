extends "res://src/main/playable_main.gd"

const PlayabilityTraversalDirector = preload("res://src/qa/playability_traversal_director.gd")
const ShippingNativeChunkBackend = preload("res://src/world/native_chunk_backend.gd")

var _native_initial_chunk_count: int = 0
var _native_streamed_chunk_count: int = 0
var _native_fallback_count: int = 0
var _native_core_version: String = "unavailable"


func _ready() -> void:
	super._ready()
	if "--qa-playability" in OS.get_cmdline_user_args() and _player != null:
		var director: TeknikPlayabilityTraversalDirector = PlayabilityTraversalDirector.new()
		director.name = "PlayabilityTraversalDirector"
		add_child(director)
		director.begin(self, _player)


func _process_environment_refresh_if_idle() -> void:
	# The distant terrain ring is still too expensive to rebuild on the main
	# thread, but leaving vegetation fixed at the initial spawn makes the world
	# visibly empty after only a few streamed chunks. Refresh the lightweight
	# batched feature layer once movement has been stable long enough and the
	# terrain/collision queues are idle. Distant LOD refresh remains deferred
	# until its mesh generation moves off the main thread.
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
	var started_usec: int = Time.get_ticks_usec()
	_rebuild_streamed_features()
	_feature_center = _world_center
	_feature_refresh_pending = false
	_last_environment_refresh_usec = Time.get_ticks_usec() - started_usec
	_runtime_log.event("info", "environment", "playable_features_refreshed", {
		"center": str(_world_center),
		"usec": _last_environment_refresh_usec,
		"distant_refresh_deferred": _distant_refresh_pending,
	})


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
	return snapshot


func _diagnostic_context() -> Dictionary:
	var context: Dictionary = super._diagnostic_context()
	context["native_initial_chunks"] = _native_initial_chunk_count
	context["native_streamed_chunks"] = _native_streamed_chunk_count
	context["native_fallbacks"] = _native_fallback_count
	context["native_core_version"] = _native_core_version
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
