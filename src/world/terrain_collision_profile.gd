class_name TeknikTerrainCollisionProfile
extends RefCounted

const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GRID_SIZE: int = VoxelChunk.SIZE + 1


static func build(
	seed: int,
	coordinate: Vector3i,
	edit_snapshots: Dictionary
) -> Dictionary:
	return _build_profile(seed, coordinate, edit_snapshots, null)


static func build_from_chunk(
	seed: int,
	coordinate: Vector3i,
	edit_snapshots: Dictionary,
	chunk: TeknikVoxelChunk
) -> Dictionary:
	return _build_profile(seed, coordinate, edit_snapshots, chunk)


static func _build_profile(
	seed: int,
	coordinate: Vector3i,
	edit_snapshots: Dictionary,
	chunk: TeknikVoxelChunk
) -> Dictionary:
	var world_origin: Vector3i = coordinate * VoxelChunk.SIZE
	var height_data := PackedFloat32Array()
	height_data.resize(GRID_SIZE * GRID_SIZE)
	for z: int in range(GRID_SIZE):
		for x: int in range(GRID_SIZE):
			var top_local_y: int = -1
			if chunk != null and x < VoxelChunk.SIZE and z < VoxelChunk.SIZE:
				top_local_y = _top_solid_local_y(chunk, x, z)
			else:
				top_local_y = _sample_top_local_y(
					seed,
					coordinate,
					edit_snapshots,
					world_origin.x + x,
					world_origin.z + z
				)
			var index: int = z * GRID_SIZE + x
			height_data[index] = NAN if top_local_y < 0 else float(top_local_y + 1)

	return {
		"height_data": height_data,
		"box_runs": _placed_box_runs(seed, coordinate, edit_snapshots),
	}


static func create_body(profile: Dictionary, body_name: String) -> StaticBody3D:
	var height_data: PackedFloat32Array = profile.get("height_data", PackedFloat32Array())
	if height_data.size() != GRID_SIZE * GRID_SIZE:
		return null

	var body := StaticBody3D.new()
	body.name = body_name

	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = GRID_SIZE
	height_shape.map_depth = GRID_SIZE
	height_shape.map_data = height_data
	var terrain_collision := CollisionShape3D.new()
	terrain_collision.name = "TerrainHeightfield"
	terrain_collision.shape = height_shape
	terrain_collision.position = Vector3(float(VoxelChunk.SIZE) * 0.5, 0.0, float(VoxelChunk.SIZE) * 0.5)
	body.add_child(terrain_collision)

	var runs: Array = profile.get("box_runs", [])
	for run_variant: Variant in runs:
		if not run_variant is Dictionary:
			continue
		var run: Dictionary = run_variant
		var size: Vector3 = run.get("size", Vector3.ZERO)
		var position: Vector3 = run.get("position", Vector3.ZERO)
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			continue
		var box := BoxShape3D.new()
		box.size = size
		var collision := CollisionShape3D.new()
		collision.name = "PlacedBlockRun"
		collision.shape = box
		collision.position = position
		body.add_child(collision)

	return body


static func shape_count(profile: Dictionary) -> int:
	var runs: Array = profile.get("box_runs", [])
	return 1 + runs.size()


static func _top_solid_local_y(chunk: TeknikVoxelChunk, local_x: int, local_z: int) -> int:
	for local_y: int in range(VoxelChunk.SIZE - 1, -1, -1):
		if chunk.get_voxel(Vector3i(local_x, local_y, local_z)) != VoxelChunk.AIR:
			return local_y
	return -1


static func _sample_top_local_y(
	seed: int,
	coordinate: Vector3i,
	edit_snapshots: Dictionary,
	world_x: int,
	world_z: int
) -> int:
	var world_origin_y: int = coordinate.y * VoxelChunk.SIZE
	var top_world_y: int = mini(
		TerrainGenerator.surface_height(seed, world_x, world_z),
		world_origin_y + VoxelChunk.SIZE - 1
	)
	while top_world_y >= world_origin_y and _has_air_override(
		edit_snapshots,
		Vector3i(world_x, top_world_y, world_z)
	):
		top_world_y -= 1
	return top_world_y - world_origin_y


static func _has_air_override(edit_snapshots: Dictionary, world_position: Vector3i) -> bool:
	var coordinate := Vector3i(
		floori(float(world_position.x) / float(VoxelChunk.SIZE)),
		floori(float(world_position.y) / float(VoxelChunk.SIZE)),
		floori(float(world_position.z) / float(VoxelChunk.SIZE))
	)
	var edits: Dictionary = edit_snapshots.get(coordinate, {})
	if edits.is_empty():
		return false
	var local: Vector3i = world_position - coordinate * VoxelChunk.SIZE
	var index: int = VoxelChunk.index_of(local)
	return edits.has(index) and int(edits[index]) == VoxelChunk.AIR


static func _placed_box_runs(
	seed: int,
	coordinate: Vector3i,
	edit_snapshots: Dictionary
) -> Array[Dictionary]:
	var edits: Dictionary = edit_snapshots.get(coordinate, {})
	var columns: Dictionary = {}
	var world_origin: Vector3i = coordinate * VoxelChunk.SIZE
	for index_variant: Variant in edits.keys():
		var index: int = int(index_variant)
		if index < 0 or index >= VoxelChunk.VOLUME:
			continue
		var material: int = int(edits[index])
		if material == VoxelChunk.AIR:
			continue
		var local_y: int = floori(float(index) / float(VoxelChunk.SIZE * VoxelChunk.SIZE))
		var remainder: int = index % (VoxelChunk.SIZE * VoxelChunk.SIZE)
		var local_z: int = floori(float(remainder) / float(VoxelChunk.SIZE))
		var local_x: int = remainder % VoxelChunk.SIZE
		var world_position: Vector3i = world_origin + Vector3i(local_x, local_y, local_z)
		if TerrainGenerator.voxel_at(seed, world_position) != VoxelChunk.AIR:
			continue
		var key := Vector2i(local_x, local_z)
		var heights: Array = columns.get(key, [])
		heights.append(local_y)
		columns[key] = heights

	var result: Array[Dictionary] = []
	for key_variant: Variant in columns.keys():
		var key: Vector2i = key_variant
		var heights: Array = columns[key]
		heights.sort()
		if heights.is_empty():
			continue
		var run_start: int = int(heights[0])
		var run_end: int = int(heights[0])
		for height_index: int in range(1, heights.size()):
			var height: int = int(heights[height_index])
			if height == run_end + 1:
				run_end = height
			else:
				result.append(_box_run(key, run_start, run_end))
				run_start = height
				run_end = height
		result.append(_box_run(key, run_start, run_end))
	return result


static func _box_run(column: Vector2i, start_y: int, end_y: int) -> Dictionary:
	var height: float = float(end_y - start_y + 1)
	return {
		"position": Vector3(float(column.x) + 0.5, float(start_y) + height * 0.5, float(column.y) + 0.5),
		"size": Vector3(1.0, height, 1.0),
	}
