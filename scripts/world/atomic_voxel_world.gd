extends "res://scripts/world/voxel_world.gd"

var pending_rebuilds: Dictionary = {}
var atomic_swap_count := 0
var atomic_swap_failures := 0

func _rebuild_chunk(coord: Vector2i) -> void:
	if not loaded_chunks.has(coord):
		super._rebuild_chunk(coord)
		return

	pending_rebuilds[coord] = true
	if not queued_chunks.has(coord):
		build_queue.push_front(coord)
		queued_chunks[coord] = true

func _pump_build_queue() -> void:
	if build_queue.is_empty():
		return

	var frame_start: int = Time.get_ticks_usec()
	while not build_queue.is_empty():
		var coord: Vector2i = build_queue.pop_front()
		queued_chunks.erase(coord)

		var replacing: bool = pending_rebuilds.has(coord)
		if loaded_chunks.has(coord) and not replacing:
			continue
		if max(abs(coord.x - current_center.x), abs(coord.y - current_center.y)) > RENDER_RADIUS:
			pending_rebuilds.erase(coord)
			continue

		var build_start: int = Time.get_ticks_usec()
		var data: Dictionary = _build_chunk_mesh(coord)
		if replacing:
			if _commit_atomic_replacement(coord, data):
				pending_rebuilds.erase(coord)
			else:
				atomic_swap_failures += 1
				if not queued_chunks.has(coord):
					build_queue.push_back(coord)
					queued_chunks[coord] = true
		else:
			_commit_chunk(coord, data)

		last_build_usec = Time.get_ticks_usec() - build_start
		last_face_count = int(data["face_count"])
		if Time.get_ticks_usec() - frame_start >= BUILD_BUDGET_USEC:
			break

func _commit_atomic_replacement(coord: Vector2i, data: Dictionary) -> bool:
	if not loaded_chunks.has(coord):
		_commit_chunk(coord, data)
		atomic_swap_count += 1
		return true

	var old_entry: Dictionary = loaded_chunks[coord]
	var old_root: Node3D = old_entry["root"]
	var replacement := _create_replacement_entry(coord, data)
	if replacement.is_empty():
		return false

	var new_root: Node3D = replacement["root"]
	add_child(new_root)
	loaded_chunks[coord] = replacement

	collision_add_queue.erase(coord)
	collision_remove_queue.erase(coord)
	collision_add_queued.erase(coord)
	collision_remove_queued.erase(coord)

	if is_instance_valid(old_root):
		old_root.queue_free()
	atomic_swap_count += 1
	return true

func _create_replacement_entry(coord: Vector2i, data: Dictionary) -> Dictionary:
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	chunk_root.position = Vector3(coord.x * CHUNK_SIZE, 0, coord.y * CHUNK_SIZE)
	chunk_root.set_meta("chunk_coord", coord)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]

	var mesh := ArrayMesh.new()
	var vertices: PackedVector3Array = data["vertices"]
	if vertices.is_empty():
		return {}

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, shared_material)
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

func _create_replacement_collision(mesh: ArrayMesh) -> StaticBody3D:
	if mesh.get_surface_count() == 0:
		return null

	var collision_shape: Shape3D = mesh.create_trimesh_shape()
	if collision_shape == null:
		return null
	if collision_shape is ConcavePolygonShape3D:
		collision_shape.backface_collision = true

	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = 1
	static_body.collision_mask = 2
	var shape_node := CollisionShape3D.new()
	shape_node.shape = collision_shape
	static_body.add_child(shape_node)
	return static_body

func get_status_text() -> String:
	return "%s\nedit-swaps %d  failures %d" % [
		super.get_status_text(),
		atomic_swap_count,
		atomic_swap_failures
	]
