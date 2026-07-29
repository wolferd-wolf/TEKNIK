class_name TeknikRecipeBook
extends RefCounted

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")

const STATION_HAND: StringName = &"hand"
const STATION_TABLE: StringName = &"crafting_table"
const STATION_FURNACE: StringName = &"furnace"

const RECIPE_PLANKS: StringName = &"planks"
const RECIPE_STRIPPED_WOOD: StringName = &"stripped_wood"
const RECIPE_WOODEN_SLAB: StringName = &"wooden_slab"
const RECIPE_WOODEN_ROD: StringName = &"wooden_rod"
const RECIPE_PAPER: StringName = &"paper"
const RECIPE_STONE_GEAR: StringName = &"stone_gear"
const RECIPE_WORKBENCH: StringName = &"workbench"
const RECIPE_FURNACE: StringName = &"furnace"
const RECIPE_PLANT_FIBER: StringName = &"plant_fiber"
const RECIPE_ANDESITE: StringName = &"andesite"
const RECIPE_KELP: StringName = &"kelp"
const RECIPE_QUARTZ: StringName = &"quartz"
const RECIPE_REDSTONE: StringName = &"redstone"
const RECIPE_NETHERRACK: StringName = &"netherrack"
const RECIPE_IRON_NUGGETS: StringName = &"iron_nuggets"
const RECIPE_GOLD_NUGGETS: StringName = &"gold_nuggets"
const RECIPE_COPPER_NUGGETS: StringName = &"copper_nuggets"
const RECIPE_ZINC_NUGGETS: StringName = &"zinc_nuggets"
const RECIPE_SAND_PAPER: StringName = &"sand_paper"
const RECIPE_ROSE_QUARTZ: StringName = &"rose_quartz"
const RECIPE_POLISHED_ROSE_QUARTZ: StringName = &"polished_rose_quartz"

const RECIPE_CRUSHED_STONE: StringName = &"crushed_stone"
const RECIPE_ZINC_CONCENTRATE: StringName = &"zinc_concentrate"
const RECIPE_COPPER_CONCENTRATE: StringName = &"copper_concentrate"
const RECIPE_IRON_CONCENTRATE: StringName = &"iron_concentrate"
const RECIPE_GOLD_CONCENTRATE: StringName = &"gold_concentrate"
const RECIPE_ZINC_INGOT: StringName = &"zinc_ingot"
const RECIPE_COPPER_INGOT: StringName = &"copper_ingot"
const RECIPE_IRON_INGOT: StringName = &"iron_ingot"
const RECIPE_GOLD_INGOT: StringName = &"gold_ingot"
const RECIPE_DRIED_KELP: StringName = &"dried_kelp"
const RECIPE_BRASS_INGOT: StringName = &"brass_ingot"

const RECIPE_ANDESITE_ALLOY: StringName = &"andesite_alloy"
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
const RECIPE_INCOMPLETE_PRECISION_MECHANISM: StringName = &"incomplete_precision_mechanism"
const RECIPE_PRECISION_MECHANISM: StringName = &"precision_mechanism"
const RECIPE_EMPTY_BLAZE_BURNER: StringName = &"empty_blaze_burner"
const RECIPE_STONE_CRUSHER: StringName = &"stone_crusher"


static func registered_recipes() -> Array[StringName]:
	return [
		RECIPE_PLANKS, RECIPE_STRIPPED_WOOD, RECIPE_WOODEN_SLAB,
		RECIPE_WOODEN_ROD, RECIPE_PAPER, RECIPE_STONE_GEAR, RECIPE_WORKBENCH,
		RECIPE_FURNACE, RECIPE_PLANT_FIBER, RECIPE_ANDESITE, RECIPE_KELP,
		RECIPE_QUARTZ, RECIPE_REDSTONE, RECIPE_NETHERRACK,
		RECIPE_IRON_NUGGETS, RECIPE_GOLD_NUGGETS, RECIPE_COPPER_NUGGETS,
		RECIPE_ZINC_NUGGETS, RECIPE_SAND_PAPER, RECIPE_ROSE_QUARTZ,
		RECIPE_POLISHED_ROSE_QUARTZ,
		RECIPE_CRUSHED_STONE, RECIPE_ZINC_CONCENTRATE,
		RECIPE_COPPER_CONCENTRATE, RECIPE_IRON_CONCENTRATE,
		RECIPE_GOLD_CONCENTRATE, RECIPE_ZINC_INGOT, RECIPE_COPPER_INGOT,
		RECIPE_IRON_INGOT, RECIPE_GOLD_INGOT, RECIPE_DRIED_KELP,
		RECIPE_BRASS_INGOT, RECIPE_ANDESITE_ALLOY, RECIPE_COPPER_SHEET,
		RECIPE_IRON_SHEET, RECIPE_GOLD_SHEET, RECIPE_BRASS_SHEET,
		RECIPE_STONE_SHAFT, RECIPE_SHAFT, RECIPE_COGWHEEL,
		RECIPE_LARGE_COGWHEEL, RECIPE_BELT_CONNECTOR,
		RECIPE_ANDESITE_CASING, RECIPE_BRASS_CASING, RECIPE_HAND_CRANK,
		RECIPE_MECHANICAL_BEARING, RECIPE_WRENCH, RECIPE_ELECTRON_TUBE,
		RECIPE_INCOMPLETE_PRECISION_MECHANISM, RECIPE_PRECISION_MECHANISM,
		RECIPE_EMPTY_BLAZE_BURNER, RECIPE_STONE_CRUSHER,
	]


static func recipe(recipe_id: StringName) -> Dictionary:
	match recipe_id:
		RECIPE_PLANKS:
			return _definition(recipe_id, "Saw Wooden Planks", "Woodworking", {ItemRegistry.ITEM_WOOD: 1}, ItemRegistry.ITEM_PLANKS, 4, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, &"", "Minecraft planks relationship", "TEKNIK bridge")
		RECIPE_STRIPPED_WOOD:
			return _definition(recipe_id, "Prepare Stripped Wood", "Woodworking", {ItemRegistry.ITEM_WOOD: 1}, ItemRegistry.ITEM_STRIPPED_WOOD, 1, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, &"", "Create casing substrate", "TEKNIK bridge")
		RECIPE_WOODEN_SLAB:
			return _definition(recipe_id, "Wooden Slabs x6", "Woodworking", {ItemRegistry.ITEM_PLANKS: 3}, ItemRegistry.ITEM_WOODEN_SLAB, 6, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, &"", "Minecraft slab relationship", "TEKNIK bridge")
		RECIPE_WOODEN_ROD:
			return _definition(recipe_id, "Wooden Rods x4", "Woodworking", {ItemRegistry.ITEM_PLANKS: 2}, ItemRegistry.ITEM_WOODEN_ROD, 4, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, &"", "c:rods/wooden dependency", "TEKNIK bridge")
		RECIPE_PAPER:
			return _definition(recipe_id, "Paper x3", "Organic Materials", {ItemRegistry.ITEM_PLANT_FIBER: 3}, ItemRegistry.ITEM_PAPER, 3, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, &"", "Minecraft paper dependency", "TEKNIK bridge")
		RECIPE_STONE_GEAR:
			return _definition(recipe_id, "Stone Gear", "Primitive Components", {ItemRegistry.ITEM_STONE: 4}, ItemRegistry.ITEM_STONE_GEAR, 1, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_WORKBENCH:
			return _definition(recipe_id, "Crafting Table", "Stations", {ItemRegistry.ITEM_PLANKS: 4}, ItemRegistry.ITEM_WORKBENCH, 1, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, ProgressionState.UNLOCK_WORKBENCH)
		RECIPE_FURNACE:
			return _definition(recipe_id, "Furnace", "Stations", {ItemRegistry.ITEM_STONE: 8}, ItemRegistry.ITEM_FURNACE, 1, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_PLANT_FIBER:
			return _definition(recipe_id, "Separate Plant Fiber", "Organic Materials", {ItemRegistry.ITEM_GRASS: 1}, ItemRegistry.ITEM_PLANT_FIBER, 4, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_ANDESITE:
			return _definition(recipe_id, "Blend Andesite x2", "Mineral Bridges", {ItemRegistry.ITEM_STONE: 2, ItemRegistry.ITEM_SOIL: 1}, ItemRegistry.ITEM_ANDESITE, 2, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, &"", "minecraft:andesite dependency", "TEKNIK bridge")
		RECIPE_KELP:
			return _definition(recipe_id, "Bind Kelp Strips x2", "Organic Materials", {ItemRegistry.ITEM_PLANT_FIBER: 2, ItemRegistry.ITEM_GRASS: 1}, ItemRegistry.ITEM_KELP, 2, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, &"", "minecraft:kelp dependency", "TEKNIK bridge")
		RECIPE_QUARTZ:
			return _definition(recipe_id, "Separate Quartz", "Mineral Bridges", {ItemRegistry.ITEM_SAND: 4}, ItemRegistry.ITEM_QUARTZ, 1, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, &"", "c:gems/quartz dependency", "TEKNIK bridge")
		RECIPE_REDSTONE:
			return _definition(recipe_id, "Separate Redstone x8", "Mineral Bridges", {ItemRegistry.ITEM_CRUSHED_STONE: 2, ItemRegistry.ITEM_IRON_CONCENTRATE: 1}, ItemRegistry.ITEM_REDSTONE, 8, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING, &"", "c:dusts/redstone dependency", "TEKNIK bridge")
		RECIPE_NETHERRACK:
			return _definition(recipe_id, "Bind Netherrack x4", "Heat Materials", {ItemRegistry.ITEM_STONE: 4, ItemRegistry.ITEM_REDSTONE: 1}, ItemRegistry.ITEM_NETHERRACK, 4, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING, &"", "c:netherracks dependency", "TEKNIK bridge")
		RECIPE_IRON_NUGGETS:
			return _definition(recipe_id, "Iron Nuggets x9", "Metal Parts", {ItemRegistry.ITEM_IRON_INGOT: 1}, ItemRegistry.ITEM_IRON_NUGGET, 9, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_GOLD_NUGGETS:
			return _definition(recipe_id, "Gold Nuggets x9", "Metal Parts", {ItemRegistry.ITEM_GOLD_INGOT: 1}, ItemRegistry.ITEM_GOLD_NUGGET, 9, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_COPPER_NUGGETS:
			return _definition(recipe_id, "Copper Nuggets x9", "Metal Parts", {ItemRegistry.ITEM_COPPER_INGOT: 1}, ItemRegistry.ITEM_COPPER_NUGGET, 9, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_ZINC_NUGGETS:
			return _definition(recipe_id, "Zinc Nuggets x9", "Metal Parts", {ItemRegistry.ITEM_ZINC_INGOT: 1}, ItemRegistry.ITEM_ZINC_NUGGET, 9, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_SAND_PAPER:
			return _definition(recipe_id, "Sand Paper", "Tools", {ItemRegistry.ITEM_PAPER: 1, ItemRegistry.ITEM_SAND: 1}, ItemRegistry.ITEM_SAND_PAPER, 1, STATION_HAND, ProgressionState.UNLOCK_HAND_CRAFTING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/materials/sand_paper.json")
		RECIPE_ROSE_QUARTZ:
			return _definition(recipe_id, "Rose Quartz", "Precision Materials", {ItemRegistry.ITEM_QUARTZ: 1, ItemRegistry.ITEM_REDSTONE: 8}, ItemRegistry.ITEM_ROSE_QUARTZ, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/materials/rose_quartz.json")
		RECIPE_POLISHED_ROSE_QUARTZ:
			return _definition(recipe_id, "Polished Rose Quartz", "Precision Materials", {ItemRegistry.ITEM_ROSE_QUARTZ: 1, ItemRegistry.ITEM_SAND_PAPER: 1}, ItemRegistry.ITEM_POLISHED_ROSE_QUARTZ, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING, &"", "Sandpaper Polishing", "src/generated/resources/data/create/recipe/sandpaper_polishing/rose_quartz.json")
		RECIPE_CRUSHED_STONE:
			return _definition(recipe_id, "Crush Stone", "Mineral Processing", {ItemRegistry.ITEM_STONE: 2}, ItemRegistry.ITEM_CRUSHED_STONE, 3, STATION_TABLE, ProgressionState.UNLOCK_WORKBENCH, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_ZINC_CONCENTRATE:
			return _definition(recipe_id, "Separate Zinc Concentrate", "Mineral Processing", {ItemRegistry.ITEM_CRUSHED_STONE: 2, ItemRegistry.ITEM_SAND: 1}, ItemRegistry.ITEM_ZINC_CONCENTRATE, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_COPPER_CONCENTRATE:
			return _definition(recipe_id, "Separate Copper Concentrate", "Mineral Processing", {ItemRegistry.ITEM_CRUSHED_STONE: 2, ItemRegistry.ITEM_SOIL: 1}, ItemRegistry.ITEM_COPPER_CONCENTRATE, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_IRON_CONCENTRATE:
			return _definition(recipe_id, "Separate Iron Concentrate", "Mineral Processing", {ItemRegistry.ITEM_CRUSHED_STONE: 3, ItemRegistry.ITEM_STONE: 1}, ItemRegistry.ITEM_IRON_CONCENTRATE, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_GOLD_CONCENTRATE:
			return _definition(recipe_id, "Pan Gold Concentrate", "Mineral Processing", {ItemRegistry.ITEM_SAND: 4, ItemRegistry.ITEM_CRUSHED_STONE: 2}, ItemRegistry.ITEM_GOLD_CONCENTRATE, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_ZINC_INGOT:
			return _definition(recipe_id, "Smelt Zinc", "Smelting", {ItemRegistry.ITEM_ZINC_CONCENTRATE: 1}, ItemRegistry.ITEM_ZINC_INGOT, 1, STATION_FURNACE, ProgressionState.UNLOCK_WORKBENCH)
		RECIPE_COPPER_INGOT:
			return _definition(recipe_id, "Smelt Copper", "Smelting", {ItemRegistry.ITEM_COPPER_CONCENTRATE: 1}, ItemRegistry.ITEM_COPPER_INGOT, 1, STATION_FURNACE, ProgressionState.UNLOCK_WORKBENCH)
		RECIPE_IRON_INGOT:
			return _definition(recipe_id, "Smelt Iron", "Smelting", {ItemRegistry.ITEM_IRON_CONCENTRATE: 1}, ItemRegistry.ITEM_IRON_INGOT, 1, STATION_FURNACE, ProgressionState.UNLOCK_WORKBENCH)
		RECIPE_GOLD_INGOT:
			return _definition(recipe_id, "Smelt Gold", "Smelting", {ItemRegistry.ITEM_GOLD_CONCENTRATE: 1}, ItemRegistry.ITEM_GOLD_INGOT, 1, STATION_FURNACE, ProgressionState.UNLOCK_WORKBENCH)
		RECIPE_DRIED_KELP:
			return _definition(recipe_id, "Dry Kelp", "Smelting", {ItemRegistry.ITEM_KELP: 1}, ItemRegistry.ITEM_DRIED_KELP, 1, STATION_FURNACE, ProgressionState.UNLOCK_HAND_CRAFTING)
		RECIPE_BRASS_INGOT:
			return _definition(recipe_id, "Heat-Mix Brass x2", "Heated Alloying", {ItemRegistry.ITEM_COPPER_INGOT: 1, ItemRegistry.ITEM_ZINC_INGOT: 1}, ItemRegistry.ITEM_BRASS_INGOT, 2, STATION_FURNACE, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, ProgressionState.UNLOCK_BRASS_ENGINEERING, "Heated Mixing", "src/generated/resources/data/create/recipe/mixing/brass_ingot.json")
		RECIPE_ANDESITE_ALLOY:
			return _definition(recipe_id, "Andesite Alloy", "Alloys", {ItemRegistry.ITEM_ANDESITE: 2, ItemRegistry.ITEM_IRON_NUGGET: 2}, ItemRegistry.ITEM_ANDESITE_ALLOY, 1, STATION_TABLE, ProgressionState.UNLOCK_WORKBENCH, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, "Crafting", "src/generated/resources/data/create/recipe/crafting/materials/andesite_alloy.json")
		RECIPE_COPPER_SHEET:
			return _definition(recipe_id, "Form Copper Sheet", "Formed Metals", {ItemRegistry.ITEM_COPPER_INGOT: 1}, ItemRegistry.ITEM_COPPER_SHEET, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING, &"", "Mechanical Press adaptation", "src/generated/resources/data/create/recipe/pressing/copper_ingot.json")
		RECIPE_IRON_SHEET:
			return _definition(recipe_id, "Form Iron Sheet", "Formed Metals", {ItemRegistry.ITEM_IRON_INGOT: 1}, ItemRegistry.ITEM_IRON_SHEET, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING, &"", "Mechanical Press adaptation", "src/generated/resources/data/create/recipe/pressing/iron_ingot.json")
		RECIPE_GOLD_SHEET:
			return _definition(recipe_id, "Form Gold Sheet", "Formed Metals", {ItemRegistry.ITEM_GOLD_INGOT: 1}, ItemRegistry.ITEM_GOLD_SHEET, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING, &"", "Mechanical Press adaptation", "src/generated/resources/data/create/recipe/pressing/gold_ingot.json")
		RECIPE_BRASS_SHEET:
			return _definition(recipe_id, "Form Brass Sheet", "Formed Metals", {ItemRegistry.ITEM_BRASS_INGOT: 1}, ItemRegistry.ITEM_BRASS_SHEET, 1, STATION_TABLE, ProgressionState.UNLOCK_BRASS_ENGINEERING, &"", "Mechanical Press adaptation", "src/generated/resources/data/create/recipe/pressing/brass_ingot.json")
		RECIPE_STONE_SHAFT:
			return _definition(recipe_id, "Stone Shaft", "Primitive Components", {ItemRegistry.ITEM_CRUSHED_STONE: 2}, ItemRegistry.ITEM_STONE_SHAFT, 1, STATION_TABLE, ProgressionState.UNLOCK_STONE_PROCESSING)
		RECIPE_SHAFT:
			return _definition(recipe_id, "Shaft x8", "Kinetic Components", {ItemRegistry.ITEM_ANDESITE_ALLOY: 2}, ItemRegistry.ITEM_SHAFT, 8, STATION_TABLE, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/kinetics/shaft.json")
		RECIPE_COGWHEEL:
			return _definition(recipe_id, "Cogwheel", "Kinetic Components", {ItemRegistry.ITEM_SHAFT: 1, ItemRegistry.ITEM_PLANKS: 1}, ItemRegistry.ITEM_COGWHEEL, 1, STATION_TABLE, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/kinetics/cogwheel.json")
		RECIPE_LARGE_COGWHEEL:
			return _definition(recipe_id, "Large Cogwheel", "Kinetic Components", {ItemRegistry.ITEM_SHAFT: 1, ItemRegistry.ITEM_PLANKS: 2}, ItemRegistry.ITEM_LARGE_COGWHEEL, 1, STATION_TABLE, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/kinetics/large_cogwheel.json")
		RECIPE_BELT_CONNECTOR:
			return _definition(recipe_id, "Belt Connector", "Kinetic Components", {ItemRegistry.ITEM_DRIED_KELP: 6}, ItemRegistry.ITEM_BELT_CONNECTOR, 1, STATION_TABLE, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/kinetics/belt_connector.json")
		RECIPE_ANDESITE_CASING:
			return _definition(recipe_id, "Andesite Casing", "Casings", {ItemRegistry.ITEM_STRIPPED_WOOD: 1, ItemRegistry.ITEM_ANDESITE_ALLOY: 1}, ItemRegistry.ITEM_ANDESITE_CASING, 1, STATION_TABLE, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, &"", "Item Application adaptation", "src/generated/resources/data/create/recipe/item_application/andesite_casing_from_wood.json")
		RECIPE_BRASS_CASING:
			return _definition(recipe_id, "Brass Casing", "Casings", {ItemRegistry.ITEM_STRIPPED_WOOD: 1, ItemRegistry.ITEM_BRASS_INGOT: 1}, ItemRegistry.ITEM_BRASS_CASING, 1, STATION_TABLE, ProgressionState.UNLOCK_BRASS_ENGINEERING, &"", "Item Application adaptation", "src/generated/resources/data/create/recipe/item_application/brass_casing_from_wood.json")
		RECIPE_HAND_CRANK:
			return _definition(recipe_id, "Hand Crank", "Kinetic Components", {ItemRegistry.ITEM_PLANKS: 3, ItemRegistry.ITEM_ANDESITE_ALLOY: 1}, ItemRegistry.ITEM_HAND_CRANK, 1, STATION_TABLE, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, ProgressionState.UNLOCK_KINETIC_STARTER, "Crafting", "src/generated/resources/data/create/recipe/crafting/kinetics/hand_crank.json")
		RECIPE_MECHANICAL_BEARING:
			return _definition(recipe_id, "Mechanical Bearing", "Kinetic Components", {ItemRegistry.ITEM_WOODEN_SLAB: 1, ItemRegistry.ITEM_ANDESITE_CASING: 1, ItemRegistry.ITEM_SHAFT: 1}, ItemRegistry.ITEM_MECHANICAL_BEARING, 1, STATION_TABLE, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/kinetics/mechanical_bearing.json")
		RECIPE_WRENCH:
			return _definition(recipe_id, "Wrench", "Tools", {ItemRegistry.ITEM_GOLD_SHEET: 3, ItemRegistry.ITEM_COGWHEEL: 1, ItemRegistry.ITEM_WOODEN_ROD: 1}, ItemRegistry.ITEM_WRENCH, 1, STATION_TABLE, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/kinetics/wrench.json")
		RECIPE_ELECTRON_TUBE:
			return _definition(recipe_id, "Electron Tube", "Precision Components", {ItemRegistry.ITEM_POLISHED_ROSE_QUARTZ: 1, ItemRegistry.ITEM_IRON_SHEET: 1}, ItemRegistry.ITEM_ELECTRON_TUBE, 1, STATION_TABLE, ProgressionState.UNLOCK_BRASS_ENGINEERING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/materials/electron_tube.json")
		RECIPE_INCOMPLETE_PRECISION_MECHANISM:
			return _definition(recipe_id, "Begin Precision Mechanism", "Precision Components", {ItemRegistry.ITEM_GOLD_SHEET: 1}, ItemRegistry.ITEM_INCOMPLETE_PRECISION_MECHANISM, 1, STATION_TABLE, ProgressionState.UNLOCK_BRASS_ENGINEERING, &"", "Sequenced Assembly transitional item", "src/generated/resources/data/create/recipe/sequenced_assembly/precision_mechanism.json")
		RECIPE_PRECISION_MECHANISM:
			return _definition(recipe_id, "Complete Precision Mechanism", "Precision Components", {ItemRegistry.ITEM_INCOMPLETE_PRECISION_MECHANISM: 1, ItemRegistry.ITEM_COGWHEEL: 5, ItemRegistry.ITEM_LARGE_COGWHEEL: 5, ItemRegistry.ITEM_IRON_NUGGET: 5}, ItemRegistry.ITEM_PRECISION_MECHANISM, 1, STATION_TABLE, ProgressionState.UNLOCK_BRASS_ENGINEERING, ProgressionState.UNLOCK_PRECISION_ENGINEERING, "Sequenced Assembly (5 loops) adaptation", "src/generated/resources/data/create/recipe/sequenced_assembly/precision_mechanism.json")
		RECIPE_EMPTY_BLAZE_BURNER:
			return _definition(recipe_id, "Empty Blaze Burner", "Heat Components", {ItemRegistry.ITEM_IRON_SHEET: 4, ItemRegistry.ITEM_NETHERRACK: 1}, ItemRegistry.ITEM_EMPTY_BLAZE_BURNER, 1, STATION_TABLE, ProgressionState.UNLOCK_BRASS_ENGINEERING, &"", "Crafting", "src/generated/resources/data/create/recipe/crafting/kinetics/empty_blaze_burner.json")
		RECIPE_STONE_CRUSHER:
			return _definition(recipe_id, "Stone Crusher", "Primitive Kinetics", {ItemRegistry.ITEM_STONE: 6, ItemRegistry.ITEM_CRUSHED_STONE: 2}, ItemRegistry.ITEM_STONE_CRUSHER, 1, STATION_TABLE, ProgressionState.UNLOCK_KINETIC_STARTER)
		_:
			return {}


static func _definition(
	id: StringName,
	display: String,
	category: String,
	ingredients: Dictionary,
	output: StringName,
	count: int,
	station: StringName,
	required_unlock: StringName,
	grants_unlock: StringName = &"",
	source_process: String = "TEKNIK crafting",
	source_recipe: String = ""
) -> Dictionary:
	return {
		"id": id,
		"display_name": display,
		"category": category,
		"ingredients": ingredients,
		"output_item": output,
		"output_count": count,
		"station": station,
		"required_unlock": required_unlock,
		"grants_unlock": grants_unlock,
		"source_process": source_process,
		"source_recipe": source_recipe,
	}


static func station_recipes(station: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for recipe_id: StringName in registered_recipes():
		if StringName(str(recipe(recipe_id).get("station", ""))) == station:
			result.append(recipe_id)
	return result


static func available_recipes(progression: TeknikProgressionState) -> Array[StringName]:
	var result: Array[StringName] = []
	for recipe_id: StringName in registered_recipes():
		var definition: Dictionary = recipe(recipe_id)
		if progression.is_unlocked(StringName(str(definition.required_unlock))):
			result.append(recipe_id)
	return result


static func available_recipes_for_station(
	progression: TeknikProgressionState,
	station: StringName
) -> Array[StringName]:
	var result: Array[StringName] = []
	for recipe_id: StringName in station_recipes(station):
		var definition: Dictionary = recipe(recipe_id)
		if progression.is_unlocked(StringName(str(definition.required_unlock))):
			result.append(recipe_id)
	return result


static func can_craft(
	inventory: TeknikStackInventory,
	recipe_id: StringName,
	progression: TeknikProgressionState = null
) -> bool:
	return can_craft_at_station(inventory, recipe_id, progression, &"")


static func can_craft_at_station(
	inventory: TeknikStackInventory,
	recipe_id: StringName,
	progression: TeknikProgressionState,
	station: StringName
) -> bool:
	var definition: Dictionary = recipe(recipe_id)
	if definition.is_empty():
		return false
	if station != &"" and StringName(str(definition.station)) != station:
		return false
	if progression != null and not progression.is_unlocked(StringName(str(definition.required_unlock))):
		return false
	var trial := StackInventory.new()
	if not trial.decode(inventory.encode()):
		return false
	for item_variant: Variant in (definition.ingredients as Dictionary).keys():
		var item_id := StringName(str(item_variant))
		if not trial.remove(item_id, int(definition.ingredients[item_variant])):
			return false
	return trial.add(StringName(str(definition.output_item)), int(definition.output_count)) == 0


static func craft(
	inventory: TeknikStackInventory,
	recipe_id: StringName,
	progression: TeknikProgressionState = null
) -> bool:
	return craft_at_station(inventory, recipe_id, progression, &"")


static func craft_at_station(
	inventory: TeknikStackInventory,
	recipe_id: StringName,
	progression: TeknikProgressionState,
	station: StringName
) -> bool:
	if not can_craft_at_station(inventory, recipe_id, progression, station):
		return false
	var definition: Dictionary = recipe(recipe_id)
	var trial := StackInventory.new()
	if not trial.decode(inventory.encode()):
		return false
	for item_variant: Variant in (definition.ingredients as Dictionary).keys():
		var item_id := StringName(str(item_variant))
		if not trial.remove(item_id, int(definition.ingredients[item_variant])):
			return false
	if trial.add(StringName(str(definition.output_item)), int(definition.output_count)) != 0:
		return false
	if not inventory.decode(trial.encode()):
		return false
	if progression != null:
		var granted := StringName(str(definition.get("grants_unlock", "")))
		if granted != &"":
			progression.unlock(granted)
	return true
