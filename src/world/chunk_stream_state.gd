extends RefCounted
class_name TeknikChunkStreamState

const ChunkStreamPlan = preload("res://src/world/chunk_stream_plan.gd")

var _active: Dictionary = {}


func reconcile(
	center: Vector3i,
	radius: int,
	priority: Vector3i = Vector3i.ZERO
) -> Dictionary:
	var desired: Array[Vector3i] = ChunkStreamPlan.ordered_square(center, radius, priority)
	var desired_set: Dictionary = {}
	var to_load: Array[Vector3i] = []
	for coordinate: Vector3i in desired:
		desired_set[coordinate] = true
		if not _active.has(coordinate):
			to_load.append(coordinate)

	var to_unload: Array[Vector3i] = []
	for coordinate: Vector3i in _active.keys():
		if not desired_set.has(coordinate):
			to_unload.append(coordinate)
	to_unload.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x
	)

	return {
		"load": to_load,
		"unload": to_unload,
		"desired_count": desired.size(),
	}


func mark_loaded(coordinate: Vector3i) -> void:
	_active[coordinate] = true


func mark_unloaded(coordinate: Vector3i) -> void:
	_active.erase(coordinate)


func active_count() -> int:
	return _active.size()


func has(coordinate: Vector3i) -> bool:
	return _active.has(coordinate)
