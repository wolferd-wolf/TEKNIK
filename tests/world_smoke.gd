extends SceneTree

const SAVE_PATH := "user://teknik_world_v1.json"
const COLLISION_RADIUS := 1

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()

	var main := _instantiate_main()
	if main == null:
		quit(1)
		return

	var world: Node = main.get_node_or_null("World")
	if world == null:
		_fail("World node was not created")
		await _finish(main)
		return

	var player: Node3D = await _wait_for_player(main, 900)
	if player == null:
		_fail("Player was released before a complete safe spawn ring was available")
	else:
		_assert_collision_ring(world, Vector2i.ZERO, "initial spawn")

	if world.loaded_chunks.size() < 9:
		_fail("Fewer than nine collision-priority chunks were loaded")
	if world.get_block(Vector3i(0, 0, 0)) == 0:
		_fail("Base terrain is unexpectedly empty")

	if player != null:
		var travel_position := Vector3(13.5, 0.0, 6.5)
		travel_position = world.get_recovery_position(travel_position)
		player.global_position = travel_position
		var streamed := await _wait_for_center(world, Vector2i(1, 0), 600)
		if not streamed:
			_fail("World center did not follow the player across a chunk boundary")
		else:
			var collision_ready := await _wait_for_collision_ring(world, Vector2i(1, 0), 600)
			if not collision_ready:
				_fail("Collision safety ring did not complete after a streamed chunk transition")

	var persistence_cell := _find_air_cell_above_surface(world, 6, 6)
	world.call("_set_block", persistence_cell, 2)
	if world.get_block(persistence_cell) != 2:
		_fail("Placed block did not enter authoritative world data")
	world.call("_save_world")

	main.queue_free()
	await process_frame
	await process_frame

	var reloaded_main := _instantiate_main()
	if reloaded_main == null:
		quit(1)
		return
	var reloaded_world: Node = reloaded_main.get_node_or_null("World")
	if reloaded_world == null:
		_fail("Reloaded world node was not created")
	elif reloaded_world.get_block(persistence_cell) != 2:
		_fail("Saved block edit did not survive a world reload")

	await _finish(reloaded_main)

func _instantiate_main() -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Main scene failed to load")
		return null
	var main := packed.instantiate()
	root.add_child(main)
	return main

func _wait_for_player(main: Node, maximum_frames: int) -> Node3D:
	for _frame in range(maximum_frames):
		var player := main.get_node_or_null("Player") as Node3D
		if player != null:
			return player
		await process_frame
	return null

func _wait_for_center(world: Node, expected: Vector2i, maximum_frames: int) -> bool:
	for _frame in range(maximum_frames):
		if world.current_center == expected:
			return true
		await process_frame
	return false

func _wait_for_collision_ring(world: Node, center: Vector2i, maximum_frames: int) -> bool:
	for _frame in range(maximum_frames):
		if _collision_ring_ready(world, center):
			return true
		await process_frame
	return false

func _assert_collision_ring(world: Node, center: Vector2i, label: String) -> void:
	if not _collision_ring_ready(world, center):
		_fail("Incomplete collision ring at %s" % label)

func _collision_ring_ready(world: Node, center: Vector2i) -> bool:
	for z in range(center.y - COLLISION_RADIUS, center.y + COLLISION_RADIUS + 1):
		for x in range(center.x - COLLISION_RADIUS, center.x + COLLISION_RADIUS + 1):
			var coord := Vector2i(x, z)
			if not world.loaded_chunks.has(coord):
				return false
			var entry: Dictionary = world.loaded_chunks[coord]
			if not is_instance_valid(entry["collision"]):
				return false
	return true

func _find_air_cell_above_surface(world: Node, x: int, z: int) -> Vector3i:
	for y in range(29, 0, -1):
		var cell := Vector3i(x, y, z)
		if world.get_block(cell) != 0:
			return cell + Vector3i.UP
	return Vector3i(x, 1, z)

func _finish(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame
	_remove_test_save()
	quit(1 if failed else 0)

func _remove_test_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _fail(message: String) -> void:
	failed = true
	push_error(message)
