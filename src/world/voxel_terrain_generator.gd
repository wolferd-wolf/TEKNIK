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


static func climate_at(seed: int, world_x: int, world_z: int) -> Vector2:
	var moisture: float = WorldSeed.sample_value_noise(
		seed + 1217, float(world_x), float(world_z), 92.0
	)
	var temperature: float = WorldSeed.sample_value_noise(
		seed + 1291, float(world_x), float(world_z), 138.0
	)
	return Vector2(moisture, temperature)


static func surface_color(
	seed: int,
	material: int,
	world_position: Vector3i
) -> Color:
	var climate: Vector2 = climate_at(seed, world_position.x, world_position.z)
	var elevation: float = clampf(
		(float(world_position.y) - 8.0) / float(MAX_SURFACE_HEIGHT - 8),
		0.0,
		1.0
	)
	match material:
		GRASS:
			var dry_grass := Color("777442")
			var meadow_grass := Color("477544")
			var cool_upland := Color("456653")
			var grass: Color = dry_grass.lerp(meadow_grass, smoothstep(0.28, 0.72, climate.x))
			return grass.lerp(cool_upland, elevation * (0.22 + (1.0 - climate.y) * 0.28))
		SOIL:
			return Color("674735").lerp(Color("493f38"), elevation * 0.34)
		SAND:
			return Color("aa8c55").lerp(Color("8d815e"), climate.x * 0.22)
		STONE:
			return Color("626d6b").lerp(Color("77817d"), elevation * 0.3)
		_:
			return Color("8c7e69")


static func generate_chunk(seed: int, chunk_coordinate: Vector3i) -> TeknikVoxelChunk:
	var chunk := VoxelChunk.new()
	var world_origin: Vector3i = chunk_coordinate * VoxelChunk.SIZE

	for z: int in range(VoxelChunk.SIZE):
		for x: int in range(VoxelChunk.SIZE):
			var world_x: int = world_origin.x + x
			var world_z: int = world_origin.z + z
			var column: Vector2i = sample_column(seed, world_x, world_z)
			var height: int = column.x
			var top_material: int = column.y
			var highest_solid_local_y: int = mini(
				VoxelChunk.SIZE - 1,
				height - world_origin.y
			)
			for y: int in range(maxi(0, highest_solid_local_y + 1)):
				var local_position := Vector3i(x, y, z)
				var world_y: int = world_origin.y + y
				var material: int = _material_at_height(world_y, height, top_material)
				if material != VoxelChunk.AIR:
					chunk.set_voxel(local_position, material)

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
		+ continental * 8.0
		+ (rolling - 0.5) * 4.0
		+ ridge * 6.0
	)

	var distance_to_river: float = river_distance(seed, world_x, world_z)
	var valley_blend: float = smoothstep(4.0, 20.0, distance_to_river)
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
	return _surface_material_for_height(seed, world_x, world_z, height)


static func sample_column(seed: int, world_x: int, world_z: int) -> Vector2i:
	var height: int = surface_height(seed, world_x, world_z)
	return Vector2i(height, _surface_material_for_height(seed, world_x, world_z, height))


static func material_from_column(world_y: int, column: Vector2i) -> int:
	return _material_at_height(world_y, column.x, column.y)


static func _surface_material_for_height(
	seed: int,
	world_x: int,
	world_z: int,
	height: int
) -> int:
	if height <= WATER_LEVEL + 1:
		return SAND
	if height >= 22 and surface_slope(seed, world_x, world_z) >= 2:
		return STONE
	return GRASS


static func voxel_at(seed: int, world_position: Vector3i) -> int:
	if world_position.y < 0:
		return STONE
	var column: Vector2i = sample_column(seed, world_position.x, world_position.z)
	return material_from_column(world_position.y, column)


static func _material_at_height(world_y: int, height: int, top_material: int) -> int:
	if world_y > height:
		return VoxelChunk.AIR
	if world_y == height:
		return top_material
	if top_material == SAND and world_y >= height - 3:
		return SAND
	if top_material != STONE and world_y >= height - 2:
		return SOIL
	return STONE
