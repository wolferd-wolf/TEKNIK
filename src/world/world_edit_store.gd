class_name TeknikWorldEditStore
extends RefCounted

const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const SCHEMA_VERSION: int = 1

var _chunks: Dictionary = {}
var _dirty: bool = false


static func chunk_coordinate(world_position: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(world_position.x) / float(VoxelChunk.SIZE)),
		floori(float(world_position.y) / float(VoxelChunk.SIZE)),
		floori(float(world_position.z) / float(VoxelChunk.SIZE))
	)


static func local_coordinate(world_position: Vector3i) -> Vector3i:
	var coordinate: Vector3i = chunk_coordinate(world_position)
	return world_position - coordinate * VoxelChunk.SIZE


func set_override(world_position: Vector3i, material: int) -> bool:
	var coordinate: Vector3i = chunk_coordinate(world_position)
	var local: Vector3i = local_coordinate(world_position)
	var index: int = VoxelChunk.index_of(local)
	var value: int = clampi(material, 0, 255)
	var edits: Dictionary = _chunks.get(coordinate, {})
	if edits.has(index) and int(edits[index]) == value:
		return false
	edits[index] = value
	_chunks[coordinate] = edits
	_dirty = true
	return true


func remove_override(world_position: Vector3i) -> bool:
	var coordinate: Vector3i = chunk_coordinate(world_position)
	if not _chunks.has(coordinate):
		return false
	var edits: Dictionary = _chunks[coordinate]
	var index: int = VoxelChunk.index_of(local_coordinate(world_position))
	if not edits.erase(index):
		return false
	if edits.is_empty():
		_chunks.erase(coordinate)
	else:
		_chunks[coordinate] = edits
	_dirty = true
	return true


func has_override(world_position: Vector3i) -> bool:
	var coordinate: Vector3i = chunk_coordinate(world_position)
	if not _chunks.has(coordinate):
		return false
	return (_chunks[coordinate] as Dictionary).has(VoxelChunk.index_of(local_coordinate(world_position)))


func get_override(world_position: Vector3i, fallback: int = VoxelChunk.AIR) -> int:
	var coordinate: Vector3i = chunk_coordinate(world_position)
	if not _chunks.has(coordinate):
		return fallback
	return int((_chunks[coordinate] as Dictionary).get(VoxelChunk.index_of(local_coordinate(world_position)), fallback))


func snapshot_for_chunk(coordinate: Vector3i) -> Dictionary:
	return (_chunks.get(coordinate, {}) as Dictionary).duplicate(true)


func apply_to_chunk(coordinate: Vector3i, chunk: TeknikVoxelChunk) -> int:
	var edits: Dictionary = _chunks.get(coordinate, {})
	var applied: int = 0
	for index_variant: Variant in edits.keys():
		var index: int = int(index_variant)
		if index < 0 or index >= VoxelChunk.VOLUME:
			continue
		if int(chunk.voxels[index]) != int(edits[index]):
			chunk.voxels[index] = int(edits[index])
			applied += 1
	if applied > 0:
		chunk.revision += 1
	return applied


func override_count() -> int:
	var total: int = 0
	for edits: Dictionary in _chunks.values():
		total += edits.size()
	return total


func chunk_count() -> int:
	return _chunks.size()


func is_dirty() -> bool:
	return _dirty


func mark_clean() -> void:
	_dirty = false


func encode(seed: int) -> Dictionary:
	var coordinates: Array[Vector3i] = []
	for coordinate: Vector3i in _chunks.keys():
		coordinates.append(coordinate)
	coordinates.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z
	)
	var chunk_records: Array[Dictionary] = []
	for coordinate: Vector3i in coordinates:
		var edits: Dictionary = _chunks[coordinate]
		var indices: Array[int] = []
		for index_variant: Variant in edits.keys():
			indices.append(int(index_variant))
		indices.sort()
		var values: Array[int] = []
		for index: int in indices:
			values.append(int(edits[index]))
		chunk_records.append({
			"coordinate": [coordinate.x, coordinate.y, coordinate.z],
			"indices": indices,
			"materials": values,
		})
	return {
		"schema": SCHEMA_VERSION,
		"world_seed": seed,
		"chunk_size": VoxelChunk.SIZE,
		"chunks": chunk_records,
	}


func decode(document: Dictionary, expected_seed: int) -> Error:
	if int(document.get("schema", -1)) != SCHEMA_VERSION:
		return ERR_FILE_UNRECOGNIZED
	if int(document.get("chunk_size", -1)) != VoxelChunk.SIZE:
		return ERR_FILE_CORRUPT
	if int(document.get("world_seed", expected_seed)) != expected_seed:
		return ERR_INVALID_DATA
	var rebuilt: Dictionary = {}
	var records: Array = document.get("chunks", [])
	for record_variant: Variant in records:
		if not record_variant is Dictionary:
			return ERR_FILE_CORRUPT
		var record: Dictionary = record_variant
		var coordinate_values: Array = record.get("coordinate", [])
		var indices: Array = record.get("indices", [])
		var materials: Array = record.get("materials", [])
		if coordinate_values.size() != 3 or indices.size() != materials.size():
			return ERR_FILE_CORRUPT
		var coordinate := Vector3i(int(coordinate_values[0]), int(coordinate_values[1]), int(coordinate_values[2]))
		var edits: Dictionary = {}
		for index: int in range(indices.size()):
			var voxel_index: int = int(indices[index])
			var material: int = int(materials[index])
			if voxel_index < 0 or voxel_index >= VoxelChunk.VOLUME or material < 0 or material > 255:
				return ERR_FILE_CORRUPT
			edits[voxel_index] = material
		if not edits.is_empty():
			rebuilt[coordinate] = edits
	_chunks = rebuilt
	_dirty = false
	return OK


func save_atomic(path: String, seed: int) -> Error:
	var absolute_path: String = path if path.is_absolute_path() else ProjectSettings.globalize_path(path)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var temporary_path: String = absolute_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(encode(seed)))
	file.flush()
	file = null
	if FileAccess.file_exists(absolute_path):
		var remove_error: Error = DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			return remove_error
	var rename_error: Error = DirAccess.rename_absolute(temporary_path, absolute_path)
	if rename_error == OK:
		_dirty = false
	return rename_error


func load_file(path: String, expected_seed: int) -> Error:
	var absolute_path: String = path if path.is_absolute_path() else ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	return decode(parsed, expected_seed)
