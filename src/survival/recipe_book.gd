class_name TeknikRecipeBook
extends RefCounted

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")

const RECIPE_STONE_GEAR: StringName = &"stone_gear"
const RECIPE_WORKBENCH: StringName = &"workbench"
const RECIPE_CRUSHED_STONE: StringName = &"crushed_stone"
const RECIPE_STONE_SHAFT: StringName = &"stone_shaft"
const RECIPE_HAND_CRANK: StringName = &"hand_crank"


static func registered_recipes() -> Array[StringName]:
	return [RECIPE_STONE_GEAR, RECIPE_WORKBENCH, RECIPE_CRUSHED_STONE, RECIPE_STONE_SHAFT, RECIPE_HAND_CRANK]


static func recipe(recipe_id: StringName) -> Dictionary:
	match recipe_id:
		RECIPE_STONE_GEAR:
			return _definition(recipe_id, "Stone Gear", "Components", {ItemRegistry.ITEM_STONE: 4}, ItemRegistry.ITEM_STONE_GEAR, 1, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_WORKBENCH:
			return _definition(recipe_id, "Stone Workbench", "Stations", {ItemRegistry.ITEM_STONE: 8, ItemRegistry.ITEM_STONE_GEAR: 1}, ItemRegistry.ITEM_WORKBENCH, 1, ProgressionState.UNLOCK_HAND_CRAFTING, ProgressionState.UNLOCK_WORKBENCH)
		RECIPE_CRUSHED_STONE:
			return _definition(recipe_id, "Crush Stone", "Processing", {ItemRegistry.ITEM_STONE: 2}, ItemRegistry.ITEM_CRUSHED_STONE, 3, ProgressionState.UNLOCK_WORKBENCH, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_STONE_SHAFT:
			return _definition(recipe_id, "Stone Shaft", "Components", {ItemRegistry.ITEM_CRUSHED_STONE: 2}, ItemRegistry.ITEM_STONE_SHAFT, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_HAND_CRANK:
			return _definition(recipe_id, "Hand Crank", "Kinetics", {ItemRegistry.ITEM_STONE_GEAR: 1, ItemRegistry.ITEM_STONE_SHAFT: 1}, ItemRegistry.ITEM_HAND_CRANK, 1, ProgressionState.UNLOCK_STONE_PROCESSING, ProgressionState.UNLOCK_KINETIC_STARTER)
		_:
			return {}


static func _definition(id: StringName, display: String, category: String, ingredients: Dictionary, output: StringName, count: int, required_unlock: StringName, grants_unlock: StringName = &"") -> Dictionary:
	return {"id": id, "display_name": display, "category": category, "ingredients": ingredients, "output_item": output, "output_count": count, "required_unlock": required_unlock, "grants_unlock": grants_unlock}


static func available_recipes(progression: TeknikProgressionState) -> Array[StringName]:
	var result: Array[StringName] = []
	for recipe_id: StringName in registered_recipes():
		var definition: Dictionary = recipe(recipe_id)
		if progression.is_unlocked(StringName(definition.required_unlock)):
			result.append(recipe_id)
	return result


static func can_craft(inventory: TeknikStackInventory, recipe_id: StringName, progression: TeknikProgressionState = null) -> bool:
	var definition: Dictionary = recipe(recipe_id)
	if definition.is_empty():
		return false
	if progression != null and not progression.is_unlocked(StringName(definition.required_unlock)):
		return false
	var trial := StackInventory.new()
	if not trial.decode(inventory.encode()):
		return false
	for item_variant: Variant in (definition.ingredients as Dictionary).keys():
		var item_id := StringName(str(item_variant))
		if not trial.remove(item_id, int(definition.ingredients[item_variant])):
			return false
	return trial.add(StringName(definition.output_item), int(definition.output_count)) == 0


static func craft(inventory: TeknikStackInventory, recipe_id: StringName, progression: TeknikProgressionState = null) -> bool:
	if not can_craft(inventory, recipe_id, progression):
		return false
	var definition: Dictionary = recipe(recipe_id)
	var trial := StackInventory.new()
	if not trial.decode(inventory.encode()):
		return false
	for item_variant: Variant in (definition.ingredients as Dictionary).keys():
		var item_id := StringName(str(item_variant))
		if not trial.remove(item_id, int(definition.ingredients[item_variant])):
			return false
	if trial.add(StringName(definition.output_item), int(definition.output_count)) != 0:
		return false
	if not inventory.decode(trial.encode()):
		return false
	if progression != null:
		var granted := StringName(str(definition.get("grants_unlock", "")))
		if granted != &"":
			progression.unlock(granted)
	return true
