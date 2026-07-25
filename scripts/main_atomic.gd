extends "res://scripts/main.gd"

const TexturedAtomicVoxelWorldScript := preload("res://scripts/world/textured_atomic_voxel_world.gd")
const MobileSafePlayerScript := preload("res://scripts/player/mobile_safe_player_controller.gd")
const MobileSafeHudScript := preload("res://scripts/ui/mobile_hud_safe.gd")

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

	_prepare_telemetry_file()
	_setup_environment()
	world = TexturedAtomicVoxelWorldScript.new()
	world.name = "World"
	add_child(world)
	world.spawn_ready.connect(_on_spawn_ready)

	hud = MobileSafeHudScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.attach_world(world)

func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.22
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.78, 0.87, 0.94)
	environment.fog_light_energy = 0.82
	environment.fog_density = 0.0018
	environment.fog_height = 9.0
	environment.fog_height_density = 0.035

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.38, 0.66)
	sky_material.sky_horizon_color = Color(0.76, 0.86, 0.95)
	sky_material.ground_bottom_color = Color(0.17, 0.22, 0.25)
	sky_material.ground_horizon_color = Color(0.55, 0.61, 0.58)
	sky_material.sun_angle_max = 28.0
	sky.sky_material = sky_material
	environment.sky = sky
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.42
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
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
