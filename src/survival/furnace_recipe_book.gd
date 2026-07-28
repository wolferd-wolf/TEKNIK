class_name TeknikFurnaceRecipeBook
extends RefCounted

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")

const FUEL_ITEM: StringName = ItemRegistry.ITEM_WOOD
const FUEL_PER_OPERATION: int = 1


static func recipe_ids() -> Array[StringName]:
	return RecipeBook.station_recipes(RecipeBook.STATION_FURNACE)


static func recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_id: StringName in recipe_ids():
		result.append(RecipeBook.recipe(recipe_id))
	return result


static func can_smelt(
	inventory: TeknikStackInventory,
	recipe_id: StringName,
	progression: TeknikProgressionState = null
) -> bool:
	if inventory.count(FUEL_ITEM) < FUEL_PER_OPERATION:
		return false
	return RecipeBook.can_craft_at_station(
		inventory,
		recipe_id,
		progression,
		RecipeBook.STATION_FURNACE
	)


static func first_available(
	inventory: TeknikStackInventory,
	progression: TeknikProgressionState = null
) -> Dictionary:
	for recipe_id: StringName in recipe_ids():
		if can_smelt(inventory, recipe_id, progression):
			return RecipeBook.recipe(recipe_id)
	return {}


static func smelt(
	inventory: TeknikStackInventory,
	recipe_id: StringName,
	progression: TeknikProgressionState = null
) -> Dictionary:
	if not can_smelt(inventory, recipe_id, progression):
		return {}
	var definition: Dictionary = RecipeBook.recipe(recipe_id)
	var trial := StackInventory.new()
	if not trial.decode(inventory.encode()):
		return {}
	if not trial.remove(FUEL_ITEM, FUEL_PER_OPERATION):
		return {}
	for item_variant: Variant in (definition.ingredients as Dictionary).keys():
		var item_id := StringName(str(item_variant))
		if not trial.remove(item_id, int(definition.ingredients[item_variant])):
			return {}
	var output_item := StringName(str(definition.output_item))
	var output_count: int = int(definition.output_count)
	if trial.add(output_item, output_count) != 0:
		return {}
	if not inventory.decode(trial.encode()):
		return {}
	if progression != null:
		var granted := StringName(str(definition.get("grants_unlock", "")))
		if granted != &"":
			progression.unlock(granted)
	return {
		"recipe": recipe_id,
		"fuel": FUEL_ITEM,
		"fuel_count": FUEL_PER_OPERATION,
		"ingredients": definition.ingredients,
		"output": output_item,
		"count": output_count,
		"source_process": str(definition.get("source_process", "Smelting")),
	}


static func smelt_one(
	inventory: TeknikStackInventory,
	progression: TeknikProgressionState = null
) -> Dictionary:
	var definition: Dictionary = first_available(inventory, progression)
	if definition.is_empty():
		return {}
	return smelt(inventory, StringName(str(definition.id)), progression)
