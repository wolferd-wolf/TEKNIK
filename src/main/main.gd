extends Node3D

const WorldSeed = preload("res://src/world/world_seed.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")

const WORLD_SEED: int = 73_421
const CHUNK_RADIUS: int = 3
const TREE_SPACING: int = 6

var _total_quads: int = 0
var _tree_count: int = 0


func _ready() -> void:
	_build_environment()
	_build_terrain()
	_build_water()
	_build_forest()

	var screenshot_path: String = _qa_screenshot_path()
	if not screenshot_path.is_empty():
		call_deferred("_capture_qa_screenshot", screenshot_path)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("3f7198")
	sky_material.sky_horizon_color = Color("b8d2d8")
	sky_material.ground_bottom_color = Color("273b3d")
	sky_material.ground_horizon_color = Color("9db3aa")
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08

	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.62
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color("b5cbd0")
	environment.fog_light_energy = 0.82
	environment.fog_density = 0.0038
	environment.fog_sky_affect = 0.62

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47.0, -38.0, 0.0)
	sun.light_color = Color("ffe1a6")
	sun.light_energy = 1.48
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 135.0
	add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(-52.0, 38.0, 66.0)
	camera.fov = 58.0
	camera.far = 280.0
	add_child(camera)
	camera.look_at(Vector3(22.0, 9.0, -18.0), Vector3.UP)


func _build_terrain() -> void:
	for chunk_z: int in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for chunk_x: int in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			var coordinate := Vector3i(chunk_x, 0, chunk_z)
			var chunk: TeknikVoxelChunk = TerrainGenerator.generate_chunk(WORLD_SEED, coordinate)
			var report: Dictionary = GreedyMesher.build_mesh(chunk)
			_total_quads += int(report.quads)

			var terrain := MeshInstance3D.new()
			terrain.mesh = report.mesh
			terrain.position = Vector3(
				chunk_x * VoxelChunk.SIZE,
				0.0,
				chunk_z * VoxelChunk.SIZE
			)
			terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(terrain)

	print("WORLD_QA chunks=", (CHUNK_RADIUS * 2 + 1) ** 2, " quads=", _total_quads)


func _build_water() -> void:
	var world_size: float = float((CHUNK_RADIUS * 2 + 1) * VoxelChunk.SIZE)
	var world_center: float = float(VoxelChunk.SIZE) * 0.5
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(world_size, world_size)
	water_mesh.subdivide_width = 24
	water_mesh.subdivide_depth = 24

	var water_material := StandardMaterial3D.new()
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.albedo_color = Color(0.12, 0.39, 0.52, 0.78)
	water_material.metallic = 0.18
	water_material.roughness = 0.2
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	water_material.emission_enabled = true
	water_material.emission = Color("123d4d")
	water_material.emission_energy_multiplier = 0.18
	water_mesh.material = water_material

	var water := MeshInstance3D.new()
	water.mesh = water_mesh
	water.position = Vector3(
		world_center,
		float(TerrainGenerator.WATER_LEVEL) + 0.62,
		world_center
	)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_forest() -> void:
	var trunk_transforms: Array[Transform3D] = []
	var lower_canopy_transforms: Array[Transform3D] = []
	var upper_canopy_transforms: Array[Transform3D] = []
	var world_min: int = -CHUNK_RADIUS * VoxelChunk.SIZE + 5
	var world_max: int = (CHUNK_RADIUS + 1) * VoxelChunk.SIZE - 5

	for grid_z: int in range(world_min, world_max, TREE_SPACING):
		for grid_x: int in range(world_min, world_max, TREE_SPACING):
			var cell_x: int = floori(float(grid_x) / float(TREE_SPACING))
			var cell_z: int = floori(float(grid_z) / float(TREE_SPACING))
			if WorldSeed.sample_unit(WORLD_SEED + 701, cell_x, cell_z) < 0.79:
				continue

			var jitter_x: float = (WorldSeed.sample_unit(WORLD_SEED + 719, cell_x, cell_z) - 0.5) * 4.0
			var jitter_z: float = (WorldSeed.sample_unit(WORLD_SEED + 733, cell_x, cell_z) - 0.5) * 4.0
			var world_x: int = roundi(float(grid_x) + jitter_x)
			var world_z: int = roundi(float(grid_z) + jitter_z)
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			if height <= TerrainGenerator.WATER_LEVEL + 2:
				continue
			if TerrainGenerator.river_distance(WORLD_SEED, world_x, world_z) < 15.0:
				continue
			if TerrainGenerator.surface_slope(WORLD_SEED, world_x, world_z) > 1:
				continue

			var scale: float = lerpf(
				0.78,
				1.28,
				WorldSeed.sample_unit(WORLD_SEED + 751, cell_x, cell_z)
			)
			var rotation: float = WorldSeed.sample_unit(WORLD_SEED + 769, cell_x, cell_z) * TAU
			var basis := Basis(Vector3.UP, rotation).scaled(Vector3.ONE * scale)
			var ground := Vector3(float(world_x) + 0.5, float(height) + 1.0, float(world_z) + 0.5)
			trunk_transforms.append(Transform3D(basis, ground + Vector3.UP * 1.35 * scale))
			lower_canopy_transforms.append(Transform3D(basis, ground + Vector3.UP * 3.25 * scale))
			upper_canopy_transforms.append(Transform3D(basis, ground + Vector3.UP * 4.65 * scale))

	_tree_count = trunk_transforms.size()
	_add_tree_multimesh(_trunk_mesh(), trunk_transforms)
	_add_tree_multimesh(_lower_canopy_mesh(), lower_canopy_transforms)
	_add_tree_multimesh(_upper_canopy_mesh(), upper_canopy_transforms)
	print("WORLD_QA trees=", _tree_count)


func _add_tree_multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)


func _trunk_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.62, 2.7, 0.62)
	mesh.material = _material(Color("614632"), 0.92)
	return mesh


func _lower_canopy_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 1.55
	mesh.height = 2.8
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.material = _material(Color("355f47"), 0.96)
	return mesh


func _upper_canopy_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 1.12
	mesh.height = 2.35
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.material = _material(Color("47775a"), 0.96)
	return mesh


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _qa_screenshot_path() -> String:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(arguments.size()):
		var argument: String = arguments[index]
		if argument.begins_with("--qa-screenshot="):
			return argument.trim_prefix("--qa-screenshot=")
		if argument == "--qa-screenshot" and index + 1 < arguments.size():
			return arguments[index + 1]
	return ""


func _capture_qa_screenshot(path: String) -> void:
	for frame: int in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var absolute_path: String = path if path.is_absolute_path() else ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var image: Image = get_viewport().get_texture().get_image()
	var result: Error = image.save_png(absolute_path)
	if result == OK:
		print("QA_SCREENSHOT_SAVED ", absolute_path)
		get_tree().quit(0)
	else:
		push_error("Failed to save QA screenshot: %s" % error_string(result))
		get_tree().quit(1)
