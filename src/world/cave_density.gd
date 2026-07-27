extends RefCounted
class_name TeknikCaveDensity

# Original fixed-point 3D value-noise cave field. The design uses the same broad
# idea as common 3D-noise voxel caves, but no external implementation or assets.
# Integer interpolation keeps Godot and the Rust worker byte-for-byte consistent.
const FIXED_SCALE: int = 4096
const NOISE_MID: int = 32768
const TUNNEL_BAND_A: int = 8000
const TUNNEL_BAND_B: int = 10000
const CHAMBER_THRESHOLD: int = 61500
const MIN_WORLD_Y: int = 2
const SURFACE_ROOF: int = 4


static func should_carve(seed: int, world_position: Vector3i, surface_height: int) -> bool:
	var depth: int = surface_height - world_position.y
	if world_position.y < MIN_WORLD_Y or depth < SURFACE_ROOF:
		return false

	# Fade the tunnel bands near both the bedrock floor and protected surface roof.
	var safety: int = mini(depth - (SURFACE_ROOF - 1), world_position.y - 1)
	var band_a: int = mini(TUNNEL_BAND_A, 5000 + safety * 700)
	var band_b: int = mini(TUNNEL_BAND_B, 6500 + safety * 800)
	var stretched_y: int = world_position.y * 2
	var field_a: int = sample_noise_3d(
		seed + 3001,
		world_position.x,
		stretched_y,
		world_position.z,
		18
	)
	var field_b: int = sample_noise_3d(
		seed + 3019,
		world_position.x + 7,
		stretched_y - 5,
		world_position.z - 11,
		23
	)
	var tunnel: bool = (
		absi(field_a - NOISE_MID) < band_a
		and absi(field_b - NOISE_MID) < band_b
	)
	if tunnel:
		return true

	# Sparse lower-frequency pockets widen selected tunnel intersections into rooms.
	if depth < 8 or world_position.y < 3:
		return false
	var chamber_field: int = sample_noise_3d(
		seed + 3079,
		world_position.x,
		world_position.y,
		world_position.z,
		30
	)
	if chamber_field <= CHAMBER_THRESHOLD:
		return false
	var chamber_detail: int = sample_noise_3d(
		seed + 3137,
		world_position.x - 19,
		world_position.y,
		world_position.z + 13,
		15
	)
	return chamber_detail > 40000


static func sample_noise_3d(
	seed: int,
	world_x: int,
	world_y: int,
	world_z: int,
	cell_size: int
) -> int:
	var cell_x: int = _floor_div(world_x, cell_size)
	var cell_y: int = _floor_div(world_y, cell_size)
	var cell_z: int = _floor_div(world_z, cell_size)
	var remainder_x: int = world_x - cell_x * cell_size
	var remainder_y: int = world_y - cell_y * cell_size
	var remainder_z: int = world_z - cell_z * cell_size
	var blend_x: int = _smooth_fixed(remainder_x, cell_size)
	var blend_y: int = _smooth_fixed(remainder_y, cell_size)
	var blend_z: int = _smooth_fixed(remainder_z, cell_size)

	var x00: int = _lerp_fixed(
		_sample_hash(seed, cell_x, cell_y, cell_z),
		_sample_hash(seed, cell_x + 1, cell_y, cell_z),
		blend_x
	)
	var x10: int = _lerp_fixed(
		_sample_hash(seed, cell_x, cell_y + 1, cell_z),
		_sample_hash(seed, cell_x + 1, cell_y + 1, cell_z),
		blend_x
	)
	var x01: int = _lerp_fixed(
		_sample_hash(seed, cell_x, cell_y, cell_z + 1),
		_sample_hash(seed, cell_x + 1, cell_y, cell_z + 1),
		blend_x
	)
	var x11: int = _lerp_fixed(
		_sample_hash(seed, cell_x, cell_y + 1, cell_z + 1),
		_sample_hash(seed, cell_x + 1, cell_y + 1, cell_z + 1),
		blend_x
	)
	var y0: int = _lerp_fixed(x00, x10, blend_y)
	var y1: int = _lerp_fixed(x01, x11, blend_y)
	return _lerp_fixed(y0, y1, blend_z)


static func _sample_hash(seed: int, x: int, y: int, z: int) -> int:
	var wrapped_x: int = x & 0x1fffff
	var wrapped_y: int = y & 0x1fffff
	var wrapped_z: int = z & 0x1fffff
	var value: int = (
		wrapped_x * 374761393
		+ wrapped_y * 1442695041
		+ wrapped_z * 668265263
		+ seed * 69069
	) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return ((value ^ (value >> 16)) & 0x7fffffff) & 0xffff


static func _floor_div(value: int, divisor: int) -> int:
	return floori(float(value) / float(divisor))


static func _smooth_fixed(remainder: int, cell_size: int) -> int:
	var t: int = floori(float(remainder * FIXED_SCALE) / float(cell_size))
	return floori(
		float(t * t * (3 * FIXED_SCALE - 2 * t))
		/ float(FIXED_SCALE * FIXED_SCALE)
	)


static func _lerp_fixed(from: int, to: int, weight: int) -> int:
	# int() truncates toward zero, matching Rust's signed integer division.
	return from + int(float((to - from) * weight) / float(FIXED_SCALE))
