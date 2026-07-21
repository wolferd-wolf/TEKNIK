class_name TeknikSpawnPlanner
extends RefCounted

const WorldSeed = preload("res://src/world/world_seed.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")

const SEARCH_CANDIDATES: int = 72
const SEARCH_RADIUS_BLOCKS: int = 768


static func find_spawn(seed: int, salt: int) -> Vector3:
	var best_position := Vector3(0.5, float(TerrainGenerator.surface_height(seed, 0, 0)) + 2.5, 0.5)
	var best_score: float = INF
	for candidate_index: int in range(SEARCH_CANDIDATES):
		var sample_x: float = WorldSeed.sample_unit(seed + salt + 3109, candidate_index, salt & 0xffff)
		var sample_z: float = WorldSeed.sample_unit(seed + salt + 3251, salt & 0xffff, candidate_index)
		var world_x: int = roundi(lerpf(-float(SEARCH_RADIUS_BLOCKS), float(SEARCH_RADIUS_BLOCKS), sample_x))
		var world_z: int = roundi(lerpf(-float(SEARCH_RADIUS_BLOCKS), float(SEARCH_RADIUS_BLOCKS), sample_z))
		var height: int = TerrainGenerator.surface_height(seed, world_x, world_z)
		var slope: int = TerrainGenerator.surface_slope(seed, world_x, world_z)
		var river_gap: float = TerrainGenerator.river_distance(seed, world_x, world_z)
		var score: float = float(slope) * 24.0
		score += absf(float(height) - 15.0) * 0.7
		if height <= TerrainGenerator.WATER_LEVEL + 2:
			score += 200.0
		if river_gap < 12.0:
			score += (12.0 - river_gap) * 12.0
		if river_gap > 80.0:
			score += (river_gap - 80.0) * 0.05
		if score < best_score:
			best_score = score
			best_position = Vector3(float(world_x) + 0.5, float(height) + 2.5, float(world_z) + 0.5)
			if slope == 0 and height > TerrainGenerator.WATER_LEVEL + 3 and river_gap >= 18.0 and river_gap <= 64.0:
				break
	return best_position


static func chunk_coordinate(position: Vector3, chunk_size: int) -> Vector3i:
	return Vector3i(
		floori(position.x / float(chunk_size)),
		0,
		floori(position.z / float(chunk_size))
	)
