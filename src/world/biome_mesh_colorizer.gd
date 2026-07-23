class_name TeknikBiomeMeshColorizer
extends RefCounted

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const PackedFaceCodec = preload("res://src/world/packed_face_codec.gd")
const BiomePalette = preload("res://src/world/biome_surface_palette.gd")


static func recolor_report(report: Dictionary, world_origin: Vector3i, seed: int) -> void:
	var arrays: Array = report.get("arrays", [])
	if arrays.size() < Mesh.ARRAY_MAX:
		return
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return
	var packed_faces: PackedInt32Array = report.get("packed_faces", PackedInt32Array())
	if packed_faces.size() / PackedFaceCodec.WORDS_PER_FACE * 4 == vertices.size():
		_recolor_packed(arrays, packed_faces, world_origin, seed)
	else:
		_recolor_legacy(arrays, world_origin, seed)
	report["arrays"] = arrays


static func recolor_distant_plan(plan: Dictionary, seed: int) -> void:
	var vertices: PackedVector3Array = plan.get("vertices", PackedVector3Array())
	var normals: PackedVector3Array = plan.get("normals", PackedVector3Array())
	if vertices.is_empty() or normals.size() != vertices.size():
		return
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	var cache: Dictionary = {}
	for index: int in range(vertices.size()):
		var vertex: Vector3 = vertices[index]
		var normal: Vector3 = normals[index]
		var world_position := Vector3i(
			roundi(vertex.x),
			roundi(vertex.y),
			roundi(vertex.z)
		)
		var weights: Vector4 = BiomePalette.biome_weights(
			seed,
			world_position.x,
			world_position.z,
			vertex.y
		)
		var material: int
		if normal.y > 0.5:
			if vertex.y <= float(TerrainGenerator.WATER_LEVEL + 2) or weights.w > 0.58:
				material = TerrainGenerator.SAND
			elif weights.z > 0.58:
				material = TerrainGenerator.STONE
			else:
				material = TerrainGenerator.GRASS
		else:
			material = (
				TerrainGenerator.STONE
				if weights.z > 0.30 or vertex.y >= 15.0
				else TerrainGenerator.SOIL
			)
		var base: Color = BiomePalette.color(
			seed,
			material,
			world_position,
			vertex.y,
			cache
		)
		var light: float = 1.02 if normal.y > 0.5 else 0.90
		if normal.x > 0.5 or normal.z < -0.5:
			light *= 1.03
		var variation: float = _variation(world_position)
		colors[index] = Color(
			base.r * light * variation,
			base.g * light * variation,
			base.b * light * variation,
			1.0
		)
	plan["colors"] = colors


static func _recolor_packed(
	arrays: Array,
	packed_faces: PackedInt32Array,
	world_origin: Vector3i,
	seed: int
) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	var cache: Dictionary = {}
	var face_count: int = packed_faces.size() / PackedFaceCodec.WORDS_PER_FACE
	for face_index: int in range(face_count):
		var decoded: Dictionary = PackedFaceCodec.decode_face_words(
			packed_faces[face_index * 2],
			packed_faces[face_index * 2 + 1]
		)
		if not bool(decoded.get("valid", false)):
			continue
		var direction: int = int(decoded.direction)
		var face_light: float = _face_light(direction)
		var material: int = int(decoded.material)
		var base_vertex: int = face_index * 4
		var surface_y: float = -INF
		for corner: int in range(4):
			surface_y = maxf(surface_y, vertices[base_vertex + corner].y + float(world_origin.y))
		for corner: int in range(4):
			var local_position: Vector3 = vertices[base_vertex + corner]
			var sample := Vector3i(
				world_origin.x + roundi(local_position.x),
				world_origin.y + roundi(local_position.y),
				world_origin.z + roundi(local_position.z)
			)
			var base: Color = BiomePalette.color(
				seed,
				material,
				sample,
				surface_y,
				cache
			)
			var variation: float = _variation(sample)
			colors[base_vertex + corner] = Color(
				base.r * face_light * variation,
				base.g * face_light * variation,
				base.b * face_light * variation,
				1.0
			)
	arrays[Mesh.ARRAY_COLOR] = colors


static func _recolor_legacy(arrays: Array, world_origin: Vector3i, seed: int) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var old_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if normals.size() != vertices.size() or old_colors.size() != vertices.size():
		return
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	var cache: Dictionary = {}
	var face_count: int = vertices.size() / 4
	for face_index: int in range(face_count):
		var base_vertex: int = face_index * 4
		var material: int = _infer_material(old_colors[base_vertex])
		var normal: Vector3 = normals[base_vertex]
		var face_light: float = _face_light_from_normal(normal)
		var surface_y: float = -INF
		for corner: int in range(4):
			surface_y = maxf(surface_y, vertices[base_vertex + corner].y + float(world_origin.y))
		for corner: int in range(4):
			var local_position: Vector3 = vertices[base_vertex + corner]
			var sample := Vector3i(
				world_origin.x + roundi(local_position.x),
				world_origin.y + roundi(local_position.y),
				world_origin.z + roundi(local_position.z)
			)
			var base: Color = BiomePalette.color(
				seed,
				material,
				sample,
				surface_y,
				cache
			)
			var variation: float = _variation(sample)
			colors[base_vertex + corner] = Color(
				base.r * face_light * variation,
				base.g * face_light * variation,
				base.b * face_light * variation,
				1.0
			)
	arrays[Mesh.ARRAY_COLOR] = colors


static func _infer_material(value: Color) -> int:
	var luminance: float = maxf((value.r + value.g + value.b) / 3.0, 0.001)
	var normalized := Vector3(value.r / luminance, value.g / luminance, value.b / luminance)
	var anchors: Array[Vector3] = [
		Vector3(0.302, 0.459, 0.263) / 0.341,
		Vector3(0.376, 0.271, 0.212) / 0.286,
		Vector3(0.647, 0.549, 0.361) / 0.519,
		Vector3(0.365, 0.408, 0.396) / 0.390,
	]
	var materials: Array[int] = [
		TerrainGenerator.GRASS,
		TerrainGenerator.SOIL,
		TerrainGenerator.SAND,
		TerrainGenerator.STONE,
	]
	var best_material: int = TerrainGenerator.STONE
	var best_distance: float = INF
	for index: int in range(anchors.size()):
		var distance: float = normalized.distance_squared_to(anchors[index])
		if distance < best_distance:
			best_distance = distance
			best_material = materials[index]
	return best_material


static func _face_light(direction: int) -> float:
	match direction:
		PackedFaceCodec.FACE_POS_Y:
			return 1.03
		PackedFaceCodec.FACE_NEG_Y:
			return 0.76
		_:
			return 0.94


static func _face_light_from_normal(normal: Vector3) -> float:
	if normal.y > 0.5:
		return 1.03
	if normal.y < -0.5:
		return 0.76
	return 0.94


static func _variation(sample: Vector3i) -> float:
	return 0.96 + fposmod(
		sin(
			float(sample.x) * 12.9898
			+ float(sample.y) * 37.719
			+ float(sample.z) * 78.233
		) * 43758.5453,
		1.0
	) * 0.07
