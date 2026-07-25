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
	snapshot["schema"] = 4
	snapshot["static_memory_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	snapshot["static_memory_peak_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	snapshot["draw_calls"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	snapshot["rendered_primitives"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	snapshot["node_count"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if is_instance_valid(player) and player.has_method("get_stream_hold_metrics"):
		var hold_metrics: Dictionary = player.call("get_stream_hold_metrics")
		for key: Variant in hold_metrics.keys():
			snapshot[key] = hold_metrics[key]
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
	summary["schema"] = 3
	summary["peak_static_memory_bytes"] = peak_static_memory_bytes
	summary["engine_static_memory_peak_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	summary["peak_draw_calls"] = peak_draw_calls
	summary["peak_rendered_primitives"] = peak_primitives
	summary["peak_node_count"] = peak_node_count
	if is_instance_valid(player) and player.has_method("get_stream_hold_metrics"):
		var hold_metrics: Dictionary = player.call("get_stream_hold_metrics")
		for key: Variant in hold_metrics.keys():
			summary[key] = hold_metrics[key]

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
	environment.ambient_light_energy = 1.10
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.55, 0.74, 0.90)
	environment.fog_light_energy = 0.70
	environment.fog_density = 0.00065
	environment.fog_height = 12.0
	environment.fog_height_density = 0.008

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.07, 0.30, 0.68)
	sky_material.sky_horizon_color = Color(0.58, 0.80, 0.96)
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = Color(0.18, 0.24, 0.28)
	sky_material.ground_horizon_color = Color(0.43, 0.60, 0.70)
	sky_material.ground_curve = 0.12
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.10
	sky_material.sun_energy_multiplier = 2.2
	sky.sky_material = sky_material
	environment.sky = sky
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.08
	# Real-time shadows remain disabled during the foundation milestone.
	# Directional face shading gives the color-only terrain its depth.
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
