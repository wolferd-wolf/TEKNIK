extends Node3D

const WorldSeed = preload("res://src/world/world_seed.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")
const ChunkStreamPlan = preload("res://src/world/chunk_stream_plan.gd")

const WORLD_SEED: int = 73_421
const CHUNK_RADIUS: int = 3
const TREE_SPACING: int = 6

var _total_quads: int = 0
var _tree_count: int = 0
var _boulder_count: int = 0
var _grass_count: int = 0
var _cloud_count: int = 0
var _render_instance_count: int = 0
var _world_sample_cache: Dictionary = {}
var _world_column_cache: Dictionary = {}


func _ready() -> void:
	var build_started_ms: int = Time.get_ticks_msec()
	_build_environment()
	_build_terrain_ordered()
	_build_water()
	_build_forest()
	_build_boulders()
	_build_ground_detail()
	_build_clouds()
	print(
		"WORLD_QA build_ms=", Time.get_ticks_msec() - build_started_ms,
		" render_instances=", _render_instance_count,
		" grass=", _grass_count,
		" clouds=", _cloud_count
	)

	var screenshot_path: String = _qa_screenshot_path()
	if not screenshot_path.is_empty():
		call_deferred("_capture_qa_screenshot", screenshot_path)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("356689")
	sky_material.sky_horizon_color = Color("8faeb8")
	sky_material.ground_bottom_color = Color("273b3d")
	sky_material.ground_horizon_color = Color("9db3aa")
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08

	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4cfc3")
	environment.ambient_light_energy = 0.28
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color("9fb7bc")
	environment.fog_light_energy = 0.36
	environment.fog_density = 0.0011
	environment.fog_sky_affect = 0.38

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47.0, -38.0, 0.0)
	sun.light_color = Color("ffe1a6")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.shadow_blur = 1.35
	sun.directional_shadow_max_distance = 135.0
	add_child(sun)

	var camera := Camera3D.new()
	camera.position = _camera_position()
	camera.fov = 50.0
	camera.far = 280.0
	add_child(camera)
	camera.look_at(Vector3(
		38.0,
		float(TerrainGenerator.WATER_LEVEL) + 4.0,
		TerrainGenerator.river_center_z(WORLD_SEED, 38)
	), Vector3.UP)


func _build_terrain_ordered() -> void:
	var camera_position: Vector3 = _camera_position()
	var priority_coordinate := Vector3i(
		floori(camera_position.x / float(VoxelChunk.SIZE)),
		0,
		floori(camera_position.z / float(VoxelChunk.SIZE))
	)
	var coordinates: Array[Vector3i] = ChunkStreamPlan.ordered_square(
		Vector3i.ZERO, CHUNK_RADIUS, priority_coordinate
	)
	for coordinate: Vector3i in coordinates:
		var chunk: TeknikVoxelChunk = TerrainGenerator.generate_chunk(WORLD_SEED, coordinate)
		var report: Dictionary = GreedyMesher.build_mesh(
			chunk,
			coordinate * VoxelChunk.SIZE,
			Callable(self, "_sample_world_voxel")
		)
		_total_quads += int(report.quads)

		var terrain := MeshInstance3D.new()
		terrain.mesh = report.mesh
		terrain.position = Vector3(
			coordinate.x * VoxelChunk.SIZE,
			0.0,
			coordinate.z * VoxelChunk.SIZE
		)
		terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(terrain)
		_render_instance_count += 1

	_world_sample_cache.clear()
	_world_column_cache.clear()
	print(
		"WORLD_QA chunks=", coordinates.size(),
		" quads=", _total_quads
	)


func _build_water() -> void:
	var world_min: int = -CHUNK_RADIUS * VoxelChunk.SIZE
	var world_max: int = (CHUNK_RADIUS + 1) * VoxelChunk.SIZE
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var half_width: float = 5.35
	var segment_index: int = 0
	for world_x: int in range(world_min, world_max + 1, 2):
		var center_z: float = TerrainGenerator.river_center_z(WORLD_SEED, world_x)
		vertices.append(Vector3(
			float(world_x),
			float(TerrainGenerator.WATER_LEVEL) + 0.58,
			center_z - half_width
		))
		vertices.append(Vector3(
			float(world_x),
			float(TerrainGenerator.WATER_LEVEL) + 0.58,
			center_z + half_width
		))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		if segment_index > 0:
			var previous: int = (segment_index - 1) * 2
			var current: int = segment_index * 2
			indices.append_array(PackedInt32Array([
				previous, current, current + 1,
				previous, current + 1, previous + 1,
			]))
		segment_index += 1

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var water_mesh := ArrayMesh.new()
	water_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var water_material := StandardMaterial3D.new()
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.albedo_color = Color(0.055, 0.29, 0.4, 0.82)
	water_material.metallic = 0.18
	water_material.roughness = 0.2
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	water_material.emission_enabled = true
	water_material.emission = Color("123d4d")
	water_material.emission_energy_multiplier = 0.08
	water_mesh.surface_set_material(0, water_material)

	var water := MeshInstance3D.new()
	water.mesh = water_mesh
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_render_instance_count += 1


func _build_forest() -> void:
	var trunk_transforms: Array[Transform3D] = []
	var lower_canopy_transforms: Array[Transform3D] = []
	var world_min: int = -CHUNK_RADIUS * VoxelChunk.SIZE + 5
	var world_max: int = (CHUNK_RADIUS + 1) * VoxelChunk.SIZE - 5

	for grid_z: int in range(world_min, world_max, TREE_SPACING):
		for grid_x: int in range(world_min, world_max, TREE_SPACING):
			var cell_x: int = floori(float(grid_x) / float(TREE_SPACING))
			var cell_z: int = floori(float(grid_z) / float(TREE_SPACING))
			if WorldSeed.sample_unit(WORLD_SEED + 701, cell_x, cell_z) < 0.88:
				continue

			var jitter_x: float = (WorldSeed.sample_unit(WORLD_SEED + 719, cell_x, cell_z) - 0.5) * 4.0
			var jitter_z: float = (WorldSeed.sample_unit(WORLD_SEED + 733, cell_x, cell_z) - 0.5) * 4.0
			var world_x: int = roundi(float(grid_x) + jitter_x)
			var world_z: int = roundi(float(grid_z) + jitter_z)
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			if height <= TerrainGenerator.WATER_LEVEL + 2:
				continue
			if TerrainGenerator.river_distance(WORLD_SEED, world_x, world_z) < 12.0:
				continue
			if TerrainGenerator.surface_slope(WORLD_SEED, world_x, world_z) > 1:
				continue
			var camera_position: Vector3 = _camera_position()
			if Vector2(
				float(world_x) - camera_position.x,
				float(world_z) - camera_position.z
			).length() < 18.0:
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
			lower_canopy_transforms.append(Transform3D(basis, ground + Vector3.UP * 3.7 * scale))

	_tree_count = trunk_transforms.size()
	_add_tree_multimesh(_trunk_mesh(), trunk_transforms)
	_add_tree_multimesh(_lower_canopy_mesh(), lower_canopy_transforms)
	print("WORLD_QA trees=", _tree_count)


func _build_boulders() -> void:
	var transforms: Array[Transform3D] = []
	var world_min: int = -CHUNK_RADIUS * VoxelChunk.SIZE + 6
	var world_max: int = (CHUNK_RADIUS + 1) * VoxelChunk.SIZE - 6
	var camera_position: Vector3 = _camera_position()

	for grid_z: int in range(world_min, world_max, 10):
		for grid_x: int in range(world_min, world_max, 10):
			var cell_x: int = floori(float(grid_x) / 10.0)
			var cell_z: int = floori(float(grid_z) / 10.0)
			if WorldSeed.sample_unit(WORLD_SEED + 811, cell_x, cell_z) < 0.84:
				continue
			var world_x: int = grid_x + roundi((WorldSeed.sample_unit(WORLD_SEED + 823, cell_x, cell_z) - 0.5) * 6.0)
			var world_z: int = grid_z + roundi((WorldSeed.sample_unit(WORLD_SEED + 839, cell_x, cell_z) - 0.5) * 6.0)
			if TerrainGenerator.river_distance(WORLD_SEED, world_x, world_z) < 8.0:
				continue
			if Vector2(
				float(world_x) - camera_position.x,
				float(world_z) - camera_position.z
			).length() < 8.0:
				continue
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			var width: float = lerpf(0.65, 1.55, WorldSeed.sample_unit(WORLD_SEED + 853, cell_x, cell_z))
			var depth: float = lerpf(0.7, 1.4, WorldSeed.sample_unit(WORLD_SEED + 877, cell_x, cell_z))
			var rise: float = lerpf(0.45, 1.1, WorldSeed.sample_unit(WORLD_SEED + 881, cell_x, cell_z))
			var rotation: float = WorldSeed.sample_unit(WORLD_SEED + 907, cell_x, cell_z) * TAU
			var basis := Basis(Vector3.UP, rotation).scaled(Vector3(width, rise, depth))
			transforms.append(Transform3D(
				basis,
				Vector3(float(world_x) + 0.5, float(height) + 1.0 + rise * 0.42, float(world_z) + 0.5)
			))

	_boulder_count = transforms.size()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = _material(Color("697471"), 0.98)
	_add_tree_multimesh(mesh, transforms)
	print("WORLD_QA boulders=", _boulder_count)


func _build_ground_detail() -> void:
	var transforms: Array[Transform3D] = []
	var world_min: int = -CHUNK_RADIUS * VoxelChunk.SIZE + 4
	var world_max: int = (CHUNK_RADIUS + 1) * VoxelChunk.SIZE - 4
	var camera_position: Vector3 = _camera_position()

	for grid_z: int in range(world_min, world_max, 3):
		for grid_x: int in range(world_min, world_max, 3):
			var cell_x: int = floori(float(grid_x) / 3.0)
			var cell_z: int = floori(float(grid_z) / 3.0)
			if WorldSeed.sample_unit(WORLD_SEED + 947, cell_x, cell_z) < 0.91:
				continue
			var world_x: int = grid_x + roundi((WorldSeed.sample_unit(WORLD_SEED + 953, cell_x, cell_z) - 0.5) * 2.0)
			var world_z: int = grid_z + roundi((WorldSeed.sample_unit(WORLD_SEED + 967, cell_x, cell_z) - 0.5) * 2.0)
			if Vector2(
				float(world_x) - camera_position.x,
				float(world_z) - camera_position.z
			).length() > 112.0:
				continue
			if TerrainGenerator.surface_material(WORLD_SEED, world_x, world_z) != TerrainGenerator.GRASS:
				continue
			if TerrainGenerator.surface_slope(WORLD_SEED, world_x, world_z) > 1:
				continue
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			var scale: float = lerpf(0.65, 1.2, WorldSeed.sample_unit(WORLD_SEED + 977, cell_x, cell_z))
			var rotation: float = WorldSeed.sample_unit(WORLD_SEED + 991, cell_x, cell_z) * TAU
			var basis := Basis(Vector3.UP, rotation).scaled(Vector3(scale, scale, scale))
			transforms.append(Transform3D(
				basis,
				Vector3(float(world_x) + 0.5, float(height) + 1.0 + 0.3 * scale, float(world_z) + 0.5)
			))

	_grass_count = transforms.size()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.018
	mesh.bottom_radius = 0.13
	mesh.height = 0.34
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.material = _material(Color("315f2d"), 0.98)
	_add_tree_multimesh(mesh, transforms, false)


func _build_clouds() -> void:
	var transforms: Array[Transform3D] = []
	for cloud_index: int in range(12):
		var world_x: float = lerpf(
			-105.0, 135.0,
			WorldSeed.sample_unit(WORLD_SEED + 1013, cloud_index, 0)
		)
		var world_z: float = lerpf(
			-105.0, 105.0,
			WorldSeed.sample_unit(WORLD_SEED + 1021, cloud_index, 0)
		)
		var height: float = lerpf(
			43.0, 57.0,
			WorldSeed.sample_unit(WORLD_SEED + 1031, cloud_index, 0)
		)
		var width: float = lerpf(7.0, 13.5, WorldSeed.sample_unit(WORLD_SEED + 1039, cloud_index, 0))
		var depth: float = lerpf(4.0, 7.0, WorldSeed.sample_unit(WORLD_SEED + 1051, cloud_index, 0))
		var thickness: float = lerpf(1.65, 2.8, WorldSeed.sample_unit(WORLD_SEED + 1061, cloud_index, 0))
		var rotation: float = WorldSeed.sample_unit(WORLD_SEED + 1069, cloud_index, 0) * TAU
		var basis := Basis(Vector3.UP, rotation).scaled(Vector3(width, thickness, depth))
		transforms.append(Transform3D(basis, Vector3(world_x, height, world_z)))

	_cloud_count = transforms.size()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.4
	mesh.radial_segments = 8
	mesh.rings = 4
	var cloud_material := StandardMaterial3D.new()
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.albedo_color = Color(0.88, 0.93, 0.95, 0.82)
	cloud_material.roughness = 1.0
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = cloud_material
	_add_tree_multimesh(mesh, transforms, false)


func _add_tree_multimesh(
	mesh: Mesh,
	transforms: Array[Transform3D],
	cast_shadows: bool = true
) -> void:
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
	if cast_shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_render_instance_count += 1


func _sample_world_voxel(world_position: Vector3i) -> int:
	if _world_sample_cache.has(world_position):
		return int(_world_sample_cache[world_position])
	if world_position.y < 0:
		return TerrainGenerator.STONE
	var column_key := Vector2i(world_position.x, world_position.z)
	if not _world_column_cache.has(column_key):
		_world_column_cache[column_key] = TerrainGenerator.sample_column(
			WORLD_SEED, world_position.x, world_position.z
		)
	var column: Vector2i = _world_column_cache[column_key]
	var material: int = TerrainGenerator.material_from_column(world_position.y, column)
	_world_sample_cache[world_position] = material
	return material


func _camera_position() -> Vector3:
	var world_x: int = -70
	var world_z: int = roundi(TerrainGenerator.river_center_z(WORLD_SEED, world_x) + 16.0)
	var ground_height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
	return Vector3(float(world_x), float(ground_height) + 7.5, float(world_z))


func _trunk_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.62, 2.7, 0.62)
	mesh.material = _material(Color("614632"), 0.92)
	return mesh


func _lower_canopy_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.55
	mesh.height = 3.25
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _material(Color("396b47"), 0.96)
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
