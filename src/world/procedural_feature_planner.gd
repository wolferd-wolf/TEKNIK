class_name TeknikProceduralFeaturePlanner
extends RefCounted

const ProceduralEcology = preload("res://src/world/procedural_ecology.gd")
const WorldSeed = preload("res://src/world/world_seed.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const WorldWindowPlan = preload("res://src/world/world_window_plan.gd")


func build(
	seed: int,
	center: Vector3i,
	chunk_radius: int,
	chunk_size: int,
	exclusion_position: Vector3
) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var plan: Dictionary = {
		"trunks": [],
		"broadleaf_lower": [],
		"broadleaf_upper": [],
		"broadleaf_side": [],
		"conifer_lower": [],
		"conifer_middle": [],
		"conifer_upper": [],
		"fallen_logs": [],
		"cool_rock_primary": [],
		"cool_rock_secondary": [],
		"warm_rock_primary": [],
		"warm_rock_secondary": [],
		"lush_tufts": [],
		"dry_tufts": [],
		"shrubs_lower": [],
		"shrubs_upper": [],
	}
	_plan_forest(plan, seed, center, chunk_radius, chunk_size, exclusion_position)
	_plan_boulders(plan, seed, center, chunk_radius, chunk_size, exclusion_position)
	_plan_ground(plan, seed, center, chunk_radius, chunk_size, exclusion_position)
	plan["tree_count"] = (plan["trunks"] as Array).size()
	plan["boulder_count"] = (
		(plan["cool_rock_primary"] as Array).size()
		+ (plan["warm_rock_primary"] as Array).size()
	)
	plan["ground_part_count"] = (
		(plan["lush_tufts"] as Array).size()
		+ (plan["dry_tufts"] as Array).size()
		+ (plan["shrubs_lower"] as Array).size()
		+ (plan["shrubs_upper"] as Array).size()
	)
	plan["generation_usec"] = Time.get_ticks_usec() - started_usec
	plan["center"] = center
	return plan


func _plan_forest(
	plan: Dictionary,
	seed: int,
	center: Vector3i,
	chunk_radius: int,
	chunk_size: int,
	exclusion_position: Vector3
) -> void:
	var trunks: Array = plan["trunks"]
	var broadleaf_lower: Array = plan["broadleaf_lower"]
	var broadleaf_upper: Array = plan["broadleaf_upper"]
	var broadleaf_side: Array = plan["broadleaf_side"]
	var conifer_lower: Array = plan["conifer_lower"]
	var conifer_middle: Array = plan["conifer_middle"]
	var conifer_upper: Array = plan["conifer_upper"]
	var fallen_logs: Array = plan["fallen_logs"]
	var world_rect: Rect2i = WorldWindowPlan.active_world_rect(
		center, chunk_radius, chunk_size, 7
	)
	var cell_size: int = ProceduralEcology.TREE_CELL_SIZE
	var start_x: int = floori(float(world_rect.position.x) / float(cell_size)) - 1
	var end_x: int = ceili(float(world_rect.end.x) / float(cell_size)) + 1
	var start_z: int = floori(float(world_rect.position.y) / float(cell_size)) - 1
	var end_z: int = ceili(float(world_rect.end.y) / float(cell_size)) + 1

	for cell_z: int in range(start_z, end_z + 1):
		for cell_x: int in range(start_x, end_x + 1):
			if not ProceduralEcology.blue_noise_accept(
				seed + 701,
				cell_x,
				cell_z,
				cell_size,
				ProceduralEcology.TREE_MIN_DISTANCE
			):
				continue
			var candidate: Vector2 = ProceduralEcology.candidate_position(
				seed + 701, cell_x, cell_z, cell_size
			)
			var world_x: int = floori(candidate.x)
			var world_z: int = floori(candidate.y)
			if not world_rect.has_point(Vector2i(world_x, world_z)):
				continue
			if Vector2(
				float(world_x) - exclusion_position.x,
				float(world_z) - exclusion_position.z
			).length() < 14.0:
				continue
			var height: int = TerrainGenerator.surface_height(seed, world_x, world_z)
			if height <= TerrainGenerator.WATER_LEVEL + 2:
				continue
			if TerrainGenerator.surface_material(seed, world_x, world_z) != TerrainGenerator.GRASS:
				continue
			var river_gap: float = TerrainGenerator.river_distance(seed, world_x, world_z)
			if river_gap < 6.5:
				continue
			var slope: int = TerrainGenerator.surface_slope(seed, world_x, world_z)
			if slope > 1:
				continue
			var vegetation: Vector3 = TerrainGenerator.vegetation_profile(seed, world_x, world_z)
			var climate: Vector2 = TerrainGenerator.climate_at(seed, world_x, world_z)
			var elevation: float = clampf(
				(float(height) - 9.0) / float(TerrainGenerator.MAX_SURFACE_HEIGHT - 9),
				0.0,
				1.0
			)
			var density: float = ProceduralEcology.forest_density(
				seed,
				world_x,
				world_z,
				vegetation.x,
				climate.x,
				climate.y,
				elevation,
				slope,
				river_gap
			)
			if WorldSeed.sample_unit(seed + 709, cell_x, cell_z) > density:
				continue

			var scale: float = ProceduralEcology.tree_scale(
				seed, cell_x, cell_z, vegetation.x, climate.x, elevation
			)
			var quarter_turn: int = floori(
				WorldSeed.sample_unit(seed + 769, cell_x, cell_z) * 4.0
			) % 4
			var rotation: float = float(quarter_turn) * PI * 0.5
			var ground := Vector3(
				float(world_x) + 0.5,
				float(height) + 1.0,
				float(world_z) + 0.5
			)
			var trunk_height: float = scale * lerpf(
				3.3,
				5.2,
				clampf(vegetation.x * 0.72 + climate.x * 0.28, 0.0, 1.0)
			)
			var trunk_width: float = scale * lerpf(0.54, 0.76, vegetation.x)
			trunks.append(Transform3D(
				Basis(Vector3.UP, rotation).scaled(Vector3(
					trunk_width, trunk_height, trunk_width
				)),
				ground + Vector3.UP * trunk_height * 0.5
			))

			var conifer_chance: float = ProceduralEcology.conifer_probability(
				seed, world_x, world_z, climate.x, climate.y, elevation
			)
			if WorldSeed.sample_unit(seed + 787, cell_x, cell_z) < conifer_chance:
				conifer_lower.append(_box_transform(
					ground + Vector3.UP * (trunk_height + scale * 0.18),
					Vector3(scale * 3.05, scale * 0.92, scale * 3.05),
					rotation
				))
				conifer_middle.append(_box_transform(
					ground + Vector3.UP * (trunk_height + scale * 1.10),
					Vector3(scale * 2.25, scale * 0.90, scale * 2.25),
					rotation
				))
				conifer_upper.append(_box_transform(
					ground + Vector3.UP * (trunk_height + scale * 2.00),
					Vector3(scale * 1.35, scale * 0.88, scale * 1.35),
					rotation
				))
			else:
				var crown_width: float = scale * lerpf(
					2.65,
					3.55,
					clampf(vegetation.x * 0.7 + climate.x * 0.3, 0.0, 1.0)
				)
				var side_direction: Vector3 = Basis(Vector3.UP, rotation) * Vector3.RIGHT
				broadleaf_lower.append(_box_transform(
					ground + Vector3.UP * (trunk_height + scale * 0.45),
					Vector3(crown_width, scale * 1.55, crown_width * 0.88),
					rotation
				))
				broadleaf_upper.append(_box_transform(
					ground + Vector3.UP * (trunk_height + scale * 1.62),
					Vector3(crown_width * 0.72, scale * 1.35, crown_width * 0.72),
					rotation
				))
				broadleaf_side.append(_box_transform(
					ground
					+ side_direction * (crown_width * 0.43)
					+ Vector3.UP * (trunk_height + scale * 0.92),
					Vector3(crown_width * 0.52, scale * 1.02, crown_width * 0.48),
					rotation
				))

			var edge: float = ProceduralEcology.forest_edge(seed, world_x, world_z)
			if (
				edge > 0.58
				and WorldSeed.sample_unit(seed + 811, cell_x, cell_z) < 0.075
			):
				fallen_logs.append(_box_transform(
					ground + Vector3.UP * scale * 0.26,
					Vector3(scale * 3.0, scale * 0.38, scale * 0.42),
					rotation + PI * 0.5
				))


func _plan_boulders(
	plan: Dictionary,
	seed: int,
	center: Vector3i,
	chunk_radius: int,
	chunk_size: int,
	exclusion_position: Vector3
) -> void:
	var cool_primary: Array = plan["cool_rock_primary"]
	var cool_secondary: Array = plan["cool_rock_secondary"]
	var warm_primary: Array = plan["warm_rock_primary"]
	var warm_secondary: Array = plan["warm_rock_secondary"]
	var world_rect: Rect2i = WorldWindowPlan.active_world_rect(
		center, chunk_radius, chunk_size, 7
	)
	var cell_size: int = ProceduralEcology.ROCK_CELL_SIZE
	var start_x: int = floori(float(world_rect.position.x) / float(cell_size)) - 1
	var end_x: int = ceili(float(world_rect.end.x) / float(cell_size)) + 1
	var start_z: int = floori(float(world_rect.position.y) / float(cell_size)) - 1
	var end_z: int = ceili(float(world_rect.end.y) / float(cell_size)) + 1

	for cell_z: int in range(start_z, end_z + 1):
		for cell_x: int in range(start_x, end_x + 1):
			if not ProceduralEcology.blue_noise_accept(
				seed + 823,
				cell_x,
				cell_z,
				cell_size,
				ProceduralEcology.ROCK_MIN_DISTANCE
			):
				continue
			var candidate: Vector2 = ProceduralEcology.candidate_position(
				seed + 823, cell_x, cell_z, cell_size
			)
			var world_x: int = floori(candidate.x)
			var world_z: int = floori(candidate.y)
			if not world_rect.has_point(Vector2i(world_x, world_z)):
				continue
			if Vector2(
				float(world_x) - exclusion_position.x,
				float(world_z) - exclusion_position.z
			).length() < 8.0:
				continue
			var height: int = TerrainGenerator.surface_height(seed, world_x, world_z)
			var slope: int = TerrainGenerator.surface_slope(seed, world_x, world_z)
			var river_gap: float = TerrainGenerator.river_distance(seed, world_x, world_z)
			var vegetation: Vector3 = TerrainGenerator.vegetation_profile(seed, world_x, world_z)
			var elevation: float = clampf(
				(float(height) - 9.0) / float(TerrainGenerator.MAX_SURFACE_HEIGHT - 9),
				0.0,
				1.0
			)
			var density: float = ProceduralEcology.rock_density(
				seed, world_x, world_z, vegetation.z, elevation, slope, river_gap
			)
			if WorldSeed.sample_unit(seed + 839, cell_x, cell_z) > density:
				continue
			var width: float = lerpf(
				0.72, 1.55, WorldSeed.sample_unit(seed + 853, cell_x, cell_z)
			)
			var depth: float = lerpf(
				0.68, 1.38, WorldSeed.sample_unit(seed + 877, cell_x, cell_z)
			)
			var rise: float = lerpf(
				0.48, 1.08, WorldSeed.sample_unit(seed + 881, cell_x, cell_z)
			)
			var rotation: float = float(
				floori(WorldSeed.sample_unit(seed + 907, cell_x, cell_z) * 8.0)
			) * PI * 0.25
			var ground := Vector3(
				float(world_x) + 0.5,
				float(height) + 1.0,
				float(world_z) + 0.5
			)
			var primary := _box_transform(
				ground + Vector3.UP * rise * 0.42,
				Vector3(width, rise, depth),
				rotation
			)
			var offset_direction: Vector3 = Basis(Vector3.UP, rotation) * Vector3.RIGHT
			var secondary := _box_transform(
				ground
				+ offset_direction * width * 0.42
				+ Vector3.UP * rise * 0.54,
				Vector3(width * 0.58, rise * 0.66, depth * 0.52),
				rotation + PI * 0.5
			)
			if vegetation.z + elevation > 0.92:
				cool_primary.append(primary)
				cool_secondary.append(secondary)
			else:
				warm_primary.append(primary)
				warm_secondary.append(secondary)


func _plan_ground(
	plan: Dictionary,
	seed: int,
	center: Vector3i,
	chunk_radius: int,
	chunk_size: int,
	exclusion_position: Vector3
) -> void:
	var lush_tufts: Array = plan["lush_tufts"]
	var dry_tufts: Array = plan["dry_tufts"]
	var shrubs_lower: Array = plan["shrubs_lower"]
	var shrubs_upper: Array = plan["shrubs_upper"]
	var world_rect: Rect2i = WorldWindowPlan.active_world_rect(
		center, chunk_radius, chunk_size, 5
	)
	var cell_size: int = ProceduralEcology.COVER_CELL_SIZE
	var start_x: int = floori(float(world_rect.position.x) / float(cell_size)) - 1
	var end_x: int = ceili(float(world_rect.end.x) / float(cell_size)) + 1
	var start_z: int = floori(float(world_rect.position.y) / float(cell_size)) - 1
	var end_z: int = ceili(float(world_rect.end.y) / float(cell_size)) + 1

	for cell_z: int in range(start_z, end_z + 1):
		for cell_x: int in range(start_x, end_x + 1):
			if not ProceduralEcology.blue_noise_accept(
				seed + 947,
				cell_x,
				cell_z,
				cell_size,
				ProceduralEcology.COVER_MIN_DISTANCE
			):
				continue
			var candidate: Vector2 = ProceduralEcology.candidate_position(
				seed + 947, cell_x, cell_z, cell_size
			)
			var world_x: int = floori(candidate.x)
			var world_z: int = floori(candidate.y)
			if not world_rect.has_point(Vector2i(world_x, world_z)):
				continue
			if Vector2(
				float(world_x) - exclusion_position.x,
				float(world_z) - exclusion_position.z
			).length() > 116.0:
				continue
			if TerrainGenerator.surface_material(seed, world_x, world_z) != TerrainGenerator.GRASS:
				continue
			var slope: int = TerrainGenerator.surface_slope(seed, world_x, world_z)
			if slope > 1:
				continue
			var height: int = TerrainGenerator.surface_height(seed, world_x, world_z)
			var river_gap: float = TerrainGenerator.river_distance(seed, world_x, world_z)
			var vegetation: Vector3 = TerrainGenerator.vegetation_profile(seed, world_x, world_z)
			var climate: Vector2 = TerrainGenerator.climate_at(seed, world_x, world_z)
			var elevation: float = clampf(
				(float(height) - 9.0) / float(TerrainGenerator.MAX_SURFACE_HEIGHT - 9),
				0.0,
				1.0
			)
			var forest_value: float = ProceduralEcology.forest_density(
				seed,
				world_x,
				world_z,
				vegetation.x,
				climate.x,
				climate.y,
				elevation,
				slope,
				river_gap
			)
			var density: float = ProceduralEcology.ground_cover_density(
				seed,
				world_x,
				world_z,
				vegetation.y,
				climate.x,
				elevation,
				forest_value
			)
			if WorldSeed.sample_unit(seed + 953, cell_x, cell_z) > density:
				continue
			var scale: float = lerpf(
				0.72, 1.24, WorldSeed.sample_unit(seed + 977, cell_x, cell_z)
			)
			var rotation: float = float(
				floori(WorldSeed.sample_unit(seed + 991, cell_x, cell_z) * 8.0)
			) * PI * 0.25
			var ground := Vector3(
				float(world_x) + 0.5,
				float(height) + 1.01,
				float(world_z) + 0.5
			)
			var tuft_a := _box_transform(
				ground + Vector3.UP * scale * 0.28,
				Vector3(scale * 0.12, scale * 0.56, scale * 0.58),
				rotation
			)
			var tuft_b := _box_transform(
				ground + Vector3.UP * scale * 0.26,
				Vector3(scale * 0.12, scale * 0.52, scale * 0.52),
				rotation + PI * 0.5
			)
			if climate.x > 0.46:
				lush_tufts.append(tuft_a)
				lush_tufts.append(tuft_b)
			else:
				dry_tufts.append(tuft_a)
				dry_tufts.append(tuft_b)

			var edge: float = ProceduralEcology.forest_edge(seed, world_x, world_z)
			if (
				edge * vegetation.x > 0.34
				and WorldSeed.sample_unit(seed + 1009, cell_x, cell_z) < 0.22
			):
				shrubs_lower.append(_box_transform(
					ground + Vector3.UP * scale * 0.28,
					Vector3(scale * 0.90, scale * 0.56, scale * 0.78),
					rotation
				))
				shrubs_upper.append(_box_transform(
					ground + Vector3.UP * scale * 0.72,
					Vector3(scale * 0.58, scale * 0.48, scale * 0.58),
					rotation + PI * 0.5
				))


func _box_transform(origin: Vector3, size: Vector3, rotation: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rotation).scaled(size), origin)
