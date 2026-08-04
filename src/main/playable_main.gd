extends "res://src/main/visual_quality_main.gd"

const ChunkBuildPool = preload("res://src/world/chunk_build_pool.gd")
const ChunkStreamPlanPlayable = preload("res://src/world/chunk_stream_plan.gd")
const SpawnPlanner = preload("res://src/world/spawn_planner.gd")
const PlayableExplorationController = preload("res://src/player/exploration_controller.gd")
const PlayableTerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const PlayableVoxelChunk = preload("res://src/world/voxel_chunk.gd")
const PlayableGreedyMesher = preload("res://src/world/greedy_mesher.gd")
const PlayableCollisionProfile = preload("res://src/world/terrain_collision_profile.gd")

const INITIAL_RADIUS: int = 2
const MOBILE_WORKERS: int = 3
const DESKTOP_WORKERS: int = 4
const PLAYER_STATE_PATH: String = "user://teknik-player-state.json"
const PLAYER_STATE_SCHEMA: int = 1
const PLAYER_SAVE_INTERVAL_MS: int = 3000
const LOOKAHEAD_SECONDS: float = 4.0
const PLAYER_GUARD_RADIUS: float = 0.54

var _playable_pool: TeknikChunkBuildPool = ChunkBuildPool.new()
var _planned_spawn: Vector3 = Vector3.ZERO
var _initial_center: Vector3i = Vector3i.ZERO
var _desired_chunks: Dictionary = {}
var _emergency_load_queue: Array[Vector3i] = []
var _next_player_save_ms: int = 0
var _terrain_wait_started_ms: int = 0
var _terrain_wait_total_ms: int = 0
var _fall_recovery_count: int = 0


func _ready() -> void:
	_playable_pool.configure(MOBILE_WORKERS if OS.has_feature("mobile") else DESKTOP_WORKERS)
	if _qa_screenshot_path().is_empty():
		_planned_spawn = _load_or_choose_spawn()
		_initial_center = SpawnPlanner.chunk_coordinate(_planned_spawn, PlayableVoxelChunk.SIZE)
	else:
		_planned_spawn = Vector3.ZERO
		_initial_center = Vector3i.ZERO
	super._ready()
	if _qa_screenshot_path().is_empty():
		_refresh_terrain(_initial_center, _initial_center)
	_next_player_save_ms = Time.get_ticks_msec() + PLAYER_SAVE_INTERVAL_MS
	_runtime_log.event("info", "playability", "runtime_ready", {
		"spawn": str(_planned_spawn),
		"initial_center": str(_initial_center),
		"workers": _playable_pool.capacity(),
		"movement_guard": true,
	})


func _process(delta: float) -> void:
	super._process(delta)
	var now_ms: int = Time.get_ticks_msec()
	if _player != null and now_ms >= _next_player_save_ms:
		_save_player_state()
		_next_player_save_ms = now_ms + PLAYER_SAVE_INTERVAL_MS


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_player_state()
	super._notification(what)


func _build_terrain_ordered() -> void:
	if not _qa_screenshot_path().is_empty():
		super._build_terrain_ordered()
		return
	_refresh_world_window(_initial_center, _initial_center)


func _refresh_terrain(center: Vector3i, priority: Vector3i) -> void:
	if _terrain_nodes.is_empty() and _chunk_stream.active_count() == 0:
		var initial_coordinates: Array[Vector3i] = ChunkStreamPlanPlayable.ordered_square(
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
	_runtime_log.event("info", "stream", "playable_plan_queued", {
		"center": str(center),
		"priority": str(priority),
		"loads": filtered_loads.size(),
		"unloads": filtered_unloads.size(),
		"inflight": _playable_pool.inflight_count(),
	})


func _update_world_streaming() -> void:
	if _exploration_anchor == null:
		return
	var current_position: Vector3 = _exploration_anchor.global_position
	var requested_center: Vector3i = SpawnPlanner.chunk_coordinate(current_position, PlayableVoxelChunk.SIZE)
	var lookahead_position: Vector3 = current_position
	if _player != null:
		lookahead_position += Vector3(_player.velocity.x, 0.0, _player.velocity.z) * LOOKAHEAD_SECONDS
	var priority_center: Vector3i = SpawnPlanner.chunk_coordinate(lookahead_position, PlayableVoxelChunk.SIZE)
	if requested_center != _world_center:
		_refresh_world_window(requested_center, priority_center)


func _process_chunk_work() -> void:
	var frame_started_usec: int = Time.get_ticks_usec()
	var completed_loads: int = 0
	var worker_peak_usec: int = 0
	for report: Dictionary in _playable_pool.collect_ready():
		var coordinate: Vector3i = report.coordinate
		worker_peak_usec = maxi(worker_peak_usec, int(report.worker_usec))
		if _desired_chunks.has(coordinate) or _terrain_nodes.has(coordinate):
			_commit_terrain_chunk(report)
			completed_loads += 1
			_stream_loaded_total += 1
		else:
			_runtime_log.event("info", "stream", "stale_worker_result_discarded", {
				"coordinate": str(coordinate),
				"worker_usec": int(report.worker_usec),
			})
		_runtime_log.event("info", "stream", "playable_worker_collected", {
			"coordinate": str(coordinate),
			"worker_usec": int(report.worker_usec),
			"generation_usec": int(report.get("generation_usec", 0)),
			"mesh_worker_usec": int(report.get("mesh_worker_usec", 0)),
			"collision_profile_usec": int(report.get("collision_profile_usec", 0)),
			"boundary_columns": int(report.get("boundary_column_count", 0)),
			"mesh_commit_usec": _last_mesh_commit_usec,
		})

	var unload_work: Dictionary = _chunk_work_budget.take_frame(0, STREAM_UNLOADS_PER_FRAME)
	var to_unload: Array[Vector3i] = unload_work.unload
	for coordinate: Vector3i in to_unload:
		if _is_player_safety_coordinate(coordinate):
			continue
		_unload_terrain_chunk(coordinate)
		_stream_unloaded_total += 1

	var dispatched: int = 0
	while _playable_pool.has_capacity():
		var coordinate_to_build: Vector3i = _next_build_coordinate()
		if coordinate_to_build == Vector3i(2_147_483_647, 0, 2_147_483_647):
			break
		# _next_build_coordinate() already vets every coordinate it returns
		# (rebuild queue, emergency queue, or fresh load) as resident-safe and
		# not already in flight. The stale queue-membership check that used to
		# live here assumed _next_build_coordinate() left rebuild coordinates
		# sitting in _edit_rebuild_queue as an in-flight marker; the live
		# override (targeted_interaction_main.gd, via EditRebuildScheduler)
		# instead pops them immediately, so that check discarded every mining
		# edit rebuild before it could dispatch, permanently stalling
		# TeknikMiningController in WAITING_FOR_COMMIT after the first mine.
		if _dispatch_playable_chunk(coordinate_to_build):
			dispatched += 1

	var main_usec: int = Time.get_ticks_usec() - frame_started_usec
	if completed_loads > 0 or not to_unload.is_empty() or dispatched > 0:
		_performance_telemetry.record_stream(main_usec, worker_peak_usec)
		_world_sample_cache.clear()
		_world_column_cache.clear()
	if not _chunk_work_budget.has_work() and _edit_rebuild_queue.is_empty() and _emergency_load_queue.is_empty() and not _playable_pool.is_busy() and _stream_plan_started_ms > 0:
		var elapsed_ms: int = Time.get_ticks_msec() - _stream_plan_started_ms
		_runtime_log.event("info", "stream", "playable_plan_complete", {
			"center": str(_stream_plan_center),
			"elapsed_ms": elapsed_ms,
			"loaded": _stream_loaded_total,
			"unloaded": _stream_unloaded_total,
		})
		_stream_plan_started_ms = 0


func _next_build_coordinate() -> Vector3i:
	while not _emergency_load_queue.is_empty():
		var emergency: Vector3i = _emergency_load_queue.pop_front()
		if not _terrain_nodes.has(emergency) and not _playable_pool.has_coordinate(emergency):
			return emergency
	while not _edit_rebuild_queue.is_empty():
		var rebuild: Vector3i = _edit_rebuild_queue.pop_front()
		if _terrain_nodes.has(rebuild) and not _playable_pool.has_coordinate(rebuild):
			return rebuild
	var load_work: Dictionary = _chunk_work_budget.take_frame(1, 0)
	var loads: Array[Vector3i] = load_work.load
	if loads.is_empty():
		return Vector3i(2_147_483_647, 0, 2_147_483_647)
	var coordinate: Vector3i = loads[0]
	if _terrain_nodes.has(coordinate) or _playable_pool.has_coordinate(coordinate):
		return _next_build_coordinate()
	return coordinate


func _dispatch_chunk_build(coordinate: Vector3i) -> void:
	_dispatch_playable_chunk(coordinate)


func _dispatch_playable_chunk(coordinate: Vector3i) -> bool:
	var snapshots: Dictionary = _world_edits.snapshot_neighborhood(coordinate)
	var start_result: Error = _playable_pool.start(WORLD_SEED, coordinate, snapshots)
	if start_result != OK:
		if start_result != ERR_ALREADY_IN_USE and start_result != ERR_BUSY:
			_runtime_log.event("error", "stream", "playable_worker_start_failed", {
				"coordinate": str(coordinate),
				"error": error_string(start_result),
			})
		return false
	_runtime_log.event("info", "stream", "playable_worker_dispatched", {
		"coordinate": str(coordinate),
		"inflight": _playable_pool.inflight_count(),
	})
	return true


func _commit_terrain_chunk(report: Dictionary) -> void:
	var commit_started_usec: int = Time.get_ticks_usec()
	var coordinate: Vector3i = report.coordinate
	var mesh: ArrayMesh = PlayableGreedyMesher.mesh_from_arrays(report.arrays)
	var new_quads: int = int(report.quads)
	var profile: Dictionary = report.get("collision_profile", {})
	var terrain: MeshInstance3D = _terrain_nodes.get(coordinate)
	var old_collision: StaticBody3D = _collision_bodies.get(coordinate)
	if terrain != null:
		_total_quads -= int(terrain.get_meta("quad_count", 0))
		terrain.mesh = mesh
		terrain.set_meta("quad_count", new_quads)
	else:
		terrain = MeshInstance3D.new()
		terrain.position = Vector3(coordinate.x * PlayableVoxelChunk.SIZE, 0.0, coordinate.z * PlayableVoxelChunk.SIZE)
		terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		terrain.mesh = mesh
		terrain.set_meta("quad_count", new_quads)
		add_child(terrain)
		_terrain_nodes[coordinate] = terrain
		_render_instance_count += 1
	terrain.set_meta("collision_profile", profile)
	_total_quads += new_quads
	_chunk_stream.mark_loaded(coordinate)

	if old_collision != null and not profile.is_empty():
		var replacement: StaticBody3D = PlayableCollisionProfile.create_body(
			profile,
			"TerrainCollision_%d_%d" % [coordinate.x, coordinate.z]
		)
		if replacement != null:
			terrain.add_child(replacement)
			_collision_bodies[coordinate] = replacement
			old_collision.queue_free()
	elif _coordinate_needs_collision(coordinate) and not _collision_add_queue.has(coordinate):
		_collision_add_queue.append(coordinate)
	_last_mesh_commit_usec = Time.get_ticks_usec() - commit_started_usec


func _build_initial_chunk(coordinate: Vector3i) -> void:
	var chunk: TeknikVoxelChunk = PlayableTerrainGenerator.generate_chunk(WORLD_SEED, coordinate)
	_world_edits.apply_to_chunk(coordinate, chunk)
	var world_origin: Vector3i = coordinate * PlayableVoxelChunk.SIZE
	var boundary_columns: Dictionary = {}
	var report: Dictionary = PlayableGreedyMesher.build_arrays(
		chunk,
		world_origin,
		func(world_position: Vector3i) -> int:
			var owner := Vector3i(
				floori(float(world_position.x) / float(PlayableVoxelChunk.SIZE)),
				floori(float(world_position.y) / float(PlayableVoxelChunk.SIZE)),
				floori(float(world_position.z) / float(PlayableVoxelChunk.SIZE))
			)
			if owner == coordinate:
				return chunk.get_voxel(world_position - world_origin)
			var key := Vector2i(world_position.x, world_position.z)
			var column: Vector2i
			if boundary_columns.has(key):
				column = boundary_columns[key]
			else:
				column = PlayableTerrainGenerator.sample_column(WORLD_SEED, world_position.x, world_position.z)
				boundary_columns[key] = column
			var generated: int = PlayableTerrainGenerator.material_from_column(world_position.y, column)
			return _world_edits.get_override(world_position, generated),
		func(material: int, world_position: Vector3i) -> Color:
			return PlayableTerrainGenerator.fast_surface_color(WORLD_SEED, material, world_position)
	)
	var terrain := MeshInstance3D.new()
	terrain.mesh = PlayableGreedyMesher.mesh_from_arrays(report.arrays)
	terrain.position = Vector3(coordinate.x * PlayableVoxelChunk.SIZE, 0.0, coordinate.z * PlayableVoxelChunk.SIZE)
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.set_meta("quad_count", int(report.quads))
	terrain.set_meta("collision_profile", PlayableCollisionProfile.build_from_chunk(
		WORLD_SEED,
		coordinate,
		_world_edits.snapshot_neighborhood(coordinate),
		chunk
	))
	add_child(terrain)
	_terrain_nodes[coordinate] = terrain
	_chunk_stream.mark_loaded(coordinate)
	_total_quads += int(report.quads)
	_render_instance_count += 1


func _build_player_controller() -> void:
	_player = PlayableExplorationController.new()
	_player.name = "ExplorationController"
	_player.position = _planned_spawn
	_player.set_initial_safe_position(_planned_spawn)
	_player.set_movement_guard(Callable(self, "_can_player_enter"))
	add_child(_player)
	_player.set_camera_active(true)
	_player.break_requested.connect(_on_break_requested)
	_player.place_requested.connect(_on_place_requested)
	_player.diagnostics_requested.connect(_on_diagnostics_requested)
	_player.terrain_wait_changed.connect(_on_terrain_wait_changed)
	_player.recovered_from_fall.connect(_on_player_recovered)
	_exploration_anchor = _player
	_add_chunk_collision(_initial_center)
	_runtime_log.event("info", "player", "procedural_spawned", {
		"position": str(_planned_spawn),
		"chunk": str(_initial_center),
	})


func _can_player_enter(position: Vector3) -> bool:
	var offsets: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-PLAYER_GUARD_RADIUS, -PLAYER_GUARD_RADIUS),
		Vector2(PLAYER_GUARD_RADIUS, -PLAYER_GUARD_RADIUS),
		Vector2(-PLAYER_GUARD_RADIUS, PLAYER_GUARD_RADIUS),
		Vector2(PLAYER_GUARD_RADIUS, PLAYER_GUARD_RADIUS),
	]
	var ready: bool = true
	for offset: Vector2 in offsets:
		var coordinate: Vector3i = SpawnPlanner.chunk_coordinate(
			position + Vector3(offset.x, 0.0, offset.y),
			PlayableVoxelChunk.SIZE
		)
		if not _terrain_nodes.has(coordinate):
			_queue_emergency_load(coordinate)
			ready = false
		elif not _collision_bodies.has(coordinate):
			if not _collision_add_queue.has(coordinate):
				_collision_add_queue.push_front(coordinate)
			ready = false
	return ready


func _queue_emergency_load(coordinate: Vector3i) -> void:
	_desired_chunks[coordinate] = true
	if _terrain_nodes.has(coordinate) or _playable_pool.has_coordinate(coordinate) or _emergency_load_queue.has(coordinate):
		return
	_emergency_load_queue.push_front(coordinate)
	_runtime_log.event("warning", "stream", "emergency_chunk_requested", {
		"coordinate": str(coordinate),
		"player": str(_player.global_position) if _player != null else "none",
	})


func _is_player_safety_coordinate(coordinate: Vector3i) -> bool:
	if _player == null:
		return false
	var player_coordinate: Vector3i = SpawnPlanner.chunk_coordinate(_player.global_position, PlayableVoxelChunk.SIZE)
	return absi(coordinate.x - player_coordinate.x) <= 1 and absi(coordinate.z - player_coordinate.z) <= 1


func _set_desired_chunks(center: Vector3i, radius: int, priority: Vector3i) -> void:
	_desired_chunks.clear()
	for coordinate: Vector3i in ChunkStreamPlanPlayable.ordered_square(center, radius, priority):
		_desired_chunks[coordinate] = true


func _process_environment_refresh_if_idle() -> void:
	# The old global feature/distant rebuild took roughly eight seconds on the phone.
	# Keep the initial environment stable until features become chunk-local worker data.
	_feature_refresh_pending = false
	_distant_refresh_pending = false


func qa_world_idle() -> bool:
	return not _chunk_work_budget.has_work() and _edit_rebuild_queue.is_empty() and _emergency_load_queue.is_empty() and not _playable_pool.is_busy() and _collision_add_queue.is_empty() and _collision_remove_queue.is_empty()


func qa_playability_snapshot() -> Dictionary:
	return {
		"player_position": _player.global_position if _player != null else Vector3.ZERO,
		"safe_position": _player.safe_position() if _player != null else Vector3.ZERO,
		"waiting": _player.is_waiting_for_terrain() if _player != null else false,
		"wait_total_ms": _terrain_wait_total_ms,
		"recoveries": _fall_recovery_count,
		"loaded_chunks": _terrain_nodes.size(),
		"collision_chunks": _collision_bodies.size(),
		"inflight": _playable_pool.inflight_count(),
	}


func _on_terrain_wait_changed(waiting: bool) -> void:
	if waiting:
		_terrain_wait_started_ms = Time.get_ticks_msec()
		_runtime_log.event("info", "playability", "terrain_wait_started", _diagnostic_context())
	elif _terrain_wait_started_ms > 0:
		var waited_ms: int = Time.get_ticks_msec() - _terrain_wait_started_ms
		_terrain_wait_total_ms += waited_ms
		_terrain_wait_started_ms = 0
		_runtime_log.event("info", "playability", "terrain_wait_finished", {
			"waited_ms": waited_ms,
			"total_wait_ms": _terrain_wait_total_ms,
		})


func _on_player_recovered(previous_position: Vector3, safe_position: Vector3) -> void:
	_fall_recovery_count += 1
	_runtime_log.event("error", "playability", "fall_recovered", {
		"previous": str(previous_position),
		"safe": str(safe_position),
		"count": _fall_recovery_count,
	})


func _load_or_choose_spawn() -> Vector3:
	var absolute_path: String = ProjectSettings.globalize_path(PLAYER_STATE_PATH)
	if FileAccess.file_exists(absolute_path):
		var file := FileAccess.open(absolute_path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				var document: Dictionary = parsed
				var position_values: Array = document.get("position", [])
				if int(document.get("schema", -1)) == PLAYER_STATE_SCHEMA and int(document.get("world_seed", -1)) == WORLD_SEED and position_values.size() == 3:
					var loaded := Vector3(float(position_values[0]), float(position_values[1]), float(position_values[2]))
					if loaded.y >= 0.0:
						return loaded
	var salt: int = 20_260_721 if "--qa-gameplay" in OS.get_cmdline_user_args() or "--qa-playability" in OS.get_cmdline_user_args() else int(Time.get_unix_time_from_system() * 1000.0) ^ OS.get_process_id()
	return SpawnPlanner.find_spawn(WORLD_SEED, salt)


func _save_player_state() -> void:
	if _player == null:
		return
	var safe: Vector3 = _player.safe_position()
	if safe.y < 0.0:
		return
	var absolute_path: String = ProjectSettings.globalize_path(PLAYER_STATE_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"schema": PLAYER_STATE_SCHEMA,
		"world_seed": WORLD_SEED,
		"position": [safe.x, safe.y, safe.z],
	}))
	file.flush()
	file = null
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	DirAccess.rename_absolute(absolute_path + ".tmp", absolute_path)


func _diagnostic_context() -> Dictionary:
	var context: Dictionary = super._diagnostic_context()
	context["playable_pool_workers"] = _playable_pool.capacity()
	context["playable_pool_inflight"] = _playable_pool.inflight_count()
	context["emergency_load_queue"] = _emergency_load_queue.size()
	context["terrain_wait_total_ms"] = _terrain_wait_total_ms
	context["fall_recoveries"] = _fall_recovery_count
	return context
