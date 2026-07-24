class_name TeknikStackInventory
extends RefCounted

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const SCHEMA: int = 1
const SLOT_COUNT: int = 12

var _slots: Array[Dictionary] = []


func _init() -> void:
	clear()


func clear() -> void:
	_slots.clear()
	for _index: int in range(SLOT_COUNT):
		_slots.append({"item": &"", "count": 0})


func add(item_id: StringName, amount: int) -> int:
	if amount <= 0 or ItemRegistry.material_for_item(item_id) == ItemRegistry.AIR:
		return amount
	var remaining: int = amount
	for slot: Dictionary in _slots:
		if StringName(slot.item) != item_id or int(slot.count) >= ItemRegistry.MAX_STACK:
			continue
		var accepted: int = mini(remaining, ItemRegistry.MAX_STACK - int(slot.count))
		slot.count = int(slot.count) + accepted
		remaining -= accepted
		if remaining == 0:
			return 0
	for slot: Dictionary in _slots:
		if int(slot.count) > 0:
			continue
		var accepted: int = mini(remaining, ItemRegistry.MAX_STACK)
		slot.item = item_id
		slot.count = accepted
		remaining -= accepted
		if remaining == 0:
			break
	return remaining


func remove(item_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	if count(item_id) < amount:
		return false
	var remaining: int = amount
	for slot: Dictionary in _slots:
		if StringName(slot.item) != item_id:
			continue
		var taken: int = mini(remaining, int(slot.count))
		slot.count = int(slot.count) - taken
		remaining -= taken
		if int(slot.count) == 0:
			slot.item = &""
		if remaining == 0:
			return true
	return true


func count(item_id: StringName) -> int:
	var total: int = 0
	for slot: Dictionary in _slots:
		if StringName(slot.item) == item_id:
			total += int(slot.count)
	return total


func slots() -> Array[Dictionary]:
	return _slots.duplicate(true)


func encode() -> Dictionary:
	var serialized: Array[Dictionary] = []
	for slot: Dictionary in _slots:
		serialized.append({"item": str(slot.item), "count": int(slot.count)})
	return {"schema": SCHEMA, "slots": serialized}


func decode(payload: Dictionary) -> bool:
	if int(payload.get("schema", -1)) != SCHEMA:
		return false
	var incoming: Variant = payload.get("slots", [])
	if not incoming is Array or (incoming as Array).size() != SLOT_COUNT:
		return false
	var restored: Array[Dictionary] = []
	for value: Variant in incoming:
		if not value is Dictionary:
			return false
		var source: Dictionary = value
		var item_id := StringName(str(source.get("item", "")))
		var amount: int = int(source.get("count", 0))
		if amount < 0 or amount > ItemRegistry.MAX_STACK:
			return false
		if amount > 0 and ItemRegistry.material_for_item(item_id) == ItemRegistry.AIR:
			return false
		restored.append({"item": item_id if amount > 0 else &"", "count": amount})
	_slots = restored
	return true
