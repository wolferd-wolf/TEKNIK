extends RefCounted
class_name TeknikVoxelTerrainGenerator

const WorldSeed = preload("res://src/world/world_seed.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const STONE: int = 1
const SOIL: int = 2
const GRASS: int = 3
const SAND: int = 4
const WATER_LEVEL: int = 7
const MAX_SURFACE_HEIGHT: int = 26


static func generate_chunk(seed: int, chunk_coordinate: Vector3i) -> TeknikVoxelChunk:
	var chunk := VoxelChunk.new()
	var world_origin: Vector3i = chunk_coordinate * VoxelChunk.SIZE

	for z: int in range(VoxelChunk.SIZE):
		for x: int in range(VoxelChunk.SIZE):
			var world_x: int = world_origin.x + x
			var world_z: int = world_origin.z + z
			var surface_y: int = surface_height(seed, world_x, world_z)
			var top_material: int = surface_material(seed, world_x, world_z)

			for y: int in range(VoxelChunk.SIZE):
				var world_y: int = world_origin.y + y
				if world_y > surface_y:
					continue
				var material: int = STONE
				if world_y == surface_y:
					material = top_material
				elif top_material == SAND and world_y >= surface_y - 3:
					material = SAND
				elif top_material != STONE and world_y >= surface_y - 2:
					material = SOIL
				chunk.set_voxel(Vector3i(x, y, z), material)

	return chunk


static func surface_height(seed: int, world_x: int, world_z: int) -> int:
	var continental: float = WorldSeed.sample_value_noise(
		seed + 19, float(world_x), float(world_z), 76.0
	)
	var rolling: float = WorldSeed.sample_value_noise(
		seed + 131, float(world_x), float(world_z), 31.0
	)
	var ridge_source: float = WorldSeed.sample_value_noise(
		seed + 283, float(world_x), float(world_z), 48.0
	)
	var ridge: float = pow(absf(ridge_source * 2.0 - 1.0), 1.7)
	var upland_height: float = (
		10.0
		+ continental * 9.0
		+ (rolling - 0.5) * 4.0
		+ ridge * 5.0
	)

	var distance_to_river: float = river_distance(seed, world_x, world_z)
	var valley_blend: float = smoothstep(4.0, 34.0, distance_to_river)
	var carved_height: float = lerpf(float(WATER_LEVEL - 2), upland_height, valley_blend)
	if distance_to_river < 4.0:
		carved_height = minf(carved_height, float(WATER_LEVEL - 2))
	return clampi(roundi(carved_height), 2, MAX_SURFACE_HEIGHT)


static func river_center_z(seed: int, world_x: int) -> float:
	var broad_meander: float = WorldSeed.sample_value_noise(
		seed + 541, float(world_x), 0.0, 68.0
	)
	var smaller_meander: float = WorldSeed.sample_value_noise(
		seed + 617, float(world_x), 0.0, 29.0
	)
	return (broad_meander - 0.5) * 30.0 + (smaller_meander - 0.5) * 8.0


static func river_distance(seed: int, world_x: int, world_z: int) -> float:
	return absf(float(world_z) - river_center_z(seed, world_x))


static func surface_slope(seed: int, world_x: int, world_z: int) -> int:
	var center: int = surface_height(seed, world_x, world_z)
	var steepest: int = 0
	steepest = maxi(steepest, absi(center - surface_height(seed, world_x + 1, world_z)))
	steepest = maxi(steepest, absi(center - surface_height(seed, world_x - 1, world_z)))
	steepest = maxi(steepest, absi(center - surface_height(seed, world_x, world_z + 1)))
	steepest = maxi(steepest, absi(center - surface_height(seed, world_x, world_z - 1)))
	return steepest


static func surface_material(seed: int, world_x: int, world_z: int) -> int:
	var height: int = surface_height(seed, world_x, world_z)
	if height <= WATER_LEVEL + 1:
		return SAND
	if height >= 21 or surface_slope(seed, world_x, world_z) >= 2:
		return STONE
	return GRASS
