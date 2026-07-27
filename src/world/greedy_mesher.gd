extends RefCounted
class_name TeknikGreedyMesher

const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainTextureMaterial = preload("res://src/world/terrain_texture_material.gd")
const PADDED_SIZE: int = VoxelChunk.SIZE + 2
const PADDED_VOLUME: int = PADDED_SIZE * PADDED_SIZE * PADDED_SIZE


static func build_mesh(
	chunk: TeknikVoxelChunk,
	world_origin: Vector3i = Vector3i.ZERO,
	world_sampler: Callable = Callable(),
	color_sampler: Callable = Callable()
) -> Dictionary:
	var report: Dictionary = build_arrays(chunk, world_origin, world_sampler, color_sampler)
	report["mesh"] = mesh_from_arrays(report.arrays)
	return report


static func build_arrays(
	chunk: TeknikVoxelChunk,
	world_origin: Vector3i = Vector3i.ZERO,
	world_sampler: Callable = Callable(),
	color_sampler: Callable = Callable()
) -> Dictionary:
	var padded: PackedByteArray = _build_padded_voxels(chunk, world_origin, world_sampler)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var mask := PackedInt32Array()
	mask.resize(VoxelChunk.SIZE * VoxelChunk.SIZE)
	var quad_count: int = 0
	var dimensions := PackedInt32Array([VoxelChunk.SIZE, VoxelChunk.SIZE, VoxelChunk.SIZE])

	for axis: int in range(3):
		var axis_u: int = (axis + 1) % 3
		var axis_v: int = (axis + 2) % 3
		var cursor := PackedInt32Array([0, 0, 0])
		var step := PackedInt32Array([0, 0, 0])
		step[axis] = 1
		cursor[axis] = -1
		while cursor[axis] < dimensions[axis]:
			var mask_index: int = 0
			for coordinate_v: int in range(dimensions[axis_v]):
				cursor[axis_v] = coordinate_v
				for coordinate_u: int in range(dimensions[axis_u]):
					cursor[axis_u] = coordinate_u
					var padded_x: int = cursor[0] + 1
					var padded_y: int = cursor[1] + 1
					var padded_z: int = cursor[2] + 1
					var current_index: int = padded_x + PADDED_SIZE * (padded_z + PADDED_SIZE * padded_y)
					var neighbor_index: int = (
						padded_x + step[0]
						+ PADDED_SIZE * (
							padded_z + step[2]
							+ PADDED_SIZE * (padded_y + step[1])
						)
					)
					var current: int = int(padded[current_index])
					var neighbor: int = int(padded[neighbor_index])
					if (current == VoxelChunk.AIR) == (neighbor == VoxelChunk.AIR):
						mask[mask_index] = 0
					elif current != VoxelChunk.AIR:
						mask[mask_index] = current
					else:
						mask[mask_index] = -neighbor
					mask_index += 1

			cursor[axis] += 1
			mask_index = 0
			for coordinate_v: int in range(dimensions[axis_v]):
				var coordinate_u: int = 0
				while coordinate_u < dimensions[axis_u]:
					var face: int = mask[mask_index]
					if face == 0:
						coordinate_u += 1
						mask_index += 1
						continue
					var width: int = 1
					while coordinate_u + width < dimensions[axis_u] and mask[mask_index + width] == face:
						width += 1
					var height: int = 1
					var height_valid: bool = true
					while coordinate_v + height < dimensions[axis_v] and height_valid:
						for offset_u: int in range(width):
							if mask[mask_index + offset_u + height * dimensions[axis_u]] != face:
								height_valid = false
								break
						if height_valid:
							height += 1
					cursor[axis_u] = coordinate_u
					cursor[axis_v] = coordinate_v
					var origin := Vector3(cursor[0], cursor[1], cursor[2])
					var delta_u := Vector3.ZERO
					var delta_v := Vector3.ZERO
					delta_u[axis_u] = float(width)
					delta_v[axis_v] = float(height)
					_append_quad(vertices, normals, colors, indices, origin, delta_u, delta_v, axis, face, world_origin, color_sampler)
					quad_count += 1
					for offset_v: int in range(height):
						for offset_u: int in range(width):
							mask[mask_index + offset_u + offset_v * dimensions[axis_u]] = 0
					coordinate_u += width
					mask_index += width

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return {
		"arrays": arrays,
		"quads": quad_count,
		"vertices": vertices.size(),
		"triangles": indices.size() / 3,
	}


static func _build_padded_voxels(
	chunk: TeknikVoxelChunk,
	world_origin: Vector3i,
	world_sampler: Callable
) -> PackedByteArray:
	var padded := PackedByteArray()
	padded.resize(PADDED_VOLUME)
	padded.fill(VoxelChunk.AIR)
	for y: int in range(VoxelChunk.SIZE):
		for z: int in range(VoxelChunk.SIZE):
			var chunk_row: int = VoxelChunk.SIZE * (z + VoxelChunk.SIZE * y)
			var padded_row: int = 1 + PADDED_SIZE * ((z + 1) + PADDED_SIZE * (y + 1))
			for x: int in range(VoxelChunk.SIZE):
				padded[padded_row + x] = chunk.voxels[chunk_row + x]

	if not world_sampler.is_valid():
		return padded

	for y: int in range(VoxelChunk.SIZE):
		for z: int in range(VoxelChunk.SIZE):
			padded[_padded_index(0, y + 1, z + 1)] = clampi(int(world_sampler.call(world_origin + Vector3i(-1, y, z))), 0, 255)
			padded[_padded_index(VoxelChunk.SIZE + 1, y + 1, z + 1)] = clampi(int(world_sampler.call(world_origin + Vector3i(VoxelChunk.SIZE, y, z))), 0, 255)
	for z: int in range(VoxelChunk.SIZE):
		for x: int in range(VoxelChunk.SIZE):
			padded[_padded_index(x + 1, 0, z + 1)] = clampi(int(world_sampler.call(world_origin + Vector3i(x, -1, z))), 0, 255)
			padded[_padded_index(x + 1, VoxelChunk.SIZE + 1, z + 1)] = clampi(int(world_sampler.call(world_origin + Vector3i(x, VoxelChunk.SIZE, z))), 0, 255)
	for y: int in range(VoxelChunk.SIZE):
		for x: int in range(VoxelChunk.SIZE):
			padded[_padded_index(x + 1, y + 1, 0)] = clampi(int(world_sampler.call(world_origin + Vector3i(x, y, -1))), 0, 255)
			padded[_padded_index(x + 1, y + 1, VoxelChunk.SIZE + 1)] = clampi(int(world_sampler.call(world_origin + Vector3i(x, y, VoxelChunk.SIZE))), 0, 255)
	return padded


static func _padded_index(x: int, y: int, z: int) -> int:
	return x + PADDED_SIZE * (z + PADDED_SIZE * y)


static func mesh_from_arrays(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, TerrainTextureMaterial.shared_material())
	return mesh


static func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	delta_u: Vector3,
	delta_v: Vector3,
	axis: int,
	face: int,
	world_origin: Vector3i,
	color_sampler: Callable
) -> void:
	var base: int = vertices.size()
	var local_positions: Array[Vector3] = [origin, origin + delta_u, origin + delta_u + delta_v, origin + delta_v]
	for local_position: Vector3 in local_positions:
		vertices.append(local_position)
	var normal := Vector3.ZERO
	normal[axis] = 1.0 if face > 0 else -1.0
	var face_light: float = 1.0
	if axis == 1 and face > 0:
		face_light = 1.03
	elif axis == 1:
		face_light = 0.76
	else:
		face_light = 0.94
	var material_id: int = absi(face)
	for local_position: Vector3 in local_positions:
		var sample_position := Vector3i(
			roundi(float(world_origin.x) + local_position.x),
			roundi(float(world_origin.y) + local_position.y),
			roundi(float(world_origin.z) + local_position.z)
		)
		var color: Color = _material_color(material_id)
		if color_sampler.is_valid():
			var sampled_color: Variant = color_sampler.call(material_id, sample_position)
			if sampled_color is Color:
				color = sampled_color
		var variation: float = 0.96 + fposmod(
			sin(float(sample_position.x) * 12.9898 + float(sample_position.y) * 37.719 + float(sample_position.z) * 78.233) * 43758.5453,
			1.0
		) * 0.07
		normals.append(normal)
		colors.append(Color(
			color.r * face_light * variation,
			color.g * face_light * variation,
			color.b * face_light * variation,
			float(material_id) / 255.0
		))
	if face > 0:
		indices.append_array(PackedInt32Array([base, base + 3, base + 2, base, base + 2, base + 1]))
	else:
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


static func _material_color(material: int) -> Color:
	match material:
		1:
			return Color("626c6b")
		2:
			return Color("614735")
		3:
			return Color("4e723f")
		4:
			return Color("9a895f")
		5:
			return Color("9aa6a2")
		6:
			return Color("b76845")
		7:
			return Color("9a6f58")
		8:
			return Color("d2a438")
		_:
			return Color("8c7e69")
