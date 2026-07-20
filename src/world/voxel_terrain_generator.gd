extends RefCounted
class_name TeknikVoxelTerrainGenerator

const WorldSeed = preload("res://src/world/world_seed.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const STONE: int = 1
const SOIL: int = 2
const SURFACE: int = 3


static func generate_chunk(seed: int, chunk_coordinate: Vector3i) -> TeknikVoxelChunk:
	var chunk := VoxelChunk.new()
	var world_origin: Vector3i = chunk_coordinate * VoxelChunk.SIZE

	for z: int in range(VoxelChunk.SIZE):
		for x: int in range(VoxelChunk.SIZE):
			var world_x: int = world_origin.x + x
			var world_z: int = world_origin.z + z
			var terrain_sample: float = WorldSeed.sample_preview_height(seed, world_x, world_z)
			var surface_y: int = floori(terrain_sample * 3.0)

			for y: int in range(VoxelChunk.SIZE):
				var world_y: int = world_origin.y + y
				if world_y > surface_y:
					continue
				var material: int = STONE
				if world_y == surface_y:
					material = SURFACE
				elif world_y >= surface_y - 2:
					material = SOIL
				chunk.set_voxel(Vector3i(x, y, z), material)

	return chunk
