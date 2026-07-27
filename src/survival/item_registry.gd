class_name TeknikItemRegistry
extends RefCounted

const AIR: int = 0
const STONE: int = 1
const SOIL: int = 2
const GRASS: int = 3
const SAND: int = 4

const ITEM_STONE: StringName = &"stone"
const ITEM_SOIL: StringName = &"soil"
const ITEM_GRASS: StringName = &"grass"
const ITEM_SAND: StringName = &"sand"
const ITEM_STONE_GEAR: StringName = &"stone_gear"
const ITEM_WORKBENCH: StringName = &"workbench"
const ITEM_CRUSHED_STONE: StringName = &"crushed_stone"
const ITEM_STONE_SHAFT: StringName = &"stone_shaft"
const ITEM_HAND_CRANK: StringName = &"hand_crank"
const ITEM_STONE_CRUSHER: StringName = &"stone_crusher"

# Original TEKNIK feedstock used until dedicated ore processing is added.
const ITEM_ZINC_CONCENTRATE: StringName = &"zinc_concentrate"
const ITEM_COPPER_CONCENTRATE: StringName = &"copper_concentrate"
const ITEM_IRON_CONCENTRATE: StringName = &"iron_concentrate"
const ITEM_GOLD_CONCENTRATE: StringName = &"gold_concentrate"
const ITEM_COPPER_INGOT: StringName = &"copper_ingot"
const ITEM_IRON_INGOT: StringName = &"iron_ingot"
const ITEM_GOLD_INGOT: StringName = &"gold_ingot"
const ITEM_PLANT_FIBER: StringName = &"plant_fiber"

# Phase 1 Create-inspired engineering catalog. Only the item roles and familiar
# names are referenced; implementation, recipes, visuals and data are TEKNIK's.
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
const ITEM_PRECISION_MECHANISM: StringName = &"precision_mechanism"
const ITEM_EMPTY_BLAZE_BURNER: StringName = &"empty_blaze_burner"

const MAX_STACK: int = 64

const REGISTERED_ITEMS = [
	ITEM_STONE, ITEM_SOIL, ITEM_GRASS, ITEM_SAND,
	ITEM_STONE_GEAR, ITEM_WORKBENCH, ITEM_CRUSHED_STONE, ITEM_STONE_SHAFT,
	ITEM_HAND_CRANK, ITEM_STONE_CRUSHER,
	ITEM_ZINC_CONCENTRATE, ITEM_COPPER_CONCENTRATE, ITEM_IRON_CONCENTRATE,
	ITEM_GOLD_CONCENTRATE, ITEM_COPPER_INGOT, ITEM_IRON_INGOT, ITEM_GOLD_INGOT,
	ITEM_PLANT_FIBER,
	ITEM_ANDESITE_ALLOY, ITEM_ZINC_INGOT, ITEM_BRASS_INGOT,
	ITEM_COPPER_SHEET, ITEM_BRASS_SHEET, ITEM_IRON_SHEET, ITEM_GOLD_SHEET,
	ITEM_ANDESITE_CASING, ITEM_BRASS_CASING, ITEM_SHAFT, ITEM_COGWHEEL,
	ITEM_LARGE_COGWHEEL, ITEM_BELT_CONNECTOR, ITEM_MECHANICAL_BEARING,
	ITEM_WRENCH, ITEM_ELECTRON_TUBE, ITEM_PRECISION_MECHANISM,
	ITEM_EMPTY_BLAZE_BURNER,
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
	ITEM_STONE_GEAR: ["Stone Gear", "Primitive Components", "A rough early gear.", "77716a", 32],
	ITEM_WORKBENCH: ["Stone Workbench", "Stations", "Unlocks structured engineering recipes.", "67645c", 32],
	ITEM_CRUSHED_STONE: ["Crushed Stone", "Primitive Materials", "Processed mineral aggregate.", "858986", 64],
	ITEM_STONE_SHAFT: ["Stone Shaft", "Primitive Components", "An early rotational connector.", "767b78", 32],
	ITEM_HAND_CRANK: ["Hand Crank", "Kinetic Components", "A manual rotational power source.", "957047", 32],
	ITEM_STONE_CRUSHER: ["Stone Crusher", "Machines", "The starter material-processing machine.", "676b69", 32],
	ITEM_ZINC_CONCENTRATE: ["Zinc Concentrate", "Mineral Feedstock", "A zinc-rich fraction separated from crushed rock.", "87948f", 64],
	ITEM_COPPER_CONCENTRATE: ["Copper Concentrate", "Mineral Feedstock", "A copper-rich fraction separated from crushed rock.", "9a5f48", 64],
	ITEM_IRON_CONCENTRATE: ["Iron Concentrate", "Mineral Feedstock", "A dense iron-bearing mineral fraction.", "7b817e", 64],
	ITEM_GOLD_CONCENTRATE: ["Gold Concentrate", "Mineral Feedstock", "A small heavy-mineral fraction containing gold.", "b38c34", 64],
	ITEM_COPPER_INGOT: ["Copper Ingot", "Metals", "Refined conductive copper.", "b76845", 64],
	ITEM_IRON_INGOT: ["Iron Ingot", "Metals", "Refined structural iron.", "aeb3b0", 64],
	ITEM_GOLD_INGOT: ["Gold Ingot", "Metals", "Refined soft conductive gold.", "d8ad38", 64],
	ITEM_PLANT_FIBER: ["Plant Fiber", "Organic Materials", "Flexible strands separated from grass.", "68764b", 64],
	ITEM_ANDESITE_ALLOY: ["Andesite Alloy", "Alloys", "A stone-metal composite for early engineering.", "687873", 64],
	ITEM_ZINC_INGOT: ["Zinc Ingot", "Metals", "Refined zinc used in corrosion-resistant alloys.", "9aa6a2", 64],
	ITEM_BRASS_INGOT: ["Brass Ingot", "Alloys", "A copper-zinc alloy for advanced mechanisms.", "b98c39", 64],
	ITEM_COPPER_SHEET: ["Copper Sheet", "Formed Metals", "A conductive formed copper plate.", "b76845", 64],
	ITEM_BRASS_SHEET: ["Brass Sheet", "Formed Metals", "A formed brass plate for precision assemblies.", "b98c39", 64],
	ITEM_IRON_SHEET: ["Iron Sheet", "Formed Metals", "A strong general-purpose metal plate.", "aeb3b0", 64],
	ITEM_GOLD_SHEET: ["Gold Sheet", "Formed Metals", "A soft conductive plate used in precision work.", "d8ad38", 64],
	ITEM_ANDESITE_CASING: ["Andesite Casing", "Casings", "A structural shell for early machinery.", "53645f", 32],
	ITEM_BRASS_CASING: ["Brass Casing", "Casings", "A high-tier shell for precision machinery.", "a57d32", 32],
	ITEM_SHAFT: ["Shaft", "Kinetic Components", "A standard rotational power-transfer component.", "687873", 32],
	ITEM_COGWHEEL: ["Cogwheel", "Kinetic Components", "A compact rotational transmission gear.", "8b6a3f", 32],
	ITEM_LARGE_COGWHEEL: ["Large Cogwheel", "Kinetic Components", "A wide gear reserved for speed-ratio systems.", "8b6a3f", 32],
	ITEM_BELT_CONNECTOR: ["Belt Connector", "Kinetic Components", "Flexible material for the future two-point belt system.", "4b5842", 64],
	ITEM_MECHANICAL_BEARING: ["Mechanical Bearing", "Kinetic Components", "A rotational mount for future moving structures.", "826342", 32],
	ITEM_WRENCH: ["Wrench", "Tools", "A durable configuration tool for engineering parts.", "b79049", 1],
	ITEM_ELECTRON_TUBE: ["Electron Tube", "Precision Components", "An insulated control component for machine logic.", "c65e52", 64],
	ITEM_PRECISION_MECHANISM: ["Precision Mechanism", "Precision Components", "A layered mechanism for advanced automation.", "d2a750", 32],
	ITEM_EMPTY_BLAZE_BURNER: ["Empty Blaze Burner", "Heat Components", "A heat-resistant burner frame awaiting a heat source.", "71655a", 32],
}


static func item_for_material(material: int) -> StringName:
	match material:
		STONE: return ITEM_STONE
		SOIL: return ITEM_SOIL
		GRASS: return ITEM_GRASS
		SAND: return ITEM_SAND
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
	return [ITEM_WORKBENCH, ITEM_STONE_SHAFT, ITEM_HAND_CRANK, ITEM_STONE_CRUSHER]


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
