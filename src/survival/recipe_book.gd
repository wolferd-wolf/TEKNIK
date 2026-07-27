class_name TeknikRecipeBook
extends RefCounted

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")

const RECIPE_STONE_GEAR: StringName = &"stone_gear"
const RECIPE_WORKBENCH: StringName = &"workbench"
const RECIPE_PLANT_FIBER: StringName = &"plant_fiber"
const RECIPE_CRUSHED_STONE: StringName = &"crushed_stone"
const RECIPE_ZINC_CONCENTRATE: StringName = &"zinc_concentrate"
const RECIPE_COPPER_CONCENTRATE: StringName = &"copper_concentrate"
const RECIPE_IRON_CONCENTRATE: StringName = &"iron_concentrate"
const RECIPE_GOLD_CONCENTRATE: StringName = &"gold_concentrate"
const RECIPE_ZINC_INGOT: StringName = &"zinc_ingot"
const RECIPE_COPPER_INGOT: StringName = &"copper_ingot"
const RECIPE_IRON_INGOT: StringName = &"iron_ingot"
const RECIPE_GOLD_INGOT: StringName = &"gold_ingot"
const RECIPE_ANDESITE_ALLOY: StringName = &"andesite_alloy"
const RECIPE_BRASS_INGOT: StringName = &"brass_ingot"
const RECIPE_COPPER_SHEET: StringName = &"copper_sheet"
const RECIPE_IRON_SHEET: StringName = &"iron_sheet"
const RECIPE_GOLD_SHEET: StringName = &"gold_sheet"
const RECIPE_BRASS_SHEET: StringName = &"brass_sheet"
const RECIPE_STONE_SHAFT: StringName = &"stone_shaft"
const RECIPE_SHAFT: StringName = &"shaft"
const RECIPE_COGWHEEL: StringName = &"cogwheel"
const RECIPE_LARGE_COGWHEEL: StringName = &"large_cogwheel"
const RECIPE_BELT_CONNECTOR: StringName = &"belt_connector"
const RECIPE_ANDESITE_CASING: StringName = &"andesite_casing"
const RECIPE_BRASS_CASING: StringName = &"brass_casing"
const RECIPE_HAND_CRANK: StringName = &"hand_crank"
const RECIPE_MECHANICAL_BEARING: StringName = &"mechanical_bearing"
const RECIPE_WRENCH: StringName = &"wrench"
const RECIPE_ELECTRON_TUBE: StringName = &"electron_tube"
const RECIPE_PRECISION_MECHANISM: StringName = &"precision_mechanism"
const RECIPE_EMPTY_BLAZE_BURNER: StringName = &"empty_blaze_burner"
const RECIPE_STONE_CRUSHER: StringName = &"stone_crusher"


static func registered_recipes() -> Array[StringName]:
	return [
		RECIPE_STONE_GEAR, RECIPE_WORKBENCH, RECIPE_PLANT_FIBER,
		RECIPE_CRUSHED_STONE, RECIPE_ZINC_CONCENTRATE, RECIPE_COPPER_CONCENTRATE,
		RECIPE_IRON_CONCENTRATE, RECIPE_GOLD_CONCENTRATE,
		RECIPE_ZINC_INGOT, RECIPE_COPPER_INGOT, RECIPE_IRON_INGOT,
		RECIPE_GOLD_INGOT, RECIPE_ANDESITE_ALLOY, RECIPE_BRASS_INGOT,
		RECIPE_COPPER_SHEET, RECIPE_IRON_SHEET, RECIPE_GOLD_SHEET,
		RECIPE_BRASS_SHEET, RECIPE_STONE_SHAFT, RECIPE_SHAFT,
		RECIPE_COGWHEEL, RECIPE_LARGE_COGWHEEL, RECIPE_BELT_CONNECTOR,
		RECIPE_ANDESITE_CASING, RECIPE_BRASS_CASING, RECIPE_HAND_CRANK,
		RECIPE_MECHANICAL_BEARING, RECIPE_WRENCH, RECIPE_ELECTRON_TUBE,
		RECIPE_PRECISION_MECHANISM, RECIPE_EMPTY_BLAZE_BURNER,
		RECIPE_STONE_CRUSHER,
	]


static func recipe(recipe_id: StringName) -> Dictionary:
	match recipe_id:
		RECIPE_STONE_GEAR:
			return _definition(recipe_id, "Stone Gear", "Primitive Components", {ItemRegistry.ITEM_STONE: 4}, ItemRegistry.ITEM_STONE_GEAR, 1, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_WORKBENCH:
			return _definition(recipe_id, "Stone Workbench", "Stations", {ItemRegistry.ITEM_STONE: 8, ItemRegistry.ITEM_STONE_GEAR: 1}, ItemRegistry.ITEM_WORKBENCH, 1, ProgressionState.UNLOCK_HAND_CRAFTING, ProgressionState.UNLOCK_WORKBENCH)
		RECIPE_PLANT_FIBER:
			return _definition(recipe_id, "Separate Plant Fiber", "Primitive Materials", {ItemRegistry.ITEM_GRASS: 1}, ItemRegistry.ITEM_PLANT_FIBER, 4, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_CRUSHED_STONE:
			return _definition(recipe_id, "Crush Stone", "Mineral Processing", {ItemRegistry.ITEM_STONE: 2}, ItemRegistry.ITEM_CRUSHED_STONE, 3, ProgressionState.UNLOCK_WORKBENCH, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_ZINC_CONCENTRATE:
			return _definition(recipe_id, "Separate Zinc Concentrate", "Mineral Processing", {ItemRegistry.ITEM_CRUSHED_STONE: 2, ItemRegistry.ITEM_SAND: 1}, ItemRegistry.ITEM_ZINC_CONCENTRATE, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_COPPER_CONCENTRATE:
			return _definition(recipe_id, "Separate Copper Concentrate", "Mineral Processing", {ItemRegistry.ITEM_CRUSHED_STONE: 2, ItemRegistry.ITEM_SOIL: 1}, ItemRegistry.ITEM_COPPER_CONCENTRATE, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_IRON_CONCENTRATE:
			return _definition(recipe_id, "Separate Iron Concentrate", "Mineral Processing", {ItemRegistry.ITEM_CRUSHED_STONE: 3, ItemRegistry.ITEM_STONE: 1}, ItemRegistry.ITEM_IRON_CONCENTRATE, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_GOLD_CONCENTRATE:
			return _definition(recipe_id, "Pan Gold Concentrate", "Mineral Processing", {ItemRegistry.ITEM_SAND: 4, ItemRegistry.ITEM_CRUSHED_STONE: 2}, ItemRegistry.ITEM_GOLD_CONCENTRATE, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_ZINC_INGOT:
			return _definition(recipe_id, "Refine Zinc", "Metallurgy", {ItemRegistry.ITEM_ZINC_CONCENTRATE: 2, ItemRegistry.ITEM_CRUSHED_STONE: 1}, ItemRegistry.ITEM_ZINC_INGOT, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_COPPER_INGOT:
			return _definition(recipe_id, "Refine Copper", "Metallurgy", {ItemRegistry.ITEM_COPPER_CONCENTRATE: 2, ItemRegistry.ITEM_CRUSHED_STONE: 1}, ItemRegistry.ITEM_COPPER_INGOT, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_IRON_INGOT:
			return _definition(recipe_id, "Refine Iron", "Metallurgy", {ItemRegistry.ITEM_IRON_CONCENTRATE: 2, ItemRegistry.ITEM_CRUSHED_STONE: 1}, ItemRegistry.ITEM_IRON_INGOT, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_GOLD_INGOT:
			return _definition(recipe_id, "Refine Gold", "Metallurgy", {ItemRegistry.ITEM_GOLD_CONCENTRATE: 2, ItemRegistry.ITEM_CRUSHED_STONE: 1}, ItemRegistry.ITEM_GOLD_INGOT, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_ANDESITE_ALLOY:
			return _definition(recipe_id, "Andesite Alloy", "Alloys", {ItemRegistry.ITEM_STONE: 2, ItemRegistry.ITEM_ZINC_INGOT: 1}, ItemRegistry.ITEM_ANDESITE_ALLOY, 2, ProgressionState.UNLOCK_STONE_PROCESSING, ProgressionState.UNLOCK_ANDESITE_ENGINEERING)
		RECIPE_BRASS_INGOT:
			return _definition(recipe_id, "Brass Ingot", "Alloys", {ItemRegistry.ITEM_COPPER_INGOT: 1, ItemRegistry.ITEM_ZINC_INGOT: 1}, ItemRegistry.ITEM_BRASS_INGOT, 2, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, ProgressionState.UNLOCK_BRASS_ENGINEERING)
		RECIPE_COPPER_SHEET:
			return _definition(recipe_id, "Form Copper Sheet", "Metal Forming", {ItemRegistry.ITEM_COPPER_INGOT: 1, ItemRegistry.ITEM_CRUSHED_STONE: 1}, ItemRegistry.ITEM_COPPER_SHEET, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_IRON_SHEET:
			return _definition(recipe_id, "Form Iron Sheet", "Metal Forming", {ItemRegistry.ITEM_IRON_INGOT: 1, ItemRegistry.ITEM_CRUSHED_STONE: 1}, ItemRegistry.ITEM_IRON_SHEET, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_GOLD_SHEET:
			return _definition(recipe_id, "Form Gold Sheet", "Metal Forming", {ItemRegistry.ITEM_GOLD_INGOT: 1, ItemRegistry.ITEM_CRUSHED_STONE: 1}, ItemRegistry.ITEM_GOLD_SHEET, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_BRASS_SHEET:
			return _definition(recipe_id, "Form Brass Sheet", "Metal Forming", {ItemRegistry.ITEM_BRASS_INGOT: 1, ItemRegistry.ITEM_CRUSHED_STONE: 1}, ItemRegistry.ITEM_BRASS_SHEET, 1, ProgressionState.UNLOCK_BRASS_ENGINEERING)
		RECIPE_STONE_SHAFT:
			return _definition(recipe_id, "Stone Shaft", "Primitive Components", {ItemRegistry.ITEM_CRUSHED_STONE: 2}, ItemRegistry.ITEM_STONE_SHAFT, 1, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_SHAFT:
			return _definition(recipe_id, "Shaft x4", "Kinetic Components", {ItemRegistry.ITEM_ANDESITE_ALLOY: 2}, ItemRegistry.ITEM_SHAFT, 4, ProgressionState.UNLOCK_ANDESITE_ENGINEERING)
		RECIPE_COGWHEEL:
			return _definition(recipe_id, "Cogwheel", "Kinetic Components", {ItemRegistry.ITEM_SHAFT: 1, ItemRegistry.ITEM_STONE_GEAR: 1}, ItemRegistry.ITEM_COGWHEEL, 1, ProgressionState.UNLOCK_ANDESITE_ENGINEERING)
		RECIPE_LARGE_COGWHEEL:
			return _definition(recipe_id, "Large Cogwheel", "Kinetic Components", {ItemRegistry.ITEM_COGWHEEL: 1, ItemRegistry.ITEM_STONE_GEAR: 2}, ItemRegistry.ITEM_LARGE_COGWHEEL, 1, ProgressionState.UNLOCK_ANDESITE_ENGINEERING)
		RECIPE_BELT_CONNECTOR:
			return _definition(recipe_id, "Belt Connector", "Kinetic Components", {ItemRegistry.ITEM_PLANT_FIBER: 6, ItemRegistry.ITEM_COPPER_SHEET: 1}, ItemRegistry.ITEM_BELT_CONNECTOR, 1, ProgressionState.UNLOCK_ANDESITE_ENGINEERING)
		RECIPE_ANDESITE_CASING:
			return _definition(recipe_id, "Andesite Casing", "Casings", {ItemRegistry.ITEM_STONE: 4, ItemRegistry.ITEM_ANDESITE_ALLOY: 2}, ItemRegistry.ITEM_ANDESITE_CASING, 1, ProgressionState.UNLOCK_ANDESITE_ENGINEERING)
		RECIPE_BRASS_CASING:
			return _definition(recipe_id, "Brass Casing", "Casings", {ItemRegistry.ITEM_ANDESITE_CASING: 1, ItemRegistry.ITEM_BRASS_SHEET: 2}, ItemRegistry.ITEM_BRASS_CASING, 1, ProgressionState.UNLOCK_BRASS_ENGINEERING)
		RECIPE_HAND_CRANK:
			return _definition(recipe_id, "Hand Crank", "Kinetic Components", {ItemRegistry.ITEM_SHAFT: 1, ItemRegistry.ITEM_COGWHEEL: 1, ItemRegistry.ITEM_ANDESITE_ALLOY: 1}, ItemRegistry.ITEM_HAND_CRANK, 1, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, ProgressionState.UNLOCK_KINETIC_STARTER)
		RECIPE_MECHANICAL_BEARING:
			return _definition(recipe_id, "Mechanical Bearing", "Kinetic Components", {ItemRegistry.ITEM_ANDESITE_CASING: 1, ItemRegistry.ITEM_SHAFT: 1, ItemRegistry.ITEM_LARGE_COGWHEEL: 1}, ItemRegistry.ITEM_MECHANICAL_BEARING, 1, ProgressionState.UNLOCK_ANDESITE_ENGINEERING)
		RECIPE_WRENCH:
			return _definition(recipe_id, "Wrench", "Tools", {ItemRegistry.ITEM_GOLD_SHEET: 2, ItemRegistry.ITEM_COGWHEEL: 1, ItemRegistry.ITEM_SHAFT: 1}, ItemRegistry.ITEM_WRENCH, 1, ProgressionState.UNLOCK_ANDESITE_ENGINEERING)
		RECIPE_ELECTRON_TUBE:
			return _definition(recipe_id, "Electron Tube", "Precision Components", {ItemRegistry.ITEM_SAND: 2, ItemRegistry.ITEM_COPPER_SHEET: 1, ItemRegistry.ITEM_IRON_SHEET: 1}, ItemRegistry.ITEM_ELECTRON_TUBE, 1, ProgressionState.UNLOCK_BRASS_ENGINEERING)
		RECIPE_PRECISION_MECHANISM:
			return _definition(recipe_id, "Precision Mechanism", "Precision Components", {ItemRegistry.ITEM_GOLD_SHEET: 1, ItemRegistry.ITEM_COGWHEEL: 1, ItemRegistry.ITEM_LARGE_COGWHEEL: 1, ItemRegistry.ITEM_ELECTRON_TUBE: 1}, ItemRegistry.ITEM_PRECISION_MECHANISM, 1, ProgressionState.UNLOCK_BRASS_ENGINEERING, ProgressionState.UNLOCK_PRECISION_ENGINEERING)
		RECIPE_EMPTY_BLAZE_BURNER:
			return _definition(recipe_id, "Empty Blaze Burner", "Heat Components", {ItemRegistry.ITEM_IRON_SHEET: 4, ItemRegistry.ITEM_BRASS_CASING: 1, ItemRegistry.ITEM_CRUSHED_STONE: 2}, ItemRegistry.ITEM_EMPTY_BLAZE_BURNER, 1, ProgressionState.UNLOCK_BRASS_ENGINEERING)
		RECIPE_STONE_CRUSHER:
			return _definition(recipe_id, "Stone Crusher", "Primitive Kinetics", {ItemRegistry.ITEM_STONE: 6, ItemRegistry.ITEM_CRUSHED_STONE: 2}, ItemRegistry.ITEM_STONE_CRUSHER, 1, ProgressionState.UNLOCK_KINETIC_STARTER)
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
