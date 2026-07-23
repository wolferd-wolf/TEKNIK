class_name TeknikBiomeSurfacePalette
extends RefCounted

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const WorldSeed = preload("res://src/world/world_seed.gd")
const BiomeRegionField = preload("res://src/world/biome_region_field.gd")

const BIOME_PLAINS: int = 0
const BIOME_FOREST: int = 1
const BIOME_DRY_SCRUB: int = 2
const BIOME_ROCKY_UPLAND: int = 3
const BIOME_RIVERBANK: int = 4


static func biome_weights(
	seed: int,
	world_x: int,
	world_z: int,
	surface_y: float,
	slope_hint: float = 0.0
) -> Vector4:
	# Broad macro regions establish biome identity first. Climate, river distance,
	# elevation and slope then modulate that identity without hard borders.
	var climate: Vector2 = TerrainGenerator.climate_at(seed, world_x, world_z)
	var macro: Dictionary = BiomeRegionField.sample(seed, world_x, world_z)
	var river_gap: float = TerrainGenerator.river_distance(seed, world_x, world_z)
	var river_influence: float = 1.0 - smoothstep(5.0, 29.0, river_gap)
	var elevation: float = clampf(
		(surface_y - float(TerrainGenerator.WATER_LEVEL + 1))
		/ float(TerrainGenerator.MAX_SURFACE_HEIGHT - TerrainGenerator.WATER_LEVEL - 1),
		0.0,
		1.0
	)
	var local_patch: float = WorldSeed.sample_value_noise(
		seed + 3089, float(world_x), float(world_z), 42.0
	)
	var local_rugged: float = WorldSeed.sample_value_noise(
		seed + 3167, float(world_x), float(world_z), 58.0
	)

	var moisture: float = clampf(
		float(macro.moisture) * 0.56
		+ climate.x * 0.34
		+ river_influence * 0.24
		+ (local_patch - 0.5) * 0.10,
		0.0,
		1.0
	)
	var temperature: float = clampf(
		float(macro.temperature) * 0.62
		+ climate.y * 0.30
		- elevation * 0.20
		+ (local_patch - 0.5) * 0.07,
		0.0,
		1.0
	)
	var ruggedness: float = clampf(
		float(macro.ruggedness) * 0.50
		+ local_rugged * 0.18
		+ elevation * 0.28
		+ clampf(slope_hint, 0.0, 1.0) * 0.42,
		0.0,
		1.0
	)
	var identity: float = float(macro.identity)

	var rocky: float = (
		smoothstep(0.52, 0.82, ruggedness)
		* smoothstep(0.30, 0.72, identity + elevation * 0.22)
		* (1.0 - river_influence * 0.72)
	)
	var riverbank: float = (
		river_influence
		* smoothstep(0.24, 0.70, moisture)
		* (1.0 - rocky * 0.80)
	)
	var forest: float = (
		smoothstep(0.49, 0.76, moisture)
		* (1.0 - smoothstep(0.78, 0.96, temperature))
		* smoothstep(0.34, 0.68, 1.0 - absf(identity - 0.58) * 1.7)
		* (1.0 - rocky)
		* (1.0 - riverbank * 0.70)
	)
	var dry_scrub: float = (
		smoothstep(0.45, 0.75, 1.0 - moisture)
		* smoothstep(0.48, 0.74, temperature)
		* smoothstep(0.34, 0.70, identity)
		* (1.0 - rocky)
		* (1.0 - riverbank)
	)

	var weights := Vector4(forest, dry_scrub, rocky, riverbank)
	var claimed: float = weights.x + weights.y + weights.z + weights.w
	if claimed > 0.94:
		weights *= 0.94 / claimed
	return weights


static func plains_weight(weights: Vector4) -> float:
	return maxf(0.0, 1.0 - weights.x - weights.y - weights.z - weights.w)


static func dominant_biome(weights: Vector4) -> int:
	var result: int = BIOME_PLAINS
	var strongest: float = plains_weight(weights)
	var values: Array[float] = [weights.x, weights.y, weights.z, weights.w]
	for index: int in range(values.size()):
		if values[index] > strongest:
			strongest = values[index]
			result = index + 1
	return result


static func biome_name(biome: int) -> String:
	match biome:
		BIOME_FOREST:
			return "forest"
		BIOME_DRY_SCRUB:
			return "dry_scrub"
		BIOME_ROCKY_UPLAND:
			return "rocky_upland"
		BIOME_RIVERBANK:
			return "riverbank"
		_:
			return "plains"


static func color(
	seed: int,
	material: int,
	world_position: Vector3i,
	surface_y: float,
	cache: Dictionary
) -> Color:
	var cache_key := Vector3i(world_position.x, roundi(surface_y), world_position.z)
	var weights: Vector4
	if cache.has(cache_key):
		weights = cache[cache_key]
	else:
		weights = biome_weights(
			seed,
			world_position.x,
			world_position.z,
			surface_y
		)
		cache[cache_key] = weights

	var plains: float = plains_weight(weights)
	var result: Color
	match material:
		TerrainGenerator.GRASS:
			result = _weighted_color(
				Color("527443"),
				Color("2c5637"),
				Color("847746"),
				Color("536054"),
				Color("3b6949"),
				plains,
				weights
			)
		TerrainGenerator.SOIL:
			result = _weighted_color(
				Color("644734"),
				Color("3d392f"),
				Color("775237"),
				Color("504c46"),
				Color("473b31"),
				plains,
				weights
			)
		TerrainGenerator.SAND:
			result = _weighted_color(
				Color("aa915c"),
				Color("8b805d"),
				Color("b59a5d"),
				Color("918568"),
				Color("75694f"),
				plains,
				weights
			)
		TerrainGenerator.STONE:
			result = _weighted_color(
				Color("626b68"),
				Color("53605b"),
				Color("786b57"),
				Color("737c79"),
				Color("56625d"),
				plains,
				weights
			)
			var strata: float = fposmod(
				float(world_position.y) + WorldSeed.sample_unit(
					seed + 3251,
					world_position.x,
					world_position.z
				) * 3.0,
				5.0
			) / 5.0
			result = result.lerp(Color("858b83"), absf(strata - 0.5) * 0.13)
		_:
			result = Color("8c7e69")

	var micro: float = WorldSeed.sample_unit(
		seed + 3319,
		world_position.x * 3 + world_position.y,
		world_position.z * 3 - world_position.y
	)
	var tint: float = (micro - 0.5) * 0.060
	if tint > 0.0:
		result = result.lightened(tint)
	elif tint < 0.0:
		result = result.darkened(-tint)
	return result


static func _weighted_color(
	plains_color: Color,
	forest_color: Color,
	dry_color: Color,
	rocky_color: Color,
	river_color: Color,
	plains: float,
	weights: Vector4
) -> Color:
	return (
		plains_color * plains
		+ forest_color * weights.x
		+ dry_color * weights.y
		+ rocky_color * weights.z
		+ river_color * weights.w
	)
