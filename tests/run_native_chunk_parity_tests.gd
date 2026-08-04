extends SceneTree

const NativeChunkBackend = preload("res://src/world/native_chunk_backend.gd")
const PackedFaceCodec = preload("res://src/world/packed_face_codec.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const SEED: int = 73_421
const COLOR_EPSILON: float = 0.00005
const MINIMUM_PACKED_COMPRESSION_RATIO: float = 20.0

var _failures: int = 0


func _init() -> void:
	var backend := NativeChunkBackend.new()
	_expect(backend.is_available(), "Rust C++ native chunk backend is loaded")
	if not backend.is_available():
		_finish()
		return
	print("NATIVE_CHUNK_CORE version=", backend.core_version())
	_expect(
		backend.core_version().contains("packed-face"),
		"native core exposes the packed-face ABI version"
	)

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
	_compare_arrays(label + " native legacy", native_arrays, reference_arrays)

	var packed_faces: PackedInt32Array = native.get("packed_faces", PackedInt32Array())
	var packed_directional_faces: PackedInt32Array = native.get(
		"packed_directional_faces",
		PackedInt32Array()
	)
	var direction_offsets: PackedInt32Array = native.get(
		"packed_direction_offsets",
		PackedInt32Array()
	)
	var direction_counts: PackedInt32Array = native.get(
		"packed_direction_counts",
		PackedInt32Array()
	)
	_expect(
		packed_faces.size() == int(native.quads) * PackedFaceCodec.WORDS_PER_FACE,
		label + " has one two-word packed record per greedy quad"
	)
	_expect(
		int(native.get("packed_face_count", -1)) == int(native.quads),
		label + " packed face count matches quad count"
	)
	_expect(
		int(native.get("packed_face_bytes", -1)) == int(native.quads) * 8,
		label + " packed payload is exactly eight bytes per quad"
	)
	_expect(
		float(native.get("packed_compression_ratio", 0.0)) >= MINIMUM_PACKED_COMPRESSION_RATIO,
		label + " packed payload is at least twenty times smaller than legacy arrays"
	)

	var decoded: Dictionary = PackedFaceCodec.decode_arrays(
		packed_faces,
		coordinate * VoxelChunk.SIZE,
		SEED
	)
	_expect(bool(decoded.get("success", false)), label + " packed faces decode in Godot")
	if bool(decoded.get("success", false)):
		_expect(int(decoded.quads) == int(native.quads), label + " decoded quad count matches")
		_trace_first_packed_mismatch(coordinate, packed_faces, decoded.arrays, native_arrays)
		_compare_arrays(label + " packed decode", decoded.arrays, native_arrays)

	var partition: Dictionary = PackedFaceCodec.validate_directional_partition(
		packed_directional_faces,
		direction_offsets,
		direction_counts
	)
	_expect(bool(partition.get("success", false)), label + " directional streams partition every face")
	if bool(partition.get("success", false)):
		_expect(
			int(partition.face_count) == int(native.quads),
			label + " directional stream face count matches"
		)

	var all_fields_valid: bool = true
	var invalid_face_index: int = -1
	for face_index: int in range(packed_faces.size() / PackedFaceCodec.WORDS_PER_FACE):
		var face: Dictionary = PackedFaceCodec.decode_face_words(
			packed_faces[face_index * 2],
			packed_faces[face_index * 2 + 1]
		)
		if not bool(face.valid):
			all_fields_valid = false
			invalid_face_index = face_index
			break
	_expect(all_fields_valid, label + " all packed records have valid face-plane fields")
	if not all_fields_valid:
		print("PACKED_INVALID_FACE coordinate=", coordinate, " face=", invalid_face_index)

	print(
		"NATIVE_CHUNK_PARITY coordinate=", coordinate,
		" reference_usec=", reference_usec,
		" native_bridge_usec=", native_bridge_usec,
		" rust_generation_usec=", native.get("generation_usec", 0),
		" rust_mesh_usec=", native.get("mesh_worker_usec", 0),
		" quads=", native.quads,
		" packed_bytes=", native.get("packed_face_bytes", 0),
		" legacy_bytes=", native.get("legacy_mesh_bytes", 0),
		" compression=", native.get("packed_compression_ratio", 0.0),
		" packed_checksum=", native.get("packed_face_checksum", 0),
		" voxel_checksum=", native.get("voxel_checksum", 0)
	)


func _trace_first_packed_mismatch(
	coordinate: Vector3i,
	packed_faces: PackedInt32Array,
	actual_arrays: Array,
	expected_arrays: Array
) -> void:
	var actual_vertices: PackedVector3Array = actual_arrays[Mesh.ARRAY_VERTEX]
	var expected_vertices: PackedVector3Array = expected_arrays[Mesh.ARRAY_VERTEX]
	var count: int = mini(actual_vertices.size(), expected_vertices.size())
	for vertex_index: int in range(count):
		if actual_vertices[vertex_index] == expected_vertices[vertex_index]:
			continue
		var face_index: int = vertex_index / 4
		var decoded_face: Dictionary = PackedFaceCodec.decode_face_words(
			packed_faces[face_index * 2],
			packed_faces[face_index * 2 + 1]
		)
		print(
			"PACKED_VERTEX_MISMATCH coordinate=", coordinate,
			" world_origin=", coordinate * VoxelChunk.SIZE,
			" face=", face_index,
			" corner=", vertex_index % 4,
			" expected=", expected_vertices[vertex_index],
			" actual=", actual_vertices[vertex_index],
			" delta=", actual_vertices[vertex_index] - expected_vertices[vertex_index],
			" decoded=", decoded_face,
			" geometry_word=", packed_faces[face_index * 2],
			" appearance_word=", packed_faces[face_index * 2 + 1]
		)
		break

	var actual_colors: PackedColorArray = actual_arrays[Mesh.ARRAY_COLOR]
	var expected_colors: PackedColorArray = expected_arrays[Mesh.ARRAY_COLOR]
	count = mini(actual_colors.size(), expected_colors.size())
	for color_index: int in range(count):
		var actual: Color = actual_colors[color_index]
		var expected: Color = expected_colors[color_index]
		var error: float = maxf(
			maxf(absf(actual.r - expected.r), absf(actual.g - expected.g)),
			maxf(absf(actual.b - expected.b), absf(actual.a - expected.a))
		)
		if error <= COLOR_EPSILON:
			continue
		print(
			"PACKED_COLOR_MISMATCH coordinate=", coordinate,
			" vertex=", color_index,
			" expected=", expected,
			" actual=", actual,
			" max_error=", error
		)
		break


func _compare_arrays(label: String, actual_arrays: Array, expected_arrays: Array) -> void:
	var expected_vertices: PackedVector3Array = expected_arrays[Mesh.ARRAY_VERTEX]
	var actual_vertices: PackedVector3Array = actual_arrays[Mesh.ARRAY_VERTEX]
	var expected_normals: PackedVector3Array = expected_arrays[Mesh.ARRAY_NORMAL]
	var actual_normals: PackedVector3Array = actual_arrays[Mesh.ARRAY_NORMAL]
	var expected_colors: PackedColorArray = expected_arrays[Mesh.ARRAY_COLOR]
	var actual_colors: PackedColorArray = actual_arrays[Mesh.ARRAY_COLOR]
	var expected_indices: PackedInt32Array = expected_arrays[Mesh.ARRAY_INDEX]
	var actual_indices: PackedInt32Array = actual_arrays[Mesh.ARRAY_INDEX]

	_expect(actual_vertices == expected_vertices, label + " vertex positions match")
	_expect(actual_normals == expected_normals, label + " normals match")
	_expect(actual_indices == expected_indices, label + " index order matches")
	_expect(actual_colors.size() == expected_colors.size(), label + " color count matches")
	if actual_colors.size() != expected_colors.size():
		return
	var maximum_color_error: float = 0.0
	for index: int in range(actual_colors.size()):
		var actual_color: Color = actual_colors[index]
		var expected_color: Color = expected_colors[index]
		maximum_color_error = maxf(maximum_color_error, absf(actual_color.r - expected_color.r))
		maximum_color_error = maxf(maximum_color_error, absf(actual_color.g - expected_color.g))
		maximum_color_error = maxf(maximum_color_error, absf(actual_color.b - expected_color.b))
		maximum_color_error = maxf(maximum_color_error, absf(actual_color.a - expected_color.a))
	_expect(
		maximum_color_error <= COLOR_EPSILON,
		label + " vertex colors match within float precision"
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
