class_name TeknikChunkBuildWorker
extends RefCounted

const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")

var _thread := Thread.new()
var _busy: bool = false
var _coordinate: Vector3i = Vector3i.ZERO
var _seed: int = 0
var _started_usec: int = 0


func is_busy() -> bool:
	return _busy


func start(seed: int, coordinate: Vector3i) -> Error:
	if _busy:
		return ERR_BUSY
	_seed = seed
	_coordinate = coordinate
	_started_usec = Time.get_ticks_usec()
	_busy = true
	return _thread.start(Callable(self, "_build"))


func is_ready() -> bool:
	return _busy and not _thread.is_alive()


func collect() -> Dictionary:
	if not is_ready():
		return {}
	var result: Dictionary = _thread.wait_to_finish()
	_busy = false
	result["worker_usec"] = Time.get_ticks_usec() - _started_usec
	return result


func _build() -> Dictionary:
	var chunk: TeknikVoxelChunk = TerrainGenerator.generate_chunk(_seed, _coordinate)
	var world_origin: Vector3i = _coordinate * VoxelChunk.SIZE
	var report: Dictionary = GreedyMesher.build_arrays(
		chunk,
		world_origin,
		func(world_position: Vector3i) -> int:
			return TerrainGenerator.voxel_at(_seed, world_position),
		func(material: int, world_position: Vector3i) -> Color:
			return TerrainGenerator.surface_color(_seed, material, world_position)
	)
	report["coordinate"] = _coordinate
	return report
