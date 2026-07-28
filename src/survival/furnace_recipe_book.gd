class_name TeknikFurnaceRecipeBook
extends RefCounted

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")

const RECIPES: Array[Dictionary] = [
	{"input": ItemRegistry.ITEM_ZINC_CONCENTRATE, "output": ItemRegistry.ITEM_ZINC_INGOT},
	{"input": ItemRegistry.ITEM_COPPER_CONCENTRATE, "output": ItemRegistry.ITEM_COPPER_INGOT},
	{"input": ItemRegistry.ITEM_IRON_CONCENTRATE, "output": ItemRegistry.ITEM_IRON_INGOT},
	{"input": ItemRegistry.ITEM_GOLD_CONCENTRATE, "output": ItemRegistry.ITEM_GOLD_INGOT},
]


static func recipes() -> Array[Dictionary]:
	return RECIPES.duplicate(true)


static func first_available(inventory: TeknikStackInventory) -> Dictionary:
	if inventory.count(ItemRegistry.ITEM_WOOD) < 1:
		return {}
	for definition: Dictionary in RECIPES:
		var input_item := StringName(str(definition.input))
		if inventory.count(input_item) > 0:
			return definition.duplicate(true)
	return {}


static func smelt_one(inventory: TeknikStackInventory) -> Dictionary:
	var definition: Dictionary = first_available(inventory)
	if definition.is_empty():
		return {}
	var input_item := StringName(str(definition.input))
	var output_item := StringName(str(definition.output))
	var trial := StackInventory.new()
	if not trial.decode(inventory.encode()):
		return {}
	if not trial.remove(ItemRegistry.ITEM_WOOD, 1):
		return {}
	if not trial.remove(input_item, 1):
		return {}
	if trial.add(output_item, 1) != 0:
		return {}
	if not inventory.decode(trial.encode()):
		return {}
	return {
		"fuel": ItemRegistry.ITEM_WOOD,
		"input": input_item,
		"output": output_item,
		"count": 1,
	}
