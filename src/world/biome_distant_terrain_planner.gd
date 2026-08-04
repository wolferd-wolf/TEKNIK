class_name TeknikBiomeDistantTerrainPlanner
extends "res://src/world/distant_terrain_planner.gd"

const BiomeColorizer = preload("res://src/world/biome_mesh_colorizer.gd")


func build(
	seed: int,
	center: Vector3i,
	chunk_size: int,
	active_radius: int,
	world_radius: int,
	step: int
) -> Dictionary:
	var plan: Dictionary = super.build(
		seed,
		center,
		chunk_size,
		active_radius,
		world_radius,
		step
	)
	BiomeColorizer.recolor_distant_plan(plan, seed)
	return plan
