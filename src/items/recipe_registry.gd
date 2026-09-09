extends RefCounted
class_name RecipeRegistry

## Shapeless recipe list. Every recipe: ingredients {id: count}, result [id, count],
## and `bench` flag meaning it requires proximity to a Crafting Bench.

const RECIPES: Array[Dictionary] = [
	{ "out": [BlockRegistry.PLANKS, 4], "in": { BlockRegistry.LOG: 1 }, "bench": false },
	{ "out": [ItemRegistry.STICK, 4], "in": { BlockRegistry.PLANKS: 2 }, "bench": false },
	{ "out": [BlockRegistry.CRAFTING_BENCH, 1], "in": { BlockRegistry.PLANKS: 4 }, "bench": false },
	{ "out": [ItemRegistry.WOOD_PICKAXE, 1], "in": { BlockRegistry.PLANKS: 3, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.WOOD_AXE, 1], "in": { BlockRegistry.PLANKS: 3, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.WOOD_SHOVEL, 1], "in": { BlockRegistry.PLANKS: 1, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.WOOD_SWORD, 1], "in": { BlockRegistry.PLANKS: 2, ItemRegistry.STICK: 1 }, "bench": true },
	{ "out": [ItemRegistry.STONE_PICKAXE, 1], "in": { BlockRegistry.COBBLESTONE: 3, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.STONE_AXE, 1], "in": { BlockRegistry.COBBLESTONE: 3, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.STONE_SHOVEL, 1], "in": { BlockRegistry.COBBLESTONE: 1, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.STONE_SWORD, 1], "in": { BlockRegistry.COBBLESTONE: 2, ItemRegistry.STICK: 1 }, "bench": true },
	{ "out": [ItemRegistry.IRON_PICKAXE, 1], "in": { ItemRegistry.IRON_INGOT: 3, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.IRON_AXE, 1], "in": { ItemRegistry.IRON_INGOT: 3, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.IRON_SHOVEL, 1], "in": { ItemRegistry.IRON_INGOT: 1, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.IRON_SWORD, 1], "in": { ItemRegistry.IRON_INGOT: 2, ItemRegistry.STICK: 1 }, "bench": true },
	{ "out": [ItemRegistry.DIAMOND_PICKAXE, 1], "in": { ItemRegistry.DIAMOND: 3, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.DIAMOND_AXE, 1], "in": { ItemRegistry.DIAMOND: 3, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.DIAMOND_SHOVEL, 1], "in": { ItemRegistry.DIAMOND: 1, ItemRegistry.STICK: 2 }, "bench": true },
	{ "out": [ItemRegistry.DIAMOND_SWORD, 1], "in": { ItemRegistry.DIAMOND: 2, ItemRegistry.STICK: 1 }, "bench": true },
	{ "out": [BlockRegistry.SANDSTONE, 1], "in": { BlockRegistry.SAND: 4 }, "bench": false },
	{ "out": [BlockRegistry.GLASS, 1], "in": { BlockRegistry.SAND: 2, BlockRegistry.COBBLESTONE: 1 }, "bench": true },
]


## Spruce planks come from the shared log recipe; normalize logs before matching.
static func normalize_ingredient(id: int) -> int:
	if id == BlockRegistry.SPRUCE_LOG:
		return BlockRegistry.LOG
	return id


static func can_craft(recipe: Dictionary, inv: Inventory, near_bench: bool) -> bool:
	if bool(recipe.get("bench", false)) and not near_bench:
		return false
	var need: Dictionary = recipe["in"]
	for id: int in need:
		if inv.count_of(normalize_ingredient(id)) < int(need[id]):
			return false
	return true


## Consumes ingredients. Caller must check can_craft() first; returns result stack.
static func craft(recipe: Dictionary, inv: Inventory) -> Array:
	var need: Dictionary = recipe["in"]
	for id: int in need:
		var removed := inv.remove(normalize_ingredient(id), int(need[id]))
		if removed < int(need[id]):
			push_error("RecipeRegistry.craft: consumed %d/%d of item %d" % [removed, need[id], id])
			return []
	var out: Array = recipe["out"]
	inv.add(out[0], out[1], ItemRegistry.tool_durability(out[0]))
	return out


static func find_by_output(id: int) -> Dictionary:
	for r: Dictionary in RECIPES:
		if int(r["out"][0]) == id:
			return r
	return {}


static func recipes_for(ids: Array) -> Array[Dictionary]:
	## Recipes whose ingredient set intersects `ids` (used to filter the crafting UI).
	var out: Array[Dictionary] = []
	for r: Dictionary in RECIPES:
		if ids.is_empty():
			out.append(r)
			continue
		for id: int in r["in"]:
			if ids.has(normalize_ingredient(id)):
				out.append(r)
				break
	return out


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for i in range(RECIPES.size()):
		var r: Dictionary = RECIPES[i]
		var out: Array = r["out"]
		if out.size() != 2 or not ItemRegistry.is_valid_any(int(out[0])):
			errors.append("recipe %d: invalid output" % i)
		if int(out[1]) < 1:
			errors.append("recipe %d: invalid output count" % i)
		var need: Dictionary = r["in"]
		if need.is_empty():
			errors.append("recipe %d: no ingredients" % i)
		for id: int in need:
			if not ItemRegistry.is_valid_any(id):
				errors.append("recipe %d: unknown ingredient %d" % [i, id])
			if int(need[id]) < 1:
				errors.append("recipe %d: ingredient %d count < 1" % [i, id])
	return errors
