extends "res://src/main/main.gd"

const ChunkWorkBudget = preload("res://src/world/chunk_work_budget.gd")
const ChunkBuildWorker = preload("res://src/world/chunk_build_worker.gd")

const STREAM_LOADS_PER_FRAME: int = 1
const STREAM_UNLOADS_PER_FRAME: int = 1

var _chunk_work_budget: TeknikChunkWorkBudget = ChunkWorkBudget.new()
var _chunk_build_worker: TeknikChunkBuildWorker = ChunkBuildWorker.new()
var _stream_plan_center: Vector3i = Vector3i.ZERO
var _stream_plan_started_ms: int = 0
var _stream_loaded_total: int = 0
var _stream_unloaded_total: int = 0


func _process(_delta: float) -> void:
	_update_world_streaming()
	_process_chunk_work()


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
	terrain.position = Vector3(
		coordinate.x * VoxelChunk.SIZE,
		0.0,
		coordinate.z * VoxelChunk.SIZE
	)
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.set_meta("quad_count", int(report.quads))
	add_child(terrain)
	_terrain_nodes[coordinate] = terrain
	_chunk_stream.mark_loaded(coordinate)
	_render_instance_count += 1
