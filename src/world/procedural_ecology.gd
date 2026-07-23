class_name TeknikProceduralEcology
extends RefCounted

const WorldSeed = preload("res://src/world/world_seed.gd")

const TREE_CELL_SIZE: int = 6
const TREE_MIN_DISTANCE: float = 5.65
const ROCK_CELL_SIZE: int = 10
const ROCK_MIN_DISTANCE: float = 8.25
const COVER_CELL_SIZE: int = 5
const COVER_MIN_DISTANCE: float = 4.05


static func fractal_noise(
	seed: int,
	world_x: float,
	world_z: float,
	base_cell_size: float,
	octaves: int = 4,
	lacunarity: float = 2.0,
	gain: float = 0.5
) -> float:
	var total: float = 0.0
	var normalization: float = 0.0
	var amplitude: float = 1.0
	var cell_size: float = maxf(base_cell_size, 1.0)
	for octave: int in range(maxi(octaves, 1)):
		total += WorldSeed.sample_value_noise(
			seed + octave * 1013,
			world_x,
			world_z,
			cell_size
		) * amplitude
		normalization += amplitude
		amplitude *= gain
		cell_size = maxf(cell_size / lacunarity, 1.0)
	return total / maxf(normalization, 0.0001)


static func warped_noise(
	seed: int,
	world_x: float,
	world_z: float,
	base_cell_size: float,
	warp_cell_size: float,
	warp_amplitude: float,
	octaves: int = 4
) -> float:
	var warp_x: float = (
		fractal_noise(seed + 17, world_x, world_z, warp_cell_size, 2) - 0.5
	) * warp_amplitude
	var warp_z: float = (
		fractal_noise(seed + 43, world_x, world_z, warp_cell_size, 2) - 0.5
	) * warp_amplitude
	return fractal_noise(
		seed,
		world_x + warp_x,
		world_z + warp_z,
		base_cell_size,
		octaves
	)


static func candidate_position(seed: int, cell_x: int, cell_z: int, cell_size: int) -> Vector2:
	var margin: float = float(cell_size) * 0.14
	var usable: float = float(cell_size) - margin * 2.0
	return Vector2(
		float(cell_x * cell_size) + margin
		+ WorldSeed.sample_unit(seed + 11, cell_x, cell_z) * usable,
		float(cell_z * cell_size) + margin
		+ WorldSeed.sample_unit(seed + 29, cell_x, cell_z) * usable
	)


static func blue_noise_accept(
	seed: int,
	cell_x: int,
	cell_z: int,
	cell_size: int,
	minimum_distance: float
) -> bool:
	var current: Vector2 = candidate_position(seed, cell_x, cell_z, cell_size)
	var current_priority: float = WorldSeed.sample_unit(seed + 47, cell_x, cell_z)
	var search_radius: int = ceili(minimum_distance / float(cell_size)) + 1
	var minimum_squared: float = minimum_distance * minimum_distance
	for neighbor_z: int in range(cell_z - search_radius, cell_z + search_radius + 1):
		for neighbor_x: int in range(cell_x - search_radius, cell_x + search_radius + 1):
			if neighbor_x == cell_x and neighbor_z == cell_z:
				continue
			var neighbor: Vector2 = candidate_position(seed, neighbor_x, neighbor_z, cell_size)
			if current.distance_squared_to(neighbor) >= minimum_squared:
				continue
			var neighbor_priority: float = WorldSeed.sample_unit(
				seed + 47, neighbor_x, neighbor_z
			)
			if neighbor_priority < current_priority:
				return false
			if is_equal_approx(neighbor_priority, current_priority):
				if neighbor_z < cell_z or (neighbor_z == cell_z and neighbor_x < cell_x):
					return false
	return true


static func forest_patch(seed: int, world_x: int, world_z: int) -> float:
	var broad: float = warped_noise(
		seed + 3101,
		float(world_x),
		float(world_z),
		74.0,
		176.0,
		44.0,
		4
	)
	var detail: float = fractal_noise(
		seed + 3181,
		float(world_x),
		float(world_z),
		31.0,
		3
	)
	return clampf(broad * 0.78 + detail * 0.22, 0.0, 1.0)


static func forest_density(
	seed: int,
	world_x: int,
	world_z: int,
	tree_habitat: float,
	moisture: float,
	temperature: float,
	elevation: float,
	slope: int,
	river_gap: float
) -> float:
	var patch: float = forest_patch(seed, world_x, world_z)
	var clearing: float = warped_noise(
		seed + 3253,
		float(world_x),
		float(world_z),
		27.0,
		91.0,
		21.0,
		3
	)
	var patch_cover: float = smoothstep(0.39, 0.73, patch)
	var clearing_cut: float = smoothstep(0.74, 0.92, clearing)
	var slope_factor: float = 1.0 - smoothstep(1.0, 2.25, float(slope))
	var river_factor: float = smoothstep(6.5, 17.0, river_gap)
	var climate_factor: float = clampf(
		0.68 + moisture * 0.42 - absf(temperature - 0.55) * 0.22,
		0.35,
		1.05
	)
	var elevation_factor: float = lerpf(1.0, 0.66, elevation)
	return clampf(
		tree_habitat
		* patch_cover
		* (1.0 - clearing_cut * 0.72)
		* slope_factor
		* river_factor
		* climate_factor
		* elevation_factor
		* 1.18,
		0.0,
		0.88
	)


static func conifer_probability(
	seed: int,
	world_x: int,
	world_z: int,
	moisture: float,
	temperature: float,
	elevation: float
) -> float:
	var species_patch: float = warped_noise(
		seed + 3323,
		float(world_x),
		float(world_z),
		58.0,
		151.0,
		31.0,
		3
	)
	return clampf(
		0.08
		+ (1.0 - temperature) * 0.36
		+ elevation * 0.43
		+ (1.0 - moisture) * 0.10
		+ (species_patch - 0.5) * 0.34,
		0.06,
		0.78
	)


static func tree_scale(
	seed: int,
	cell_x: int,
	cell_z: int,
	tree_habitat: float,
	moisture: float,
	elevation: float
) -> float:
	var variation: float = WorldSeed.sample_unit(seed + 3371, cell_x, cell_z)
	return lerpf(0.78, 1.26, variation) * lerpf(
		0.86,
		1.13,
		clampf(tree_habitat * 0.62 + moisture * 0.28 - elevation * 0.18, 0.0, 1.0)
	)


static func rock_density(
	seed: int,
	world_x: int,
	world_z: int,
	dryness: float,
	elevation: float,
	slope: int,
	river_gap: float
) -> float:
	var outcrop: float = warped_noise(
		seed + 3413,
		float(world_x),
		float(world_z),
		49.0,
		137.0,
		36.0,
		3
	)
	var outcrop_mask: float = smoothstep(0.58, 0.84, outcrop)
	var slope_factor: float = clampf(float(slope) * 0.28, 0.0, 0.48)
	var river_factor: float = smoothstep(7.5, 16.0, river_gap)
	return clampf(
		0.025
		+ outcrop_mask * 0.34
		+ dryness * 0.12
		+ elevation * 0.17
		+ slope_factor,
		0.0,
		0.62
	) * river_factor


static func ground_cover_density(
	seed: int,
	world_x: int,
	world_z: int,
	ground_cover: float,
	moisture: float,
	elevation: float,
	forest_density_value: float
) -> float:
	var meadow_patch: float = warped_noise(
		seed + 3491,
		float(world_x),
		float(world_z),
		36.0,
		113.0,
		25.0,
		3
	)
	var meadow_mask: float = smoothstep(0.36, 0.72, meadow_patch)
	var canopy_competition: float = 1.0 - forest_density_value * 0.58
	return clampf(
		(0.06 + ground_cover * 0.62 + meadow_mask * 0.28)
		* canopy_competition
		* lerpf(1.05, 0.72, elevation)
		* lerpf(0.72, 1.08, moisture),
		0.0,
		0.78
	)


static func forest_edge(seed: int, world_x: int, world_z: int) -> float:
	var patch: float = forest_patch(seed, world_x, world_z)
	return 1.0 - clampf(absf(patch - 0.56) / 0.24, 0.0, 1.0)
