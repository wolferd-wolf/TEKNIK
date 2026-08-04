class_name TeknikPackedFaceCodec
extends RefCounted

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")

const CHUNK_SIZE: int = 32
const MAX_FACE_PLANE: int = 32
const WORDS_PER_FACE: int = 2
const FACE_NEG_X: int = 0
const FACE_POS_X: int = 1
const FACE_NEG_Y: int = 2
const FACE_POS_Y: int = 3
const FACE_NEG_Z: int = 4
const FACE_POS_Z: int = 5
const FACE_DIRECTION_COUNT: int = 6

const FIVE_BIT_MASK: int = 0x1f
const SIX_BIT_MASK: int = 0x3f
const THREE_BIT_MASK: int = 0x07
const EIGHT_BIT_MASK: int = 0xff
const X_SHIFT: int = 0
const Y_SHIFT: int = 6
const Z_SHIFT: int = 12
const DIRECTION_SHIFT: int = 18
const MATERIAL_SHIFT: int = 21
const FLAGS_SHIFT: int = 29
const WIDTH_SHIFT: int = 0
const HEIGHT_SHIFT: int = 5


static func decode_face_words(geometry_word: int, appearance_word: int) -> Dictionary:
	var geometry: int = geometry_word & 0xffffffff
	var appearance: int = appearance_word & 0xffffffff
	var direction: int = (geometry >> DIRECTION_SHIFT) & THREE_BIT_MASK
	var material: int = (geometry >> MATERIAL_SHIFT) & EIGHT_BIT_MASK
	var width: int = ((appearance >> WIDTH_SHIFT) & FIVE_BIT_MASK) + 1
	var height: int = ((appearance >> HEIGHT_SHIFT) & FIVE_BIT_MASK) + 1
	var result: Dictionary = {
		"x": (geometry >> X_SHIFT) & SIX_BIT_MASK,
		"y": (geometry >> Y_SHIFT) & SIX_BIT_MASK,
		"z": (geometry >> Z_SHIFT) & SIX_BIT_MASK,
		"direction": direction,
		"material": material,
		"flags": (geometry >> FLAGS_SHIFT) & THREE_BIT_MASK,
		"width": width,
		"height": height,
	}
	result["valid"] = _decoded_face_is_valid(result)
	return result


static func decode_arrays(
	packed_words: PackedInt32Array,
	world_origin: Vector3i,
	seed: int
) -> Dictionary:
	if packed_words.size() % WORDS_PER_FACE != 0:
		return {
			"success": false,
			"error": "Packed face word count is not divisible by two",
		}

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var face_count: int = packed_words.size() / WORDS_PER_FACE
	vertices.resize(face_count * 4)
	normals.resize(face_count * 4)
	colors.resize(face_count * 4)
	indices.resize(face_count * 6)
	var vertex_write: int = 0
	var index_write: int = 0

	for face_index: int in range(face_count):
		var decoded: Dictionary = decode_face_words(
			packed_words[face_index * 2],
			packed_words[face_index * 2 + 1]
		)
		if not bool(decoded.valid):
			return {
				"success": false,
				"error": "Invalid packed face at index %d" % face_index,
			}
		var direction: int = int(decoded.direction)
		var axis_and_sign: Vector2i = _axis_and_sign(direction)
		var axis: int = axis_and_sign.x
		var positive: bool = axis_and_sign.y == 1
		var axis_u: int = (axis + 1) % 3
		var axis_v: int = (axis + 2) % 3
		var origin := Vector3(
			float(decoded.x),
			float(decoded.y),
			float(decoded.z)
		)
		var delta_u := Vector3.ZERO
		var delta_v := Vector3.ZERO
		delta_u[axis_u] = float(decoded.width)
		delta_v[axis_v] = float(decoded.height)
		var positions: Array[Vector3] = [
			origin,
			origin + delta_u,
			origin + delta_u + delta_v,
			origin + delta_v,
		]
		var normal := Vector3.ZERO
		normal[axis] = 1.0 if positive else -1.0
		var face_light: float = 0.94
		if axis == 1 and positive:
			face_light = 1.03
		elif axis == 1:
			face_light = 0.76

		for position: Vector3 in positions:
			var sample := Vector3i(
				world_origin.x + roundi(position.x),
				world_origin.y + roundi(position.y),
				world_origin.z + roundi(position.z)
			)
			var color: Color = TerrainGenerator.fast_surface_color(
				seed,
				int(decoded.material),
				sample
			)
			var variation: float = 0.96 + fposmod(
				sin(
					float(sample.x) * 12.9898
					+ float(sample.y) * 37.719
					+ float(sample.z) * 78.233
				) * 43758.5453,
				1.0
			) * 0.07
			vertices[vertex_write] = position
			normals[vertex_write] = normal
			colors[vertex_write] = Color(
				color.r * face_light * variation,
				color.g * face_light * variation,
				color.b * face_light * variation,
				1.0
			)
			vertex_write += 1

		var base: int = face_index * 4
		var face_indices: PackedInt32Array
		if positive:
			face_indices = PackedInt32Array([
				base,
				base + 3,
				base + 2,
				base,
				base + 2,
				base + 1,
			])
		else:
			face_indices = PackedInt32Array([
				base,
				base + 1,
				base + 2,
				base,
				base + 2,
				base + 3,
			])
		for face_index_value: int in face_indices:
			indices[index_write] = face_index_value
			index_write += 1

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return {
		"success": true,
		"arrays": arrays,
		"quads": face_count,
		"vertices": vertices.size(),
		"triangles": indices.size() / 3,
	}


static func validate_directional_partition(
	packed_directional_words: PackedInt32Array,
	direction_offsets: PackedInt32Array,
	direction_counts: PackedInt32Array
) -> Dictionary:
	if direction_offsets.size() != FACE_DIRECTION_COUNT or direction_counts.size() != FACE_DIRECTION_COUNT:
		return {
			"success": false,
			"error": "Directional metadata must contain six entries",
		}
	if packed_directional_words.size() % WORDS_PER_FACE != 0:
		return {
			"success": false,
			"error": "Directional face word count is invalid",
		}
	var total_faces: int = packed_directional_words.size() / WORDS_PER_FACE
	var expected_offset: int = 0
	for direction: int in range(FACE_DIRECTION_COUNT):
		var offset: int = direction_offsets[direction]
		var count: int = direction_counts[direction]
		if offset != expected_offset or count < 0 or offset + count > total_faces:
			return {
				"success": false,
				"error": "Directional range %d is not contiguous" % direction,
			}
		for face_index: int in range(offset, offset + count):
			var decoded: Dictionary = decode_face_words(
				packed_directional_words[face_index * 2],
				packed_directional_words[face_index * 2 + 1]
			)
			if not bool(decoded.valid) or int(decoded.direction) != direction:
				return {
					"success": false,
					"error": "Directional stream contains a mismatched face",
				}
		expected_offset += count
	return {
		"success": expected_offset == total_faces,
		"face_count": total_faces,
		"error": "" if expected_offset == total_faces else "Directional ranges do not cover all faces",
	}


static func _decoded_face_is_valid(face: Dictionary) -> bool:
	var direction: int = int(face.direction)
	var axis_and_sign: Vector2i = _axis_and_sign(direction)
	var axis: int = axis_and_sign.x
	if axis < 0:
		return false
	var coordinates: Array[int] = [int(face.x), int(face.y), int(face.z)]
	for coordinate_axis: int in range(3):
		var maximum: int = MAX_FACE_PLANE if coordinate_axis == axis else CHUNK_SIZE - 1
		if coordinates[coordinate_axis] < 0 or coordinates[coordinate_axis] > maximum:
			return false
	return (
		int(face.material) > 0
		and int(face.width) >= 1
		and int(face.width) <= CHUNK_SIZE
		and int(face.height) >= 1
		and int(face.height) <= CHUNK_SIZE
	)


static func _axis_and_sign(direction: int) -> Vector2i:
	match direction:
		FACE_NEG_X:
			return Vector2i(0, 0)
		FACE_POS_X:
			return Vector2i(0, 1)
		FACE_NEG_Y:
			return Vector2i(1, 0)
		FACE_POS_Y:
			return Vector2i(1, 1)
		FACE_NEG_Z:
			return Vector2i(2, 0)
		FACE_POS_Z:
			return Vector2i(2, 1)
		_:
			return Vector2i(-1, 0)
