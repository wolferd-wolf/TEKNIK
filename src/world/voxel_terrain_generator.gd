extends RefCounted
class_name TeknikVoxelTerrainGenerator

const WorldSeed = preload("res://src/world/world_seed.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainDomainWarp = preload("res://src/world/terrain_domain_warp.gd")
const CaveDensity = preload("res://src/world/cave_density.gd")

const STONE: int = 1
const SOIL: int = 2
const GRASS: int = 3
const SAND: int = 4
const WATER_LEVEL: int = 7
const MAX_SURFACE_HEIGHT: int = 29
const COLUMN_BORDER: int = 1
const COLUMN_GRID_SIZE: int = VoxelChunk.SIZE + COLUMN_BORDER * 2


static func climate_at(seed: int, world_x: int, world_z: int) -> Vector2:
	var moisture: float = WorldSeed.sample_value_noise(seed + 1217, float(world_x), float(world_z), 92.0)
	var temperature: float = WorldSeed.sample_value_noise(seed + 1291, float(world_x), float(world_z), 138.0)
	return Vector2(moisture, temperature)


static func terrain_landmark_profile(seed: int, world_x: int, world_z: int) -> Vector3:
	var warped: Vector2 = TerrainDomainWarp.coordinates(seed, world_x, world_z)
	return _terrain_landmark_profile_at(seed, warped.x, warped.y)


static func _terrain_landmark_profile_at(seed: int, sample_x: float, sample_z: float) -> Vector3:
	var ridge_noise: float = WorldSeed.sample_value_noise(seed + 1709, sample_x, sample_z, 118.0)
	var ridge: float = pow(absf(ridge_noise * 2.0 - 1.0), 2.35)
	var basin_noise: float = WorldSeed.sample_value_noise(seed + 1783, sample_x, sample_z, 164.0)
	var basin: float = smoothstep(0.58, 0.84, basin_noise)
	var escarpment_noise: float = WorldSeed.sample_value_noise(seed + 1861, sample_x, sample_z, 76.0)
	var escarpment: float = smoothstep(0.60, 0.88, escarpment_noise) * ridge
	return Vector3(ridge, basin, escarpment)


static func terrain_surface_profile(seed: int, world_x: int, world_z: int) -> Vector3:
	var height: int = surface_height(seed, world_x, world_z)
	var landmark: Vector3 = terrain_landmark_profile(seed, world_x, world_z)
	return _terrain_surface_profile_from(seed, world_x, world_z, height, landmark)


static func _terrain_surface_profile_from(
	seed: int,
	world_x: int,
	world_z: int,
	height: int,
	landmark: Vector3
) -> Vector3:
	var climate: Vector2 = climate_at(seed, world_x, world_z)
	var elevation: float = clampf((float(height) - 9.0) / float(MAX_SURFACE_HEIGHT - 9), 0.0, 1.0)
	var river_gap: float = river_distance(seed, world_x, world_z)
	var wet_margin: float = (1.0 - smoothstep(5.0, 17.0, river_gap)) * smoothstep(0.26, 0.82, climate.x)
	var meadow_noise: float = WorldSeed.sample_value_noise(seed + 1999, float(world_x), float(world_z), 24.0)
	var meadow: float = smoothstep(0.46, 0.76, meadow_noise) * smoothstep(0.32, 0.78, climate.x) * (1.0 - elevation * 0.58)
	var scree_noise: float = WorldSeed.sample_value_noise(seed + 2081, float(world_x), float(world_z), 19.0)
	var ruggedness: float = clampf(landmark.x * 0.45 + landmark.z * 0.90 + elevation * 0.18, 0.0, 1.0)
	var scree: float = smoothstep(0.55, 0.84, scree_noise) * ruggedness
	return Vector3(meadow, wet_margin, scree)


static func vegetation_profile(seed: int, world_x: int, world_z: int) -> Vector3:
	var climate: Vector2 = climate_at(seed, world_x, world_z)
	var river_influence: float = 1.0 - smoothstep(8.0, 42.0, river_distance(seed, world_x, world_z))
	var effective_moisture: float = clampf(climate.x * 0.76 + river_influence * 0.38, 0.0, 1.0)
	var elevation: float = clampf((float(surface_height(seed, world_x, world_z)) - 9.0) / float(MAX_SURFACE_HEIGHT - 9), 0.0, 1.0)
	var temperate_comfort: float = 1.0 - absf(climate.y - 0.56) * 1.35
	var tree_habitat: float = clampf(
		smoothstep(0.30, 0.78, effective_moisture)
		* lerpf(0.72, 1.0, temperate_comfort)
		* lerpf(1.0, 0.62, elevation),
		0.0,
		1.0
	)
	var ground_cover: float = clampf(0.10 + effective_moisture * 0.88 - elevation * 0.18, 0.0, 1.0)
	return Vector3(tree_habitat, ground_cover, 1.0 - effective_moisture)


static func surface_color(seed: int, material: int, world_position: Vector3i) -> Color:
	var climate: Vector2 = climate_at(seed, world_position.x, world_position.z)
	var elevation: float = clampf((float(world_position.y) - 8.0) / float(MAX_SURFACE_HEIGHT - 8), 0.0, 1.0)
	var landmark: Vector3 = terrain_landmark_profile(seed, world_position.x, world_position.z)
	var surface: Vector3 = _terrain_surface_profile_from(
		seed, world_position.x, world_position.z, world_position.y, landmark
	)
	var micro: float = WorldSeed.sample_value_noise(seed + 2143, float(world_position.x), float(world_position.z), 8.0)
	var micro_tint: float = (micro - 0.5) * 0.10
	match material:
		GRASS:
			var dry_grass := Color("777442")
			var meadow_grass := Color("477544")
			var cool_upland := Color("456653")
			var lush_meadow := Color("4f8148")
			var wet_grass := Color("365f43")
			var grass: Color = dry_grass.lerp(meadow_grass, smoothstep(0.28, 0.72, climate.x))
			grass = grass.lerp(cool_upland, elevation * (0.22 + (1.0 - climate.y) * 0.28))
			grass = grass.lerp(lush_meadow, surface.x * 0.52)
			grass = grass.lerp(wet_grass, surface.y * 0.46)
			return grass.lightened(maxf(0.0, micro_tint)).darkened(maxf(0.0, -micro_tint))
		SOIL:
			var soil: Color = Color("674735").lerp(Color("493f38"), elevation * 0.34)
			soil = soil.lerp(Color("3e3b35"), surface.y * 0.42)
			return soil.lightened(maxf(0.0, micro_tint * 0.5)).darkened(maxf(0.0, -micro_tint * 0.5))
		SAND:
			var sand: Color = Color("aa8c55").lerp(Color("8d815e"), climate.x * 0.22)
			var wet_sand := Color("736b55")
			sand = sand.lerp(wet_sand, surface.y * 0.72)
			return sand.lightened(maxf(0.0, micro_tint * 0.38)).darkened(maxf(0.0, -micro_tint * 0.38))
		STONE:
			var base_stone := Color("596562").lerp(Color("7d8782"), elevation * 0.42)
			var strata_phase: float = fposmod(float(world_position.y) + micro * 3.0, 5.0) / 5.0
			var strata_strength: float = smoothstep(0.08, 0.42, absf(strata_phase - 0.5))
			base_stone = base_stone.lerp(Color("4c5655"), landmark.z * 0.25)
			base_stone = base_stone.lerp(Color("879087"), strata_strength * 0.16)
			base_stone = base_stone.lerp(Color("555b58"), surface.z * 0.30)
			return base_stone.lightened(maxf(0.0, micro_tint * 0.32)).darkened(maxf(0.0, -micro_tint * 0.32))
		_:
			return Color("8c7e69")


static func fast_surface_color(seed: int, material: int, world_position: Vector3i) -> Color:
	var elevation: float = clampf((float(world_position.y) - 8.0) / float(MAX_SURFACE_HEIGHT - 8), 0.0, 1.0)
	var micro: float = WorldSeed.sample_unit(seed + 2143, world_position.x * 3 + world_position.y, world_position.z * 3 - world_position.y)
	var tint: float = (micro - 0.5) * 0.09
	var color: Color
	match material:
		GRASS:
			color = Color("4d7543").lerp(Color("456653"), elevation * 0.38)
		SOIL:
			color = Color("604536").lerp(Color("493f38"), elevation * 0.34)
		SAND:
			var wetness: float = 1.0 - smoothstep(5.0, 18.0, river_distance(seed, world_position.x, world_position.z))
			color = Color("a58c5c").lerp(Color("746b54"), wetness * 0.62)
		STONE:
			var strata: float = fposmod(float(world_position.y) + micro * 2.0, 5.0) / 5.0
			color = Color("5d6865").lerp(Color("7c8580"), elevation * 0.36 + absf(strata - 0.5) * 0.12)
		_:
			color = Color("8c7e69")
	return color.lightened(maxf(0.0, tint)).darkened(maxf(0.0, -tint))


static func generate_chunk(seed: int, chunk_coordinate: Vector3i) -> TeknikVoxelChunk:
	var chunk := VoxelChunk.new()
	var world_origin: Vector3i = chunk_coordinate * VoxelChunk.SIZE
	var heights := PackedInt32Array()
	var ridges := PackedFloat32Array()
	var escarpments := PackedFloat32Array()
	var river_gaps := PackedFloat32Array()
	var grid_volume: int = COLUMN_GRID_SIZE * COLUMN_GRID_SIZE
	heights.resize(grid_volume)
	ridges.resize(grid_volume)
	escarpments.resize(grid_volume)
	river_gaps.resize(grid_volume)

	for grid_z: int in range(COLUMN_GRID_SIZE):
		for grid_x: int in range(COLUMN_GRID_SIZE):
			var world_x: int = world_origin.x + grid_x - COLUMN_BORDER
			var world_z: int = world_origin.z + grid_z - COLUMN_BORDER
			var profile: Vector4 = _terrain_height_profile(seed, world_x, world_z)
			var grid_index: int = grid_z * COLUMN_GRID_SIZE + grid_x
			heights[grid_index] = int(profile.x)
			ridges[grid_index] = profile.y
			escarpments[grid_index] = profile.z
			river_gaps[grid_index] = profile.w

	for z: int in range(VoxelChunk.SIZE):
		for x: int in range(VoxelChunk.SIZE):
			var grid_x: int = x + COLUMN_BORDER
			var grid_z: int = z + COLUMN_BORDER
			var grid_index: int = grid_z * COLUMN_GRID_SIZE + grid_x
			var height: int = heights[grid_index]
			var slope: int = 0
			slope = maxi(slope, absi(height - heights[grid_index - 1]))
			slope = maxi(slope, absi(height - heights[grid_index + 1]))
			slope = maxi(slope, absi(height - heights[grid_index - COLUMN_GRID_SIZE]))
			slope = maxi(slope, absi(height - heights[grid_index + COLUMN_GRID_SIZE]))
			var top_material: int = _surface_material_from_cached(
				height,
				slope,
				ridges[grid_index],
				escarpments[grid_index],
				river_gaps[grid_index]
			)
			var column := Vector2i(height, top_material)
			var highest_solid_local_y: int = mini(VoxelChunk.SIZE - 1, height - world_origin.y)
			if highest_solid_local_y < 0:
				continue
			for y: int in range(highest_solid_local_y + 1):
				var world_position := Vector3i(
					world_origin.x + x,
					world_origin.y + y,
					world_origin.z + z
				)
				var material: int = material_at(seed, world_position, column)
				if material != VoxelChunk.AIR:
					chunk.voxels[VoxelChunk.index_of(Vector3i(x, y, z))] = material
	chunk.revision = 1
	return chunk


static func surface_height(seed: int, world_x: int, world_z: int) -> int:
	return int(_terrain_height_profile(seed, world_x, world_z).x)


static func _terrain_height_profile(seed: int, world_x: int, world_z: int) -> Vector4:
	var warped: Vector2 = TerrainDomainWarp.coordinates(seed, world_x, world_z)
	var continental: float = WorldSeed.sample_value_noise(seed + 19, warped.x, warped.y, 88.0)
	var rolling: float = WorldSeed.sample_value_noise(seed + 131, warped.x, warped.y, 34.0)
	var detail: float = WorldSeed.sample_value_noise(seed + 227, warped.x, warped.y, 17.0)
	var landmark: Vector3 = _terrain_landmark_profile_at(seed, warped.x, warped.y)
	var upland_height: float = (
		10.0
		+ continental * 7.5
		+ (rolling - 0.5) * 3.5
		+ (detail - 0.5) * 1.25
		+ landmark.x * 7.5
		+ landmark.z * 2.5
		- landmark.y * 3.0
	)
	var distance_to_river: float = river_distance(seed, world_x, world_z)
	var channel_floor: float = float(WATER_LEVEL - 2)
	var inner_bank: float = smoothstep(3.5, 9.5, distance_to_river)
	var outer_bank: float = smoothstep(9.5, 27.0, distance_to_river)
	var bank_height: float = lerpf(channel_floor, float(WATER_LEVEL + 2), inner_bank)
	var carved_height: float = lerpf(bank_height, upland_height, outer_bank)
	if distance_to_river < 3.5:
		carved_height = minf(carved_height, channel_floor)
	return Vector4(
		float(clampi(roundi(carved_height), 2, MAX_SURFACE_HEIGHT)),
		landmark.x,
		landmark.z,
		distance_to_river
	)


static func river_center_z(seed: int, world_x: int) -> float:
	var broad_meander: float = WorldSeed.sample_value_noise(seed + 541, float(world_x), 0.0, 74.0)
	var smaller_meander: float = WorldSeed.sample_value_noise(seed + 617, float(world_x), 0.0, 31.0)
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


static func material_at(seed: int, world_position: Vector3i, column: Vector2i) -> int:
	var material: int = material_from_column(world_position.y, column)
	if material == VoxelChunk.AIR:
		return material
	if CaveDensity.should_carve(seed, world_position, column.x):
		return VoxelChunk.AIR
	return material


static func _surface_material_for_height(seed: int, world_x: int, world_z: int, height: int) -> int:
	var river_gap: float = river_distance(seed, world_x, world_z)
	if height <= WATER_LEVEL + 1 or (river_gap < 10.5 and height <= WATER_LEVEL + 3):
		return SAND
	var slope: int = surface_slope(seed, world_x, world_z)
	var landmark: Vector3 = terrain_landmark_profile(seed, world_x, world_z)
	return _surface_material_from_cached(height, slope, landmark.x, landmark.z, river_gap)


static func _surface_material_from_cached(
	height: int,
	slope: int,
	ridge: float,
	escarpment: float,
	river_gap: float
) -> int:
	if height <= WATER_LEVEL + 1 or (river_gap < 10.5 and height <= WATER_LEVEL + 3):
		return SAND
	if slope >= 2 and (height >= 15 or escarpment > 0.38):
		return STONE
	if height >= 24 and ridge > 0.62:
		return STONE
	return GRASS


static func voxel_at(seed: int, world_position: Vector3i) -> int:
	if world_position.y < 0:
		return STONE
	var column: Vector2i = sample_column(seed, world_position.x, world_position.z)
	return material_at(seed, world_position, column)


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
