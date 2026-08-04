class_name TeknikProgressionState
extends RefCounted

const SCHEMA: int = 1
const UNLOCK_HAND_CRAFTING: StringName = &"hand_crafting"
const UNLOCK_WORKBENCH: StringName = &"workbench"
const UNLOCK_STONE_PROCESSING: StringName = &"stone_processing"
const UNLOCK_ANDESITE_ENGINEERING: StringName = &"andesite_engineering"
const UNLOCK_BRASS_ENGINEERING: StringName = &"brass_engineering"
const UNLOCK_PRECISION_ENGINEERING: StringName = &"precision_engineering"
const UNLOCK_KINETIC_STARTER: StringName = &"kinetic_starter"

var _unlocks: Dictionary = {UNLOCK_HAND_CRAFTING: true}


func is_unlocked(unlock_id: StringName) -> bool:
	return bool(_unlocks.get(unlock_id, false))


func unlock(unlock_id: StringName) -> bool:
	if unlock_id == &"" or is_unlocked(unlock_id):
		return false
	_unlocks[unlock_id] = true
	return true


func unlocked_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in _unlocks.keys():
		if bool(_unlocks[key]):
			result.append(StringName(str(key)))
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return result


func encode() -> Dictionary:
	var values: Array[String] = []
	for unlock_id: StringName in unlocked_ids():
		values.append(str(unlock_id))
	return {"schema": SCHEMA, "unlocks": values}


func decode(payload: Dictionary) -> bool:
	if int(payload.get("schema", -1)) != SCHEMA:
		return false
	var incoming: Variant = payload.get("unlocks", [])
	if not incoming is Array:
		return false
	var restored: Dictionary = {UNLOCK_HAND_CRAFTING: true}
	for value: Variant in incoming:
		var unlock_id := StringName(str(value))
		if unlock_id == &"":
			return false
		restored[unlock_id] = true
	_unlocks = restored
	return true
