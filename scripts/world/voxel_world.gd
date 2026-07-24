extends Node3D

signal spawn_ready(position: Vector3)

const CHUNK_SIZE := 12
const WORLD_HEIGHT := 30
const RENDER_RADIUS := 3
const COLLISION_RADIUS := 1
const UNLOAD_RADIUS := 4
const BUILD_BUDGET_USEC := 5500
const SEA_LEVEL := 7
const WORLD_SEED := 734921
const SAVE_PATH := "user://teknik_world_v1.json"

const BLOCK_AIR := 0
const BLOCK_GRASS := 1
const BLOCK_DIRT := 2
const BLOCK_STONE := 3
const BLOCK_SAND := 4

const FACE_DIRECTIONS := [
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]

const FACE_NORMALS := [
	Vector3.UP, Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD
]

const FACE_VERTICES := [
	[Vector3(0,1,0), Vector3(0,1,1), Vector3(1,1,1), Vector3(1,1,0)],
	[Vector3(0,0,0), Vector3(1,0,0), Vector3(1,0,1), Vector3(0,0,1)],
	[Vector3(1,0,0), Vector3(1,1,0), Vector3(1,1,1), Vector3(1,0,1)],
	[Vector3(0,0,0), Vector3(0,0,1), Vector3(0,1,1), Vector3(0,1,0)],
	[Vector3(0,0,1), Vector3(1,0,1), Vector3(1,1,1), Vector3(0,1,1)],
	[Vector3(0,0,0), Vector3(0,1,0), Vector3(1,1,0), Vector3(1,0,0)]
]

var player: Node3D
var noise := FastNoiseLite.new()
var biome_noise := FastNoiseLite.new()
var shared_material := StandardMaterial3D.new()
var loaded_chunks: Dictionary = {}
var queued_chunks: Dictionary = {}
var build_queue: Array[Vector2i] = []
var block_overrides: Dictionary = {}
var current_center := Vector2i(999999, 999999)
var spawn_emitted := false
var dirty_save := false
var save_delay := 0.0
var last_build_usec := 0
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
		var player_chunk := world_to_chunk(player.global_position)
		if player_chunk != current_center:
			_set_center(player_chunk)
	_update_collision_band()
	_pump_build_queue()
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
	var wanted: Array[Vector2i] = []
	for z in range(center.y - RENDER_RADIUS, center.y + RENDER_RADIUS + 1):
		for x in range(center.x - RENDER_RADIUS, center.x + RENDER_RADIUS + 1):
			var coord := Vector2i(x, z)
			if not loaded_chunks.has(coord) and not queued_chunks.has(coord):
				wanted.append(coord)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ac := _needs_collision(a)
		var bc := _needs_collision(b)
		if ac != bc:
			return ac
		return _chunk_distance_squared(a, center) < _chunk_distance_squared(b, center)
	)
	for coord in wanted:
		build_queue.append(coord)
		queued_chunks[coord] = true
	_unload_far_chunks()

func _pump_build_queue() -> void:
	if build_queue.is_empty():
		return
	var frame_start := Time.get_ticks_usec()
	while not build_queue.is_empty():
		var coord := build_queue.pop_front()
		queued_chunks.erase(coord)
		if loaded_chunks.has(coord):
			continue
		var build_start := Time.get_ticks_usec()
		var data := _build_chunk_mesh(coord)
		_commit_chunk(coord, data)
		last_build_usec = Time.get_ticks_usec() - build_start
		last_face_count = int(data.face_count)
		if Time.get_ticks_usec() - frame_start >= BUILD_BUDGET_USEC:
			break

func _build_chunk_mesh(coord: Vector2i) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var face_count := 0
	var origin := Vector3i(coord.x * CHUNK_SIZE, 0, coord.y * CHUNK_SIZE)

	for local_z in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var global_x := origin.x + local_x
			var global_z := origin.z + local_z
			var top_height := _terrain_height(global_x, global_z)
			for y in range(0, WORLD_HEIGHT):
				var cell := Vector3i(global_x, y, global_z)
				var block := get_block(cell, top_height)
				if block == BLOCK_AIR:
					continue
				for face_index in range(6):
					var neighbor := cell + FACE_DIRECTIONS[face_index]
					if get_block(neighbor) != BLOCK_AIR:
						continue
					var base_index := vertices.size()
					var shade := _face_shade(face_index)
					var color := _block_color(block) * shade
					var local_cell := Vector3(local_x, y, local_z)
					for vertex in FACE_VERTICES[face_index]:
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

func _commit_chunk(coord: Vector2i, data: Dictionary) -> void:
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_root.position = Vector3(coord.x * CHUNK_SIZE, 0, coord.y * CHUNK_SIZE)
	chunk_root.set_meta("chunk_coord", coord)
	add_child(chunk_root)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colors
	arrays[Mesh.ARRAY_INDEX] = data.indices

	var mesh := ArrayMesh.new()
	if data.vertices.size() > 0:
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
	if _needs_collision(coord):
		_ensure_collision(coord)

	if not spawn_emitted and coord == Vector2i.ZERO:
		spawn_emitted = true
		var spawn_x := CHUNK_SIZE / 2
		var spawn_z := CHUNK_SIZE / 2
		var spawn_y := _terrain_height(spawn_x, spawn_z) + 2.2
		spawn_ready.emit(Vector3(spawn_x + 0.5, spawn_y, spawn_z + 0.5))

func _ensure_collision(coord: Vector2i) -> void:
	if not loaded_chunks.has(coord):
		return
	var entry: Dictionary = loaded_chunks[coord]
	if is_instance_valid(entry.collision):
		return
	var mesh: ArrayMesh = entry.mesh
	if mesh.get_surface_count() == 0:
		return
	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = 1
	static_body.collision_mask = 2
	var shape_node := CollisionShape3D.new()
	var collision_shape := mesh.create_trimesh_shape()
	collision_shape.backface_collision = true
	shape_node.shape = collision_shape
	static_body.add_child(shape_node)
	entry.root.add_child(static_body)
	entry.collision = static_body
	loaded_chunks[coord] = entry

func _update_collision_band() -> void:
	for coord in loaded_chunks.keys():
		var entry: Dictionary = loaded_chunks[coord]
		if _needs_collision(coord):
			_ensure_collision(coord)
		elif is_instance_valid(entry.collision):
			entry.collision.queue_free()
			entry.collision = null
			loaded_chunks[coord] = entry

func _unload_far_chunks() -> void:
	for coord in loaded_chunks.keys():
		if max(abs(coord.x - current_center.x), abs(coord.y - current_center.y)) > UNLOAD_RADIUS:
			var entry: Dictionary = loaded_chunks[coord]
			if is_instance_valid(entry.root):
				entry.root.queue_free()
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

func get_block(cell: Vector3i, known_height: int = -9999) -> int:
	if cell.y < 0:
		return BLOCK_STONE
	if cell.y >= WORLD_HEIGHT:
		return BLOCK_AIR
	var key := _cell_key(cell)
	if block_overrides.has(key):
		return int(block_overrides[key])
	var height := known_height if known_height != -9999 else _terrain_height(cell.x, cell.z)
	if cell.y > height:
		return BLOCK_AIR
	if cell.y == height:
		return BLOCK_SAND if height <= SEA_LEVEL + 1 else BLOCK_GRASS
	if cell.y >= height - 3:
		return BLOCK_SAND if height <= SEA_LEVEL + 1 else BLOCK_DIRT
	return BLOCK_STONE

func edit_from_ray(origin: Vector3, direction: Vector3, distance: float, place_block: bool, player_position: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * distance)
	query.collision_mask = 1
	query.hit_from_inside = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hit_position: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var target_position := hit_position + normal * (0.02 if place_block else -0.02)
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
	var local_x := posmod(cell.x, CHUNK_SIZE)
	var local_z := posmod(cell.z, CHUNK_SIZE)
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
		if is_instance_valid(entry.root):
			entry.root.queue_free()
		loaded_chunks.erase(coord)
	if not queued_chunks.has(coord):
		build_queue.push_front(coord)
		queued_chunks[coord] = true

func get_recovery_position(position: Vector3) -> Vector3:
	var height := _terrain_height(floori(position.x), floori(position.z))
	return Vector3(position.x, height + 3.0, position.z)

func get_status_text() -> String:
	return "chunks %d  queue %d\nbuild %.2f ms  faces %d" % [
		loaded_chunks.size(), build_queue.size(), last_build_usec / 1000.0, last_face_count
	]

func _block_color(block: int) -> Color:
	match block:
		BLOCK_GRASS:
			return Color(0.30, 0.52, 0.20)
		BLOCK_DIRT:
			return Color(0.38, 0.25, 0.14)
		BLOCK_STONE:
			return Color(0.43, 0.45, 0.46)
		BLOCK_SAND:
			return Color(0.68, 0.61, 0.42)
		_:
			return Color.WHITE

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
	var water := MeshInstance3D.new()
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
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save world edits")
		return
	file.store_string(JSON.stringify({"version": 1, "seed": WORLD_SEED, "overrides": block_overrides}))
	dirty_save = false

func _load_world() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("overrides") and parsed.overrides is Dictionary:
		block_overrides = parsed.overrides
