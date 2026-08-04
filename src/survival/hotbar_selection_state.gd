class_name TeknikHotbarSelectionState
extends RefCounted

const ItemRegistry = preload("res://src/survival/item_registry.gd")

const SCHEMA: int = 1
const DEFAULT_ITEM: StringName = ItemRegistry.ITEM_STONE

var selected_item: StringName = DEFAULT_ITEM


func select(item_id: StringName) -> bool:
	if not ItemRegistry.is_placeable(item_id):
		return false
	selected_item = item_id
	return true


func choose_available(count_for_item: Callable) -> StringName:
	if ItemRegistry.is_placeable(selected_item) and int(count_for_item.call(selected_item)) > 0:
		return selected_item
	for item_id: StringName in ItemRegistry.placeable_items():
		if int(count_for_item.call(item_id)) > 0:
			selected_item = item_id
			return selected_item
	selected_item = DEFAULT_ITEM
	return selected_item


func encode() -> Dictionary:
	return {
		"schema": SCHEMA,
		"selected_item": str(selected_item),
	}


func decode(payload: Dictionary) -> bool:
	if int(payload.get("schema", 0)) != SCHEMA:
		return false
	var item_id := StringName(str(payload.get("selected_item", "")))
	if not ItemRegistry.is_placeable(item_id):
		return false
	selected_item = item_id
	return true
