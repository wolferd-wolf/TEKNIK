extends SceneTree

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")

const OUTPUT_PATH := "res://build/screenshots/terrain-texture-preview.png"


func _init() -> void:
	call_deferred("_capture_preview")


func _capture_preview() -> void:
	var world := Node3D.new()
	world.name = "TerrainTexturePreview"
	root.add_child(world)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.30, 0.48, 0.70)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.86)
	environment.ambient_light_energy = 0.85
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	world.add_child(sun)

	var chunk := VoxelChunk.new()
	for z: int in range(16):
		for x: int in range(16):
			var height: int = 3 + int(round(1.4 * sin(float(x) * 0.45) + 1.1 * cos(float(z) * 0.38)))
			for y: int in range(height + 1):
				var material: int = TerrainGenerator.STONE
				if y == height:
					material = TerrainGenerator.GRASS
				elif y >= height - 2:
					material = TerrainGenerator.SOIL
				chunk.set_voxel(Vector3i(x, y, z), material)

	# Expose clean stone and dirt faces near the camera for visual comparison.
	for y: int in range(1, 5):
		for z: int in range(2, 6):
			chunk.set_voxel(Vector3i(1, y, z), TerrainGenerator.STONE)
	for y: int in range(1, 4):
		for x: int in range(4, 9):
			chunk.set_voxel(Vector3i(x, y, 1), TerrainGenerator.SOIL)

	var arrays_report: Dictionary = GreedyMesher.build_arrays(chunk)
	var terrain_mesh: ArrayMesh = GreedyMesher.mesh_from_arrays(arrays_report.arrays)
	var terrain := MeshInstance3D.new()
	terrain.mesh = terrain_mesh
	world.add_child(terrain)

	var camera := Camera3D.new()
	camera.position = Vector3(21.0, 15.0, 23.0)
	camera.fov = 58.0
	camera.look_at(Vector3(7.5, 2.8, 7.5), Vector3.UP)
	camera.current = true
	world.add_child(camera)

	for _frame: int in range(180):
		await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/screenshots"))
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("TERRAIN_SCREENSHOT_FAIL empty viewport image")
		quit(1)
		return
	var error: Error = image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("TERRAIN_SCREENSHOT_FAIL save_png error=%d" % error)
		quit(1)
		return
	print("TERRAIN_SCREENSHOT_PASS path=%s size=%dx%d" % [OUTPUT_PATH, image.get_width(), image.get_height()])
	quit(0)
