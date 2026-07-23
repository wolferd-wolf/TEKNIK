class_name TeknikBiomeRegionField
extends RefCounted

const WorldSeed = preload("res://src/world/world_seed.gd")

# Large-scale fields deliberately use cell sizes much wider than a terrain chunk.
# This follows the established climate-map approach used by mature procedural
# worlds: broad climate zones first, then smaller local variation inside them.
const REGION_SCALE: float = 224.0
const CLIMATE_SCALE: float = 304.0
const TRANSITION_SCALE: float = 96.0


static func sample(seed: int, world_x: int, world_z: int) -> Dictionary:
	var x: float = float(world_x)
	var z: float = float(world_z)
	var region_a: float = WorldSeed.sample_value_noise(seed + 4013, x, z, REGION_SCALE)
	var region_b: float = WorldSeed.sample_value_noise(seed + 4091, x, z, REGION_SCALE * 1.31)
	var moisture_macro: float = WorldSeed.sample_value_noise(seed + 4153, x, z, CLIMATE_SCALE)
	var temperature_macro: float = WorldSeed.sample_value_noise(seed + 4211, x, z, CLIMATE_SCALE * 1.17)
	var local_transition: float = WorldSeed.sample_value_noise(seed + 4271, x, z, TRANSITION_SCALE)
	var rugged_macro: float = WorldSeed.sample_value_noise(seed + 4337, x, z, REGION_SCALE * 0.83)

	# Two broad fields are blended rather than thresholded. This prevents square
	# biome borders while keeping regions large enough to read during exploration.
	var region_identity: float = clampf(region_a * 0.62 + region_b * 0.38, 0.0, 1.0)
	var transition: float = clampf((local_transition - 0.5) * 0.24, -0.12, 0.12)
	return {
		"identity": region_identity,
		"moisture": clampf(moisture_macro + transition, 0.0, 1.0),
		"temperature": clampf(temperature_macro - transition * 0.55, 0.0, 1.0),
		"ruggedness": clampf(rugged_macro * 0.82 + region_identity * 0.18, 0.0, 1.0),
		"transition": local_transition,
	}


static func signature(seed: int, world_x: int, world_z: int) -> Vector4:
	var data: Dictionary = sample(seed, world_x, world_z)
	return Vector4(
		float(data.identity),
		float(data.moisture),
		float(data.temperature),
		float(data.ruggedness)
	)
