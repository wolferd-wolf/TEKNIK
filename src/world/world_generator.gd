extends RefCounted
class_name WorldGenerator

## Deterministic terrain + structure generation for one chunk.
## Never mutates shared state: identical (seed, chunk) always yields identical voxels,
## including cross-chunk structures (trees are decided per world column, clipped per chunk).

const BIOME_PLAINS := 0
const BIOME_FOREST := 1
const BIOME_DESERT := 2
const BIOME_MOUNTAINS := 3
const BIOME_TAIGA := 4
const BIOME_OCEAN := 5

const BIOME_NAMES := {
	BIOME_PLAINS: "Plains", BIOME_FOREST: "Forest", BIOME_DESERT: "Desert",
	BIOME_MOUNTAINS: "Mountains", BIOME_TAIGA: "Taiga", BIOME_OCEAN: "Ocean",
}

var noise: FBM
var world_seed: int


func _init(p_seed: int) -> void:
	world_seed = p_seed
	noise = FBM.new(p_seed)


static func hash2(seed: int, x: int, z: int, salt: int = 0) -> int:
	var h := seed ^ (x * 374761393) ^ (z * 668265263) ^ (salt * 2246822519)
	h = (h ^ (h >> 13)) * 1274126177
	h = (h ^ (h >> 16)) & 0x7FFFFFFF
	return h


static func hash_unit(seed: int, x: int, z: int, salt: int = 0) -> float:
	return float(hash2(seed, x, z, salt) & 0xFFFFFF) / float(0x1000000)


func biome_at(x: int, z: int) -> int:
	var h := noise.height_at(x, z)
	var t := noise.temperature(x, z)
	var r := noise.rainfall(x, z)
	if h <= Chunk.SEA_LEVEL - 1:
		return BIOME_OCEAN
	if h >= 74:
		return BIOME_MOUNTAINS
	if t > 0.25 and r < -0.05:
		return BIOME_DESERT
	if t < -0.3:
		return BIOME_TAIGA
	if r > 0.12:
		return BIOME_FOREST
	return BIOME_PLAINS


## Tree candidate density per world column (0..1). 0 = none.
func _tree_chance(biome: int) -> float:
	match biome:
		BIOME_FOREST: return 0.045
		BIOME_TAIGA: return 0.035
		BIOME_PLAINS: return 0.006
		BIOME_DESERT: return 0.004   # cacti
		BIOME_MOUNTAINS: return 0.004
		_: return 0.0


## Generates voxel data for the chunk at (cx, cz) into `chunk`.
func generate_chunk(chunk: Chunk) -> void:
	var origin_x := chunk.cx * Chunk.SIZE
	var origin_z := chunk.cz * Chunk.SIZE
	chunk.blocks.fill(BlockRegistry.AIR)

	# --- terrain columns
	for lz in range(Chunk.SIZE):
		for lx in range(Chunk.SIZE):
			var wx := origin_x + lx
			var wz := origin_z + lz
			_fill_column(chunk, lx, lz, wx, wz)

	# --- caves (skip: already carved inside _fill_column for cache locality)

	# --- cross-chunk structures (trees/cacti whose canopy may overhang this chunk)
	var margin := 3  # max structure radius in blocks
	var min_cx := int(floor(float(origin_x - margin) / Chunk.SIZE))
	var max_cx := int(floor(float(origin_x + Chunk.SIZE - 1 + margin) / Chunk.SIZE))
	var min_cz := int(floor(float(origin_z - margin) / Chunk.SIZE))
	var max_cz := int(floor(float(origin_z + Chunk.SIZE - 1 + margin) / Chunk.SIZE))
	for scz in range(min_cz, max_cz + 1):
		for scx in range(min_cx, max_cx + 1):
			_stamp_structures(chunk, scx, scz)

	# --- rare underground ruin rooms
	_stamp_ruin(chunk)

	chunk.max_y = mini(chunk.max_y + 1, Chunk.HEIGHT - 1)
	chunk.generated = true


func _fill_column(chunk: Chunk, lx: int, lz: int, wx: int, wz: int) -> void:
	var h := noise.height_at(wx, wz)
	var biome := biome_at(wx, wz)
	var is_ocean := h <= Chunk.SEA_LEVEL - 1

	var surface := BlockRegistry.GRASS
	var sub := BlockRegistry.DIRT
	var sub_depth := 3
	if h <= Chunk.SEA_LEVEL + 1 and biome != BIOME_MOUNTAINS:
		# beaches / shallow water beds
		surface = BlockRegistry.SAND
		sub = BlockRegistry.SAND
		sub_depth = 3
	match biome:
		BIOME_DESERT:
			surface = BlockRegistry.SAND
			sub = BlockRegistry.SANDSTONE
			sub_depth = 4
		BIOME_TAIGA:
			surface = BlockRegistry.SNOW
			sub = BlockRegistry.DIRT
		BIOME_MOUNTAINS:
			surface = BlockRegistry.STONE if h >= 84 else BlockRegistry.SNOW
			sub = BlockRegistry.STONE
		BIOME_OCEAN:
			surface = BlockRegistry.SAND if h > Chunk.SEA_LEVEL - 7 else BlockRegistry.GRAVEL
			sub = BlockRegistry.SAND

	for y in range(0, h + 1):
		var id: int
		if y == 0:
			id = BlockRegistry.BEDROCK
		elif y <= 2 and WorldGenerator.hash_unit(world_seed, wx * 7 + y, wz * 13, 91) < 0.55:
			id = BlockRegistry.BEDROCK
		elif y == h:
			id = surface
		elif y >= h - sub_depth:
			id = sub
		else:
			id = BlockRegistry.STONE
			id = _ore_or_stone(wx, y, wz)
		# caves carve stone/dirt but never bedrock or the sea floor under water
		if id != BlockRegistry.BEDROCK and y > 4 and not (is_ocean and y >= h - 2):
			if noise.cave_density(wx, y, wz):
				continue
		chunk.set_block(lx, y, lz, id)

	# water fill up to sea level
	if is_ocean:
		for y in range(h + 1, Chunk.SEA_LEVEL + 1):
			chunk.set_block(lx, y, lz, BlockRegistry.WATER)


func _ore_or_stone(x: int, y: int, z: int) -> int:
	var n := noise.ore_noise(x, y, z)
	if n > 0.72 and y < 52:
		# cluster type by depth + position hash
		var r := WorldGenerator.hash_unit(world_seed ^ 777, x, z + y * 31, 5)
		if y < 14 and r > 0.94:
			return BlockRegistry.DIAMOND_ORE
		if y < 22 and r > 0.86:
			return BlockRegistry.GOLD_ORE
		if y < 44 and r > 0.62:
			return BlockRegistry.IRON_ORE
		return BlockRegistry.COAL_ORE
	if n < -0.78 and WorldGenerator.hash_unit(world_seed ^ 555, x, z, 9) > 0.6:
		return BlockRegistry.GRAVEL
	return BlockRegistry.STONE


## Decides and stamps the structures owned by chunk (scx, scz) into `chunk`
## (only the blocks that actually fall inside `chunk` are written).
func _stamp_structures(chunk: Chunk, scx: int, scz: int) -> void:
	var count := 0
	# each chunk owns 8 structure candidates at hashed positions
	for i in range(8):
		var r1 := WorldGenerator.hash_unit(world_seed ^ 31337, scx, scz, i * 4 + 1)
		if r1 > 0.5:
			continue  # ~50% of candidates exist
		var wx := scx * Chunk.SIZE + int(WorldGenerator.hash_unit(world_seed ^ 4242, scx, scz, i * 4 + 3) * 16.0) % Chunk.SIZE
		var wz := scz * Chunk.SIZE + int(WorldGenerator.hash_unit(world_seed ^ 4242, scx, scz, i * 4 + 4) * 16.0) % Chunk.SIZE
		var biome := biome_at(wx, wz)
		var chance := _tree_chance(biome)
		if chance <= 0.0:
			continue
		var roll := WorldGenerator.hash_unit(world_seed ^ 999, wx, wz, i)
		if roll >= chance * 8.0:
			continue
		var h := noise.height_at(wx, wz)
		if h <= Chunk.SEA_LEVEL or h >= Chunk.HEIGHT - 24:
			continue
		# ground must not be caved out directly under the trunk
		if noise.cave_density(wx, h, wz):
			continue
		match biome:
			BIOME_DESERT:
				_stamp_cactus(chunk, wx, h, wz)
			BIOME_TAIGA:
				_stamp_spruce(chunk, wx, h, wz, WorldGenerator.hash2(world_seed, wx, wz, i))
			_:
				_stamp_oak(chunk, wx, h, wz, WorldGenerator.hash2(world_seed, wx, wz, i))
		count += 1
		if count >= 2:
			break


func _put_if_inside(chunk: Chunk, wx: int, wy: int, wz: int, id: int, replace_air_only: bool = true) -> void:
	var lx := wx - chunk.cx * Chunk.SIZE
	var lz := wz - chunk.cz * Chunk.SIZE
	if not Chunk.in_bounds(lx, wy, lz):
		return
	if replace_air_only:
		var cur := chunk.get_block(lx, wy, lz)
		if cur != BlockRegistry.AIR and cur != BlockRegistry.LEAVES and cur != BlockRegistry.SPRUCE_LEAVES:
			return
	chunk.set_block(lx, wy, lz, id)


func _stamp_oak(chunk: Chunk, wx: int, ground: int, wz: int, h: int) -> void:
	var trunk_h := 4 + (h % 3)
	var top := ground + trunk_h
	for y in range(ground + 1, top + 1):
		_put_if_inside(chunk, wx, y, wz, BlockRegistry.LOG, false)
	for dy in range(-2, 2):
		var radius := 2 if dy < 0 else 1
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if dx == 0 and dz == 0 and dy < 0:
					continue
				# clip corners for a rounder canopy
				if absi(dx) == radius and absi(dz) == radius and (h + dy) % 2 == 0:
					continue
				_put_if_inside(chunk, wx + dx, top + dy, wz + dz, BlockRegistry.LEAVES)


func _stamp_spruce(chunk: Chunk, wx: int, ground: int, wz: int, h: int) -> void:
	var trunk_h := 6 + (h % 3)
	var top := ground + trunk_h
	for y in range(ground + 1, top + 1):
		_put_if_inside(chunk, wx, y, wz, BlockRegistry.SPRUCE_LOG, false)
	var dy := 0
	var radius := 2
	while top - dy > ground + 2:
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if absi(dx) == radius and absi(dz) == radius:
					continue
				_put_if_inside(chunk, wx + dx, top - dy, wz + dz, BlockRegistry.SPRUCE_LEAVES)
		dy += 2
		radius = 1 if radius == 2 else 2
	_put_if_inside(chunk, wx, top + 1, wz, BlockRegistry.SPRUCE_LEAVES)


func _stamp_cactus(chunk: Chunk, wx: int, ground: int, wz: int) -> void:
	var ch := 2 + (WorldGenerator.hash2(world_seed, wx, wz, 77) % 3)
	for y in range(ground + 1, ground + 1 + ch):
		_put_if_inside(chunk, wx, y, wz, BlockRegistry.CACTUS, false)


## Rare underground mossy-stone rooms, deterministic per 16x16-chunk region.
func _stamp_ruin(chunk: Chunk) -> void:
	const REGION := 16  # chunks per region
	var rx := int(floor(float(chunk.cx) / REGION))
	var rz := int(floor(float(chunk.cz) / REGION))
	var r := WorldGenerator.hash_unit(world_seed ^ 60660, rx, rz, 13)
	if r > 0.35:
		return
	# room center in world coords
	var center_wx := rx * REGION * Chunk.SIZE + int(WorldGenerator.hash_unit(world_seed ^ 60661, rx, rz, 14) * REGION * Chunk.SIZE)
	var center_wz := rz * REGION * Chunk.SIZE + int(WorldGenerator.hash_unit(world_seed ^ 60662, rx, rz, 15) * REGION * Chunk.SIZE)
	var cy := 10 + int(WorldGenerator.hash_unit(world_seed ^ 60663, rx, rz, 16) * 26.0)
	var half := 3 + int(WorldGenerator.hash_unit(world_seed ^ 60664, rx, rz, 17) * 3.0)
	for dx in range(-half, half + 1):
		for dz in range(-half, half + 1):
			for dy in range(0, 5):
				var edge := absi(dx) == half or absi(dz) == half or dy == 0 or dy == 4
				var id := BlockRegistry.MOSSY_STONE if edge else BlockRegistry.AIR
				if edge and dx == 0 and dz == 0 and dy == 4:
					id = BlockRegistry.GLASS  # skylight
				if not edge and dy == 0:
					id = BlockRegistry.STONE  # floor
				_put_if_inside(chunk, center_wx + dx, cy + dy, center_wz + dz, id, false)


static func validate_determinism(p_seed: int, samples: int = 3) -> bool:
	## Generates a few chunks twice and compares voxel hashes.
	for i in range(samples):
		var a := Chunk.new(i, -i)
		var b := Chunk.new(i, -i)
		WorldGenerator.new(p_seed).generate_chunk(a)
		WorldGenerator.new(p_seed).generate_chunk(b)
		if a.compute_hash() != b.compute_hash():
			return false
	return true
