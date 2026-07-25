extends "res://scripts/main.gd"

const ColoredAtomicVoxelWorldScript := preload("res://scripts/world/colored_atomic_voxel_world.gd")
const MobileSafePlayerScript := preload("res://scripts/player/mobile_safe_player_controller.gd")
const MobileSafeHudScript := preload("res://scripts/ui/mobile_hud_safe.gd")

var peak_static_memory_bytes := 0
var peak_draw_calls := 0
var peak_primitives := 0
var peak_node_count := 0
var resource_summary_augmented := false

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

	_prepare_telemetry_file()
	_setup_environment()
	world = ColoredAtomicVoxelWorldScript.new()
	world.name = "World"
	add_child(world)
	world.spawn_ready.connect(_on_spawn_ready)

	hud = MobileSafeHudScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.attach_world(world)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_flush_world_for_lifecycle("application-paused")
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_flush_world_for_lifecycle("focus-out")
		NOTIFICATION_WM_CLOSE_REQUEST:
			_flush_world_for_lifecycle("close-request")

func _flush_world_for_lifecycle(reason: String) -> bool:
	if not is_instance_valid(world) or not world.has_method("flush_pending_save"):
		return true
	return bool(world.call("flush_pending_save", reason))

func _capture_telemetry_snapshot() -> Dictionary:
	var snapshot: Dictionary = super._capture_telemetry_snapshot()
	snapshot["schema"] = 3
	snapshot["static_memory_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	snapshot["static_memory_peak_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	snapshot["draw_calls"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	snapshot["rendered_primitives"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	snapshot["node_count"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	return snapshot

func _update_session_peaks(snapshot: Dictionary) -> void:
	super._update_session_peaks(snapshot)
	peak_static_memory_bytes = maxi(peak_static_memory_bytes, int(snapshot.get("static_memory_bytes", 0)))
	peak_draw_calls = maxi(peak_draw_calls, int(snapshot.get("draw_calls", 0)))
	peak_primitives = maxi(peak_primitives, int(snapshot.get("rendered_primitives", 0)))
	peak_node_count = maxi(peak_node_count, int(snapshot.get("node_count", 0)))

func write_session_summary(clean_shutdown: bool) -> bool:
	if resource_summary_augmented:
		return true
	if not super.write_session_summary(clean_shutdown):
		return false

	var file := FileAccess.open(TELEMETRY_SUMMARY_PATH, FileAccess.READ)
	if file == null:
		telemetry_write_failures += 1
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		telemetry_write_failures += 1
		return false
	var summary: Dictionary = parser.data
	summary["schema"] = 2
	summary["peak_static_memory_bytes"] = peak_static_memory_bytes
	summary["engine_static_memory_peak_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	summary["peak_draw_calls"] = peak_draw_calls
	summary["peak_rendered_primitives"] = peak_primitives
	summary["peak_node_count"] = peak_node_count

	file = FileAccess.open(TELEMETRY_SUMMARY_PATH, FileAccess.WRITE)
	if file == null:
		telemetry_write_failures += 1
		return false
	file.store_string(JSON.stringify(summary, "\t"))
	resource_summary_augmented = true
	return true

func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.34
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.82, 0.90, 0.97)
	environment.fog_light_energy = 0.90
	environment.fog_density = 0.0012
	environment.fog_height = 10.0
	environment.fog_height_density = 0.02

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.50, 0.78)
	sky_material.sky_horizon_color = Color(0.82, 0.91, 0.98)
	sky_material.ground_bottom_color = Color(0.28, 0.34, 0.34)
	sky_material.ground_horizon_color = Color(0.64, 0.70, 0.63)
	sky_material.sun_angle_max = 24.0
	sky.sky_material = sky_material
	environment.sky = sky
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.90)
	sun.light_energy = 1.18
	# Real-time shadows are intentionally disabled during the foundation milestone.
	# Face shading keeps terrain readable without the oversized near-camera artifact.
	sun.shadow_enabled = false
	add_child(sun)

func _on_spawn_ready(spawn_position: Vector3) -> void:
	if is_instance_valid(player):
		return
	player = MobileSafePlayerScript.new()
	player.name = "Player"
	player.world = world
	add_child(player)
	player.global_position = spawn_position
	world.set_player(player)
	hud.attach_player(player)
