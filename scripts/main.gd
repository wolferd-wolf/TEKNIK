extends Node3D

const VoxelWorldScript := preload("res://scripts/world/voxel_world.gd")
const PlayerControllerScript := preload("res://scripts/player/player_controller.gd")
const MobileHudScript := preload("res://scripts/ui/mobile_hud.gd")

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer

func _ready() -> void:
	_setup_environment()
	world = VoxelWorldScript.new()
	world.name = "World"
	add_child(world)
	world.spawn_ready.connect(_on_spawn_ready)

	hud = MobileHudScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.attach_world(world)

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
