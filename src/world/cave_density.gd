extends RefCounted
class_name TeknikCaveDensity

# Deterministic worm-carved cave field. Expensive density noise is no longer
# evaluated for every solid voxel. A bounded set of seed-derived paths is
# rasterized into one reusable mask per chunk, so generation cost follows worm
# count and path length instead of underground world volume.
const CHUNK_SIZE: int = 32
const CHUNK_VOLUME: int = CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE
const REGION_SIZE: int = 48
const WORMS_PER_REGION: int = 2
const WORM_STEPS: int = 18
const MAX_RADIUS: int = 4
const MAX_REACH: int = WORM_STEPS * 3 + MAX_RADIUS + 2
const MIN_WORLD_Y: int = 2
const SURFACE_ROOF: int = 4
const MASK_CACHE_LIMIT: int = 48

static var _mask_cache: Dictionary = {}
static var _mask_order: Array[String] = []


static func should_carve(seed: int, world_position: Vector3i, surface_height: int) -> bool:
	var depth: int = surface_height - world_position.y
	if world_position.y < MIN_WORLD_Y or depth < SURFACE_ROOF:
		return false
	var chunk_coordinate := Vector3i(
		_floor_div(world_position.x, CHUNK_SIZE),
		_floor_div(world_position.y, CHUNK_SIZE),
		_floor_div(world_position.z, CHUNK_SIZE)
	)
	var local_position: Vector3i = world_position - chunk_coordinate * CHUNK_SIZE
	var index: int = _index_of(local_position.x, local_position.y, local_position.z)
	var mask: PackedByteArray = chunk_mask(seed, chunk_coordinate)
	return index >= 0 and index < mask.size() and int(mask[index]) != 0


static func mask_carves(
	mask: PackedByteArray,
	index: int,
	world_y: int,
	surface_height: int
) -> bool:
	if world_y < MIN_WORLD_Y or surface_height - world_y < SURFACE_ROOF:
		return false
	return index >= 0 and index < mask.size() and int(mask[index]) != 0


static func chunk_mask(seed: int, chunk_coordinate: Vector3i) -> PackedByteArray:
	var key: String = "%d:%d:%d:%d" % [
		seed,
		chunk_coordinate.x,
		chunk_coordinate.y,
		chunk_coordinate.z,
	]
	if _mask_cache.has(key):
		return _mask_cache[key] as PackedByteArray
	var mask: PackedByteArray = _build_chunk_mask(seed, chunk_coordinate)
	_mask_cache[key] = mask
	_mask_order.append(key)
	if _mask_order.size() > MASK_CACHE_LIMIT:
		var evicted: String = _mask_order.pop_front()
		_mask_cache.erase(evicted)
	return mask


static func clear_cache() -> void:
	_mask_cache.clear()
	_mask_order.clear()


static func _build_chunk_mask(seed: int, chunk_coordinate: Vector3i) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(CHUNK_VOLUME)
	mask.fill(0)
	var world_origin: Vector3i = chunk_coordinate * CHUNK_SIZE
	var min_region_x: int = _floor_div(world_origin.x - MAX_REACH, REGION_SIZE)
	var max_region_x: int = _floor_div(
		world_origin.x + CHUNK_SIZE - 1 + MAX_REACH,
		REGION_SIZE
	)
	var min_region_z: int = _floor_div(world_origin.z - MAX_REACH, REGION_SIZE)
	var max_region_z: int = _floor_div(
		world_origin.z + CHUNK_SIZE - 1 + MAX_REACH,
		REGION_SIZE
	)
	for region_z: int in range(min_region_z, max_region_z + 1):
		for region_x: int in range(min_region_x, max_region_x + 1):
			for worm_index: int in range(WORMS_PER_REGION):
				_rasterize_worm(
					mask,
					world_origin,
					seed,
					region_x,
					region_z,
					worm_index
				)
	return mask


static func _rasterize_worm(
	mask: PackedByteArray,
	world_origin: Vector3i,
	seed: int,
	region_x: int,
	region_z: int,
	worm_index: int
) -> void:
	var worm_seed: int = seed + 4001 + worm_index * 977
	if worm_index > 0 and (_sample_hash(worm_seed, region_x, worm_index, region_z) & 3) == 0:
		return
	var region_origin_x: int = region_x * REGION_SIZE
	var region_origin_z: int = region_z * REGION_SIZE
	var start_span: int = REGION_SIZE - 16
	var center := Vector3i(
		region_origin_x + 8 + _sample_hash(worm_seed + 11, region_x, worm_index, region_z) % start_span,
		4 + _sample_hash(worm_seed + 37, region_x, worm_index, region_z) % 13,
		region_origin_z + 8 + _sample_hash(worm_seed + 23, region_x, worm_index, region_z) % start_span
	)
	var heading: int = _sample_hash(worm_seed + 41, region_x, worm_index, region_z) % 8
	for step: int in range(WORM_STEPS):
		var step_hash: int = _sample_hash(
			worm_seed + step * 53,
			region_x,
			step + worm_index * 31,
			region_z
		)
		var radius: int = 2 + (step_hash & 1)
		if step % 7 == 3 and ((step_hash >> 3) & 3) == 3:
			radius = MAX_RADIUS
		_carve_sphere(mask, world_origin, center, radius)

		var turn: int = (step_hash >> 5) % 5
		if turn == 0:
			heading = (heading + 7) % 8
		elif turn == 4:
			heading = (heading + 1) % 8
		var vertical_step: int = int((step_hash >> 9) % 3) - 1
		if center.y <= 5 and vertical_step < 0:
			vertical_step = 0
		elif center.y >= 18 and vertical_step > 0:
			vertical_step = 0
		var direction: Vector2i = _direction(heading)
		center += Vector3i(direction.x, vertical_step, direction.y)


static func _carve_sphere(
	mask: PackedByteArray,
	world_origin: Vector3i,
	center: Vector3i,
	radius: int
) -> void:
	if (
		center.x + radius < world_origin.x
		or center.x - radius >= world_origin.x + CHUNK_SIZE
		or center.y + radius < world_origin.y
		or center.y - radius >= world_origin.y + CHUNK_SIZE
		or center.z + radius < world_origin.z
		or center.z - radius >= world_origin.z + CHUNK_SIZE
	):
		return
	var min_x: int = maxi(0, center.x - radius - world_origin.x)
	var max_x: int = mini(CHUNK_SIZE - 1, center.x + radius - world_origin.x)
	var min_y: int = maxi(0, center.y - radius - world_origin.y)
	var max_y: int = mini(CHUNK_SIZE - 1, center.y + radius - world_origin.y)
	var min_z: int = maxi(0, center.z - radius - world_origin.z)
	var max_z: int = mini(CHUNK_SIZE - 1, center.z + radius - world_origin.z)
	var radius_squared: int = radius * radius
	for local_y: int in range(min_y, max_y + 1):
		var delta_y: int = world_origin.y + local_y - center.y
		for local_z: int in range(min_z, max_z + 1):
			var delta_z: int = world_origin.z + local_z - center.z
			for local_x: int in range(min_x, max_x + 1):
				var delta_x: int = world_origin.x + local_x - center.x
				if delta_x * delta_x + delta_y * delta_y + delta_z * delta_z <= radius_squared:
					mask[_index_of(local_x, local_y, local_z)] = 1


static func _direction(heading: int) -> Vector2i:
	match heading & 7:
		0:
			return Vector2i(3, 0)
		1:
			return Vector2i(2, 2)
		2:
			return Vector2i(0, 3)
		3:
			return Vector2i(-2, 2)
		4:
			return Vector2i(-3, 0)
		5:
			return Vector2i(-2, -2)
		6:
			return Vector2i(0, -3)
		_:
			return Vector2i(2, -2)


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
	return (value ^ (value >> 16)) & 0x7fffffff


static func _floor_div(value: int, divisor: int) -> int:
	return floori(float(value) / float(divisor))


static func _index_of(x: int, y: int, z: int) -> int:
	return x + CHUNK_SIZE * (z + CHUNK_SIZE * y)
