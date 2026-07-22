extends "res://src/main/budgeted_main.gd"

const BROADLEAF_THRESHOLD: float = 0.58


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("294b66")
	sky_material.sky_horizon_color = Color("a8bcc2")
	sky_material.ground_bottom_color = Color("263735")
	sky_material.ground_horizon_color = Color("8f9f96")
	sky_material.sun_angle_max = 11.0
	sky_material.sun_curve = 0.045

	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6cdc4")
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color("b6c4c4")
	environment.fog_light_energy = 0.46
	environment.fog_density = 0.0030
	environment.fog_sky_affect = 0.52

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42.0, -31.0, 0.0)
	sun.light_color = Color("ffdda6")
	sun.light_energy = 0.96
	sun.shadow_enabled = true
	sun.shadow_blur = 0.72
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(38.0, 142.0, 0.0)
	fill.light_color = Color("9fb7c8")
	fill.light_energy = 0.14
	fill.shadow_enabled = false
	add_child(fill)

	var camera := Camera3D.new()
	camera.name = "WorldPreviewCamera"
	camera.position = _camera_position()
	camera.fov = 52.0
	camera.far = 280.0
	add_child(camera)
	camera.look_at(_camera_target(), Vector3.UP)


func _build_forest() -> void:
	var trunk_transforms: Array[Transform3D] = []
	var broadleaf_lower: Array[Transform3D] = []
	var broadleaf_upper: Array[Transform3D] = []
	var broadleaf_side: Array[Transform3D] = []
	var conifer_lower: Array[Transform3D] = []
	var conifer_middle: Array[Transform3D] = []
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
			var trunk_height: float = scale * lerpf(2.9, 4.25, vegetation.x)
			var trunk_basis := Basis(Vector3.UP, rotation).scaled(Vector3(scale, trunk_height / 2.7, scale))
			trunk_transforms.append(Transform3D(trunk_basis, ground + Vector3.UP * trunk_height * 0.5))

			if species < BROADLEAF_THRESHOLD:
				var crown_width: float = scale * lerpf(0.95, 1.28, vegetation.x)
				var side_direction: Vector3 = Basis(Vector3.UP, rotation) * Vector3.RIGHT
				broadleaf_lower.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(crown_width, scale * 0.86, crown_width * 0.94)),
					ground + Vector3.UP * (trunk_height + scale * 0.46)
				))
				broadleaf_upper.append(Transform3D(
					Basis(Vector3.UP, rotation + 0.45).scaled(Vector3(crown_width * 0.73, scale * 0.70, crown_width * 0.73)),
					ground + Vector3.UP * (trunk_height + scale * 1.48)
				))
				broadleaf_side.append(Transform3D(
					Basis(Vector3.UP, rotation - 0.31).scaled(Vector3(crown_width * 0.56, scale * 0.56, crown_width * 0.62)),
					ground + side_direction * (scale * 0.72) + Vector3.UP * (trunk_height + scale * 0.78)
				))
			else:
				conifer_lower.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(scale * 1.22, scale * 1.08, scale * 1.22)),
					ground + Vector3.UP * (trunk_height + scale * 0.02)
				))
				conifer_middle.append(Transform3D(
					Basis(Vector3.UP, rotation + 0.17).scaled(Vector3(scale * 0.93, scale * 1.0, scale * 0.93)),
					ground + Vector3.UP * (trunk_height + scale * 1.22)
				))
				conifer_upper.append(Transform3D(
					Basis(Vector3.UP, rotation + 0.31).scaled(Vector3(scale * 0.61, scale * 0.88, scale * 0.61)),
					ground + Vector3.UP * (trunk_height + scale * 2.22)
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
	_add_tree_multimesh(_broadleaf_mesh(Color("315f3e")), broadleaf_lower)
	_add_tree_multimesh(_broadleaf_mesh(Color("477a4b")), broadleaf_upper)
	_add_tree_multimesh(_broadleaf_mesh(Color("3b7044")), broadleaf_side)
	_add_tree_multimesh(_conifer_mesh(Color("234839")), conifer_lower)
	_add_tree_multimesh(_conifer_mesh(Color("2d5941")), conifer_middle)
	_add_tree_multimesh(_conifer_mesh(Color("39694a")), conifer_upper)
	_add_tree_multimesh(_sapling_mesh(), saplings, false)
	print("WORLD_QA mixed_trees=", _tree_count, " saplings=", saplings.size())


func _build_boulders() -> void:
	var cool_rocks: Array[Transform3D] = []
	var warm_rocks: Array[Transform3D] = []
	var world_rect: Rect2i = WorldWindowPlan.active_world_rect(
		_world_center, CHUNK_RADIUS, VoxelChunk.SIZE, 6
	)
	var camera_position: Vector3 = _camera_position()

	for grid_z: int in range(world_rect.position.y, world_rect.end.y, 9):
		for grid_x: int in range(world_rect.position.x, world_rect.end.x, 9):
			var cell_x: int = floori(float(grid_x) / 9.0)
			var cell_z: int = floori(float(grid_z) / 9.0)
			var world_x: int = grid_x + roundi((WorldSeed.sample_unit(WORLD_SEED + 823, cell_x, cell_z) - 0.5) * 6.0)
			var world_z: int = grid_z + roundi((WorldSeed.sample_unit(WORLD_SEED + 839, cell_x, cell_z) - 0.5) * 6.0)
			var vegetation: Vector3 = TerrainGenerator.vegetation_profile(WORLD_SEED, world_x, world_z)
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			var elevation: float = clampf(
				(float(height) - 10.0) / float(TerrainGenerator.MAX_SURFACE_HEIGHT - 10),
				0.0,
				1.0
			)
			var boulder_chance: float = 0.045 + vegetation.z * 0.12 + elevation * 0.09
			if WorldSeed.sample_unit(WORLD_SEED + 811, cell_x, cell_z) > boulder_chance:
				continue
			if TerrainGenerator.river_distance(WORLD_SEED, world_x, world_z) < 7.5:
				continue
			if Vector2(float(world_x) - camera_position.x, float(world_z) - camera_position.z).length() < 8.0:
				continue
			var width: float = lerpf(0.56, 1.42, WorldSeed.sample_unit(WORLD_SEED + 853, cell_x, cell_z))
			var depth: float = lerpf(0.62, 1.32, WorldSeed.sample_unit(WORLD_SEED + 877, cell_x, cell_z))
			var rise: float = lerpf(0.42, 1.04, WorldSeed.sample_unit(WORLD_SEED + 881, cell_x, cell_z))
			var rotation: float = WorldSeed.sample_unit(WORLD_SEED + 907, cell_x, cell_z) * TAU
			var tilt: float = lerpf(-0.20, 0.20, WorldSeed.sample_unit(WORLD_SEED + 919, cell_x, cell_z))
			var basis := Basis(Vector3.UP, rotation)
			basis = basis.rotated(Vector3.RIGHT, tilt)
			basis = basis.scaled(Vector3(width, rise, depth))
			var transform := Transform3D(
				basis,
				Vector3(float(world_x) + 0.5, float(height) + 1.0 + rise * 0.34, float(world_z) + 0.5)
			)
			if WorldSeed.sample_unit(WORLD_SEED + 929, cell_x, cell_z) < 0.48:
				cool_rocks.append(transform)
			else:
				warm_rocks.append(transform)

	_boulder_count = cool_rocks.size() + warm_rocks.size()
	_add_tree_multimesh(_quality_rock_mesh(Color("667471")), cool_rocks)
	_add_tree_multimesh(_quality_rock_mesh(Color("756f63")), warm_rocks)
	print("WORLD_QA boulders=", _boulder_count)


func _build_ground_detail() -> void:
	var lush_grass: Array[Transform3D] = []
	var dry_grass: Array[Transform3D] = []
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
			var climate: Vector2 = TerrainGenerator.climate_at(WORLD_SEED, world_x, world_z)
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			var sample: float = WorldSeed.sample_unit(WORLD_SEED + 947, cell_x, cell_z)
			var ground := Vector3(float(world_x) + 0.5, float(height) + 1.02, float(world_z) + 0.5)
			var rotation: float = WorldSeed.sample_unit(WORLD_SEED + 991, cell_x, cell_z) * TAU
			if sample < 0.04 + vegetation.y * 0.22:
				var scale: float = lerpf(0.62, 1.28, WorldSeed.sample_unit(WORLD_SEED + 977, cell_x, cell_z))
				var transform := Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(scale, scale, scale)),
					ground + Vector3.UP * 0.22 * scale
				)
				if climate.x > 0.47:
					lush_grass.append(transform)
				else:
					dry_grass.append(transform)
			if vegetation.x > 0.48 and sample > 0.90:
				var shrub_scale: float = lerpf(0.55, 1.05, vegetation.x)
				shrub_transforms.append(Transform3D(
					Basis(Vector3.UP, rotation).scaled(Vector3(shrub_scale, shrub_scale * 0.7, shrub_scale)),
					ground + Vector3.UP * 0.34
				))

	_grass_count = lush_grass.size() + dry_grass.size()
	_add_tree_multimesh(_grass_clump_mesh(Color("315f31")), lush_grass, false)
	_add_tree_multimesh(_grass_clump_mesh(Color("67633a")), dry_grass, false)
	_add_tree_multimesh(_shrub_mesh(), shrub_transforms, false)
	print("WORLD_QA grass_clumps=", _grass_count, " shrubs=", shrub_transforms.size())


func _build_clouds() -> void:
	var core_transforms: Array[Transform3D] = []
	var shoulder_transforms: Array[Transform3D] = []
	var wisp_transforms: Array[Transform3D] = []
	for cloud_index: int in range(14):
		var world_x: float = lerpf(
			-118.0, 148.0,
			WorldSeed.sample_unit(WORLD_SEED + 1013, cloud_index, 0)
		)
		var world_z: float = lerpf(
			-116.0, 116.0,
			WorldSeed.sample_unit(WORLD_SEED + 1021, cloud_index, 0)
		)
		var height: float = lerpf(
			45.0, 60.0,
			WorldSeed.sample_unit(WORLD_SEED + 1031, cloud_index, 0)
		)
		var width: float = lerpf(7.5, 14.5, WorldSeed.sample_unit(WORLD_SEED + 1039, cloud_index, 0))
		var depth: float = lerpf(3.8, 7.2, WorldSeed.sample_unit(WORLD_SEED + 1051, cloud_index, 0))
		var thickness: float = lerpf(1.45, 2.65, WorldSeed.sample_unit(WORLD_SEED + 1061, cloud_index, 0))
		var rotation: float = WorldSeed.sample_unit(WORLD_SEED + 1069, cloud_index, 0) * TAU
		var center := Vector3(world_x, height, world_z)
		var horizontal: Vector3 = Basis(Vector3.UP, rotation) * Vector3.RIGHT
		core_transforms.append(Transform3D(
			Basis(Vector3.UP, rotation).scaled(Vector3(width * 0.56, thickness, depth * 0.70)),
			center
		))
		shoulder_transforms.append(Transform3D(
			Basis(Vector3.UP, rotation + 0.08).scaled(Vector3(width * 0.40, thickness * 0.74, depth * 0.88)),
			center + horizontal * (width * 0.34) + Vector3.UP * (thickness * 0.18)
		))
		wisp_transforms.append(Transform3D(
			Basis(Vector3.UP, rotation - 0.12).scaled(Vector3(width * 0.32, thickness * 0.58, depth * 0.58)),
			center - horizontal * (width * 0.38) - Vector3.UP * (thickness * 0.08)
		))

	_cloud_count = core_transforms.size()
	var cloud_mesh := _cloud_mesh()
	_add_tree_multimesh(cloud_mesh, core_transforms, false, false)
	_add_tree_multimesh(cloud_mesh, shoulder_transforms, false, false)
	_add_tree_multimesh(cloud_mesh, wisp_transforms, false, false)


func _quality_trunk_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.21
	mesh.bottom_radius = 0.36
	mesh.height = 2.7
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.material = _material(Color("554033"), 0.98)
	return mesh


func _broadleaf_mesh(color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.5
	mesh.height = 2.2
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _material(color, 0.99)
	return mesh


func _conifer_mesh(color: Color) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = 1.45
	mesh.height = 2.45
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = _material(color, 0.99)
	return mesh


func _sapling_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = 0.62
	mesh.height = 1.8
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.material = _material(Color("3a7046"), 0.99)
	return mesh


func _quality_rock_mesh(color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.72
	mesh.height = 1.05
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _material(color, 1.0)
	return mesh


func _grass_clump_mesh(color: Color) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.018
	mesh.bottom_radius = 0.15
	mesh.height = 0.48
	mesh.radial_segments = 5
	mesh.rings = 1
	mesh.material = _material(color, 1.0)
	return mesh


func _shrub_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.58
	mesh.height = 0.72
	mesh.radial_segments = 7
	mesh.rings = 3
	mesh.material = _material(Color("2c5d38"), 1.0)
	return mesh


func _cloud_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.28
	mesh.radial_segments = 9
	mesh.rings = 4
	var cloud_material := StandardMaterial3D.new()
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.albedo_color = Color(0.90, 0.94, 0.96, 0.78)
	cloud_material.roughness = 1.0
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = cloud_material
	return mesh
