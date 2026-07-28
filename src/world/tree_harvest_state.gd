class_name TeknikTreeHarvestState
extends RefCounted

const SCHEMA: int = 1

var _mined: Dictionary = {}


static func id_for_transform(transform: Transform3D) -> String:
	return id_for_position(transform.origin)


static func id_for_position(position: Vector3) -> String:
	return "%d:%d:%d" % [
		roundi(position.x * 100.0),
		roundi(position.y * 100.0),
		roundi(position.z * 100.0),
	]


func mark_mined(tree_id: String, center: Vector3) -> bool:
	if tree_id.is_empty() or _mined.has(tree_id):
		return false
	_mined[tree_id] = center
	return true


func is_mined(tree_id: String) -> bool:
	return _mined.has(tree_id)


func count() -> int:
	return _mined.size()


func centers() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for value: Variant in _mined.values():
		if value is Vector3:
			result.append(value)
	return result


func near_mined_tree(position: Vector3, radius: float) -> bool:
	var radius_squared: float = maxf(radius, 0.0) * maxf(radius, 0.0)
	for center: Vector3 in centers():
		var delta := Vector2(position.x - center.x, position.z - center.z)
		if delta.length_squared() <= radius_squared:
			return true
	return false


func encode() -> Dictionary:
	var rows: Array[Dictionary] = []
	var ids: Array = _mined.keys()
	ids.sort()
	for value: Variant in ids:
		var tree_id: String = str(value)
		var center: Vector3 = _mined[tree_id]
		rows.append({
			"id": tree_id,
			"center": [center.x, center.y, center.z],
		})
	return {"schema": SCHEMA, "trees": rows}


func decode(payload: Dictionary) -> bool:
	if int(payload.get("schema", -1)) != SCHEMA:
		return false
	var rows: Variant = payload.get("trees", [])
	if not rows is Array:
		return false
	var restored: Dictionary = {}
	for value: Variant in rows:
		if not value is Dictionary:
			return false
		var row: Dictionary = value
		var tree_id: String = str(row.get("id", ""))
		var center_data: Variant = row.get("center", [])
		if tree_id.is_empty() or restored.has(tree_id):
			return false
		if not center_data is Array or (center_data as Array).size() != 3:
			return false
		restored[tree_id] = Vector3(
			float(center_data[0]),
			float(center_data[1]),
			float(center_data[2])
		)
	_mined = restored
	return true
