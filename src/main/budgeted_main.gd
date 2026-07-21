extends "res://src/main/main.gd"

const ChunkWorkBudget = preload("res://src/world/chunk_work_budget.gd")

const STREAM_LOADS_PER_FRAME: int = 1
const STREAM_UNLOADS_PER_FRAME: int = 1

var _chunk_work_budget: TeknikChunkWorkBudget = ChunkWorkBudget.new()
var _stream_plan_center: Vector3i = Vector3i.ZERO
var _stream_plan_started_ms: int = 0
var _stream_loaded_total: int = 0
var _stream_unloaded_total: int = 0


func _process(_delta: float) -> void:
	_update_world_streaming()
	_process_chunk_work()


func _refresh_terrain(center: Vector3i, priority: Vector3i) -> void:
	# The initial world must be complete before the first rendered frame and QA capture.
	# Runtime shifts are deliberately spread across frames to prevent a seven-chunk spike.
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
		" load_budget=", STREAM_LOADS_PER_FRAME,
		" unload_budget=", STREAM_UNLOADS_PER_FRAME
	)


func _process_chunk_work() -> void:
	if not _chunk_work_budget.has_work():
		return

	var frame_started_usec: int = Time.get_ticks_usec()
	var work: Dictionary = _chunk_work_budget.take_frame(
		STREAM_LOADS_PER_FRAME,
		STREAM_UNLOADS_PER_FRAME
	)
	var to_unload: Array[Vector3i] = work.unload
	var to_load: Array[Vector3i] = work.load

	for coordinate: Vector3i in to_unload:
		_unload_terrain_chunk(coordinate)
	for coordinate: Vector3i in to_load:
		_load_terrain_chunk(coordinate)

	_world_sample_cache.clear()
	_world_column_cache.clear()
	_stream_loaded_total += to_load.size()
	_stream_unloaded_total += to_unload.size()

	var frame_work_usec: int = Time.get_ticks_usec() - frame_started_usec
	print(
		"WORLD_STREAM frame_usec=", frame_work_usec,
		" loaded=", to_load.size(),
		" unloaded=", to_unload.size(),
		" remaining_loads=", int(work.remaining_loads),
		" remaining_unloads=", int(work.remaining_unloads),
		" active=", _chunk_stream.active_count()
	)

	if not _chunk_work_budget.has_work():
		print(
			"WORLD_STREAM complete_center=", _stream_plan_center,
			" elapsed_ms=", Time.get_ticks_msec() - _stream_plan_started_ms,
			" loaded_total=", _stream_loaded_total,
			" unloaded_total=", _stream_unloaded_total,
			" quads=", _total_quads,
			" render_instances=", _render_instance_count
		)


func _unload_terrain_chunk(coordinate: Vector3i) -> void:
	var terrain: MeshInstance3D = _terrain_nodes.get(coordinate)
	if terrain != null:
		_total_quads -= int(terrain.get_meta("quad_count", 0))
		terrain.queue_free()
		_terrain_nodes.erase(coordinate)
		_render_instance_count -= 1
	_chunk_stream.mark_unloaded(coordinate)


func _load_terrain_chunk(coordinate: Vector3i) -> void:
	if _terrain_nodes.has(coordinate):
		_chunk_stream.mark_loaded(coordinate)
		return

	var chunk: TeknikVoxelChunk = TerrainGenerator.generate_chunk(WORLD_SEED, coordinate)
	var report: Dictionary = GreedyMesher.build_mesh(
		chunk,
		coordinate * VoxelChunk.SIZE,
		Callable(self, "_sample_world_voxel"),
		Callable(self, "_sample_world_color")
	)
	_total_quads += int(report.quads)

	var terrain := MeshInstance3D.new()
	terrain.mesh = report.mesh
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
