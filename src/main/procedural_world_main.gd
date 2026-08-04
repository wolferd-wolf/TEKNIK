extends "res://src/main/mobile_shipping_main.gd"

const ProceduralEcology = preload("res://src/world/procedural_ecology.gd")
const PWorldSeed = preload("res://src/world/world_seed.gd")
const PTerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const PWorldWindowPlan = preload("res://src/world/world_window_plan.gd")
const PVoxelChunk = preload("res://src/world/voxel_chunk.gd")


func _build_forest() -> void:
	var trunk_transforms: Array[Transform3D] = []
	var broadleaf_lower: Array[Transform3D] = []
	var broadleaf_upper: Array[Transform3D] = []
	var broadleaf_side: Array[Transform3D] = []
	var conifer_lower: Array[Transform3D] = []
	var conifer_middle: Array[Transform3D] = []
	var conifer_upper: Array[Transform3D] = []
	var fallen_logs: Array[Transform3D] = []
	var world_rect: Rect2i = PWorldWindowPlan.active_world_rect(
		_world_center, CHUNK_RADIUS, PVoxelChunk.SIZE, 7
	)
	var camera_position: Vector3 = _camera_position()
	var cell_size: int = ProceduralEcology.TREE_CELL_SIZE
	var start_x: int = floori(float(world_rect.position.x) / float(cell_size)) - 1
	var end_x: int = ceili(float(world_rect.end.x) / float(cell_size)) + 1
	var start_z: int = floori(float(world_rect.position.y) / float(cell_size)) - 1
	var end_z: int = ceili(float(world_rect.end.y) / float(cell_size)) + 1

	for cell_z: int in range(start_z, end_z + 1):
		for cell_x: int in range(start_x, end_x + 1):
			if not ProceduralEcology.blue_noise_accept(
				WORLD_SEED + 701,
				cell_x,
				cell_z,
				cell_size,
				ProceduralEcology.TREE_MIN_DISTANCE
			):
				continue
			var candidate: Vector2 = ProceduralEcology.candidate_position(
				WORLD_SEED + 701, cell_x, cell_z, cell_size
			)
			var world_x: int = floori(candidate.x)
			var world_z: int = floori(candidate.y)
			if not world_rect.has_point(Vector2i(world_x, world_z)):
				continue
			var horizontal_distance: float = Vector2(
				float(world_x) - camera_position.x,
				float(world_z) - camera_position.z
			).length()
			if horizontal_distance < 14.0:
				continue
			var height: int = PTerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			if height <= PTerrainGenerator.WATER_LEVEL + 2:
				continue
			if PTerrainGenerator.surface_material(
				WORLD_SEED, world_x, world_z
			) != PTerrainGenerator.GRASS:
				continue
			var river_gap: float = PTerrainGenerator.river_distance(
				WORLD_SEED, world_x, world_z
			)
			if river_gap < 6.5:
				continue
			var slope: int = PTerrainGenerator.surface_slope(WORLD_SEED, world_x, world_z)
			if slope > 1:
				continue
			var vegetation: Vector3 = PTerrainGenerator.vegetation_profile(
				WORLD_SEED, world_x, world_z
			)
			var climate: Vector2 = PTerrainGenerator.climate_at(
				WORLD_SEED, world_x, world_z
			)
			var elevation: float = clampf(
				(float(height) - 9.0)
				/ float(PTerrainGenerator.MAX_SURFACE_HEIGHT - 9),
				0.0,
				1.0
			)
			var density: float = ProceduralEcology.forest_density(
				WORLD_SEED,
				world_x,
				world_z,
				vegetation.x,
				climate.x,
				climate.y,
				elevation,
				slope,
				river_gap
			)
			if PWorldSeed.sample_unit(WORLD_SEED + 709, cell_x, cell_z) > density:
				continue

			var scale: float = ProceduralEcology.tree_scale(
				WORLD_SEED, cell_x, cell_z, vegetation.x, climate.x, elevation
			)
			var quarter_turn: int = floori(
				PWorldSeed.sample_unit(WORLD_SEED + 769, cell_x, cell_z) * 4.0
			) % 4
			var rotation: float = float(quarter_turn) * PI * 0.5
			var ground := Vector3(
				float(world_x) + 0.5,
				float(height) + 1.0,
				float(world_z) + 0.5
			)
			var trunk_height: float = scale * lerpf(
				3.3, 5.2, clampf(vegetation.x * 0.72 + climate.x * 0.28, 0.0, 1.0)
			)
			var trunk_width: float = scale * lerpf(0.54, 0.76, vegetation.x)
			trunk_transforms.append(Transform3D(
				Basis(Vector3.UP, rotation).scaled(Vector3(
					trunk_width,
					trunk_height,
					trunk_width
				)),
				ground + Vector3.UP * trunk_height * 0.5
			))

			var conifer_chance: float = ProceduralEcology.conifer_probability(
				WORLD_SEED, world_x, world_z, climate.x, climate.y, elevation
			)
			var species_roll: float = PWorldSeed.sample_unit(
				WORLD_SEED + 787, cell_x, cell_z
			)
			if species_roll < conifer_chance:
				conifer_lower.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(
						scale * 3.05, scale * 0.92, scale * 3.05
					)),
					ground + Vector3.UP * (trunk_height + scale * 0.18)
				))
				conifer_middle.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(
						scale * 2.25, scale * 0.90, scale * 2.25
					)),
					ground + Vector3.UP * (trunk_height + scale * 1.10)
				))
				conifer_upper.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(
						scale * 1.35, scale * 0.88, scale * 1.35
					)),
					ground + Vector3.UP * (trunk_height + scale * 2.00)
				))
			else:
				var crown_width: float = scale * lerpf(
					2.65, 3.55, clampf(vegetation.x * 0.7 + climate.x * 0.3, 0.0, 1.0)
				)
				var side_direction: Vector3 = Basis(Vector3.UP, rotation) * Vector3.RIGHT
				broadleaf_lower.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(
						crown_width,
						scale * 1.55,
						crown_width * 0.88
					)),
					ground + Vector3.UP * (trunk_height + scale * 0.45)
				))
				broadleaf_upper.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(
						crown_width * 0.72,
						scale * 1.35,
						crown_width * 0.72
					)),
					ground + Vector3.UP * (trunk_height + scale * 1.62)
				))
				broadleaf_side.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(
						crown_width * 0.52,
						scale * 1.02,
						crown_width * 0.48
					)),
					ground
					+ side_direction * (crown_width * 0.43)
					+ Vector3.UP * (trunk_height + scale * 0.92)
				))

			var edge: float = ProceduralEcology.forest_edge(
				WORLD_SEED, world_x, world_z
			)
			if edge > 0.58 and PWorldSeed.sample_unit(
				WORLD_SEED + 811, cell_x, cell_z
			) < 0.075:
				var log_rotation: float = rotation + PI * 0.5
				fallen_logs.append(Transform3D(
					Basis(Vector3.UP, log_rotation).scaled(Vector3(
						scale * 3.0, scale * 0.38, scale * 0.42
					)),
					ground + Vector3.UP * scale * 0.26
				))

	_tree_count = trunk_transforms.size()
	_add_tree_multimesh(_voxel_box_mesh(Color("5b4030"), 0.98), trunk_transforms)
	_add_tree_multimesh(_voxel_box_mesh(Color("2f5d38"), 0.99), broadleaf_lower)
	_add_tree_multimesh(_voxel_box_mesh(Color("477a49"), 0.99), broadleaf_upper)
	_add_tree_multimesh(_voxel_box_mesh(Color("386c40"), 0.99), broadleaf_side)
	_add_tree_multimesh(_voxel_box_mesh(Color("244936"), 0.99), conifer_lower)
	_add_tree_multimesh(_voxel_box_mesh(Color("2d5a3e"), 0.99), conifer_middle)
	_add_tree_multimesh(_voxel_box_mesh(Color("3b6d48"), 0.99), conifer_upper)
	_add_tree_multimesh(_voxel_box_mesh(Color("654733"), 1.0), fallen_logs)
	print(
		"WORLD_QA procedural_trees=", _tree_count,
		" broadleaf=", broadleaf_lower.size(),
		" conifer=", conifer_lower.size(),
		" fallen_logs=", fallen_logs.size()
	)


func _build_boulders() -> void:
	var cool_primary: Array[Transform3D] = []
	var cool_secondary: Array[Transform3D] = []
	var warm_primary: Array[Transform3D] = []
	var warm_secondary: Array[Transform3D] = []
	var world_rect: Rect2i = PWorldWindowPlan.active_world_rect(
		_world_center, CHUNK_RADIUS, PVoxelChunk.SIZE, 7
	)
	var camera_position: Vector3 = _camera_position()
	var cell_size: int = ProceduralEcology.ROCK_CELL_SIZE
	var start_x: int = floori(float(world_rect.position.x) / float(cell_size)) - 1
	var end_x: int = ceili(float(world_rect.end.x) / float(cell_size)) + 1
	var start_z: int = floori(float(world_rect.position.y) / float(cell_size)) - 1
	var end_z: int = ceili(float(world_rect.end.y) / float(cell_size)) + 1

	for cell_z: int in range(start_z, end_z + 1):
		for cell_x: int in range(start_x, end_x + 1):
			if not ProceduralEcology.blue_noise_accept(
				WORLD_SEED + 823,
				cell_x,
				cell_z,
				cell_size,
				ProceduralEcology.ROCK_MIN_DISTANCE
			):
				continue
			var candidate: Vector2 = ProceduralEcology.candidate_position(
				WORLD_SEED + 823, cell_x, cell_z, cell_size
			)
			var world_x: int = floori(candidate.x)
			var world_z: int = floori(candidate.y)
			if not world_rect.has_point(Vector2i(world_x, world_z)):
				continue
			if Vector2(
				float(world_x) - camera_position.x,
				float(world_z) - camera_position.z
			).length() < 8.0:
				continue
			var height: int = PTerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			var slope: int = PTerrainGenerator.surface_slope(WORLD_SEED, world_x, world_z)
			var river_gap: float = PTerrainGenerator.river_distance(
				WORLD_SEED, world_x, world_z
			)
			var vegetation: Vector3 = PTerrainGenerator.vegetation_profile(
				WORLD_SEED, world_x, world_z
			)
			var elevation: float = clampf(
				(float(height) - 9.0)
				/ float(PTerrainGenerator.MAX_SURFACE_HEIGHT - 9),
				0.0,
				1.0
			)
			var density: float = ProceduralEcology.rock_density(
				WORLD_SEED,
				world_x,
				world_z,
				vegetation.z,
				elevation,
				slope,
				river_gap
			)
			if PWorldSeed.sample_unit(WORLD_SEED + 839, cell_x, cell_z) > density:
				continue
			var width: float = lerpf(
				0.72, 1.55, PWorldSeed.sample_unit(WORLD_SEED + 853, cell_x, cell_z)
			)
			var depth: float = lerpf(
				0.68, 1.38, PWorldSeed.sample_unit(WORLD_SEED + 877, cell_x, cell_z)
			)
			var rise: float = lerpf(
				0.48, 1.08, PWorldSeed.sample_unit(WORLD_SEED + 881, cell_x, cell_z)
			)
			var rotation: float = float(
				floori(PWorldSeed.sample_unit(WORLD_SEED + 907, cell_x, cell_z) * 8.0)
			) * PI * 0.25
			var ground := Vector3(
				float(world_x) + 0.5,
				float(height) + 1.0,
				float(world_z) + 0.5
			)
			var primary := Transform3D(
				Basis(Vector3.UP, rotation).scaled(Vector3(width, rise, depth)),
				ground + Vector3.UP * rise * 0.42
			)
			var offset_direction: Vector3 = Basis(Vector3.UP, rotation) * Vector3.RIGHT
			var secondary := Transform3D(
				Basis(Vector3.UP, rotation + PI * 0.5).scaled(Vector3(
					width * 0.58, rise * 0.66, depth * 0.52
				)),
				ground
				+ offset_direction * width * 0.42
				+ Vector3.UP * rise * 0.54
			)
			if vegetation.z + elevation > 0.92:
				cool_primary.append(primary)
				cool_secondary.append(secondary)
			else:
				warm_primary.append(primary)
				warm_secondary.append(secondary)

	_boulder_count = cool_primary.size() + warm_primary.size()
	_add_tree_multimesh(_voxel_box_mesh(Color("667471"), 1.0), cool_primary)
	_add_tree_multimesh(_voxel_box_mesh(Color("7c8783"), 1.0), cool_secondary)
	_add_tree_multimesh(_voxel_box_mesh(Color("756f63"), 1.0), warm_primary)
	_add_tree_multimesh(_voxel_box_mesh(Color("8b8170"), 1.0), warm_secondary)
	print("WORLD_QA procedural_boulders=", _boulder_count)


func _build_ground_detail() -> void:
	var lush_tufts: Array[Transform3D] = []
	var dry_tufts: Array[Transform3D] = []
	var shrubs_lower: Array[Transform3D] = []
	var shrubs_upper: Array[Transform3D] = []
	var world_rect: Rect2i = PWorldWindowPlan.active_world_rect(
		_world_center, CHUNK_RADIUS, PVoxelChunk.SIZE, 5
	)
	var camera_position: Vector3 = _camera_position()
	var cell_size: int = ProceduralEcology.COVER_CELL_SIZE
	var start_x: int = floori(float(world_rect.position.x) / float(cell_size)) - 1
	var end_x: int = ceili(float(world_rect.end.x) / float(cell_size)) + 1
	var start_z: int = floori(float(world_rect.position.y) / float(cell_size)) - 1
	var end_z: int = ceili(float(world_rect.end.y) / float(cell_size)) + 1

	for cell_z: int in range(start_z, end_z + 1):
		for cell_x: int in range(start_x, end_x + 1):
			if not ProceduralEcology.blue_noise_accept(
				WORLD_SEED + 947,
				cell_x,
				cell_z,
				cell_size,
				ProceduralEcology.COVER_MIN_DISTANCE
			):
				continue
			var candidate: Vector2 = ProceduralEcology.candidate_position(
				WORLD_SEED + 947, cell_x, cell_z, cell_size
			)
			var world_x: int = floori(candidate.x)
			var world_z: int = floori(candidate.y)
			if not world_rect.has_point(Vector2i(world_x, world_z)):
				continue
			if Vector2(
				float(world_x) - camera_position.x,
				float(world_z) - camera_position.z
			).length() > 116.0:
				continue
			if PTerrainGenerator.surface_material(
				WORLD_SEED, world_x, world_z
			) != PTerrainGenerator.GRASS:
				continue
			var slope: int = PTerrainGenerator.surface_slope(WORLD_SEED, world_x, world_z)
			if slope > 1:
				continue
			var height: int = PTerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			var river_gap: float = PTerrainGenerator.river_distance(
				WORLD_SEED, world_x, world_z
			)
			var vegetation: Vector3 = PTerrainGenerator.vegetation_profile(
				WORLD_SEED, world_x, world_z
			)
			var climate: Vector2 = PTerrainGenerator.climate_at(
				WORLD_SEED, world_x, world_z
			)
			var elevation: float = clampf(
				(float(height) - 9.0)
				/ float(PTerrainGenerator.MAX_SURFACE_HEIGHT - 9),
				0.0,
				1.0
			)
			var forest_density_value: float = ProceduralEcology.forest_density(
				WORLD_SEED,
				world_x,
				world_z,
				vegetation.x,
				climate.x,
				climate.y,
				elevation,
				slope,
				river_gap
			)
			var density: float = ProceduralEcology.ground_cover_density(
				WORLD_SEED,
				world_x,
				world_z,
				vegetation.y,
				climate.x,
				elevation,
				forest_density_value
			)
			if PWorldSeed.sample_unit(WORLD_SEED + 953, cell_x, cell_z) > density:
				continue
			var scale: float = lerpf(
				0.72, 1.24, PWorldSeed.sample_unit(WORLD_SEED + 977, cell_x, cell_z)
			)
			var rotation: float = float(
				floori(PWorldSeed.sample_unit(WORLD_SEED + 991, cell_x, cell_z) * 8.0)
			) * PI * 0.25
			var ground := Vector3(
				float(world_x) + 0.5,
				float(height) + 1.01,
				float(world_z) + 0.5
			)
			var tuft_a := Transform3D(
				Basis(Vector3.UP, rotation).scaled(Vector3(
					scale * 0.12, scale * 0.56, scale * 0.58
				)),
				ground + Vector3.UP * scale * 0.28
			)
			var tuft_b := Transform3D(
				Basis(Vector3.UP, rotation + PI * 0.5).scaled(Vector3(
					scale * 0.12, scale * 0.52, scale * 0.52
				)),
				ground + Vector3.UP * scale * 0.26
			)
			if climate.x > 0.46:
				lush_tufts.append(tuft_a)
				lush_tufts.append(tuft_b)
			else:
				dry_tufts.append(tuft_a)
				dry_tufts.append(tuft_b)

			var edge: float = ProceduralEcology.forest_edge(
				WORLD_SEED, world_x, world_z
			)
			if edge * vegetation.x > 0.34 and PWorldSeed.sample_unit(
				WORLD_SEED + 1009, cell_x, cell_z
			) < 0.22:
				shrubs_lower.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(
						scale * 0.90, scale * 0.56, scale * 0.78
					)),
					ground + Vector3.UP * scale * 0.28
				))
				shrubs_upper.append(Transform3D(
					Basis(Vector3.UP, rotation + PI * 0.5).scaled(Vector3(
						scale * 0.58, scale * 0.48, scale * 0.58
					)),
					ground + Vector3.UP * scale * 0.72
				))

	_grass_count = lush_tufts.size() + dry_tufts.size()
	_add_tree_multimesh(
		_voxel_box_mesh(Color("315f31"), 1.0), lush_tufts, false
	)
	_add_tree_multimesh(
		_voxel_box_mesh(Color("716a3b"), 1.0), dry_tufts, false
	)
	_add_tree_multimesh(
		_voxel_box_mesh(Color("2d5c36"), 1.0), shrubs_lower, false
	)
	_add_tree_multimesh(
		_voxel_box_mesh(Color("3a7042"), 1.0), shrubs_upper, false
	)
	print(
		"WORLD_QA procedural_ground_parts=", _grass_count,
		" shrubs=", shrubs_lower.size()
	)


func _voxel_box_mesh(color: Color, roughness: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = _material(color, roughness)
	return mesh
