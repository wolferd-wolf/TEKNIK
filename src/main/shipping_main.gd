extends "res://src/main/playable_main.gd"

const PlayabilityTraversalDirector = preload("res://src/qa/playability_traversal_director.gd")


func _ready() -> void:
	super._ready()
	if "--qa-playability" in OS.get_cmdline_user_args() and _player != null:
		var director: TeknikPlayabilityTraversalDirector = PlayabilityTraversalDirector.new()
		director.name = "PlayabilityTraversalDirector"
		add_child(director)
		director.begin(self, _player)


func _refresh_terrain(center: Vector3i, priority: Vector3i) -> void:
	if not _qa_screenshot_path().is_empty() and _terrain_nodes.is_empty() and _chunk_stream.active_count() == 0:
		var coordinates: Array[Vector3i] = ChunkStreamPlanPlayable.ordered_square(
			center,
			CHUNK_RADIUS,
			priority
		)
		for coordinate: Vector3i in coordinates:
			_build_initial_chunk(coordinate)
		_set_desired_chunks(center, CHUNK_RADIUS, priority)
		return
	super._refresh_terrain(center, priority)


func _build_initial_chunk(coordinate: Vector3i) -> void:
	var chunk: TeknikVoxelChunk = PlayableTerrainGenerator.generate_chunk(WORLD_SEED, coordinate)
	_world_edits.apply_to_chunk(coordinate, chunk)
	var world_origin: Vector3i = coordinate * PlayableVoxelChunk.SIZE
	var boundary_columns: Dictionary = {}
	var report: Dictionary = PlayableGreedyMesher.build_arrays(
		chunk,
		world_origin,
		func(world_position: Vector3i) -> int:
			if world_position.y < world_origin.y:
				return PlayableTerrainGenerator.STONE
			if world_position.y >= world_origin.y + PlayableVoxelChunk.SIZE:
				return PlayableVoxelChunk.AIR
			var owner := Vector3i(
				floori(float(world_position.x) / float(PlayableVoxelChunk.SIZE)),
				coordinate.y,
				floori(float(world_position.z) / float(PlayableVoxelChunk.SIZE))
			)
			if owner == coordinate:
				return chunk.get_voxel(world_position - world_origin)
			var key := Vector2i(world_position.x, world_position.z)
			var column: Vector2i
			if boundary_columns.has(key):
				column = boundary_columns[key]
			else:
				column = PlayableTerrainGenerator.sample_column(WORLD_SEED, world_position.x, world_position.z)
				boundary_columns[key] = column
			var generated: int = PlayableTerrainGenerator.material_from_column(world_position.y, column)
			return _world_edits.get_override(world_position, generated),
		func(material: int, world_position: Vector3i) -> Color:
			return PlayableTerrainGenerator.fast_surface_color(WORLD_SEED, material, world_position)
	)
	var terrain := MeshInstance3D.new()
	terrain.mesh = PlayableGreedyMesher.mesh_from_arrays(report.arrays)
	terrain.position = Vector3(coordinate.x * PlayableVoxelChunk.SIZE, 0.0, coordinate.z * PlayableVoxelChunk.SIZE)
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.set_meta("quad_count", int(report.quads))
	terrain.set_meta("collision_profile", PlayableCollisionProfile.build_from_chunk(
		WORLD_SEED,
		coordinate,
		_world_edits.snapshot_neighborhood(coordinate),
		chunk
	))
	add_child(terrain)
	_terrain_nodes[coordinate] = terrain
	_chunk_stream.mark_loaded(coordinate)
	_total_quads += int(report.quads)
	_render_instance_count += 1


func _next_build_coordinate() -> Vector3i:
	while not _emergency_load_queue.is_empty():
		var emergency: Vector3i = _emergency_load_queue.pop_front()
		if not _terrain_nodes.has(emergency) and not _playable_pool.has_coordinate(emergency):
			return emergency
	while not _edit_rebuild_queue.is_empty():
		var rebuild: Vector3i = _edit_rebuild_queue.pop_front()
		if _terrain_nodes.has(rebuild) and not _playable_pool.has_coordinate(rebuild):
			# Keep the marker until the parent dispatches it. The next pool slot
			# removes this marker after seeing the coordinate already in flight.
			_edit_rebuild_queue.push_front(rebuild)
			return rebuild
	var load_work: Dictionary = _chunk_work_budget.take_frame(1, 0)
	var loads: Array[Vector3i] = load_work.load
	if loads.is_empty():
		return Vector3i(2_147_483_647, 0, 2_147_483_647)
	var coordinate: Vector3i = loads[0]
	if _terrain_nodes.has(coordinate) or _playable_pool.has_coordinate(coordinate):
		return _next_build_coordinate()
	return coordinate
