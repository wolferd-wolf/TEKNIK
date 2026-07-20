extends RefCounted
class_name TeknikWorldSeed

## Deterministic coordinate sampling used by the world foundation.
## Value noise keeps neighboring terrain samples coherent while remaining cheap
## enough to evaluate during chunk generation on mobile hardware.
static func hash_2d(seed: int, x: int, z: int) -> int:
	var wrapped_x: int = x & 0x1fffff
	var wrapped_z: int = z & 0x1fffff
	var value: int = (wrapped_x * 374761393 + wrapped_z * 668265263 + seed * 69069) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return (value ^ (value >> 16)) & 0x7fffffff


static func sample_unit(seed: int, x: int, z: int) -> float:
	return float(hash_2d(seed, x, z) % 1_000_000) / 999_999.0


static func sample_value_noise(seed: int, x: float, z: float, cell_size: float) -> float:
	var grid_x: float = x / cell_size
	var grid_z: float = z / cell_size
	var x0: int = floori(grid_x)
	var z0: int = floori(grid_z)
	var blend_x: float = _smooth(grid_x - float(x0))
	var blend_z: float = _smooth(grid_z - float(z0))

	var north: float = lerpf(
		sample_unit(seed, x0, z0),
		sample_unit(seed, x0 + 1, z0),
		blend_x
	)
	var south: float = lerpf(
		sample_unit(seed, x0, z0 + 1),
		sample_unit(seed, x0 + 1, z0 + 1),
		blend_x
	)
	return lerpf(north, south, blend_z)


static func sample_preview_height(seed: int, x: int, z: int) -> float:
	var continental: float = sample_value_noise(seed + 97, float(x), float(z), 72.0)
	var rolling: float = sample_value_noise(seed + 211, float(x), float(z), 28.0)
	var detail: float = sample_value_noise(seed + 397, float(x), float(z), 11.0)
	return clampf(continental * 0.56 + rolling * 0.31 + detail * 0.13, 0.0, 1.0)


static func _smooth(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
