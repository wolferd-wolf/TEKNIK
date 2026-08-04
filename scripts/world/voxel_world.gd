extends Node3D

signal spawn_ready(position: Vector3)

const CHUNK_SIZE := 12
const WORLD_HEIGHT := 30
const RENDER_RADIUS := 3
const COLLISION_RADIUS := 1
const UNLOAD_RADIUS := 4
const BUILD_BUDGET_USEC := 5500
const COLLISION_ADDS_PER_FRAME := 1
const COLLISION_REMOVES_PER_FRAME := 2
const SEA_LEVEL := 7
const WORLD_SEED := 734921
const SAVE_PATH := "user://teknik_world_v1.json"
const HEIGHT_CACHE_WIDTH := CHUNK_SIZE + 2

const BLOCK_AIR := 0
const BLOCK_GRASS := 1
const BLOCK_DIRT := 2
const BLOCK_STONE := 3
const BLOCK_SAND := 4

const FACE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]

const FACE_NORMALS: Array[Vector3] = [
	Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD
]

const FACE_VERTICES: Array = [
	[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]
]

var player: Node3D
var noise := FastNoiseLite.new()
var biome_noise := FastNoiseLite.new()
var shared_material := StandardMaterial3D.new()
var water: MeshInstance3D

var loaded_chunks: Dictionary = {}
var queued_chunks: Dictionary = {}
var build_queue: Array[Vector2i] = []
var collision_add_queue: Array[Vector2i] = []
var collision_remove_queue: Array[Vector2i] = []
var collision_add_queued: Dictionary = {}
var collision_remove_queued: Dictionary = {}
var block_overrides: Dictionary = {}

var current_center := Vector2i(999999, 999999)
var spawn_emitted := false
var dirty_save := false
var save_delay := 0.0
var last_build_usec := 0
var last_collision_usec := 0
var last_face_count := 0

func _ready() -> void:
	noise.seed = WORLD_SEED
	noise.frequency = 0.011
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.48
	noise.fractal_lacunarity = 2.05

	biome_noise.seed = WORLD_SEED ^ 0x5f3759df
	biome_noise.frequency = 0.0035
	biome_noise.fractal_octaves = 2

	shared_material.vertex_color_use_as_albedo = true
	shared_material.roughness = 0.96
	shared_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_load_world()
	_create_water()
	_set_center(Vector2i.ZERO)

func _process(delta: float) -> void:
	if is_instance_valid(player):
		var player_chunk: Vector2i = world_to_chunk(player.global_position)
		if player_chunk != current_center:
			_set_center(player_chunk)
		if is_instance_valid(water):
			water.position.x = player.global_position.x
			water.position.z = player.global_position.z

	_pump_build_queue()
	_refresh_collision_queues()
	_pump_collision_queues()
	_try_emit_spawn()

	if dirty_save:
		save_delay -= delta
		if save_delay <= 0.0:
			_save_world()

func _exit_tree() -> void:
	if dirty_save:
		_save_world()

func set_player(value: Node3D) -> void:
	player = value
	_set_center(world_to_chunk(player.global_position))

func world_to_chunk(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / float(CHUNK_SIZE)), floori(position.z / float(CHUNK_SIZE)))

func cell_to_chunk(cell: Vector3i) -> Vector2i:
	return Vector2i(floori(cell.x / float(CHUNK_SIZE)), floori(cell.z / float(CHUNK_SIZE)))

func _set_center(center: Vector2i) -> void:
	current_center = center
	_prune_build_queue()

	for z in range(center.y - RENDER_RADIUS, center.y + RENDER_RADIUS + 1):
		for x in range(center.x - RENDER_RADIUS, center.x + RENDER_RADIUS + 1):
			var coord := Vector2i(x, z)
			if not loaded_chunks.has(coord) and not queued_chunks.has(coord):
				build_queue.append(coord)
				queued_chunks[coord] = true

	_sort_build_queue()
	_unload_far_chunks()

func _prune_build_queue() -> void:
	var filtered: Array[Vector2i] = []
	queued_chunks.clear()
	for coord in build_queue:
		if max(abs(coord.x - current_center.x), abs(coord.y - current_center.y)) <= RENDER_RADIUS:
			filtered.append(coord)
			queued_chunks[coord] = true
	build_queue = filtered

func _sort_build_queue() -> void:
	build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_collision: bool = _needs_collision(a)
		var b_collision: bool = _needs_collision(b)
		if a_collision != b_collision:
			return a_collision
		return _chunk_distance_squared(a, current_center) < _chunk_distance_squared(b, current_center)
	)

func _pump_build_queue() -> void:
	if build_queue.is_empty():
		return

	var frame_start: int = Time.get_ticks_usec()
	while not build_queue.is_empty():
		var coord: Vector2i = build_queue.pop_front()
		queued_chunks.erase(coord)

		if loaded_chunks.has(coord):
			continue
		if max(abs(coord.x - current_center.x), abs(coord.y - current_center.y)) > RENDER_RADIUS:
			continue

		var build_start: int = Time.get_ticks_usec()
		var data: Dictionary = _build_chunk_mesh(coord)
		_commit_chunk(coord, data)
		last_build_usec = Time.get_ticks_usec() - build_start
		last_face_count = int(data["face_count"])

		if Time.get_ticks_usec() - frame_start >= BUILD_BUDGET_USEC:
			break

func _build_chunk_mesh(coord: Vector2i) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
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

					for vertex_value in face_vertices:
						var vertex := Vector3(vertex_value)
						vertices.append(local_cell + vertex)
						normals.append(FACE_NORMALS[face_index])
						colors.append(color)

					indices.append_array(PackedInt32Array([
						base_index, base_index + 1, base_index + 2,
						base_index, base_index + 2, base_index + 3
					]))
					face_count += 1

	return {
		"vertices": vertices,
		"normals": normals,
		"colors": colors,
		"indices": indices,
		"face_count": face_count
	}

func _build_height_cache(origin: Vector3i) -> PackedInt32Array:
	var heights := PackedInt32Array()
	heights.resize(HEIGHT_CACHE_WIDTH * HEIGHT_CACHE_WIDTH)
	for local_z in range(-1, CHUNK_SIZE + 1):
		for local_x in range(-1, CHUNK_SIZE + 1):
			var index: int = (local_z + 1) * HEIGHT_CACHE_WIDTH + local_x + 1
			heights[index] = _terrain_height(origin.x + local_x, origin.z + local_z)
	return heights

func _get_block_cached(cell: Vector3i, origin: Vector3i, heights: PackedInt32Array) -> int:
	if cell.y < 0:
		return BLOCK_STONE
	if cell.y >= WORLD_HEIGHT:
		return BLOCK_AIR

	var key := _cell_key(cell)
	if block_overrides.has(key):
		return int(block_overrides[key])

	var cache_x: int = cell.x - origin.x + 1
	var cache_z: int = cell.z - origin.z + 1
	var height: int
	if cache_x >= 0 and cache_x < HEIGHT_CACHE_WIDTH and cache_z >= 0 and cache_z < HEIGHT_CACHE_WIDTH:
		height = heights[cache_z * HEIGHT_CACHE_WIDTH + cache_x]
	else:
		height = _terrain_height(cell.x, cell.z)
	return _generated_block(cell.y, height)

func _commit_chunk(coord: Vector2i, data: Dictionary) -> void:
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_root.position = Vector3(coord.x * CHUNK_SIZE, 0, coord.y * CHUNK_SIZE)
	chunk_root.set_meta("chunk_coord", coord)
	add_child(chunk_root)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]

	var mesh := ArrayMesh.new()
	var vertices: PackedVector3Array = data["vertices"]
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, shared_material)
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

func _refresh_collision_queues() -> void:
	for coord in loaded_chunks.keys():
		var entry: Dictionary = loaded_chunks[coord]
		var has_collision: bool = is_instance_valid(entry["collision"])
		if _needs_collision(coord):
			if not has_collision and not collision_add_queued.has(coord):
				collision_add_queue.append(coord)
				collision_add_queued[coord] = true
		elif has_collision and not collision_remove_queued.has(coord):
			collision_remove_queue.append(coord)
			collision_remove_queued[coord] = true

	collision_add_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chunk_distance_squared(a, current_center) < _chunk_distance_squared(b, current_center)
	)

func _pump_collision_queues() -> void:
	for _index in range(COLLISION_ADDS_PER_FRAME):
		if collision_add_queue.is_empty():
			break
		var coord: Vector2i = collision_add_queue.pop_front()
		collision_add_queued.erase(coord)
		if loaded_chunks.has(coord) and _needs_collision(coord):
			var collision_start: int = Time.get_ticks_usec()
			_ensure_collision(coord)
			last_collision_usec = Time.get_ticks_usec() - collision_start

	for _index in range(COLLISION_REMOVES_PER_FRAME):
		if collision_remove_queue.is_empty():
			break
		var coord: Vector2i = collision_remove_queue.pop_front()
		collision_remove_queued.erase(coord)
		if not loaded_chunks.has(coord) or _needs_collision(coord):
			continue
		var entry: Dictionary = loaded_chunks[coord]
		if is_instance_valid(entry["collision"]):
			entry["collision"].queue_free()
			entry["collision"] = null
			loaded_chunks[coord] = entry

func _ensure_collision(coord: Vector2i) -> void:
	if not loaded_chunks.has(coord):
		return

	var entry: Dictionary = loaded_chunks[coord]
	if is_instance_valid(entry["collision"]):
		return

	var mesh: ArrayMesh = entry["mesh"]
	if mesh.get_surface_count() == 0:
		return

	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = 1
	static_body.collision_mask = 2

	var shape_node := CollisionShape3D.new()
	var collision_shape: Shape3D = mesh.create_trimesh_shape()
	if collision_shape is ConcavePolygonShape3D:
		collision_shape.backface_collision = true
	shape_node.shape = collision_shape
	static_body.add_child(shape_node)
	entry["root"].add_child(static_body)

	entry["collision"] = static_body
	loaded_chunks[coord] = entry

func _try_emit_spawn() -> void:
	if spawn_emitted or not _spawn_ring_ready():
		return
	spawn_emitted = true
	var spawn_x: int = int(CHUNK_SIZE * 0.5)
	var spawn_z: int = int(CHUNK_SIZE * 0.5)
	var spawn_y := float(_terrain_height(spawn_x, spawn_z)) + 2.2
	spawn_ready.emit(Vector3(spawn_x + 0.5, spawn_y, spawn_z + 0.5))

func _spawn_ring_ready() -> bool:
	for z in range(-COLLISION_RADIUS, COLLISION_RADIUS + 1):
		for x in range(-COLLISION_RADIUS, COLLISION_RADIUS + 1):
			var coord := Vector2i(x, z)
			if not loaded_chunks.has(coord):
				return false
			var entry: Dictionary = loaded_chunks[coord]
			if not is_instance_valid(entry["collision"]):
				return false
	return true

func _unload_far_chunks() -> void:
	for coord in loaded_chunks.keys():
		if max(abs(coord.x - current_center.x), abs(coord.y - current_center.y)) > UNLOAD_RADIUS:
			var entry: Dictionary = loaded_chunks[coord]
			if is_instance_valid(entry["root"]):
				entry["root"].queue_free()
			loaded_chunks.erase(coord)

func _needs_collision(coord: Vector2i) -> bool:
	return max(abs(coord.x - current_center.x), abs(coord.y - current_center.y)) <= COLLISION_RADIUS

func _chunk_distance_squared(a: Vector2i, b: Vector2i) -> int:
	var delta := a - b
	return delta.x * delta.x + delta.y * delta.y

func _terrain_height(x: int, z: int) -> int:
	var continental := noise.get_noise_2d(float(x), float(z))
	var region := biome_noise.get_noise_2d(float(x), float(z))
	var height := 10.0 + continental * 6.4 + region * 3.0
	return clampi(roundi(height), 3, WORLD_HEIGHT - 3)

func get_block(cell: Vector3i) -> int:
	if cell.y < 0:
		return BLOCK_STONE
	if cell.y >= WORLD_HEIGHT:
		return BLOCK_AIR
	var key := _cell_key(cell)
	if block_overrides.has(key):
		return int(block_overrides[key])
	return _generated_block(cell.y, _terrain_height(cell.x, cell.z))

func _generated_block(y: int, height: int) -> int:
	if y > height:
		return BLOCK_AIR
	if y == height:
		return BLOCK_SAND if height <= SEA_LEVEL + 1 else BLOCK_GRASS
	if y >= height - 3:
		return BLOCK_SAND if height <= SEA_LEVEL + 1 else BLOCK_DIRT
	return BLOCK_STONE

func edit_from_ray(origin: Vector3, direction: Vector3, distance: float, place_block: bool, player_position: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * distance)
	query.collision_mask = 1
	query.hit_from_inside = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var hit_position: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var target_position: Vector3 = hit_position + normal * (0.02 if place_block else -0.02)
	var cell := Vector3i(floori(target_position.x), floori(target_position.y), floori(target_position.z))

	if place_block:
		if get_block(cell) != BLOCK_AIR:
			return
		var cell_center := Vector3(cell) + Vector3.ONE * 0.5
		if cell_center.distance_to(player_position + Vector3.UP * 0.8) < 1.25:
			return
		_set_block(cell, BLOCK_DIRT)
	else:
		if cell.y <= 0 or get_block(cell) == BLOCK_AIR:
			return
		_set_block(cell, BLOCK_AIR)

func _set_block(cell: Vector3i, block: int) -> void:
	block_overrides[_cell_key(cell)] = block
	dirty_save = true
	save_delay = 1.5

	var affected: Array[Vector2i] = [cell_to_chunk(cell)]
	var local_x: int = posmod(cell.x, CHUNK_SIZE)
	var local_z: int = posmod(cell.z, CHUNK_SIZE)
	if local_x == 0:
		affected.append(cell_to_chunk(cell + Vector3i(-1, 0, 0)))
	elif local_x == CHUNK_SIZE - 1:
		affected.append(cell_to_chunk(cell + Vector3i(1, 0, 0)))
	if local_z == 0:
		affected.append(cell_to_chunk(cell + Vector3i(0, 0, -1)))
	elif local_z == CHUNK_SIZE - 1:
		affected.append(cell_to_chunk(cell + Vector3i(0, 0, 1)))

	for coord in affected:
		_rebuild_chunk(coord)

func _rebuild_chunk(coord: Vector2i) -> void:
	if loaded_chunks.has(coord):
		var entry: Dictionary = loaded_chunks[coord]
		if is_instance_valid(entry["root"]):
			entry["root"].queue_free()
		loaded_chunks.erase(coord)

	if not queued_chunks.has(coord):
		build_queue.push_front(coord)
		queued_chunks[coord] = true

func get_recovery_position(position: Vector3) -> Vector3:
	var height: int = _terrain_height(floori(position.x), floori(position.z))
	return Vector3(position.x, height + 3.0, position.z)

func get_status_text() -> String:
	return "chunks %d  mesh-q %d\nmesh %.2f ms  faces %d\ncollision %.2f ms  q %d/%d" % [
		loaded_chunks.size(),
		build_queue.size(),
		last_build_usec / 1000.0,
		last_face_count,
		last_collision_usec / 1000.0,
		collision_add_queue.size(),
		collision_remove_queue.size()
	]

func _block_color(block: int, cell: Vector3i, shade: float) -> Color:
	var base_color: Color
	match block:
		BLOCK_GRASS:
			base_color = Color(0.30, 0.52, 0.20)
		BLOCK_DIRT:
			base_color = Color(0.38, 0.25, 0.14)
		BLOCK_STONE:
			base_color = Color(0.43, 0.45, 0.46)
		BLOCK_SAND:
			base_color = Color(0.68, 0.61, 0.42)
		_:
			base_color = Color.WHITE

	var hash_value: int = absi((cell.x * 73856093) ^ (cell.y * 83492791) ^ (cell.z * 19349663))
	var variation: float = 0.90 + float(hash_value % 17) * 0.01
	var factor: float = shade * variation
	return Color(base_color.r * factor, base_color.g * factor, base_color.b * factor, 1.0)

func _face_shade(face_index: int) -> float:
	match face_index:
		0:
			return 1.0
		1:
			return 0.55
		2, 3:
			return 0.82
		_:
			return 0.72

func _cell_key(cell: Vector3i) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, cell.z]

func _create_water() -> void:
	water = MeshInstance3D.new()
	water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2048, 2048)
	water.mesh = plane
	water.position = Vector3(0, SEA_LEVEL + 0.58, 0)

	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.10, 0.31, 0.43, 0.63)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.18
	water_material.metallic = 0.08
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = water_material
	add_child(water)

func _save_world() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save world edits")
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"seed": WORLD_SEED,
		"overrides": block_overrides
	}))
	dirty_save = false

func _load_world() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("overrides") and parsed["overrides"] is Dictionary:
		block_overrides = parsed["overrides"].duplicate(true)
