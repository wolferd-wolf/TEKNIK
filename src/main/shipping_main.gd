extends "res://src/main/playable_main.gd"

const PlayabilityTraversalDirector = preload("res://src/qa/playability_traversal_director.gd")


func _ready() -> void:
	super._ready()
	if "--qa-playability" in OS.get_cmdline_user_args() and _player != null:
		var director: TeknikPlayabilityTraversalDirector = PlayabilityTraversalDirector.new()
		director.name = "PlayabilityTraversalDirector"
		add_child(director)
		director.begin(self, _player)


func _next_build_coordinate() -> Vector3i:
	while not _emergency_load_queue.is_empty():
		var emergency: Vector3i = _emergency_load_queue.pop_front()
		if not _terrain_nodes.has(emergency) and not _playable_pool.has_coordinate(emergency):
			return emergency
	while not _edit_rebuild_queue.is_empty():
		var rebuild: Vector3i = _edit_rebuild_queue.pop_front()
		if _terrain_nodes.has(rebuild) and not _playable_pool.has_coordinate(rebuild):
			# Keep the marker until the parent dispatches it. The next pool slot
			# removes this marker after seeing the coordinate already in flight.
			_edit_rebuild_queue.push_front(rebuild)
			return rebuild
	var load_work: Dictionary = _chunk_work_budget.take_frame(1, 0)
	var loads: Array[Vector3i] = load_work.load
	if loads.is_empty():
		return Vector3i(2_147_483_647, 0, 2_147_483_647)
	var coordinate: Vector3i = loads[0]
	if _terrain_nodes.has(coordinate) or _playable_pool.has_coordinate(coordinate):
		return _next_build_coordinate()
	return coordinate
