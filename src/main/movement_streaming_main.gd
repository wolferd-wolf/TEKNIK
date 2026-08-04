extends "res://src/main/biome_visual_main.gd"

const DirectionalStreamPlan = preload("res://src/world/chunk_stream_plan.gd")
const DirectionalSpawnPlanner = preload("res://src/world/spawn_planner.gd")
const DirectionalVoxelChunk = preload("res://src/world/voxel_chunk.gd")

# A one-chunk reversal can temporarily involve seven outgoing and seven incoming
# chunks. Sixteen entries retain both strips with a small deterministic margin.
const CHUNK_CACHE_LIMIT: int = 16
const CACHE_COMMITS_PER_FRAME: int = 1
const INVALID_COORDINATE := Vector3i(2_147_483_647, 0, 2_147_483_647)

var _movement_chunk_direction: Vector2i = Vector2i.ZERO
var _chunk_report_cache: Dictionary = {}
var _chunk_cache_lru: Array[Vector3i] = []
var _cache_commits_this_frame: int = 0
var _chunk_cache_hits: int = 0
var _chunk_cache_misses: int = 0


func _ready() -> void:
	super._ready()
	_runtime_log.event("info", "stream", "directional_streaming_ready", {
		"cache_limit": CHUNK_CACHE_LIMIT,
		"cache_commits_per_frame": CACHE_COMMITS_PER_FRAME,
		"vegetation_untouched": true,
	})


func _update_world_streaming() -> void:
	if _exploration_anchor == null:
		return
	var current_position: Vector3 = _exploration_anchor.global_position
	var requested_center: Vector3i = DirectionalSpawnPlanner.chunk_coordinate(
		current_position,
		DirectionalVoxelChunk.SIZE
	)
	var lookahead_position: Vector3 = current_position
	_movement_chunk_direction = Vector2i.ZERO
	if _player != null:
		var horizontal_velocity := Vector2(_player.velocity.x, _player.velocity.z)
		if horizontal_velocity.length_squared() > 0.25:
			_movement_chunk_direction = Vector2i(
				int(signf(horizontal_velocity.x)),
				int(signf(horizontal_velocity.y))
			)
		lookahead_position += Vector3(_player.velocity.x, 0.0, _player.velocity.z) * LOOKAHEAD_SECONDS
	var priority_center: Vector3i = DirectionalSpawnPlanner.chunk_coordinate(
		lookahead_position,
		DirectionalVoxelChunk.SIZE
	)
	if requested_center != _world_center:
		_refresh_world_window(requested_center, priority_center)


func _refresh_terrain(center: Vector3i, priority: Vector3i) -> void:
	if not _qa_screenshot_path().is_empty() and _terrain_nodes.is_empty() and _chunk_stream.active_count() == 0:
		super._refresh_terrain(center, priority)
		return
	if _terrain_nodes.is_empty() and _chunk_stream.active_count() == 0:
		var initial_coordinates: Array[Vector3i] = DirectionalStreamPlan.ordered_square(
			center,
			INITIAL_RADIUS,
			priority
		)
		for coordinate: Vector3i in initial_coordinates:
			_build_initial_chunk(coordinate)
		_set_desired_chunks(center, CHUNK_RADIUS, priority)
		_runtime_log.event("info", "stream", "initial_safe_window_built", {
			"center": str(center),
			"chunks": initial_coordinates.size(),
		})
		return

	_set_desired_chunks(center, CHUNK_RADIUS, priority)
	var delta: Dictionary = _chunk_stream.reconcile(center, CHUNK_RADIUS, priority)
	var filtered_loads: Array[Vector3i] = []
	for coordinate: Vector3i in delta.load:
		if _terrain_nodes.has(coordinate) or _playable_pool.has_coordinate(coordinate):
			continue
		filtered_loads.append(coordinate)
	filtered_loads = DirectionalStreamPlan.sort_directional(
		filtered_loads,
		center,
		priority,
		_movement_chunk_direction
	)
	var filtered_unloads: Array[Vector3i] = []
	for coordinate: Vector3i in delta.unload:
		if _is_player_safety_coordinate(coordinate):
			continue
		filtered_unloads.append(coordinate)
	_chunk_work_budget.replace(filtered_loads, filtered_unloads)
	_stream_plan_center = center
	_stream_plan_started_ms = Time.get_ticks_msec()
	_stream_loaded_total = 0
	_stream_unloaded_total = 0
	_runtime_log.event("info", "stream", "directional_plan_queued", {
		"center": str(center),
		"priority": str(priority),
		"direction": str(_movement_chunk_direction),
		"loads": filtered_loads.size(),
		"unloads": filtered_unloads.size(),
		"cached_chunks": _chunk_report_cache.size(),
	})


func _set_desired_chunks(center: Vector3i, radius: int, priority: Vector3i) -> void:
	_desired_chunks.clear()
	var coordinates: Array[Vector3i] = []
	for z: int in range(center.z - radius, center.z + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			coordinates.append(Vector3i(x, center.y, z))
	for coordinate: Vector3i in DirectionalStreamPlan.sort_directional(
		coordinates,
		center,
		priority,
		_movement_chunk_direction
	):
		_desired_chunks[coordinate] = true


func _process_chunk_work() -> void:
	_cache_commits_this_frame = 0
	super._process_chunk_work()


func _dispatch_playable_chunk(coordinate: Vector3i) -> bool:
	var snapshots: Dictionary = _world_edits.snapshot_neighborhood(coordinate)
	if (
		_cache_commits_this_frame < CACHE_COMMITS_PER_FRAME
		and snapshots.is_empty()
		and _chunk_report_cache.has(coordinate)
	):
		var cached: Dictionary = (_chunk_report_cache[coordinate] as Dictionary).duplicate(true)
		cached["coordinate"] = coordinate
		cached["cache_hit"] = true
		cached["worker_usec"] = 0
		cached["generation_usec"] = 0
		cached["mesh_worker_usec"] = 0
		cached["collision_profile_usec"] = 0
		_touch_cache_coordinate(coordinate)
		_cache_commits_this_frame += 1
		_chunk_cache_hits += 1
		_commit_terrain_chunk(cached)
		_runtime_log.event("info", "stream", "chunk_cache_hit", {
			"coordinate": str(coordinate),
			"cache_size": _chunk_report_cache.size(),
			"hits": _chunk_cache_hits,
		})
		return true
	_chunk_cache_misses += 1
	return super._dispatch_playable_chunk(coordinate)


func _unload_terrain_chunk(coordinate: Vector3i) -> void:
	_cache_chunk_before_unload(coordinate)
	super._unload_terrain_chunk(coordinate)


func _cache_chunk_before_unload(coordinate: Vector3i) -> void:
	var terrain: MeshInstance3D = _terrain_nodes.get(coordinate)
	if terrain == null or not (terrain.mesh is ArrayMesh):
		return
	if not _world_edits.snapshot_neighborhood(coordinate).is_empty():
		_erase_cached_coordinate(coordinate)
		return
	var mesh := terrain.mesh as ArrayMesh
	if mesh.get_surface_count() == 0:
		return
	_chunk_report_cache[coordinate] = {
		"coordinate": coordinate,
		"arrays": mesh.surface_get_arrays(0),
		"quads": int(terrain.get_meta("quad_count", 0)),
		"collision_profile": (terrain.get_meta("collision_profile", {}) as Dictionary).duplicate(true),
		"native_backend": true,
		"native_core_version": str(terrain.get_meta("native_core_version", "cached")),
		"cache_eligible": true,
	}
	_touch_cache_coordinate(coordinate)
	while _chunk_cache_lru.size() > CHUNK_CACHE_LIMIT:
		var evicted: Vector3i = _chunk_cache_lru.pop_front()
		_chunk_report_cache.erase(evicted)


func _touch_cache_coordinate(coordinate: Vector3i) -> void:
	_chunk_cache_lru.erase(coordinate)
	_chunk_cache_lru.append(coordinate)


func _erase_cached_coordinate(coordinate: Vector3i) -> void:
	_chunk_report_cache.erase(coordinate)
	_chunk_cache_lru.erase(coordinate)


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["movement_chunk_direction"] = _movement_chunk_direction
	snapshot["chunk_cache_size"] = _chunk_report_cache.size()
	snapshot["chunk_cache_hits"] = _chunk_cache_hits
	snapshot["chunk_cache_misses"] = _chunk_cache_misses
	return snapshot


func _diagnostic_context() -> Dictionary:
	var context: Dictionary = super._diagnostic_context()
	context["movement_chunk_direction"] = str(_movement_chunk_direction)
	context["chunk_cache_size"] = _chunk_report_cache.size()
	context["chunk_cache_hits"] = _chunk_cache_hits
	context["chunk_cache_misses"] = _chunk_cache_misses
	return context
