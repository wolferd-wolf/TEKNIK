extends RefCounted
class_name BlockRegistry

## Static, data-driven registry of every voxel block.
## Block ids 0..255 are reserved for blocks; items use ids >= 256 (see ItemRegistry).

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const COBBLESTONE := 4
const SAND := 5
const GRAVEL := 6
const LOG := 7
const LEAVES := 8
const PLANKS := 9
const GLASS := 10
const WATER := 11
const COAL_ORE := 12
const IRON_ORE := 13
const GOLD_ORE := 14
const DIAMOND_ORE := 15
const BEDROCK := 16
const SNOW := 17
const SANDSTONE := 18
const CACTUS := 19
const SPRUCE_LOG := 20
const SPRUCE_LEAVES := 21
const MOSSY_STONE := 22
const CRAFTING_BENCH := 23

enum Mat { SOIL, STONE, WOOD, LEAF, SAND, GLASS }

## Property set per block. Docs:
##  solid       - collides with bodies
##  opaque      - hides neighbouring faces completely
##  liquid      - rendered in transparent pass, no collision
##  cutout      - rendered in transparent pass with alpha (leaves/glass)
##  light       - emits light (reserved; not yet used by lighting)
##  hardness    - seconds to break by hand (roughly); scaled by tool speed
##  tool        - preferred tool class: "pickaxe" | "axe" | "shovel" | ""
##  min_tier    - minimum pickaxe tier required to obtain a drop (0 = none)
##  drop        - block/item id dropped (defaults to self, -1 = nothing)
##  tiles       - tile indices [ +x, -x, +y, -y, +z, -z ] into the atlas
##  mat         - material family (sound/step feedback)
##  stack       - max stack size when carried as an item

const DEFS := {
	AIR: {
		"name": "Air", "solid": false, "opaque": false, "liquid": false, "cutout": false,
		"light": 0, "hardness": 0.0, "tool": "", "min_tier": 0, "drop": -1,
		"tiles": [-1, -1, -1, -1, -1, -1], "mat": Mat.SOIL, "stack": 0,
	},
	GRASS: {
		"name": "Grass", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 0.9, "tool": "shovel", "min_tier": 0, "drop": BlockRegistry.DIRT,
		"tiles": [2, 2, 0, 3, 2, 2], "mat": Mat.SOIL, "stack": 99,
	},
	DIRT: {
		"name": "Dirt", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 0.75, "tool": "shovel", "min_tier": 0, "drop": BlockRegistry.DIRT,
		"tiles": [2, 2, 2, 2, 2, 2], "mat": Mat.SOIL, "stack": 99,
	},
	STONE: {
		"name": "Stone", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 2.25, "tool": "pickaxe", "min_tier": 1, "drop": BlockRegistry.COBBLESTONE,
		"tiles": [3, 3, 3, 3, 3, 3], "mat": Mat.STONE, "stack": 99,
	},
	COBBLESTONE: {
		"name": "Cobblestone", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 2.5, "tool": "pickaxe", "min_tier": 1, "drop": BlockRegistry.COBBLESTONE,
		"tiles": [4, 4, 4, 4, 4, 4], "mat": Mat.STONE, "stack": 99,
	},
	SAND: {
		"name": "Sand", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 0.6, "tool": "shovel", "min_tier": 0, "drop": BlockRegistry.SAND,
		"tiles": [5, 5, 5, 5, 5, 5], "mat": Mat.SAND, "stack": 99,
	},
	GRAVEL: {
		"name": "Gravel", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 0.8, "tool": "shovel", "min_tier": 0, "drop": BlockRegistry.GRAVEL,
		"tiles": [6, 6, 6, 6, 6, 6], "mat": Mat.SAND, "stack": 99,
	},
	LOG: {
		"name": "Wood Log", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 2.0, "tool": "axe", "min_tier": 0, "drop": BlockRegistry.LOG,
		"tiles": [7, 7, 8, 8, 7, 7], "mat": Mat.WOOD, "stack": 99,
	},
	LEAVES: {
		"name": "Leaves", "solid": true, "opaque": false, "liquid": false, "cutout": true,
		"light": 0, "hardness": 0.35, "tool": "", "min_tier": 0, "drop": -2,
		"tiles": [9, 9, 9, 9, 9, 9], "mat": Mat.LEAF, "stack": 99,
	},
	PLANKS: {
		"name": "Planks", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 1.6, "tool": "axe", "min_tier": 0, "drop": BlockRegistry.PLANKS,
		"tiles": [10, 10, 10, 10, 10, 10], "mat": Mat.WOOD, "stack": 99,
	},
	GLASS: {
		"name": "Glass", "solid": true, "opaque": false, "liquid": false, "cutout": true,
		"light": 0, "hardness": 0.5, "tool": "", "min_tier": 0, "drop": -1,
		"tiles": [11, 11, 11, 11, 11, 11], "mat": Mat.GLASS, "stack": 99,
	},
	WATER: {
		"name": "Water", "solid": false, "opaque": false, "liquid": true, "cutout": false,
		"light": 0, "hardness": -1.0, "tool": "", "min_tier": 0, "drop": -1,
		"tiles": [12, 12, 12, 12, 12, 12], "mat": Mat.SOIL, "stack": 0,
	},
	COAL_ORE: {
		"name": "Coal Ore", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 3.0, "tool": "pickaxe", "min_tier": 1, "drop": ItemRegistry.COAL,
		"tiles": [13, 13, 13, 13, 13, 13], "mat": Mat.STONE, "stack": 99,
	},
	IRON_ORE: {
		"name": "Iron Ore", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 3.5, "tool": "pickaxe", "min_tier": 2, "drop": ItemRegistry.RAW_IRON,
		"tiles": [14, 14, 14, 14, 14, 14], "mat": Mat.STONE, "stack": 99,
	},
	GOLD_ORE: {
		"name": "Gold Ore", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 3.5, "tool": "pickaxe", "min_tier": 3, "drop": ItemRegistry.RAW_GOLD,
		"tiles": [15, 15, 15, 15, 15, 15], "mat": Mat.STONE, "stack": 99,
	},
	DIAMOND_ORE: {
		"name": "Diamond Ore", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 4.0, "tool": "pickaxe", "min_tier": 3, "drop": ItemRegistry.DIAMOND,
		"tiles": [16, 16, 16, 16, 16, 16], "mat": Mat.STONE, "stack": 99,
	},
	BEDROCK: {
		"name": "Bedrock", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": -1.0, "tool": "", "min_tier": 0, "drop": -1,
		"tiles": [17, 17, 17, 17, 17, 17], "mat": Mat.STONE, "stack": 0,
	},
	SNOW: {
		"name": "Snow Block", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 0.5, "tool": "shovel", "min_tier": 0, "drop": BlockRegistry.SNOW,
		"tiles": [18, 18, 18, 19, 18, 18], "mat": Mat.SAND, "stack": 99,
	},
	SANDSTONE: {
		"name": "Sandstone", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 1.8, "tool": "pickaxe", "min_tier": 1, "drop": BlockRegistry.SANDSTONE,
		"tiles": [20, 20, 20, 20, 20, 20], "mat": Mat.STONE, "stack": 99,
	},
	CACTUS: {
		"name": "Cactus", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 0.6, "tool": "axe", "min_tier": 0, "drop": BlockRegistry.CACTUS,
		"tiles": [21, 21, 22, 22, 21, 21], "mat": Mat.WOOD, "stack": 99,
	},
	SPRUCE_LOG: {
		"name": "Spruce Log", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 2.0, "tool": "axe", "min_tier": 0, "drop": BlockRegistry.SPRUCE_LOG,
		"tiles": [23, 23, 8, 8, 23, 23], "mat": Mat.WOOD, "stack": 99,
	},
	SPRUCE_LEAVES: {
		"name": "Spruce Needles", "solid": true, "opaque": false, "liquid": false, "cutout": true,
		"light": 0, "hardness": 0.35, "tool": "", "min_tier": 0, "drop": -2,
		"tiles": [24, 24, 24, 24, 24, 24], "mat": Mat.LEAF, "stack": 99,
	},
	MOSSY_STONE: {
		"name": "Mossy Stone", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 2.5, "tool": "pickaxe", "min_tier": 1, "drop": BlockRegistry.MOSSY_STONE,
		"tiles": [27, 27, 27, 27, 27, 27], "mat": Mat.STONE, "stack": 99,
	},
	CRAFTING_BENCH: {
		"name": "Crafting Bench", "solid": true, "opaque": true, "liquid": false, "cutout": false,
		"light": 0, "hardness": 1.6, "tool": "axe", "min_tier": 0, "drop": BlockRegistry.CRAFTING_BENCH,
		"tiles": [25, 25, 26, 10, 25, 25], "mat": Mat.WOOD, "stack": 99,
	},
}

const MAT_NAMES := {
	Mat.SOIL: "soil", Mat.STONE: "stone", Mat.WOOD: "wood",
	Mat.LEAF: "leaf", Mat.SAND: "sand", Mat.GLASS: "glass",
}


static func is_valid(id: int) -> bool:
	return DEFS.has(id)


static func def(id: int) -> Dictionary:
	return DEFS[id]


static func name_of(id: int) -> String:
	if DEFS.has(id):
		return DEFS[id]["name"]
	return "Unknown(%d)" % id


static func is_solid(id: int) -> bool:
	return DEFS[id]["solid"] if DEFS.has(id) else false


static func is_opaque(id: int) -> bool:
	return DEFS[id]["opaque"] if DEFS.has(id) else false


static func is_liquid(id: int) -> bool:
	return DEFS[id]["liquid"] if DEFS.has(id) else false


static func is_cutout(id: int) -> bool:
	return DEFS[id]["cutout"] if DEFS.has(id) else false


static func is_air(id: int) -> bool:
	return id == AIR


static func hardness(id: int) -> float:
	return DEFS[id]["hardness"] if DEFS.has(id) else -1.0


static func min_tier(id: int) -> int:
	return DEFS[id]["min_tier"] if DEFS.has(id) else 0


static func drop_of(id: int) -> int:
	## -2 marks "leaf": caller resolves it randomly (sticks/fruit/nothing).
	if not DEFS.has(id):
		return -1
	return DEFS[id]["drop"]


static func mat_of(id: int) -> String:
	var m: int = DEFS[id]["mat"] if DEFS.has(id) else Mat.SOIL
	return MAT_NAMES[m]


static func tile_for(id: int, face: int) -> int:
	## face: 0=+x 1=-x 2=+y 3=-y 4=+z 5=-z
	return DEFS[id]["tiles"][face] if DEFS.has(id) else -1


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for id: int in DEFS:
		var d: Dictionary = DEFS[id]
		if String(d["name"]).is_empty():
			errors.append("block %d: empty name" % id)
		if d["tiles"].size() != 6:
			errors.append("block %d: tiles must have 6 entries" % id)
		for t: int in d["tiles"]:
			if t < -1 or t >= AtlasTiles.COLS * AtlasTiles.ROWS:
				errors.append("block %d: tile index %d out of range" % [id, t])
		if id != AIR and id != WATER and id != BEDROCK and float(d["hardness"]) <= 0.0:
			errors.append("block %d: breakable block with non-positive hardness" % id)
	return errors
