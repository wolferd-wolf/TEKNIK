extends SceneTree

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")

const OUTPUT_PATH := "res://build/screenshots/terrain-texture-preview.png"
const CAPTURE_SIZE := Vector2i(1280, 720)


func _init() -> void:
	call_deferred("_capture_preview")


func _capture_preview() -> void:
	# Render into an explicit off-screen viewport. Capturing the desktop/root window
	# previously returned an Xvfb clear frame even when the game scene was running.
	var viewport := SubViewport.new()
	viewport.name = "TerrainTextureCaptureViewport"
	viewport.size = CAPTURE_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var world := Node3D.new()
	world.name = "TerrainTexturePreview"
	viewport.add_child(world)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.30, 0.48, 0.70)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.82, 0.88)
	environment.ambient_light_energy = 0.82
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -34.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.87)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	world.add_child(sun)

	var chunk := VoxelChunk.new()
	for z: int in range(16):
		for x: int in range(16):
			var height: int = 4 + int(round(1.25 * sin(float(x) * 0.48) + 1.0 * cos(float(z) * 0.41)))
			for y: int in range(height + 1):
				var material: int = TerrainGenerator.STONE
				if y == height:
					material = TerrainGenerator.GRASS
				elif y >= height - 2:
					material = TerrainGenerator.SOIL
				chunk.set_voxel(Vector3i(x, y, z), material)

	# A deliberate cutaway exposes grass side, dirt and stone in the same frame.
	for z: int in range(2, 8):
		for y: int in range(2, 7):
			chunk.set_voxel(Vector3i(1, y, z), TerrainGenerator.STONE)
	for x: int in range(4, 11):
		for y: int in range(2, 5):
			chunk.set_voxel(Vector3i(x, y, 1), TerrainGenerator.SOIL)
	for z: int in range(10, 14):
		for x: int in range(10, 14):
			chunk.set_voxel(Vector3i(x, 5, z), TerrainGenerator.SAND)

	var arrays_report: Dictionary = GreedyMesher.build_arrays(chunk)
	var terrain_mesh: ArrayMesh = GreedyMesher.mesh_from_arrays(arrays_report.arrays)
	if terrain_mesh == null or terrain_mesh.get_surface_count() == 0:
		push_error("TERRAIN_SCREENSHOT_FAIL terrain mesh is empty")
		quit(1)
		return
	var terrain := MeshInstance3D.new()
	terrain.mesh = terrain_mesh
	world.add_child(terrain)

	var camera := Camera3D.new()
	camera.position = Vector3(22.0, 16.5, 24.0)
	camera.fov = 56.0
	world.add_child(camera)
	camera.look_at(Vector3(7.5, 3.1, 7.5), Vector3.UP)
	camera.current = true

	# Wait for texture imports, shader compilation, mesh upload and two completed draws.
	for _frame: int in range(45):
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	RenderingServer.force_draw()
	await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/screenshots"))
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != CAPTURE_SIZE:
		push_error("TERRAIN_SCREENSHOT_FAIL invalid viewport image")
		quit(1)
		return

	var first := image.get_pixel(0, 0)
	var varied := false
	for y: int in range(0, image.get_height(), 48):
		for x: int in range(0, image.get_width(), 48):
			var sample := image.get_pixel(x, y)
			if Vector3(sample.r, sample.g, sample.b).distance_to(Vector3(first.r, first.g, first.b)) > 0.08:
				varied = true
				break
		if varied:
			break
	if not varied:
		push_error("TERRAIN_SCREENSHOT_FAIL viewport is uniform/blank")
		quit(1)
		return

	var error: Error = image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("TERRAIN_SCREENSHOT_FAIL save_png error=%d" % error)
		quit(1)
		return
	print("TERRAIN_SCREENSHOT_PASS path=%s size=%dx%d mesh_surfaces=%d" % [
		OUTPUT_PATH,
		image.get_width(),
		image.get_height(),
		terrain_mesh.get_surface_count(),
	])
	quit(0)
