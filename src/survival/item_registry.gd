class_name TeknikItemRegistry
extends RefCounted

const AIR: int = 0
const STONE: int = 1
const SOIL: int = 2
const GRASS: int = 3
const SAND: int = 4
const ZINC_ORE: int = 5
const COPPER_ORE: int = 6
const IRON_ORE: int = 7
const GOLD_ORE: int = 8

const ITEM_STONE: StringName = &"stone"
const ITEM_SOIL: StringName = &"soil"
const ITEM_GRASS: StringName = &"grass"
const ITEM_SAND: StringName = &"sand"
const ITEM_WOOD: StringName = &"wood"
const ITEM_PLANKS: StringName = &"planks"
const ITEM_STRIPPED_WOOD: StringName = &"stripped_wood"
const ITEM_WOODEN_SLAB: StringName = &"wooden_slab"
const ITEM_WOODEN_ROD: StringName = &"wooden_rod"
const ITEM_ANDESITE: StringName = &"andesite"
const ITEM_KELP: StringName = &"kelp"
const ITEM_DRIED_KELP: StringName = &"dried_kelp"
const ITEM_PAPER: StringName = &"paper"
const ITEM_SAND_PAPER: StringName = &"sand_paper"
const ITEM_QUARTZ: StringName = &"quartz"
const ITEM_REDSTONE: StringName = &"redstone"
const ITEM_ROSE_QUARTZ: StringName = &"rose_quartz"
const ITEM_POLISHED_ROSE_QUARTZ: StringName = &"polished_rose_quartz"
const ITEM_NETHERRACK: StringName = &"netherrack"
const ITEM_IRON_NUGGET: StringName = &"iron_nugget"
const ITEM_GOLD_NUGGET: StringName = &"gold_nugget"
const ITEM_COPPER_NUGGET: StringName = &"copper_nugget"
const ITEM_ZINC_NUGGET: StringName = &"zinc_nugget"

const ITEM_STONE_GEAR: StringName = &"stone_gear"
const ITEM_WORKBENCH: StringName = &"workbench"
const ITEM_FURNACE: StringName = &"furnace"
const ITEM_CRUSHED_STONE: StringName = &"crushed_stone"
const ITEM_STONE_SHAFT: StringName = &"stone_shaft"
const ITEM_HAND_CRANK: StringName = &"hand_crank"
const ITEM_STONE_CRUSHER: StringName = &"stone_crusher"

# TEKNIK ore feedstock. Underground ore voxels yield these directly.
const ITEM_ZINC_CONCENTRATE: StringName = &"zinc_concentrate"
const ITEM_COPPER_CONCENTRATE: StringName = &"copper_concentrate"
const ITEM_IRON_CONCENTRATE: StringName = &"iron_concentrate"
const ITEM_GOLD_CONCENTRATE: StringName = &"gold_concentrate"
const ITEM_COPPER_INGOT: StringName = &"copper_ingot"
const ITEM_IRON_INGOT: StringName = &"iron_ingot"
const ITEM_GOLD_INGOT: StringName = &"gold_ingot"
const ITEM_PLANT_FIBER: StringName = &"plant_fiber"

# Phase 1 Create-inspired engineering catalog. Recipes retain the ingredient
# relationships from Create's generated data while all runtime code and visuals
# are original TEKNIK implementations.
const ITEM_ANDESITE_ALLOY: StringName = &"andesite_alloy"
const ITEM_ZINC_INGOT: StringName = &"zinc_ingot"
const ITEM_BRASS_INGOT: StringName = &"brass_ingot"
const ITEM_COPPER_SHEET: StringName = &"copper_sheet"
const ITEM_BRASS_SHEET: StringName = &"brass_sheet"
const ITEM_IRON_SHEET: StringName = &"iron_sheet"
const ITEM_GOLD_SHEET: StringName = &"gold_sheet"
const ITEM_ANDESITE_CASING: StringName = &"andesite_casing"
const ITEM_BRASS_CASING: StringName = &"brass_casing"
const ITEM_SHAFT: StringName = &"shaft"
const ITEM_COGWHEEL: StringName = &"cogwheel"
const ITEM_LARGE_COGWHEEL: StringName = &"large_cogwheel"
const ITEM_BELT_CONNECTOR: StringName = &"belt_connector"
const ITEM_MECHANICAL_BEARING: StringName = &"mechanical_bearing"
const ITEM_WRENCH: StringName = &"wrench"
const ITEM_ELECTRON_TUBE: StringName = &"electron_tube"
const ITEM_INCOMPLETE_PRECISION_MECHANISM: StringName = &"incomplete_precision_mechanism"
const ITEM_PRECISION_MECHANISM: StringName = &"precision_mechanism"
const ITEM_EMPTY_BLAZE_BURNER: StringName = &"empty_blaze_burner"

const MAX_STACK: int = 64

const REGISTERED_ITEMS = [
	ITEM_STONE, ITEM_SOIL, ITEM_GRASS, ITEM_SAND, ITEM_WOOD,
	ITEM_PLANKS, ITEM_STRIPPED_WOOD, ITEM_WOODEN_SLAB, ITEM_WOODEN_ROD,
	ITEM_ANDESITE, ITEM_KELP, ITEM_DRIED_KELP, ITEM_PAPER, ITEM_SAND_PAPER,
	ITEM_QUARTZ, ITEM_REDSTONE, ITEM_ROSE_QUARTZ, ITEM_POLISHED_ROSE_QUARTZ,
	ITEM_NETHERRACK, ITEM_IRON_NUGGET, ITEM_GOLD_NUGGET,
	ITEM_COPPER_NUGGET, ITEM_ZINC_NUGGET,
	ITEM_STONE_GEAR, ITEM_WORKBENCH, ITEM_FURNACE, ITEM_CRUSHED_STONE,
	ITEM_STONE_SHAFT, ITEM_HAND_CRANK, ITEM_STONE_CRUSHER,
	ITEM_ZINC_CONCENTRATE, ITEM_COPPER_CONCENTRATE, ITEM_IRON_CONCENTRATE,
	ITEM_GOLD_CONCENTRATE, ITEM_COPPER_INGOT, ITEM_IRON_INGOT, ITEM_GOLD_INGOT,
	ITEM_PLANT_FIBER,
	ITEM_ANDESITE_ALLOY, ITEM_ZINC_INGOT, ITEM_BRASS_INGOT,
	ITEM_COPPER_SHEET, ITEM_BRASS_SHEET, ITEM_IRON_SHEET, ITEM_GOLD_SHEET,
	ITEM_ANDESITE_CASING, ITEM_BRASS_CASING, ITEM_SHAFT, ITEM_COGWHEEL,
	ITEM_LARGE_COGWHEEL, ITEM_BELT_CONNECTOR, ITEM_MECHANICAL_BEARING,
	ITEM_WRENCH, ITEM_ELECTRON_TUBE, ITEM_INCOMPLETE_PRECISION_MECHANISM,
	ITEM_PRECISION_MECHANISM, ITEM_EMPTY_BLAZE_BURNER,
]

const PHASE_ONE_ITEMS = [
	ITEM_ANDESITE_ALLOY, ITEM_ZINC_INGOT, ITEM_BRASS_INGOT,
	ITEM_COPPER_SHEET, ITEM_BRASS_SHEET, ITEM_IRON_SHEET, ITEM_GOLD_SHEET,
	ITEM_ANDESITE_CASING, ITEM_BRASS_CASING, ITEM_SHAFT, ITEM_COGWHEEL,
	ITEM_LARGE_COGWHEEL, ITEM_BELT_CONNECTOR, ITEM_MECHANICAL_BEARING,
	ITEM_HAND_CRANK, ITEM_WRENCH, ITEM_ELECTRON_TUBE,
	ITEM_PRECISION_MECHANISM, ITEM_EMPTY_BLAZE_BURNER,
]

const ITEM_DATA = {
	ITEM_STONE: ["Stone", "Blocks", "A basic structural voxel.", "777b79", 64],
	ITEM_SOIL: ["Soil", "Blocks", "Loose earth used in survival construction.", "674735", 64],
	ITEM_GRASS: ["Grass", "Blocks", "A living surface block and fiber source.", "4d7543", 64],
	ITEM_SAND: ["Sand", "Blocks", "Granular silica-rich material.", "a58c5c", 64],
	ITEM_WOOD: ["Wood", "Organic Materials", "Mineable timber used by starter recipes.", "76543b", 64],
	ITEM_PLANKS: ["Wooden Planks", "Wood Products", "Processed boards used by Create-style components.", "9c7048", 64],
	ITEM_STRIPPED_WOOD: ["Stripped Wood", "Wood Products", "Prepared timber used as the core of machine casings.", "8a6444", 64],
	ITEM_WOODEN_SLAB: ["Wooden Slab", "Wood Products", "A half-height wooden construction part.", "a5794f", 64],
	ITEM_WOODEN_ROD: ["Wooden Rod", "Wood Products", "A simple wooden handle and structural rod.", "8f633f", 64],
	ITEM_ANDESITE: ["Andesite", "Minerals", "A dense igneous stone used in early Create engineering.", "737875", 64],
	ITEM_KELP: ["Kelp", "Organic Materials", "Wet plant material that can be dried into belt material.", "456b45", 64],
	ITEM_DRIED_KELP: ["Dried Kelp", "Organic Materials", "Tough dried strips used to form belt connectors.", "52613b", 64],
	ITEM_PAPER: ["Paper", "Crafting Materials", "A thin plant-fiber sheet.", "d8d2b5", 64],
	ITEM_SAND_PAPER: ["Sand Paper", "Tools", "A disposable abrasive sheet for polishing rose quartz.", "c7b77c", 16],
	ITEM_QUARTZ: ["Quartz", "Minerals", "A pale crystal used in electronic components.", "e1d9ce", 64],
	ITEM_REDSTONE: ["Redstone Dust", "Minerals", "A conductive mineral powder used in control components.", "a33535", 64],
	ITEM_ROSE_QUARTZ: ["Rose Quartz", "Precision Materials", "Quartz saturated with conductive redstone.", "d86f88", 64],
	ITEM_POLISHED_ROSE_QUARTZ: ["Polished Rose Quartz", "Precision Materials", "A finished crystal lens for electron tubes.", "f08ba3", 64],
	ITEM_NETHERRACK: ["Netherrack", "Heat Materials", "A porous heat-resistant stone used inside burner frames.", "884033", 64],
	ITEM_IRON_NUGGET: ["Iron Nugget", "Metal Parts", "A small iron piece used in alloying and precision assembly.", "a9aeab", 64],
	ITEM_GOLD_NUGGET: ["Gold Nugget", "Metal Parts", "A small piece of refined gold.", "d8ad38", 64],
	ITEM_COPPER_NUGGET: ["Copper Nugget", "Metal Parts", "A small piece of refined copper.", "b76845", 64],
	ITEM_ZINC_NUGGET: ["Zinc Nugget", "Metal Parts", "A small piece of refined zinc.", "9aa6a2", 64],
	ITEM_STONE_GEAR: ["Stone Gear", "Primitive Components", "A rough early gear.", "77716a", 32],
	ITEM_WORKBENCH: ["Crafting Table", "Stations", "A wooden station with a dedicated engineering crafting interface.", "8b6745", 32],
	ITEM_FURNACE: ["Furnace", "Stations", "A stone-fired station with a dedicated smelting and alloying interface.", "5f625f", 32],
	ITEM_CRUSHED_STONE: ["Crushed Stone", "Primitive Materials", "Processed mineral aggregate.", "858986", 64],
	ITEM_STONE_SHAFT: ["Stone Shaft", "Primitive Components", "An early rotational connector.", "767b78", 32],
	ITEM_HAND_CRANK: ["Hand Crank", "Kinetic Components", "A manual rotational power source.", "957047", 32],
	ITEM_STONE_CRUSHER: ["Stone Crusher", "Machines", "The starter material-processing machine.", "676b69", 32],
	ITEM_ZINC_CONCENTRATE: ["Zinc Concentrate", "Mineral Feedstock", "A zinc-rich fraction mined from underground ore.", "87948f", 64],
	ITEM_COPPER_CONCENTRATE: ["Copper Concentrate", "Mineral Feedstock", "A copper-rich fraction mined from underground ore.", "9a5f48", 64],
	ITEM_IRON_CONCENTRATE: ["Iron Concentrate", "Mineral Feedstock", "A dense iron-bearing mineral fraction mined underground.", "7b817e", 64],
	ITEM_GOLD_CONCENTRATE: ["Gold Concentrate", "Mineral Feedstock", "A small heavy-mineral fraction mined from deep ore.", "b38c34", 64],
	ITEM_COPPER_INGOT: ["Copper Ingot", "Metals", "Refined conductive copper.", "b76845", 64],
	ITEM_IRON_INGOT: ["Iron Ingot", "Metals", "Refined structural iron.", "aeb3b0", 64],
	ITEM_GOLD_INGOT: ["Gold Ingot", "Metals", "Refined soft conductive gold.", "d8ad38", 64],
	ITEM_PLANT_FIBER: ["Plant Fiber", "Organic Materials", "Flexible strands separated from grass.", "68764b", 64],
	ITEM_ANDESITE_ALLOY: ["Andesite Alloy", "Alloys", "A stone-metal composite for early engineering.", "687873", 64],
	ITEM_ZINC_INGOT: ["Zinc Ingot", "Metals", "Refined zinc used in corrosion-resistant alloys.", "9aa6a2", 64],
	ITEM_BRASS_INGOT: ["Brass Ingot", "Alloys", "A heated copper-zinc alloy for advanced mechanisms.", "b98c39", 64],
	ITEM_COPPER_SHEET: ["Copper Sheet", "Formed Metals", "A conductive formed copper plate.", "b76845", 64],
	ITEM_BRASS_SHEET: ["Brass Sheet", "Formed Metals", "A formed brass plate for precision assemblies.", "b98c39", 64],
	ITEM_IRON_SHEET: ["Iron Sheet", "Formed Metals", "A strong general-purpose metal plate.", "aeb3b0", 64],
	ITEM_GOLD_SHEET: ["Gold Sheet", "Formed Metals", "A soft conductive plate used in precision work.", "d8ad38", 64],
	ITEM_ANDESITE_CASING: ["Andesite Casing", "Casings", "Stripped wood wrapped with andesite alloy.", "53645f", 32],
	ITEM_BRASS_CASING: ["Brass Casing", "Casings", "Stripped wood wrapped with brass.", "a57d32", 32],
	ITEM_SHAFT: ["Shaft", "Kinetic Components", "A standard rotational power-transfer component.", "687873", 32],
	ITEM_COGWHEEL: ["Cogwheel", "Kinetic Components", "A shaft fitted with a wooden gear.", "8b6a3f", 32],
	ITEM_LARGE_COGWHEEL: ["Large Cogwheel", "Kinetic Components", "A shaft fitted with a wide wooden gear.", "8b6a3f", 32],
	ITEM_BELT_CONNECTOR: ["Belt Connector", "Kinetic Components", "Six dried-kelp strips joined into a flexible belt.", "4b5842", 64],
	ITEM_MECHANICAL_BEARING: ["Mechanical Bearing", "Kinetic Components", "A rotational mount built from a slab, casing and shaft.", "826342", 32],
	ITEM_WRENCH: ["Wrench", "Tools", "A durable gold-sheet configuration tool with a cogwheel head.", "b79049", 1],
	ITEM_ELECTRON_TUBE: ["Electron Tube", "Precision Components", "Polished rose quartz mounted on an iron sheet.", "c65e52", 64],
	ITEM_INCOMPLETE_PRECISION_MECHANISM: ["Incomplete Precision Mechanism", "Precision Components", "A gold-sheet base awaiting repeated deployed components.", "b79545", 32],
	ITEM_PRECISION_MECHANISM: ["Precision Mechanism", "Precision Components", "A five-stage cogwheel and iron-nugget assembly.", "d2a750", 32],
	ITEM_EMPTY_BLAZE_BURNER: ["Empty Blaze Burner", "Heat Components", "Four iron sheets surrounding a netherrack heat core.", "71655a", 32],
}


static func item_for_material(material: int) -> StringName:
	match material:
		STONE: return ITEM_STONE
		SOIL: return ITEM_SOIL
		GRASS: return ITEM_GRASS
		SAND: return ITEM_SAND
		ZINC_ORE: return ITEM_ZINC_CONCENTRATE
		COPPER_ORE: return ITEM_COPPER_CONCENTRATE
		IRON_ORE: return ITEM_IRON_CONCENTRATE
		GOLD_ORE: return ITEM_GOLD_CONCENTRATE
		_: return &""


static func material_for_item(item_id: StringName) -> int:
	match item_id:
		ITEM_STONE: return STONE
		ITEM_SOIL: return SOIL
		ITEM_GRASS: return GRASS
		ITEM_SAND: return SAND
		_: return AIR


static func is_registered(item_id: StringName) -> bool:
	return ITEM_DATA.has(item_id)


static func is_voxel_placeable(item_id: StringName) -> bool:
	return material_for_item(item_id) != AIR


static func is_object_placeable(item_id: StringName) -> bool:
	return item_id in object_placeable_items()


static func is_placeable(item_id: StringName) -> bool:
	return is_voxel_placeable(item_id) or is_object_placeable(item_id)


static func voxel_placeable_items() -> Array[StringName]:
	return [ITEM_STONE, ITEM_SOIL, ITEM_GRASS, ITEM_SAND]


static func object_placeable_items() -> Array[StringName]:
	return [ITEM_WORKBENCH, ITEM_FURNACE, ITEM_STONE_SHAFT, ITEM_HAND_CRANK, ITEM_STONE_CRUSHER]


static func placeable_items() -> Array[StringName]:
	var items: Array[StringName] = voxel_placeable_items()
	items.append_array(object_placeable_items())
	return items


static func max_stack(item_id: StringName) -> int:
	var data: Array = ITEM_DATA.get(item_id, [])
	return int(data[4]) if data.size() >= 5 else 0


static func display_name(item_id: StringName) -> String:
	var data: Array = ITEM_DATA.get(item_id, [])
	return str(data[0]) if not data.is_empty() else "Empty"


static func category(item_id: StringName) -> String:
	var data: Array = ITEM_DATA.get(item_id, [])
	return str(data[1]) if data.size() >= 2 else "Other"


static func description(item_id: StringName) -> String:
	var data: Array = ITEM_DATA.get(item_id, [])
	return str(data[2]) if data.size() >= 3 else ""


static func item_color(item_id: StringName) -> Color:
	var data: Array = ITEM_DATA.get(item_id, [])
	return Color(str(data[3])) if data.size() >= 4 else Color("8c7e69")


static func registered_items() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in REGISTERED_ITEMS:
		result.append(StringName(value))
	return result


static func phase_one_items() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in PHASE_ONE_ITEMS:
		result.append(StringName(value))
	return result
