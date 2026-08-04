class_name TeknikFeatureDistribution
extends RefCounted

const WorldSeed = preload("res://src/world/world_seed.gd")

## Deterministic best-candidate sampling. Each cell owns one candidate, but a
## point survives only when its priority beats the eight neighboring cells.
## This produces seamless blue-noise-like spacing without storing world state.
static func is_local_winner(seed: int, cell_x: int, cell_z: int) -> bool:
	var priority: float = WorldSeed.sample_unit(seed, cell_x, cell_z)
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var neighbor: float = WorldSeed.sample_unit(seed, cell_x + dx, cell_z + dz)
			if neighbor > priority:
				return false
			if is_equal_approx(neighbor, priority) and (dx < 0 or (dx == 0 and dz < 0)):
				return false
	return true


static func candidate_position(seed: int, cell_x: int, cell_z: int, spacing: int) -> Vector2i:
	var inset: float = float(spacing) * 0.16
	var usable: float = float(spacing) - inset * 2.0
	var x: int = floori(float(cell_x * spacing) + inset + WorldSeed.sample_unit(seed + 17, cell_x, cell_z) * usable)
	var z: int = floori(float(cell_z * spacing) + inset + WorldSeed.sample_unit(seed + 31, cell_x, cell_z) * usable)
	return Vector2i(x, z)


static func forest_patch(seed: int, world_x: int, world_z: int) -> float:
	var broad: float = WorldSeed.sample_value_noise(seed + 401, float(world_x), float(world_z), 118.0)
	var medium: float = WorldSeed.sample_value_noise(seed + 419, float(world_x), float(world_z), 47.0)
	var gap: float = WorldSeed.sample_value_noise(seed + 443, float(world_x), float(world_z), 23.0)
	var patch: float = broad * 0.58 + medium * 0.42
	patch *= lerpf(0.58, 1.0, smoothstep(0.30, 0.72, gap))
	return clampf(patch, 0.0, 1.0)


static func understory_patch(seed: int, world_x: int, world_z: int) -> float:
	var broad: float = WorldSeed.sample_value_noise(seed + 467, float(world_x), float(world_z), 38.0)
	var fine: float = WorldSeed.sample_value_noise(seed + 479, float(world_x), float(world_z), 11.0)
	return clampf(broad * 0.72 + fine * 0.28, 0.0, 1.0)
