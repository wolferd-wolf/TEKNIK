class_name TeknikRecipeBook
extends RefCounted

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")

const RECIPE_STONE_GEAR: StringName = &"stone_gear"


static func registered_recipes() -> Array[StringName]:
	return [RECIPE_STONE_GEAR]


static func recipe(recipe_id: StringName) -> Dictionary:
	match recipe_id:
		RECIPE_STONE_GEAR:
			return {
				"id": RECIPE_STONE_GEAR,
				"display_name": "Stone Gear",
				"ingredients": {ItemRegistry.ITEM_STONE: 4},
				"output_item": ItemRegistry.ITEM_STONE_GEAR,
				"output_count": 1,
			}
		_:
			return {}


static func can_craft(inventory: TeknikStackInventory, recipe_id: StringName) -> bool:
	var definition: Dictionary = recipe(recipe_id)
	if definition.is_empty():
		return false
	var ingredients: Dictionary = definition.ingredients
	for item_variant: Variant in ingredients.keys():
		var item_id := StringName(str(item_variant))
		if inventory.count(item_id) < int(ingredients[item_variant]):
			return false
	var trial := StackInventory.new()
	if not trial.decode(inventory.encode()):
		return false
	for item_variant: Variant in ingredients.keys():
		var item_id := StringName(str(item_variant))
		if not trial.remove(item_id, int(ingredients[item_variant])):
			return false
	return trial.add(
		StringName(definition.output_item),
		int(definition.output_count)
	) == 0


static func craft(inventory: TeknikStackInventory, recipe_id: StringName) -> bool:
	if not can_craft(inventory, recipe_id):
		return false
	var definition: Dictionary = recipe(recipe_id)
	var trial := StackInventory.new()
	if not trial.decode(inventory.encode()):
		return false
	var ingredients: Dictionary = definition.ingredients
	for item_variant: Variant in ingredients.keys():
		var item_id := StringName(str(item_variant))
		if not trial.remove(item_id, int(ingredients[item_variant])):
			return false
	if trial.add(StringName(definition.output_item), int(definition.output_count)) != 0:
		return false
	return inventory.decode(trial.encode())
