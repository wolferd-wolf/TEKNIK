class_name TeknikBiomeSurfacePalette
extends RefCounted

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const WorldSeed = preload("res://src/world/world_seed.gd")

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
	# Four explicit masks are stored in the vector. Plains is the unclaimed
	# remainder, which keeps transitions continuous instead of drawing biome borders.
	var climate: Vector2 = TerrainGenerator.climate_at(seed, world_x, world_z)
	var river_gap: float = TerrainGenerator.river_distance(seed, world_x, world_z)
	var river_influence: float = 1.0 - smoothstep(5.0, 25.0, river_gap)
	var elevation: float = clampf(
		(surface_y - float(TerrainGenerator.WATER_LEVEL + 1))
		/ float(TerrainGenerator.MAX_SURFACE_HEIGHT - TerrainGenerator.WATER_LEVEL - 1),
		0.0,
		1.0
	)
	var region: float = WorldSeed.sample_value_noise(
		seed + 3023, float(world_x), float(world_z), 78.0
	)
	var patch: float = WorldSeed.sample_value_noise(
		seed + 3089, float(world_x), float(world_z), 31.0
	)
	var rugged: float = WorldSeed.sample_value_noise(
		seed + 3167, float(world_x), float(world_z), 54.0
	)

	var moisture: float = clampf(
		climate.x * 0.82 + (region - 0.5) * 0.24 + river_influence * 0.26,
		0.0,
		1.0
	)
	var temperature: float = clampf(
		climate.y * 0.88 + (patch - 0.5) * 0.18 - elevation * 0.20,
		0.0,
		1.0
	)
	var rocky: float = smoothstep(
		0.49,
		0.84,
		elevation * 0.58 + rugged * 0.34 + clampf(slope_hint, 0.0, 1.0) * 0.34
	)
	var riverbank: float = (
		river_influence
		* smoothstep(0.20, 0.74, moisture)
		* (1.0 - rocky * 0.72)
	)
	var forest: float = (
		smoothstep(0.48, 0.79, moisture)
		* (1.0 - smoothstep(0.76, 0.96, temperature))
		* smoothstep(0.28, 0.68, region)
		* (1.0 - rocky)
		* (1.0 - riverbank * 0.78)
	)
	var dry_scrub: float = (
		smoothstep(0.42, 0.76, 1.0 - moisture)
		* smoothstep(0.46, 0.75, temperature)
		* smoothstep(0.30, 0.72, patch)
		* (1.0 - rocky)
		* (1.0 - riverbank)
	)

	var weights := Vector4(forest, dry_scrub, rocky, riverbank)
	var claimed: float = weights.x + weights.y + weights.z + weights.w
	if claimed > 0.92:
		weights *= 0.92 / claimed
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
				Color("4f713f"),
				Color("2f5938"),
				Color("817844"),
				Color("506050"),
				Color("3f6949"),
				plains,
				weights
			)
		TerrainGenerator.SOIL:
			result = _weighted_color(
				Color("624634"),
				Color("403a31"),
				Color("745238"),
				Color("514d46"),
				Color("493d32"),
				plains,
				weights
			)
		TerrainGenerator.SAND:
			result = _weighted_color(
				Color("aa915c"),
				Color("8d805c"),
				Color("b29a60"),
				Color("918566"),
				Color("796d52"),
				plains,
				weights
			)
		TerrainGenerator.STONE:
			result = _weighted_color(
				Color("626b68"),
				Color("56625d"),
				Color("766b59"),
				Color("707977"),
				Color("58645f"),
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
	var tint: float = (micro - 0.5) * 0.075
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
