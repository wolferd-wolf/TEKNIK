extends "res://src/main/main.gd"

const ChunkWorkBudget = preload("res://src/world/chunk_work_budget.gd")
const ChunkBuildWorker = preload("res://src/world/chunk_build_worker.gd")
const CollisionWindowPlan = preload("res://src/world/collision_window_plan.gd")
const ExplorationController = preload("res://src/player/exploration_controller.gd")

const STREAM_LOADS_PER_FRAME: int = 1
const STREAM_UNLOADS_PER_FRAME: int = 1
const COLLISION_RADIUS: int = 1
const COLLISION_ADDS_PER_FRAME: int = 1
const COLLISION_REMOVES_PER_FRAME: int = 2

var _chunk_work_budget: TeknikChunkWorkBudget = ChunkWorkBudget.new()
var _chunk_build_worker: TeknikChunkBuildWorker = ChunkBuildWorker.new()
var _stream_plan_center: Vector3i = Vector3i.ZERO
var _stream_plan_started_ms: int = 0
var _stream_loaded_total: int = 0
var _stream_unloaded_total: int = 0
var _collision_bodies: Dictionary = {}
var _collision_add_queue: Array[Vector3i] = []
var _collision_remove_queue: Array[Vector3i] = []
var _collision_center: Vector3i = Vector3i(2_147_483_647, 0, 2_147_483_647)
var _player: TeknikExplorationController


func _ready() -> void:
	super._ready()
	if _qa_screenshot_path().is_empty():
		_build_player_controller()
	_queue_collision_window(_world_center)


func _process(_delta: float) -> void:
	_update_world_streaming()
	_process_chunk_work()
	_update_collision_window()
	_process_collision_work()


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
	print(
		"WORLD_STREAM queued_center=", center,
		" loads=", to_load.size(),
		" unloads=", to_unload.size(),
		" threaded_cpu=true"
	)


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
	var load_budget: int = 0 if _chunk_build_worker.is_busy() else STREAM_LOADS_PER_FRAME
	var work: Dictionary = _chunk_work_budget.take_frame(load_budget, STREAM_UNLOADS_PER_FRAME)
	var to_unload: Array[Vector3i] = work.unload
	var to_load: Array[Vector3i] = work.load
	for coordinate: Vector3i in to_unload:
		_unload_terrain_chunk(coordinate)
	_stream_unloaded_total += to_unload.size()
	if not to_load.is_empty():
		var coordinate: Vector3i = to_load[0]
		var start_result: Error = _chunk_build_worker.start(WORLD_SEED, coordinate)
		if start_result != OK:
			push_error("Failed to start chunk worker: %s" % error_string(start_result))
	if completed_loads > 0 or not to_unload.is_empty() or not to_load.is_empty():
		_world_sample_cache.clear()
		_world_column_cache.clear()
		print(
			"WORLD_STREAM main_usec=", Time.get_ticks_usec() - frame_started_usec,
			" worker_usec=", worker_usec,
			" committed=", completed_loads,
			" dispatched=", to_load.size(),
			" unloaded=", to_unload.size(),
			" remaining_loads=", int(work.remaining_loads),
			" remaining_unloads=", int(work.remaining_unloads),
			" worker_busy=", _chunk_build_worker.is_busy()
		)
	if not _chunk_work_budget.has_work() and not _chunk_build_worker.is_busy() and _stream_plan_started_ms > 0:
		print(
			"WORLD_STREAM complete_center=", _stream_plan_center,
			" elapsed_ms=", Time.get_ticks_msec() - _stream_plan_started_ms,
			" loaded_total=", _stream_loaded_total,
			" unloaded_total=", _stream_unloaded_total,
			" quads=", _total_quads,
			" render_instances=", _render_instance_count
		)
		_stream_plan_started_ms = 0


func _unload_terrain_chunk(coordinate: Vector3i) -> void:
	_remove_chunk_collision(coordinate)
	var terrain: MeshInstance3D = _terrain_nodes.get(coordinate)
	if terrain != null:
		_total_quads -= int(terrain.get_meta("quad_count", 0))
		terrain.queue_free()
		_terrain_nodes.erase(coordinate)
		_render_instance_count -= 1
	_chunk_stream.mark_unloaded(coordinate)


func _commit_terrain_chunk(report: Dictionary) -> void:
	var coordinate: Vector3i = report.coordinate
	if _terrain_nodes.has(coordinate):
		_chunk_stream.mark_loaded(coordinate)
		return
	var mesh: ArrayMesh = GreedyMesher.mesh_from_arrays(report.arrays)
	_total_quads += int(report.quads)
	var terrain := MeshInstance3D.new()
	terrain.mesh = mesh
	terrain.position = Vector3(coordinate.x * VoxelChunk.SIZE, 0.0, coordinate.z * VoxelChunk.SIZE)
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.set_meta("quad_count", int(report.quads))
	add_child(terrain)
	_terrain_nodes[coordinate] = terrain
	_chunk_stream.mark_loaded(coordinate)
	_render_instance_count += 1
	if _coordinate_needs_collision(coordinate):
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
	_exploration_anchor = _player
	print("WORLD_PLAYER spawn=", _player.position, " collision_radius=", COLLISION_RADIUS)


func _update_collision_window() -> void:
	if _world_center != _collision_center:
		_queue_collision_window(_world_center)


func _queue_collision_window(center: Vector3i) -> void:
	_collision_center = center
	var delta: Dictionary = CollisionWindowPlan.reconcile(_collision_bodies, center, COLLISION_RADIUS)
	_collision_add_queue = delta.add
	_collision_remove_queue = delta.remove
	print("WORLD_COLLISION center=", center, " queued_add=", _collision_add_queue.size(), " queued_remove=", _collision_remove_queue.size())


func _process_collision_work() -> void:
	for _index: int in range(mini(COLLISION_REMOVES_PER_FRAME, _collision_remove_queue.size())):
		_remove_chunk_collision(_collision_remove_queue.pop_front())
	for _index: int in range(mini(COLLISION_ADDS_PER_FRAME, _collision_add_queue.size())):
		var coordinate: Vector3i = _collision_add_queue.pop_front()
		if not _add_chunk_collision(coordinate) and _terrain_nodes.has(coordinate):
			_collision_add_queue.append(coordinate)


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
	print("WORLD_COLLISION added=", coordinate, " active=", _collision_bodies.size())
	return true


func _remove_chunk_collision(coordinate: Vector3i) -> void:
	var body: StaticBody3D = _collision_bodies.get(coordinate)
	if body != null:
		body.queue_free()
	_collision_bodies.erase(coordinate)
