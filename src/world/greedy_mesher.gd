extends RefCounted
class_name TeknikGreedyMesher

const VoxelChunk = preload("res://src/world/voxel_chunk.gd")


static func build_mesh(
	chunk: TeknikVoxelChunk,
	world_origin: Vector3i = Vector3i.ZERO,
	world_sampler: Callable = Callable(),
	color_sampler: Callable = Callable()
) -> Dictionary:
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
					var current_position := Vector3i(cursor[0], cursor[1], cursor[2])
					var neighbor_position := current_position + Vector3i(step[0], step[1], step[2])
					var current: int = _sample_voxel(
						chunk, current_position, world_origin, world_sampler
					)
					var neighbor: int = _sample_voxel(
						chunk, neighbor_position, world_origin, world_sampler
					)

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
					_append_quad(
						vertices, normals, colors, indices,
						origin, delta_u, delta_v, axis, face,
						world_origin, color_sampler
					)
					quad_count += 1

					for offset_v: int in range(height):
						for offset_u: int in range(width):
							mask[mask_index + offset_u + offset_v * dimensions[axis_u]] = 0

					coordinate_u += width
					mask_index += width

	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.94
		material.cull_mode = BaseMaterial3D.CULL_BACK
		mesh.surface_set_material(0, material)

	return {
		"mesh": mesh,
		"quads": quad_count,
		"vertices": vertices.size(),
		"triangles": indices.size() / 3,
	}


static func _sample_voxel(
	chunk: TeknikVoxelChunk,
	local_position: Vector3i,
	world_origin: Vector3i,
	world_sampler: Callable
) -> int:
	if VoxelChunk.in_bounds(local_position):
		return chunk.get_voxel(local_position)
	if world_sampler.is_valid():
		return int(world_sampler.call(world_origin + local_position))
	return VoxelChunk.AIR


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
	var local_positions: Array[Vector3] = [
		origin,
		origin + delta_u,
		origin + delta_u + delta_v,
		origin + delta_v,
	]
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
	for local_position: Vector3 in local_positions:
		var sample_position := Vector3i(
			roundi(float(world_origin.x) + local_position.x),
			roundi(float(world_origin.y) + local_position.y),
			roundi(float(world_origin.z) + local_position.z)
		)
		var color: Color = _material_color(absi(face))
		if color_sampler.is_valid():
			var sampled_color: Variant = color_sampler.call(absi(face), sample_position)
			if sampled_color is Color:
				color = sampled_color
		var variation: float = 0.96 + fposmod(
			sin(
				float(sample_position.x) * 12.9898
				+ float(sample_position.y) * 37.719
				+ float(sample_position.z) * 78.233
			) * 43758.5453,
			1.0
		) * 0.07
		normals.append(normal)
		colors.append(Color(
			color.r * face_light * variation,
			color.g * face_light * variation,
			color.b * face_light * variation,
			1.0
		))

	# Godot treats clockwise triangles as front-facing. The geometric cross
	# product therefore points opposite the stored outward lighting normal.
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
		_:
			return Color("8c7e69")
