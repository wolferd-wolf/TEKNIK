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
		_:
			return "Empty"


static func registered_items() -> Array[StringName]:
	return [ITEM_STONE, ITEM_SOIL, ITEM_GRASS, ITEM_SAND]
