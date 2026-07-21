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
var _edit_snapshot: Dictionary = {}

func is_busy() -> bool:
	return _busy

func start(seed: int, coordinate: Vector3i, edit_snapshot: Dictionary = {}) -> Error:
	if _busy:
		return ERR_BUSY
	_seed = seed
	_coordinate = coordinate
	_edit_snapshot = edit_snapshot.duplicate(true)
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
	var applied_edits: int = 0
	for index_variant: Variant in _edit_snapshot.keys():
		var index: int = int(index_variant)
		if index >= 0 and index < VoxelChunk.VOLUME:
			var material: int = clampi(int(_edit_snapshot[index]), 0, 255)
			if int(chunk.voxels[index]) != material:
				chunk.voxels[index] = material
				applied_edits += 1
	if applied_edits > 0:
		chunk.revision += 1
	var world_origin: Vector3i = _coordinate * VoxelChunk.SIZE
	var report: Dictionary = GreedyMesher.build_arrays(
		chunk,
		world_origin,
		func(world_position: Vector3i) -> int:
			var neighbor_coordinate := Vector3i(
				floori(float(world_position.x) / float(VoxelChunk.SIZE)),
				floori(float(world_position.y) / float(VoxelChunk.SIZE)),
				floori(float(world_position.z) / float(VoxelChunk.SIZE))
			)
			if neighbor_coordinate == _coordinate:
				var local: Vector3i = world_position - _coordinate * VoxelChunk.SIZE
				return chunk.get_voxel(local)
			return TerrainGenerator.voxel_at(_seed, world_position),
		func(material: int, world_position: Vector3i) -> Color:
			return TerrainGenerator.surface_color(_seed, material, world_position)
	)
	report["coordinate"] = _coordinate
	report["applied_edits"] = applied_edits
	return report
