extends RefCounted
class_name TeknikWorldSeed

## Small deterministic coordinate hash used by bootstrap data generation.
## The production generator will replace this with the hierarchical world plan.
static func hash_2d(seed: int, x: int, z: int) -> int:
	var wrapped_x: int = x & 0x1fffff
	var wrapped_z: int = z & 0x1fffff
	var value: int = (wrapped_x * 374761393 + wrapped_z * 668265263 + seed * 69069) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return (value ^ (value >> 16)) & 0x7fffffff


static func sample_unit(seed: int, x: int, z: int) -> float:
	return float(hash_2d(seed, x, z) % 1_000_000) / 999_999.0


static func sample_preview_height(seed: int, x: int, z: int) -> float:
	var broad_x: int = floori(float(x) / 4.0)
	var broad_z: int = floori(float(z) / 4.0)
	var local: float = sample_unit(seed, x, z)
	var broad: float = sample_unit(seed + 97, broad_x, broad_z)
	return local * 0.42 + broad * 0.58

