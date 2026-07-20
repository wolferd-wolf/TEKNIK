extends Node3D

const WorldSeed = preload("res://src/world/world_seed.gd")
const KineticNetwork = preload("res://src/simulation/kinetic_network.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")
const PREVIEW_SEED: int = 73_421

var _gear_roots: Array[Node3D] = []
var _fps_label: Label
var _fps_elapsed: float = 0.0
var _kinetic_report: Dictionary
var _voxel_report: Dictionary
var _qa_capture_mode: bool = false


func _ready() -> void:
	_build_environment()
	_build_preview_terrain()
	_build_mechanical_fixture()
	_build_hud()

	var screenshot_path: String = _qa_screenshot_path()
	if not screenshot_path.is_empty():
		_qa_capture_mode = true
		_fps_label.text = "CI SOFTWARE RENDER   |   PERFORMANCE NOT MEASURED"
		call_deferred("_capture_qa_screenshot", screenshot_path)


func _process(delta: float) -> void:
	if _gear_roots.size() >= 3:
		_gear_roots[0].rotate_y(delta * 0.62)
		_gear_roots[1].rotate_y(-delta * 0.93)
		_gear_roots[2].rotate_y(delta * 0.46)

	_fps_elapsed += delta
	if not _qa_capture_mode and _fps_elapsed >= 0.25 and is_instance_valid(_fps_label):
		_fps_elapsed = 0.0
		_fps_label.text = "RENDER  %3d FPS   |   PHYSICS  30 Hz" % Engine.get_frames_per_second()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07111d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("86a9c2")
	environment.ambient_light_energy = 0.52
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54.0, -31.0, 0.0)
	sun.light_color = Color("ffe0a3")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(18.0, 18.0, 23.0)
	camera.fov = 52.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 2.8, 0.0), Vector3.UP)


func _build_preview_terrain() -> void:
	var chunk: TeknikVoxelChunk = TerrainGenerator.generate_chunk(PREVIEW_SEED, Vector3i.ZERO)
	_voxel_report = GreedyMesher.build_mesh(chunk)
	var terrain := MeshInstance3D.new()
	terrain.mesh = _voxel_report.mesh
	terrain.position = Vector3(-VoxelChunk.SIZE * 0.5, 0.0, -VoxelChunk.SIZE * 0.5)
	add_child(terrain)


func _build_mechanical_fixture() -> void:
	_add_box(self, Vector3(9.5, 0.55, 5.8), Vector3(0.0, 3.05, 0.0), Color("263947"))
	_add_box(self, Vector3(8.8, 0.18, 5.15), Vector3(0.0, 3.42, 0.0), Color("111c27"))

	var network := KineticNetwork.new()
	network.configure_source(32.0, 8.0)
	network.add_consumer(&"ore_crusher", 1.5, 2.25)
	network.add_consumer(&"belt_line", -0.75, 1.1)
	network.add_consumer(&"alternator", 0.5, 1.7)
	_kinetic_report = network.report()

	_create_gear(Vector3(-2.55, 4.25, 0.2), 1.55, 16, Color("be7437"))
	_create_gear(Vector3(0.45, 4.28, 0.2), 1.15, 14, Color("d4a94f"))
	_create_gear(Vector3(2.85, 4.25, 0.15), 1.25, 14, Color("668b95"))

	_add_box(self, Vector3(0.55, 2.8, 0.55), Vector3(-2.55, 4.45, 0.2), Color("76523a"))
	_add_box(self, Vector3(0.48, 2.6, 0.48), Vector3(0.45, 4.42, 0.2), Color("76523a"))
	_add_box(self, Vector3(0.48, 2.6, 0.48), Vector3(2.85, 4.42, 0.15), Color("76523a"))


func _create_gear(position_3d: Vector3, radius: float, teeth: int, color: Color) -> void:
	var root := Node3D.new()
	root.position = position_3d
	add_child(root)
	_gear_roots.append(root)

	var core := CylinderMesh.new()
	core.top_radius = radius * 0.73
	core.bottom_radius = radius * 0.73
	core.height = 0.46
	core.radial_segments = teeth
	core.material = _material(color)
	var core_instance := MeshInstance3D.new()
	core_instance.mesh = core
	root.add_child(core_instance)

	for tooth_index: int in range(teeth):
		var angle: float = TAU * float(tooth_index) / float(teeth)
		var tooth_position := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var tooth := _add_box(root, Vector3(radius * 0.35, 0.55, radius * 0.24), tooth_position, color.lightened(0.08))
		tooth.rotation.y = -angle

	var hub := CylinderMesh.new()
	hub.top_radius = radius * 0.19
	hub.bottom_radius = radius * 0.19
	hub.height = 0.72
	hub.radial_segments = 16
	hub.material = _material(Color("18232b"))
	var hub_instance := MeshInstance3D.new()
	hub_instance.mesh = hub
	root.add_child(hub_instance)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := ColorRect.new()
	panel.position = Vector2(24.0, 24.0)
	panel.size = Vector2(520.0, 158.0)
	panel.color = Color(0.025, 0.045, 0.067, 0.9)
	layer.add_child(panel)

	var title := Label.new()
	title.position = Vector2(22.0, 14.0)
	title.text = "TEKNIK  /  FOUNDATION BUILD"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("f2bf69"))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(23.0, 51.0)
	subtitle.text = "SEED %d   |   32³ CHUNK   |   %d GREEDY QUADS" % [PREVIEW_SEED, int(_voxel_report.quads)]
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("9fb7c4"))
	panel.add_child(subtitle)

	var stress := Label.new()
	stress.position = Vector2(23.0, 81.0)
	stress.text = "KINETIC  %d RPM   |   STRESS  %.1f / %.1f SU" % [
		int(_kinetic_report.source_rpm),
		float(_kinetic_report.stress),
		float(_kinetic_report.capacity),
	]
	stress.add_theme_font_size_override("font_size", 16)
	stress.add_theme_color_override("font_color", Color("dbe7e5"))
	panel.add_child(stress)

	_fps_label = Label.new()
	_fps_label.position = Vector2(23.0, 113.0)
	_fps_label.text = "RENDER  --- FPS   |   PHYSICS  30 Hz"
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.add_theme_color_override("font_color", Color("7fd7ad"))
	panel.add_child(_fps_label)

	var footer := Label.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24.0
	footer.offset_right = -24.0
	footer.offset_top = -52.0
	footer.offset_bottom = -20.0
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.text = "AUTOMATED QA  •  ORIGINAL PROTOTYPE  •  SURVIVAL SANDBOX"
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color("a9bac4"))
	layer.add_child(footer)


func _add_box(parent: Node, size: Vector3, position_3d: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_3d
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.metallic = 0.18
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
	for frame: int in range(12):
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
