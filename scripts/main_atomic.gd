extends "res://scripts/main.gd"

const AtomicVoxelWorldScript := preload("res://scripts/world/atomic_voxel_world.gd")

func _ready() -> void:
	_prepare_telemetry_file()
	_setup_environment()
	world = AtomicVoxelWorldScript.new()
	world.name = "World"
	add_child(world)
	world.spawn_ready.connect(_on_spawn_ready)

	hud = MobileHudScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.attach_world(world)
