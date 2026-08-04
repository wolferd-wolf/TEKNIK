extends SceneTree

const NativeChunkBackend = preload("res://src/world/native_chunk_backend.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const SEED: int = 73_421
const MINIMUM_CAVE_VOXELS: int = 120

var _failures: int = 0


func _init() -> void:
	var backend := NativeChunkBackend.new()
	_expect(backend.is_available(), "native cave worker is available")
	if not backend.is_available():
		_finish()
		return

	var coordinates: Array[Vector3i] = [
		Vector3i.ZERO,
		Vector3i(-1, 0, 0),
		Vector3i(1, 0, 0),
	]
	var total_caves: int = 0
	for coordinate: Vector3i in coordinates:
		total_caves += _verify_chunk(backend, coordinate)

	var first: PackedByteArray = TerrainGenerator.generate_chunk(SEED, Vector3i.ZERO).voxels
	var second: PackedByteArray = TerrainGenerator.generate_chunk(SEED, Vector3i.ZERO).voxels
	_expect(first == second, "cave generation is deterministic")
	_expect(
		total_caves >= MINIMUM_CAVE_VOXELS,
		"cave field creates useful traversable underground volume"
	)
	print(
		"CAVE_GENERATION_TESTS_PASS cave_voxels=", total_caves,
		" chunks=", coordinates.size(),
		" protected_surface_roof=4",
		" protected_floor_layers=2",
		" native_parity=true"
	)
	_finish()


func _verify_chunk(backend: TeknikNativeChunkBackend, coordinate: Vector3i) -> int:
	var chunk: TeknikVoxelChunk = TerrainGenerator.generate_chunk(SEED, coordinate)
	var native: Dictionary = backend.build_chunk(SEED, coordinate, {})
	var label: String = str(coordinate)
	_expect(bool(native.get("success", false)), label + " native cave chunk builds")
	if not bool(native.get("success", false)):
		return 0
	var native_voxels: PackedByteArray = native.get("voxels", PackedByteArray())
	_expect(native_voxels == chunk.voxels, label + " Godot and Rust cave voxels match")

	var origin: Vector3i = coordinate * VoxelChunk.SIZE
	var cave_count: int = 0
	for z: int in range(VoxelChunk.SIZE):
		for x: int in range(VoxelChunk.SIZE):
			var world_x: int = origin.x + x
			var world_z: int = origin.z + z
			var column: Vector2i = TerrainGenerator.sample_column(SEED, world_x, world_z)
			var surface_y: int = column.x
			for y: int in range(VoxelChunk.SIZE):
				var world_position := Vector3i(world_x, origin.y + y, world_z)
				var index: int = VoxelChunk.index_of(Vector3i(x, y, z))
				var generated_base: int = TerrainGenerator.material_from_column(
					world_position.y,
					column
				)
				var actual: int = int(chunk.voxels[index])
				if x % 8 == 0 and z % 8 == 0 and y % 5 == 0:
					_expect(
						TerrainGenerator.voxel_at(SEED, world_position) == actual,
						label + " voxel_at agrees with chunk bytes at " + str(world_position)
					)
				if generated_base == VoxelChunk.AIR:
					continue
				var depth: int = surface_y - world_position.y
				if world_position.y <= 1 or depth < 4:
					_expect(actual != VoxelChunk.AIR, label + " cave keeps protected shell")
				elif actual == VoxelChunk.AIR:
					cave_count += 1
	return cave_count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("CAVE_TEST_FAIL: " + message)


func _finish() -> void:
	if _failures > 0:
		push_error("CAVE_GENERATION_TESTS_FAILED count=%d" % _failures)
		quit(1)
		return
	quit(0)
