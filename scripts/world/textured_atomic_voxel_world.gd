extends "res://scripts/world/atomic_voxel_world.gd"

const TERRAIN_ATLAS: Texture2D = preload("res://assets/textures/terrain_atlas.svg")
const ATLAS_WIDTH_PX := 80.0
const ATLAS_HEIGHT_PX := 16.0
const ATLAS_TILE_PX := 16.0
const ATLAS_INSET_PX := 0.45

const TILE_GRASS_TOP := 0
const TILE_GRASS_SIDE := 1
const TILE_DIRT := 2
const TILE_STONE := 3
const TILE_SAND := 4

func _ready() -> void:
	super._ready()
	shared_material.albedo_texture = TERRAIN_ATLAS
	shared_material.albedo_color = Color.WHITE
	shared_material.vertex_color_use_as_albedo = true
	shared_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	shared_material.texture_repeat = false
	shared_material.roughness = 0.90

	if is_instance_valid(water) and water.mesh is PlaneMesh:
		var plane := water.mesh as PlaneMesh
		if plane.material is StandardMaterial3D:
			var water_material := plane.material as StandardMaterial3D
			water_material.albedo_color = Color(0.16, 0.48, 0.67, 0.67)
			water_material.roughness = 0.24
			water_material.metallic = 0.02

func _build_chunk_mesh(coord: Vector2i) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var face_count := 0
	var origin := Vector3i(coord.x * CHUNK_SIZE, 0, coord.y * CHUNK_SIZE)
	var height_cache: PackedInt32Array = _build_height_cache(origin)

	for local_z in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var global_x := origin.x + local_x
			var global_z := origin.z + local_z
			for y in range(WORLD_HEIGHT):
				var cell := Vector3i(global_x, y, global_z)
				var block: int = _get_block_cached(cell, origin, height_cache)
				if block == BLOCK_AIR:
					continue

				for face_index in range(6):
					var neighbor: Vector3i = cell + FACE_DIRECTIONS[face_index]
					if _get_block_cached(neighbor, origin, height_cache) != BLOCK_AIR:
						continue

					var base_index: int = vertices.size()
					var shade: float = _face_shade(face_index)
					var color: Color = _block_color(block, cell, shade)
					var local_cell := Vector3(local_x, y, local_z)
					var face_vertices: Array = FACE_VERTICES[face_index]
					var tile_index := _tile_for_face(block, face_index)
					var uv_rect := _tile_uv_rect(tile_index)

					for vertex_index in range(4):
						var vertex := Vector3(face_vertices[vertex_index])
						vertices.append(local_cell + vertex)
						normals.append(FACE_NORMALS[face_index])
						colors.append(color)
						uvs.append(_face_uv(vertex_index, uv_rect))

					indices.append_array(PackedInt32Array([
						base_index, base_index + 1, base_index + 2,
						base_index, base_index + 2, base_index + 3
					]))
					face_count += 1

	return {
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"uvs": uvs,
		"indices": indices,
		"face_count": face_count
	}

func _commit_chunk(coord: Vector2i, data: Dictionary) -> void:
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_root.position = Vector3(coord.x * CHUNK_SIZE, 0, coord.y * CHUNK_SIZE)
	chunk_root.set_meta("chunk_coord", coord)
	add_child(chunk_root)

	var mesh := _create_textured_mesh(data)
	if mesh.get_surface_count() > 0:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "TerrainMesh"
		mesh_instance.mesh = mesh
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		chunk_root.add_child(mesh_instance)

	loaded_chunks[coord] = {
		"root": chunk_root,
		"mesh": mesh,
		"collision": null
	}

func _create_replacement_entry(coord: Vector2i, data: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = data["vertices"]
	if vertices.is_empty():
		return {}

	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_root.position = Vector3(coord.x * CHUNK_SIZE, 0, coord.y * CHUNK_SIZE)
	chunk_root.set_meta("chunk_coord", coord)

	var mesh := _create_textured_mesh(data)
	if mesh.get_surface_count() == 0:
		return {}

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	chunk_root.add_child(mesh_instance)

	var collision: StaticBody3D = null
	if _needs_collision(coord):
		collision = _create_replacement_collision(mesh)
		if collision == null:
			return {}
		chunk_root.add_child(collision)

	return {
		"root": chunk_root,
		"mesh": mesh,
		"collision": collision
	}

func _create_textured_mesh(data: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_TEX_UV] = data["uvs"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]

	var mesh := ArrayMesh.new()
	var vertices: PackedVector3Array = data["vertices"]
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, shared_material)
	return mesh

func _tile_for_face(block: int, face_index: int) -> int:
	match block:
		BLOCK_GRASS:
			if face_index == 0:
				return TILE_GRASS_TOP
			if face_index == 1:
				return TILE_DIRT
			return TILE_GRASS_SIDE
		BLOCK_DIRT:
			return TILE_DIRT
		BLOCK_STONE:
			return TILE_STONE
		BLOCK_SAND:
			return TILE_SAND
	return TILE_STONE

func _tile_uv_rect(tile_index: int) -> Rect2:
	var u0 := (float(tile_index) * ATLAS_TILE_PX + ATLAS_INSET_PX) / ATLAS_WIDTH_PX
	var u1 := (float(tile_index + 1) * ATLAS_TILE_PX - ATLAS_INSET_PX) / ATLAS_WIDTH_PX
	var v0 := ATLAS_INSET_PX / ATLAS_HEIGHT_PX
	var v1 := (ATLAS_HEIGHT_PX - ATLAS_INSET_PX) / ATLAS_HEIGHT_PX
	return Rect2(Vector2(u0, v0), Vector2(u1 - u0, v1 - v0))

func _face_uv(vertex_index: int, rect: Rect2) -> Vector2:
	match vertex_index:
		0:
			return rect.position
		1:
			return Vector2(rect.position.x, rect.end.y)
		2:
			return rect.end
		_:
			return Vector2(rect.end.x, rect.position.y)

func _block_color(block: int, cell: Vector3i, shade: float) -> Color:
	var material_tint := Color.WHITE
	match block:
		BLOCK_GRASS:
			material_tint = Color(1.03, 1.06, 1.00)
		BLOCK_DIRT:
			material_tint = Color(1.05, 1.02, 0.98)
		BLOCK_STONE:
			material_tint = Color(1.05, 1.06, 1.07)
		BLOCK_SAND:
			material_tint = Color(1.08, 1.06, 1.00)

	var hash_value: int = absi((cell.x * 73856093) ^ (cell.y * 83492791) ^ (cell.z * 19349663))
	var variation := 0.96 + float(hash_value % 9) * 0.01
	var factor := shade * variation
	return Color(
		material_tint.r * factor,
		material_tint.g * factor,
		material_tint.b * factor,
		1.0
	)

func _face_shade(face_index: int) -> float:
	match face_index:
		0:
			return 1.04
		1:
			return 0.86
		2, 3:
			return 0.98
		_:
			return 0.93
