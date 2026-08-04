class_name TeknikChunkWorkBudget
extends RefCounted

var _pending_loads: Array[Vector3i] = []
var _pending_unloads: Array[Vector3i] = []


func replace(loads: Array[Vector3i], unloads: Array[Vector3i]) -> void:
	_pending_loads = loads.duplicate()
	_pending_unloads = unloads.duplicate()


func clear() -> void:
	_pending_loads.clear()
	_pending_unloads.clear()


func has_work() -> bool:
	return not _pending_loads.is_empty() or not _pending_unloads.is_empty()


func pending_load_count() -> int:
	return _pending_loads.size()


func pending_unload_count() -> int:
	return _pending_unloads.size()


func take_frame(load_budget: int, unload_budget: int) -> Dictionary:
	var loads: Array[Vector3i] = []
	var unloads: Array[Vector3i] = []
	var safe_load_budget: int = maxi(load_budget, 0)
	var safe_unload_budget: int = maxi(unload_budget, 0)

	for _index: int in range(mini(safe_unload_budget, _pending_unloads.size())):
		unloads.append(_pending_unloads.pop_front())
	for _index: int in range(mini(safe_load_budget, _pending_loads.size())):
		loads.append(_pending_loads.pop_front())

	return {
		"load": loads,
		"unload": unloads,
		"remaining_loads": _pending_loads.size(),
		"remaining_unloads": _pending_unloads.size(),
	}
