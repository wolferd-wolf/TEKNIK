extends "res://src/main/budgeted_main.gd"

const BROADLEAF_THRESHOLD: float = 0.58


func _build_forest() -> void:
	var trunk_transforms: Array[Transform3D] = []
	var broadleaf_lower: Array[Transform3D] = []
	var broadleaf_upper: Array[Transform3D] = []
	var conifer_lower: Array[Transform3D] = []
	var conifer_upper: Array[Transform3D] = []
	var saplings: Array[Transform3D] = []
	var world_rect: Rect2i = WorldWindowPlan.active_world_rect(
		_world_center, CHUNK_RADIUS, VoxelChunk.SIZE, 5
	)
	var camera_position: Vector3 = _camera_position()

	for grid_z: int in range(world_rect.position.y, world_rect.end.y, TREE_SPACING):
		for grid_x: int in range(world_rect.position.x, world_rect.end.x, TREE_SPACING):
			var cell_x: int = floori(float(grid_x) / float(TREE_SPACING))
			var cell_z: int = floori(float(grid_z) / float(TREE_SPACING))
			var world_x: int = roundi(float(grid_x) + (WorldSeed.sample_unit(WORLD_SEED + 719, cell_x, cell_z) - 0.5) * 4.0)
			var world_z: int = roundi(float(grid_z) + (WorldSeed.sample_unit(WORLD_SEED + 733, cell_x, cell_z) - 0.5) * 4.0)
			var vegetation: Vector3 = TerrainGenerator.vegetation_profile(WORLD_SEED, world_x, world_z)
			var tree_chance: float = 0.035 + vegetation.x * 0.28
			if WorldSeed.sample_unit(WORLD_SEED + 701, cell_x, cell_z) > tree_chance:
				continue
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			if height <= TerrainGenerator.WATER_LEVEL + 2:
				continue
			if TerrainGenerator.river_distance(WORLD_SEED, world_x, world_z) < 7.0:
				continue
			if TerrainGenerator.surface_slope(WORLD_SEED, world_x, world_z) > 1:
				continue
			if Vector2(float(world_x) - camera_position.x, float(world_z) - camera_position.z).length() < 15.0:
				continue

			var scale: float = lerpf(0.72, 1.32, WorldSeed.sample_unit(WORLD_SEED + 751, cell_x, cell_z))
			var rotation: float = WorldSeed.sample_unit(WORLD_SEED + 769, cell_x, cell_z) * TAU
			var species: float = WorldSeed.sample_unit(WORLD_SEED + 787, cell_x, cell_z)
			var ground := Vector3(float(world_x) + 0.5, float(height) + 1.0, float(world_z) + 0.5)
			var trunk_height: float = scale * lerpf(2.7, 4.1, vegetation.x)
			var trunk_basis := Basis(Vector3.UP, rotation).scaled(Vector3(scale, trunk_height / 2.7, scale))
			trunk_transforms.append(Transform3D(trunk_basis, ground + Vector3.UP * trunk_height * 0.5))

			if species < BROADLEAF_THRESHOLD:
				var crown_width: float = scale * lerpf(0.9, 1.25, vegetation.x)
				broadleaf_lower.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(crown_width, scale * 0.9, crown_width * 0.92)),
					ground + Vector3.UP * (trunk_height + scale * 0.55)
				))
				broadleaf_upper.append(Transform3D(
					Basis(Vector3.UP, rotation + 0.45).scaled(Vector3(crown_width * 0.72, scale * 0.72, crown_width * 0.72)),
					ground + Vector3.UP * (trunk_height + scale * 1.55)
				))
			else:
				conifer_lower.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(scale * 1.15, scale * 1.25, scale * 1.15)),
					ground + Vector3.UP * (trunk_height + scale * 0.2)
				))
				conifer_upper.append(Transform3D(
					Basis(Vector3.UP, rotation + 0.2).scaled(Vector3(scale * 0.72, scale * 1.05, scale * 0.72)),
					ground + Vector3.UP * (trunk_height + scale * 1.75)
				))

			if vegetation.y > 0.54 and WorldSeed.sample_unit(WORLD_SEED + 797, cell_x, cell_z) < 0.42:
				var offset := Vector3(
					lerpf(-2.2, 2.2, WorldSeed.sample_unit(WORLD_SEED + 809, cell_x, cell_z)),
					0.0,
					lerpf(-2.2, 2.2, WorldSeed.sample_unit(WORLD_SEED + 821, cell_x, cell_z))
				)
				var sapling_scale: float = scale * 0.42
				saplings.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(sapling_scale, sapling_scale, sapling_scale)),
					ground + offset + Vector3.UP * 0.9
				))

	_tree_count = trunk_transforms.size()
	_add_tree_multimesh(_quality_trunk_mesh(), trunk_transforms)
	_add_tree_multimesh(_broadleaf_mesh(Color("356a43")), broadleaf_lower)
	_add_tree_multimesh(_broadleaf_mesh(Color("477d4d")), broadleaf_upper)
	_add_tree_multimesh(_conifer_mesh(Color("284f3d")), conifer_lower)
	_add_tree_multimesh(_conifer_mesh(Color("37674a")), conifer_upper)
	_add_tree_multimesh(_sapling_mesh(), saplings, false)
	print("WORLD_QA mixed_trees=", _tree_count, " saplings=", saplings.size())


func _build_ground_detail() -> void:
	var grass_transforms: Array[Transform3D] = []
	var shrub_transforms: Array[Transform3D] = []
	var world_rect: Rect2i = WorldWindowPlan.active_world_rect(
		_world_center, CHUNK_RADIUS, VoxelChunk.SIZE, 4
	)
	var camera_position: Vector3 = _camera_position()

	for grid_z: int in range(world_rect.position.y, world_rect.end.y, 3):
		for grid_x: int in range(world_rect.position.x, world_rect.end.x, 3):
			var cell_x: int = floori(float(grid_x) / 3.0)
			var cell_z: int = floori(float(grid_z) / 3.0)
			var world_x: int = grid_x + roundi((WorldSeed.sample_unit(WORLD_SEED + 953, cell_x, cell_z) - 0.5) * 2.0)
			var world_z: int = grid_z + roundi((WorldSeed.sample_unit(WORLD_SEED + 967, cell_x, cell_z) - 0.5) * 2.0)
			var distance: float = Vector2(float(world_x) - camera_position.x, float(world_z) - camera_position.z).length()
			if distance > 118.0:
				continue
			if TerrainGenerator.surface_material(WORLD_SEED, world_x, world_z) != TerrainGenerator.GRASS:
				continue
			if TerrainGenerator.surface_slope(WORLD_SEED, world_x, world_z) > 1:
				continue
			var vegetation: Vector3 = TerrainGenerator.vegetation_profile(WORLD_SEED, world_x, world_z)
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			var sample: float = WorldSeed.sample_unit(WORLD_SEED + 947, cell_x, cell_z)
			var ground := Vector3(float(world_x) + 0.5, float(height) + 1.02, float(world_z) + 0.5)
			var rotation: float = WorldSeed.sample_unit(WORLD_SEED + 991, cell_x, cell_z) * TAU
			if sample < 0.035 + vegetation.y * 0.20:
				var scale: float = lerpf(0.65, 1.35, WorldSeed.sample_unit(WORLD_SEED + 977, cell_x, cell_z))
				grass_transforms.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(scale, scale, scale)),
					ground + Vector3.UP * 0.22 * scale
				))
			if vegetation.x > 0.48 and sample > 0.90:
				var shrub_scale: float = lerpf(0.55, 1.05, vegetation.x)
				shrub_transforms.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(shrub_scale, shrub_scale * 0.7, shrub_scale)),
					ground + Vector3.UP * 0.34
				))

	_grass_count = grass_transforms.size()
	_add_tree_multimesh(_grass_clump_mesh(), grass_transforms, false)
	_add_tree_multimesh(_shrub_mesh(), shrub_transforms, false)
	print("WORLD_QA grass_clumps=", grass_transforms.size(), " shrubs=", shrub_transforms.size())


func _quality_trunk_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.34
	mesh.height = 2.7
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = _material(Color("5b4030"), 0.96)
	return mesh


func _broadleaf_mesh(color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.5
	mesh.height = 2.2
	mesh.radial_segments = 7
	mesh.rings = 4
	mesh.material = _material(color, 0.98)
	return mesh


func _conifer_mesh(color: Color) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 1.45
	mesh.height = 2.5
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.material = _material(color, 0.98)
	return mesh


func _sapling_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.62
	mesh.height = 1.8
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = _material(Color("3d7447"), 0.98)
	return mesh


func _grass_clump_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.16
	mesh.height = 0.48
	mesh.radial_segments = 5
	mesh.rings = 1
	mesh.material = _material(Color("376b31"), 1.0)
	return mesh


func _shrub_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.58
	mesh.height = 0.72
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _material(Color("2f6138"), 1.0)
	return mesh
