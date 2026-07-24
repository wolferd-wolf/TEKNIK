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

const MAX_STACK: int = 64


static func item_for_material(material: int) -> StringName:
	match material:
		STONE:
			return ITEM_STONE
		SOIL:
			return ITEM_SOIL
		GRASS:
			return ITEM_GRASS
		SAND:
			return ITEM_SAND
		_:
			return &""


static func material_for_item(item_id: StringName) -> int:
	match item_id:
		ITEM_STONE:
			return STONE
		ITEM_SOIL:
			return SOIL
		ITEM_GRASS:
			return GRASS
		ITEM_SAND:
			return SAND
		_:
			return AIR


static func is_registered(item_id: StringName) -> bool:
	return item_id in registered_items()


static func is_placeable(item_id: StringName) -> bool:
	return material_for_item(item_id) != AIR


static func max_stack(item_id: StringName) -> int:
	if not is_registered(item_id):
		return 0
	if item_id in [
		ITEM_STONE_GEAR,
		ITEM_WORKBENCH,
		ITEM_STONE_SHAFT,
		ITEM_HAND_CRANK,
		ITEM_STONE_CRUSHER,
	]:
		return 32
	return MAX_STACK


static func display_name(item_id: StringName) -> String:
	match item_id:
		ITEM_STONE:
			return "Stone"
		ITEM_SOIL:
			return "Soil"
		ITEM_GRASS:
			return "Grass"
		ITEM_SAND:
			return "Sand"
		ITEM_STONE_GEAR:
			return "Stone Gear"
		ITEM_WORKBENCH:
			return "Stone Workbench"
		ITEM_CRUSHED_STONE:
			return "Crushed Stone"
		ITEM_STONE_SHAFT:
			return "Stone Shaft"
		ITEM_HAND_CRANK:
			return "Hand Crank"
		ITEM_STONE_CRUSHER:
			return "Stone Crusher"
		_:
			return "Empty"


static func registered_items() -> Array[StringName]:
	return [
		ITEM_STONE,
		ITEM_SOIL,
		ITEM_GRASS,
		ITEM_SAND,
		ITEM_STONE_GEAR,
		ITEM_WORKBENCH,
		ITEM_CRUSHED_STONE,
		ITEM_STONE_SHAFT,
		ITEM_HAND_CRANK,
		ITEM_STONE_CRUSHER,
	]
