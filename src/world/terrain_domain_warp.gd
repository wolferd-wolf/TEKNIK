class_name TeknikTerrainDomainWarp
extends RefCounted

const WorldSeed = preload("res://src/world/world_seed.gd")

const BROAD_CELL: float = 192.0
const DETAIL_CELL: float = 83.0
const BROAD_AMPLITUDE: float = 18.0
const DETAIL_AMPLITUDE: float = 6.0


static func offset(seed: int, world_x: int, world_z: int) -> Vector2:
	var broad_x: float = WorldSeed.sample_value_noise(
		seed + 2_401, float(world_x), float(world_z), BROAD_CELL
	) * 2.0 - 1.0
	var broad_z: float = WorldSeed.sample_value_noise(
		seed + 2_417, float(world_x), float(world_z), BROAD_CELL
	) * 2.0 - 1.0
	var detail_x: float = WorldSeed.sample_value_noise(
		seed + 2_443, float(world_x), float(world_z), DETAIL_CELL
	) * 2.0 - 1.0
	var detail_z: float = WorldSeed.sample_value_noise(
		seed + 2_459, float(world_x), float(world_z), DETAIL_CELL
	) * 2.0 - 1.0
	return Vector2(
		broad_x * BROAD_AMPLITUDE + detail_x * DETAIL_AMPLITUDE,
		broad_z * BROAD_AMPLITUDE + detail_z * DETAIL_AMPLITUDE
	)


static func coordinates(seed: int, world_x: int, world_z: int) -> Vector2:
	var displacement: Vector2 = offset(seed, world_x, world_z)
	return Vector2(float(world_x), float(world_z)) + displacement


static func sample_value_noise(
	seed: int,
	world_x: int,
	world_z: int,
	cell_size: float,
	seed_offset: int = 0
) -> float:
	var warped: Vector2 = coordinates(seed, world_x, world_z)
	return WorldSeed.sample_value_noise(
		seed + seed_offset,
		warped.x,
		warped.y,
		cell_size
	)
