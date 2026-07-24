extends Node3D

const VoxelWorldScript := preload("res://scripts/world/voxel_world.gd")
const PlayerControllerScript := preload("res://scripts/player/player_controller.gd")
const MobileHudScript := preload("res://scripts/ui/mobile_hud.gd")

const TELEMETRY_PATH := "user://teknik_telemetry.jsonl"
const TELEMETRY_PREVIOUS_PATH := "user://teknik_telemetry.previous.jsonl"
const TELEMETRY_INTERVAL_SECONDS := 1.0
const TELEMETRY_MAX_SAMPLES := 600
const TELEMETRY_MAX_BYTES := 2 * 1024 * 1024
const HITCH_THRESHOLD_33_MS := 33.333
const HITCH_THRESHOLD_50_MS := 50.0
const HITCH_THRESHOLD_100_MS := 100.0

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var telemetry_elapsed := 0.0
var session_elapsed := 0.0
var frame_samples_ms: Array[float] = []
var telemetry_write_failures := 0
var last_telemetry_snapshot: Dictionary = {}
var interval_peak_frame_ms := 0.0
var interval_hitches_33_ms := 0
var interval_hitches_50_ms := 0
var interval_hitches_100_ms := 0
var total_hitches_33_ms := 0
var total_hitches_50_ms := 0
var total_hitches_100_ms := 0

func _ready() -> void:
	_prepare_telemetry_file()
	_setup_environment()
	world = VoxelWorldScript.new()
	world.name = "World"
	add_child(world)
	world.spawn_ready.connect(_on_spawn_ready)

	hud = MobileHudScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.attach_world(world)

func _process(delta: float) -> void:
	_record_frame_sample(delta)
	session_elapsed += delta
	telemetry_elapsed += delta
	if telemetry_elapsed >= TELEMETRY_INTERVAL_SECONDS:
		telemetry_elapsed = fmod(telemetry_elapsed, TELEMETRY_INTERVAL_SECONDS)
		last_telemetry_snapshot = _capture_telemetry_snapshot()
		_append_telemetry_snapshot(last_telemetry_snapshot)
		_reset_interval_hitch_counters()

func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.72, 0.80)
	environment.fog_light_energy = 0.65
	environment.fog_density = 0.0035
	environment.fog_height = 8.0
	environment.fog_height_density = 0.09

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.08, 0.20, 0.34)
	sky_material.sky_horizon_color = Color(0.62, 0.74, 0.82)
	sky_material.ground_bottom_color = Color(0.05, 0.055, 0.06)
	sky_material.ground_horizon_color = Color(0.35, 0.38, 0.37)
	sky_material.sun_angle_max = 24.0
	sky.sky_material = sky_material
	environment.sky = sky
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 72.0
	add_child(sun)

func _on_spawn_ready(spawn_position: Vector3) -> void:
	if is_instance_valid(player):
		return
	player = PlayerControllerScript.new()
	player.name = "Player"
	player.world = world
	add_child(player)
	player.global_position = spawn_position
	world.set_player(player)
	hud.attach_player(player)

func _record_frame_sample(delta: float) -> void:
	var frame_ms := delta * 1000.0
	frame_samples_ms.append(frame_ms)
	if frame_samples_ms.size() > TELEMETRY_MAX_SAMPLES:
		frame_samples_ms.pop_front()
	interval_peak_frame_ms = maxf(interval_peak_frame_ms, frame_ms)
	if frame_ms >= HITCH_THRESHOLD_33_MS:
		interval_hitches_33_ms += 1
		total_hitches_33_ms += 1
	if frame_ms >= HITCH_THRESHOLD_50_MS:
		interval_hitches_50_ms += 1
		total_hitches_50_ms += 1
	if frame_ms >= HITCH_THRESHOLD_100_MS:
		interval_hitches_100_ms += 1
		total_hitches_100_ms += 1

func _capture_telemetry_snapshot() -> Dictionary:
	var snapshot := {
		"schema": 2,
		"timestamp_unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"session_elapsed_seconds": session_elapsed,
		"fps": Engine.get_frames_per_second(),
		"frame_sample_count": frame_samples_ms.size(),
		"frame_p50_ms": _percentile(frame_samples_ms, 0.50),
		"frame_p90_ms": _percentile(frame_samples_ms, 0.90),
		"frame_p99_ms": _percentile(frame_samples_ms, 0.99),
		"interval_peak_frame_ms": interval_peak_frame_ms,
		"interval_hitches_33_ms": interval_hitches_33_ms,
		"interval_hitches_50_ms": interval_hitches_50_ms,
		"interval_hitches_100_ms": interval_hitches_100_ms,
		"total_hitches_33_ms": total_hitches_33_ms,
		"total_hitches_50_ms": total_hitches_50_ms,
		"total_hitches_100_ms": total_hitches_100_ms,
		"telemetry_write_failures": telemetry_write_failures
	}

	if is_instance_valid(world):
		snapshot["loaded_chunks"] = world.loaded_chunks.size()
		snapshot["build_queue"] = world.build_queue.size()
		snapshot["collision_add_queue"] = world.collision_add_queue.size()
		snapshot["collision_remove_queue"] = world.collision_remove_queue.size()
		snapshot["last_build_ms"] = float(world.last_build_usec) / 1000.0
		snapshot["last_collision_ms"] = float(world.last_collision_usec) / 1000.0
		snapshot["last_face_count"] = world.last_face_count
		snapshot["world_center"] = "%d,%d" % [world.current_center.x, world.current_center.y]
		snapshot["saved_overrides"] = world.block_overrides.size()

	if is_instance_valid(player):
		snapshot["player_position"] = "%.3f,%.3f,%.3f" % [player.global_position.x, player.global_position.y, player.global_position.z]
		snapshot["player_chunk"] = "%d,%d" % [world.world_to_chunk(player.global_position).x, world.world_to_chunk(player.global_position).y]
		snapshot["stream_hold_active"] = player.stream_hold_active
		snapshot["stream_hold_count"] = player.stream_hold_count

	return snapshot

func _reset_interval_hitch_counters() -> void:
	interval_peak_frame_ms = 0.0
	interval_hitches_33_ms = 0
	interval_hitches_50_ms = 0
	interval_hitches_100_ms = 0

func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	var index := clampi(int(ceil(fraction * float(ordered.size()))) - 1, 0, ordered.size() - 1)
	return ordered[index]

func _append_telemetry_snapshot(snapshot: Dictionary) -> void:
	_rotate_telemetry_if_needed()
	var file := FileAccess.open(TELEMETRY_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(TELEMETRY_PATH, FileAccess.WRITE)
	if file == null:
		telemetry_write_failures += 1
		return
	file.seek_end()
	file.store_line(JSON.stringify(snapshot))

func _prepare_telemetry_file() -> void:
	_rotate_telemetry_if_needed()
	if not FileAccess.file_exists(TELEMETRY_PATH):
		var file := FileAccess.open(TELEMETRY_PATH, FileAccess.WRITE)
		if file == null:
			telemetry_write_failures += 1

func _rotate_telemetry_if_needed() -> void:
	if not FileAccess.file_exists(TELEMETRY_PATH):
		return
	var file := FileAccess.open(TELEMETRY_PATH, FileAccess.READ)
	if file == null:
		telemetry_write_failures += 1
		return
	var should_rotate := file.get_length() >= TELEMETRY_MAX_BYTES
	file = null
	if not should_rotate:
		return
	var previous_absolute := ProjectSettings.globalize_path(TELEMETRY_PREVIOUS_PATH)
	if FileAccess.file_exists(TELEMETRY_PREVIOUS_PATH):
		DirAccess.remove_absolute(previous_absolute)
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(TELEMETRY_PATH), previous_absolute)
	if rename_error != OK:
		telemetry_write_failures += 1

func get_telemetry_path() -> String:
	return ProjectSettings.globalize_path(TELEMETRY_PATH)