extends SceneTree

const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const ChunkBuildWorker = preload("res://src/world/chunk_build_worker.gd")

var _worker: TeknikChunkBuildWorker

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_worker = ChunkBuildWorker.new()
	var coordinate := Vector3i.ZERO
	var local := Vector3i(4, 4, 4)
	var index: int = VoxelChunk.index_of(local)
	var generated: int = TerrainGenerator.voxel_at(73421, local)
	var replacement: int = 0 if generated != 0 else TerrainGenerator.STONE
	var edits: Dictionary = {index: replacement}
	var start_error: Error = _worker.start(73421, coordinate, edits)
	if start_error != OK:
		push_error("FAIL worker accepts edit snapshot")
		quit(1)
		return
	while not _worker.is_ready():
		await process_frame
	var report: Dictionary = _worker.collect()
	if int(report.get("applied_edits", 0)) != 1:
		push_error("FAIL worker applies sparse edit before meshing")
		quit(1)
		return
	if int(report.get("quads", 0)) <= 0:
		push_error("FAIL edited worker still produces mesh arrays")
		quit(1)
		return
	print("PASS worker applies sparse edit before meshing")
	print("PASS edited worker still produces mesh arrays")
	print("CHUNK_EDIT_WORKER_TEST_RESULT PASS")
	quit(0)
