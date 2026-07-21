extends SceneTree

const NativeChunkBackend = preload("res://src/world/native_chunk_backend.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const SEED: int = 73_421
const COLOR_EPSILON: float = 0.00005

var _failures: int = 0


func _init() -> void:
	var backend := NativeChunkBackend.new()
	_expect(backend.is_available(), "Rust C++ native chunk backend is loaded")
	if not backend.is_available():
		_finish()
		return
	print("NATIVE_CHUNK_CORE version=", backend.core_version())

	var coordinates: Array[Vector3i] = [
		Vector3i.ZERO,
		Vector3i(-1, 0, -1),
		Vector3i(2, 0, 1),
		Vector3i(-3, 0, 2),
	]
	for coordinate: Vector3i in coordinates:
		_compare_chunk(backend, coordinate, {})

	var edited_coordinate := Vector3i(1, 0, -2)
	var snapshots: Dictionary = {}
	var current_edits: Dictionary = {
		VoxelChunk.index_of(Vector3i(4, 12, 7)): VoxelChunk.AIR,
		VoxelChunk.index_of(Vector3i(15, 25, 15)): TerrainGenerator.STONE,
	}
	var right_edits: Dictionary = {
		VoxelChunk.index_of(Vector3i(0, 10, 9)): VoxelChunk.AIR,
		VoxelChunk.index_of(Vector3i(0, 24, 18)): TerrainGenerator.STONE,
	}
	snapshots[edited_coordinate] = current_edits
	snapshots[edited_coordinate + Vector3i.RIGHT] = right_edits
	_compare_chunk(backend, edited_coordinate, snapshots)
	_finish()


func _compare_chunk(
	backend: TeknikNativeChunkBackend,
	coordinate: Vector3i,
	snapshots: Dictionary
) -> void:
	var reference_started: int = Time.get_ticks_usec()
	var reference: Dictionary = _build_reference(coordinate, snapshots)
	var reference_usec: int = Time.get_ticks_usec() - reference_started
	var native_started: int = Time.get_ticks_usec()
	var native: Dictionary = backend.build_chunk(SEED, coordinate, snapshots)
	var native_bridge_usec: int = Time.get_ticks_usec() - native_started
	var label: String = str(coordinate)

	_expect(bool(native.get("success", false)), label + " native build succeeds")
	if not bool(native.get("success", false)):
		push_error("Native error for %s: %s" % [label, native.get("error", "unknown")])
		return

	var reference_voxels: PackedByteArray = reference.voxels
	var native_voxels: PackedByteArray = native.voxels
	_expect(native_voxels == reference_voxels, label + " voxel bytes match")
	_expect(int(native.quads) == int(reference.quads), label + " quad count matches")
	_expect(int(native.triangles) == int(reference.triangles), label + " triangle count matches")
	_expect(int(native.applied_edits) == int(reference.applied_edits), label + " edit count matches")

	var reference_arrays: Array = reference.arrays
	var native_arrays: Array = native.arrays
	var reference_vertices: PackedVector3Array = reference_arrays[Mesh.ARRAY_VERTEX]
	var native_vertices: PackedVector3Array = native_arrays[Mesh.ARRAY_VERTEX]
	var reference_normals: PackedVector3Array = reference_arrays[Mesh.ARRAY_NORMAL]
	var native_normals: PackedVector3Array = native_arrays[Mesh.ARRAY_NORMAL]
	var reference_colors: PackedColorArray = reference_arrays[Mesh.ARRAY_COLOR]
	var native_colors: PackedColorArray = native_arrays[Mesh.ARRAY_COLOR]
	var reference_indices: PackedInt32Array = reference_arrays[Mesh.ARRAY_INDEX]
	var native_indices: PackedInt32Array = native_arrays[Mesh.ARRAY_INDEX]

	_expect(native_vertices == reference_vertices, label + " vertex positions match")
	_expect(native_normals == reference_normals, label + " normals match")
	_expect(native_indices == reference_indices, label + " index order matches")
	_expect(native_colors.size() == reference_colors.size(), label + " color count matches")
	if native_colors.size() == reference_colors.size():
		var maximum_color_error: float = 0.0
		for index: int in range(native_colors.size()):
			var native_color: Color = native_colors[index]
			var reference_color: Color = reference_colors[index]
			maximum_color_error = maxf(
				maximum_color_error,
				absf(native_color.r - reference_color.r)
			)
			maximum_color_error = maxf(
				maximum_color_error,
				absf(native_color.g - reference_color.g)
			)
			maximum_color_error = maxf(
				maximum_color_error,
				absf(native_color.b - reference_color.b)
			)
			maximum_color_error = maxf(
				maximum_color_error,
				absf(native_color.a - reference_color.a)
			)
		_expect(
			maximum_color_error <= COLOR_EPSILON,
			label + " vertex colors match within float precision"
		)

	print(
		"NATIVE_CHUNK_PARITY coordinate=", coordinate,
		" reference_usec=", reference_usec,
		" native_bridge_usec=", native_bridge_usec,
		" rust_generation_usec=", native.get("generation_usec", 0),
		" rust_mesh_usec=", native.get("mesh_worker_usec", 0),
		" quads=", native.quads,
		" checksum=", native.get("voxel_checksum", 0)
	)


func _build_reference(coordinate: Vector3i, snapshots: Dictionary) -> Dictionary:
	var chunk: TeknikVoxelChunk = TerrainGenerator.generate_chunk(SEED, coordinate)
	var applied_edits: int = 0
	var current_edits: Dictionary = snapshots.get(coordinate, {})
	for index_variant: Variant in current_edits.keys():
		var index: int = int(index_variant)
		if index < 0 or index >= VoxelChunk.VOLUME:
			continue
		var material: int = clampi(int(current_edits[index]), 0, 255)
		if int(chunk.voxels[index]) != material:
			chunk.voxels[index] = material
			applied_edits += 1

	var world_origin: Vector3i = coordinate * VoxelChunk.SIZE
	var boundary_columns: Dictionary = {}
	var report: Dictionary = GreedyMesher.build_arrays(
		chunk,
		world_origin,
		func(world_position: Vector3i) -> int:
			if world_position.y < world_origin.y:
				return TerrainGenerator.STONE
			if world_position.y >= world_origin.y + VoxelChunk.SIZE:
				return VoxelChunk.AIR
			var neighbor_coordinate := Vector3i(
				floori(float(world_position.x) / float(VoxelChunk.SIZE)),
				coordinate.y,
				floori(float(world_position.z) / float(VoxelChunk.SIZE))
			)
			if neighbor_coordinate == coordinate:
				return chunk.get_voxel(world_position - world_origin)
			var key := Vector2i(world_position.x, world_position.z)
			var column: Vector2i
			if boundary_columns.has(key):
				column = boundary_columns[key]
			else:
				column = TerrainGenerator.sample_column(
					SEED,
					world_position.x,
					world_position.z
				)
				boundary_columns[key] = column
			var generated: int = TerrainGenerator.material_from_column(
				world_position.y,
				column
			)
			var neighbor_edits: Dictionary = snapshots.get(neighbor_coordinate, {})
			if neighbor_edits.is_empty():
				return generated
			var local: Vector3i = world_position - neighbor_coordinate * VoxelChunk.SIZE
			return int(neighbor_edits.get(VoxelChunk.index_of(local), generated)),
		func(material: int, world_position: Vector3i) -> Color:
			return TerrainGenerator.fast_surface_color(SEED, material, world_position)
	)
	report["voxels"] = chunk.voxels
	report["applied_edits"] = applied_edits
	return report


func _finish() -> void:
	if _failures == 0:
		print("NATIVE_CHUNK_PARITY_TEST_RESULT PASS")
		quit(0)
	else:
		print("NATIVE_CHUNK_PARITY_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
