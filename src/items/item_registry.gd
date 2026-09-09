extends RefCounted
class_name ItemRegistry

## Items are non-block carryables. Ids >= 256 so they never collide with block ids.
## Every block id is also implicitly an item (see ItemDef helpers below).

const ID_BASE := 256

const STICK := ID_BASE + 0
const COAL := ID_BASE + 1
const RAW_IRON := ID_BASE + 2
const IRON_INGOT := ID_BASE + 3
const RAW_GOLD := ID_BASE + 4
const GOLD_INGOT := ID_BASE + 5
const DIAMOND := ID_BASE + 6
const APPLE := ID_BASE + 7
const RAW_MEAT := ID_BASE + 8
const WOOD_PICKAXE := ID_BASE + 10
const WOOD_AXE := ID_BASE + 11
const WOOD_SHOVEL := ID_BASE + 12
const WOOD_SWORD := ID_BASE + 13
const STONE_PICKAXE := ID_BASE + 14
const STONE_AXE := ID_BASE + 15
const STONE_SHOVEL := ID_BASE + 16
const STONE_SWORD := ID_BASE + 17
const IRON_PICKAXE := ID_BASE + 18
const IRON_AXE := ID_BASE + 19
const IRON_SHOVEL := ID_BASE + 20
const IRON_SWORD := ID_BASE + 21
const DIAMOND_PICKAXE := ID_BASE + 22
const DIAMOND_AXE := ID_BASE + 23
const DIAMOND_SHOVEL := ID_BASE + 24
const DIAMOND_SWORD := ID_BASE + 25

## Tool tiers: 0 hand, 1 wood, 2 stone, 3 iron, 4 diamond.
const TIERS := {
	WOOD_PICKAXE: 1, WOOD_AXE: 1, WOOD_SHOVEL: 1, WOOD_SWORD: 1,
	STONE_PICKAXE: 2, STONE_AXE: 2, STONE_SHOVEL: 2, STONE_SWORD: 2,
	IRON_PICKAXE: 3, IRON_AXE: 3, IRON_SHOVEL: 3, IRON_SWORD: 3,
	DIAMOND_PICKAXE: 4, DIAMOND_AXE: 4, DIAMOND_SHOVEL: 4, DIAMOND_SWORD: 4,
}

const TOOL_CLASS := {
	WOOD_PICKAXE: "pickaxe", WOOD_AXE: "axe", WOOD_SHOVEL: "shovel", WOOD_SWORD: "sword",
	STONE_PICKAXE: "pickaxe", STONE_AXE: "axe", STONE_SHOVEL: "shovel", STONE_SWORD: "sword",
	IRON_PICKAXE: "pickaxe", IRON_AXE: "axe", IRON_SHOVEL: "shovel", IRON_SWORD: "sword",
	DIAMOND_PICKAXE: "pickaxe", DIAMOND_AXE: "axe", DIAMOND_SHOVEL: "shovel", DIAMOND_SWORD: "sword",
}

const TOOL_SPEED := { 1: 2.0, 2: 4.0, 3: 6.0, 4: 8.0 }
const TOOL_DAMAGE := {
	WOOD_SWORD: 4.0, STONE_SWORD: 5.0, IRON_SWORD: 6.0, DIAMOND_SWORD: 7.0,
	WOOD_AXE: 3.0, STONE_AXE: 3.5, IRON_AXE: 4.0, DIAMOND_AXE: 5.0,
}
const TOOL_DURABILITY := { 1: 60, 2: 132, 3: 251, 4: 1562 }

const FOOD_VALUE := { APPLE: 20, RAW_MEAT: 30 }

## name / icon tile / stack size
const DEFS := {
	STICK: { "name": "Stick", "tile": 44, "stack": 99 },
	COAL: { "name": "Coal", "tile": 51, "stack": 99 },
	RAW_IRON: { "name": "Raw Iron", "tile": 14, "stack": 99 },
	IRON_INGOT: { "name": "Iron Ingot", "tile": 52, "stack": 99 },
	RAW_GOLD: { "name": "Raw Gold", "tile": 15, "stack": 99 },
	GOLD_INGOT: { "name": "Gold Ingot", "tile": 53, "stack": 99 },
	DIAMOND: { "name": "Diamond", "tile": 54, "stack": 99 },
	APPLE: { "name": "Apple", "tile": 45, "stack": 16 },
	RAW_MEAT: { "name": "Raw Meat", "tile": 46, "stack": 16 },
	WOOD_PICKAXE: { "name": "Wood Pickaxe", "tile": 28, "stack": 1 },
	WOOD_AXE: { "name": "Wood Axe", "tile": 29, "stack": 1 },
	WOOD_SHOVEL: { "name": "Wood Shovel", "tile": 30, "stack": 1 },
	WOOD_SWORD: { "name": "Wood Sword", "tile": 31, "stack": 1 },
	STONE_PICKAXE: { "name": "Stone Pickaxe", "tile": 32, "stack": 1 },
	STONE_AXE: { "name": "Stone Axe", "tile": 33, "stack": 1 },
	STONE_SHOVEL: { "name": "Stone Shovel", "tile": 34, "stack": 1 },
	STONE_SWORD: { "name": "Stone Sword", "tile": 35, "stack": 1 },
	IRON_PICKAXE: { "name": "Iron Pickaxe", "tile": 36, "stack": 1 },
	IRON_AXE: { "name": "Iron Axe", "tile": 37, "stack": 1 },
	IRON_SHOVEL: { "name": "Iron Shovel", "tile": 38, "stack": 1 },
	IRON_SWORD: { "name": "Iron Sword", "tile": 39, "stack": 1 },
	DIAMOND_PICKAXE: { "name": "Diamond Pickaxe", "tile": 40, "stack": 1 },
	DIAMOND_AXE: { "name": "Diamond Axe", "tile": 41, "stack": 1 },
	DIAMOND_SHOVEL: { "name": "Diamond Shovel", "tile": 42, "stack": 1 },
	DIAMOND_SWORD: { "name": "Diamond Sword", "tile": 43, "stack": 1 },
}


static func is_item(id: int) -> bool:
	return id >= ID_BASE and DEFS.has(id)


static func is_valid_any(id: int) -> bool:
	return BlockRegistry.is_valid(id) or is_item(id)


static func name_of(id: int) -> String:
	if is_item(id):
		return DEFS[id]["name"]
	return BlockRegistry.name_of(id)


static func stack_of(id: int) -> int:
	if is_item(id):
		return DEFS[id]["stack"]
	if BlockRegistry.is_valid(id):
		return BlockRegistry.def(id)["stack"]
	return 0


static func tile_of(id: int) -> int:
	if is_item(id):
		return DEFS[id]["tile"]
	if BlockRegistry.is_valid(id):
		return BlockRegistry.tile_for(id, 2)  # top tile as icon
	return -1


static func is_tool_item(id: int) -> bool:
	return TOOL_CLASS.has(id)


static func tool_class(id: int) -> String:
	return TOOL_CLASS.get(id, "")


static func tool_tier(id: int) -> int:
	return TIERS.get(id, 0)


static func tool_speed(id: int) -> float:
	if TOOL_CLASS.has(id):
		return TOOL_SPEED[tool_tier(id)]
	return 1.0


static func tool_damage(id: int) -> float:
	if TOOL_CLASS.has(id):
		return TOOL_DAMAGE.get(id, 1.0)
	return 1.0


static func tool_durability(id: int) -> int:
	if TOOL_CLASS.has(id):
		return TOOL_DURABILITY[tool_tier(id)]
	return 0


static func food_value(id: int) -> int:
	return FOOD_VALUE.get(id, 0)


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for id: int in DEFS:
		var d: Dictionary = DEFS[id]
		var t: int = d["tile"]
		if t < 0 or t >= AtlasTiles.COLS * AtlasTiles.ROWS:
			errors.append("item %d: tile %d out of range" % [id, t])
		if int(d["stack"]) < 1:
			errors.append("item %d: stack must be >= 1" % id)
	for id: int in TOOL_CLASS:
		if not DEFS.has(id):
			errors.append("tool %d missing from DEFS" % id)
		if not TOOL_DURABILITY.has(TIERS.get(id, 0)):
			errors.append("tool %d has invalid tier" % id)
	return errors
