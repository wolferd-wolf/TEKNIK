extends "res://src/main/main.gd"

const ChunkWorkBudget = preload("res://src/world/chunk_work_budget.gd")
const ChunkBuildWorker = preload("res://src/world/chunk_build_worker.gd")
const CollisionWindowPlan = preload("res://src/world/collision_window_plan.gd")
const ExplorationController = preload("res://src/player/exploration_controller.gd")
const PerformanceTelemetry = preload("res://src/diagnostics/performance_telemetry.gd")
const WorldEditStore = preload("res://src/world/world_edit_store.gd")
const InteractionMath = preload("res://src/world/world_interaction_math.gd")
const GameplayCaptureDirector = preload("res://src/qa/gameplay_capture_director.gd")

const STREAM_LOADS_PER_FRAME: int = 1
const STREAM_UNLOADS_PER_FRAME: int = 1
const COLLISION_RADIUS: int = 1
const COLLISION_ADDS_PER_FRAME: int = 1
const COLLISION_REMOVES_PER_FRAME: int = 2
const TELEMETRY_REPORT_INTERVAL_MS: int = 10_000
const EDIT_SAVE_DELAY_MS: int = 1200
const INTERACTION_DISTANCE: float = 7.0
const PLACE_MATERIAL: int = 1
const EDIT_SAVE_PATH: String = "user://teknik-world-edits.json"

var _chunk_work_budget: TeknikChunkWorkBudget = ChunkWorkBudget.new()
var _chunk_build_worker: TeknikChunkBuildWorker = ChunkBuildWorker.new()
var _performance_telemetry: TeknikPerformanceTelemetry = PerformanceTelemetry.new()
var _world_edits: TeknikWorldEditStore = WorldEditStore.new()
var _edit_rebuild_queue: Array[Vector3i] = []
var _stream_plan_center: Vector3i = Vector3i.ZERO
var _stream_plan_started_ms: int = 0
var _stream_loaded_total: int = 0
var _stream_unloaded_total: int = 0
var _collision_bodies: Dictionary = {}
var _collision_add_queue: Array[Vector3i] = []
var _collision_remove_queue: Array[Vector3i] = []
var _collision_center: Vector3i = Vector3i(2_147_483_647, 0, 2_147_483_647)
var _player: TeknikExplorationController
var _next_telemetry_report_ms: int = 0
var _edit_save_due_ms: int = 0


func _ready() -> void:
	var load_result: Error = _world_edits.load_file(EDIT_SAVE_PATH, WORLD_SEED)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		push_warning("WORLD_EDIT load failed: %s" % error_string(load_result))
	super._ready()
	if _qa_screenshot_path().is_empty():
		_build_player_controller()
	_queue_collision_window(_world_center)
	_next_telemetry_report_ms = Time.get_ticks_msec() + TELEMETRY_REPORT_INTERVAL_MS
	for coordinate: Vector3i in _world_edits.edited_chunk_coordinates():
		if _terrain_nodes.has(coordinate):
			_queue_chunk_rebuild(coordinate)
	print("WORLD_EDIT loaded_overrides=", _world_edits.override_count(), " edited_chunks=", _world_edits.chunk_count())
	if "--qa-gameplay" in OS.get_cmdline_user_args() and _player != null:
		var director: TeknikGameplayCaptureDirector = GameplayCaptureDirector.new()
		director.name = "GameplayCaptureDirector"
		add_child(director)
		director.begin(self, _player)


func _process(delta: float) -> void:
	_performance_telemetry.record_frame(delta)
	_update_world_streaming()
	_process_chunk_work()
	_update_collision_window()
	_process_collision_work()
	_save_edits_if_due()
	_report_performance_if_due()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_edits_now()


func _refresh_terrain(center: Vector3i, priority: Vector3i) -> void:
	if _terrain_nodes.is_empty() and _chunk_stream.active_count() == 0:
		super._refresh_terrain(center, priority)
		return
	var delta: Dictionary = _chunk_stream.reconcile(center, CHUNK_RADIUS, priority)
	var to_load: Array[Vector3i] = delta.load
	var to_unload: Array[Vector3i] = delta.unload
	_chunk_work_budget.replace(to_load, to_unload)
	_stream_plan_center = center
	_stream_plan_started_ms = Time.get_ticks_msec()
	_stream_loaded_total = 0
	_stream_unloaded_total = 0


func _process_chunk_work() -> void:
	var frame_started_usec: int = Time.get_ticks_usec()
	var completed_loads: int = 0
	var worker_usec: int = 0
	if _chunk_build_worker.is_ready():
		var report: Dictionary = _chunk_build_worker.collect()
		worker_usec = int(report.worker_usec)
		_commit_terrain_chunk(report)
		completed_loads = 1
		_stream_loaded_total += 1

	var can_dispatch: bool = not _chunk_build_worker.is_busy()
	var load_budget: int = STREAM_LOADS_PER_FRAME if can_dispatch and _edit_rebuild_queue.is_empty() else 0
	var work: Dictionary = _chunk_work_budget.take_frame(load_budget, STREAM_UNLOADS_PER_FRAME)
	var to_unload: Array[Vector3i] = work.unload
	for coordinate: Vector3i in to_unload:
		_unload_terrain_chunk(coordinate)
	_stream_unloaded_total += to_unload.size()

	var dispatched: int = 0
	if can_dispatch and not _edit_rebuild_queue.is_empty():
		var rebuild_coordinate: Vector3i = _edit_rebuild_queue.pop_front()
		if _terrain_nodes.has(rebuild_coordinate):
			_dispatch_chunk_build(rebuild_coordinate)
			dispatched = 1
	elif can_dispatch:
		var to_load: Array[Vector3i] = work.load
		if not to_load.is_empty():
			_dispatch_chunk_build(to_load[0])
			dispatched = 1

	var main_usec: int = Time.get_ticks_usec() - frame_started_usec
	if completed_loads > 0 or not to_unload.is_empty() or dispatched > 0:
		_performance_telemetry.record_stream(main_usec, worker_usec)
		_world_sample_cache.clear()
		_world_column_cache.clear()
	if not _chunk_work_budget.has_work() and _edit_rebuild_queue.is_empty() and not _chunk_build_worker.is_busy() and _stream_plan_started_ms > 0:
		print("WORLD_STREAM complete_center=", _stream_plan_center, " elapsed_ms=", Time.get_ticks_msec() - _stream_plan_started_ms, " loaded_total=", _stream_loaded_total, " unloaded_total=", _stream_unloaded_total)
		_stream_plan_started_ms = 0


func _dispatch_chunk_build(coordinate: Vector3i) -> void:
	var snapshots: Dictionary = _world_edits.snapshot_neighborhood(coordinate)
	var start_result: Error = _chunk_build_worker.start(WORLD_SEED, coordinate, snapshots)
	if start_result != OK:
		push_error("Failed to start chunk worker: %s" % error_string(start_result))


func _queue_chunk_rebuild(coordinate: Vector3i) -> void:
	if not _terrain_nodes.has(coordinate) or _edit_rebuild_queue.has(coordinate):
		return
	_edit_rebuild_queue.append(coordinate)


func _unload_terrain_chunk(coordinate: Vector3i) -> void:
	_remove_chunk_collision(coordinate)
	var terrain: MeshInstance3D = _terrain_nodes.get(coordinate)
	if terrain != null:
		_total_quads -= int(terrain.get_meta("quad_count", 0))
		terrain.queue_free()
		_terrain_nodes.erase(coordinate)
		_render_instance_count -= 1
	_chunk_stream.mark_unloaded(coordinate)
	_edit_rebuild_queue.erase(coordinate)


func _commit_terrain_chunk(report: Dictionary) -> void:
	var coordinate: Vector3i = report.coordinate
	var mesh: ArrayMesh = GreedyMesher.mesh_from_arrays(report.arrays)
	var new_quads: int = int(report.quads)
	var terrain: MeshInstance3D = _terrain_nodes.get(coordinate)
	if terrain != null:
		_remove_chunk_collision(coordinate)
		_total_quads -= int(terrain.get_meta("quad_count", 0))
		terrain.mesh = mesh
		terrain.set_meta("quad_count", new_quads)
	else:
		terrain = MeshInstance3D.new()
		terrain.mesh = mesh
		terrain.position = Vector3(coordinate.x * VoxelChunk.SIZE, 0.0, coordinate.z * VoxelChunk.SIZE)
		terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		terrain.set_meta("quad_count", new_quads)
		add_child(terrain)
		_terrain_nodes[coordinate] = terrain
		_render_instance_count += 1
	_total_quads += new_quads
	_chunk_stream.mark_loaded(coordinate)
	if _coordinate_needs_collision(coordinate) and not _collision_add_queue.has(coordinate):
		_collision_add_queue.append(coordinate)


func _build_player_controller() -> void:
	_player = ExplorationController.new()
	_player.name = "ExplorationController"
	var spawn_x: int = -62
	var spawn_z: int = roundi(TerrainGenerator.river_center_z(WORLD_SEED, spawn_x) + 15.0)
	var spawn_height: int = TerrainGenerator.surface_height(WORLD_SEED, spawn_x, spawn_z)
	_player.position = Vector3(float(spawn_x) + 0.5, float(spawn_height) + 2.5, float(spawn_z) + 0.5)
	add_child(_player)
	_player.set_camera_active(true)
	_player.break_requested.connect(_on_break_requested)
	_player.place_requested.connect(_on_place_requested)
	_exploration_anchor = _player


func _raycast_world(origin: Vector3, direction: Vector3) -> Dictionary:
	if _player == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * INTERACTION_DISTANCE)
	query.exclude = [_player.get_rid()]
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)


func _on_break_requested(origin: Vector3, direction: Vector3) -> void:
	var hit: Dictionary = _raycast_world(origin, direction)
	if hit.is_empty():
		return
	var voxel: Vector3i = InteractionMath.removal_voxel(hit.position, hit.normal)
	var generated: int = TerrainGenerator.voxel_at(WORLD_SEED, voxel)
	var current: int = _world_edits.get_override(voxel, generated)
	if current == VoxelChunk.AIR:
		return
	_apply_voxel_edit(voxel, VoxelChunk.AIR, "removed")


func _on_place_requested(origin: Vector3, direction: Vector3) -> void:
	var hit: Dictionary = _raycast_world(origin, direction)
	if hit.is_empty():
		return
	var voxel: Vector3i = InteractionMath.placement_voxel(hit.position, hit.normal)
	var generated: int = TerrainGenerator.voxel_at(WORLD_SEED, voxel)
	var current: int = _world_edits.get_override(voxel, generated)
	if current != VoxelChunk.AIR or _placement_intersects_player(voxel):
		return
	_apply_voxel_edit(voxel, PLACE_MATERIAL, "placed")


func _placement_intersects_player(voxel: Vector3i) -> bool:
	if _player == null:
		return false
	var block_bounds := AABB(Vector3(voxel), Vector3.ONE)
	var player_bounds := AABB(
		_player.global_position + Vector3(-0.42, 0.0, -0.42),
		Vector3(0.84, 1.75, 0.84)
	)
	return block_bounds.intersects(player_bounds)


func _apply_voxel_edit(voxel: Vector3i, material: int, action: String) -> void:
	if not _world_edits.set_override(voxel, material):
		return
	var affected: Array[Vector3i] = InteractionMath.affected_chunk_coordinates(voxel, VoxelChunk.SIZE)
	for coordinate: Vector3i in affected:
		_queue_chunk_rebuild(coordinate)
	_edit_save_due_ms = Time.get_ticks_msec() + EDIT_SAVE_DELAY_MS
	print("WORLD_EDIT ", action, "=", voxel, " material=", material, " affected_chunks=", affected.size(), " total_overrides=", _world_edits.override_count())


func qa_apply_voxel_edit(voxel: Vector3i, material: int, action: String) -> void:
	_apply_voxel_edit(voxel, material, action)


func qa_world_idle() -> bool:
	return not _chunk_work_budget.has_work() and _edit_rebuild_queue.is_empty() and not _chunk_build_worker.is_busy() and not _chunk_build_worker.is_ready() and _collision_add_queue.is_empty() and _collision_remove_queue.is_empty()


func qa_save_edits_now() -> void:
	_save_edits_now()


func qa_world_seed() -> int:
	return WORLD_SEED


func qa_place_material() -> int:
	return PLACE_MATERIAL


func _save_edits_if_due() -> void:
	if _edit_save_due_ms <= 0 or Time.get_ticks_msec() < _edit_save_due_ms:
		return
	_save_edits_now()


func _save_edits_now() -> void:
	if not _world_edits.is_dirty():
		_edit_save_due_ms = 0
		return
	var result: Error = _world_edits.save_atomic(EDIT_SAVE_PATH, WORLD_SEED)
	if result != OK:
		push_error("WORLD_EDIT save failed: %s" % error_string(result))
	else:
		print("WORLD_EDIT saved overrides=", _world_edits.override_count())
	_edit_save_due_ms = 0


func _update_collision_window() -> void:
	if _world_center != _collision_center:
		_queue_collision_window(_world_center)


func _queue_collision_window(center: Vector3i) -> void:
	_collision_center = center
	var delta: Dictionary = CollisionWindowPlan.reconcile(_collision_bodies, center, COLLISION_RADIUS)
	_collision_add_queue = delta.add
	_collision_remove_queue = delta.remove


func _process_collision_work() -> void:
	var started_usec: int = Time.get_ticks_usec()
	var changed: bool = false
	for _index: int in range(mini(COLLISION_REMOVES_PER_FRAME, _collision_remove_queue.size())):
		_remove_chunk_collision(_collision_remove_queue.pop_front())
		changed = true
	for _index: int in range(mini(COLLISION_ADDS_PER_FRAME, _collision_add_queue.size())):
		var coordinate: Vector3i = _collision_add_queue.pop_front()
		if not _add_chunk_collision(coordinate) and _terrain_nodes.has(coordinate):
			_collision_add_queue.append(coordinate)
		else:
			changed = true
	if changed:
		_performance_telemetry.record_collision(Time.get_ticks_usec() - started_usec)


func _coordinate_needs_collision(coordinate: Vector3i) -> bool:
	return absi(coordinate.x - _world_center.x) <= COLLISION_RADIUS and absi(coordinate.z - _world_center.z) <= COLLISION_RADIUS


func _add_chunk_collision(coordinate: Vector3i) -> bool:
	if _collision_bodies.has(coordinate):
		return true
	var terrain: MeshInstance3D = _terrain_nodes.get(coordinate)
	if terrain == null or terrain.mesh == null:
		return false
	var shape: Shape3D = terrain.mesh.create_trimesh_shape()
	if shape == null:
		return false
	var body := StaticBody3D.new()
	body.name = "TerrainCollision_%d_%d" % [coordinate.x, coordinate.z]
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	terrain.add_child(body)
	_collision_bodies[coordinate] = body
	return true


func _remove_chunk_collision(coordinate: Vector3i) -> void:
	var body: StaticBody3D = _collision_bodies.get(coordinate)
	if body != null:
		body.queue_free()
	_collision_bodies.erase(coordinate)


func _report_performance_if_due() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_telemetry_report_ms:
		return
	var report: Dictionary = _performance_telemetry.snapshot()
	report["timestamp_unix_ms"] = Time.get_unix_time_from_system() * 1000.0
	report["world_center"] = str(_world_center)
	report["active_render_chunks"] = _terrain_nodes.size()
	report["active_collision_chunks"] = _collision_bodies.size()
	report["world_edit_overrides"] = _world_edits.override_count()
	report["static_memory_bytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	print("WORLD_PERF ", JSON.stringify(report))
	var file := FileAccess.open("user://teknik-performance-latest.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	_performance_telemetry.reset_event_peaks()
	_next_telemetry_report_ms = now_ms + TELEMETRY_REPORT_INTERVAL_MS


func _capture_qa_screenshot(path: String) -> void:
	var wait_frames: int = 0
	while (_chunk_work_budget.has_work() or not _edit_rebuild_queue.is_empty() or _chunk_build_worker.is_busy() or _chunk_build_worker.is_ready()) and wait_frames < 900:
		await get_tree().process_frame
		wait_frames += 1
	for frame: int in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var absolute_path: String = path if path.is_absolute_path() else ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var image: Image = get_viewport().get_texture().get_image()
	var result: Error = image.save_png(absolute_path)
	if result == OK:
		print("QA_SCREENSHOT_SAVED ", absolute_path, " wait_frames=", wait_frames)
		get_tree().quit(0)
	else:
		push_error("Failed to save QA screenshot: %s" % error_string(result))
		get_tree().quit(1)
