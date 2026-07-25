extends SceneTree

const SAVE_PATH := "user://teknik_world_v1.json"
const SUMMARY_PATH := "user://teknik_telemetry_summary.json"
const COLLISION_RADIUS := 1
const CHUNK_SIZE := 12

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_files()

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
		if not bool(player.call("_is_collision_ready_for_position", player.global_position)):
			_fail("Movement safety gate rejected the loaded spawn footprint")
		var unloaded_probe := Vector3(1200.0, player.global_position.y, 1200.0)
		if bool(player.call("_is_collision_ready_for_position", unloaded_probe)):
			_fail("Movement safety gate accepted an unloaded target footprint")
		var boundary_probe := Vector3(float(CHUNK_SIZE * 2) - 0.1, player.global_position.y, 6.5)
		var boundary_center_coord: Vector2i = world.world_to_chunk(boundary_probe)
		if not world.loaded_chunks.has(boundary_center_coord):
			_fail("Boundary regression probe center chunk was not loaded")
		else:
			var boundary_center_entry: Dictionary = world.loaded_chunks[boundary_center_coord]
			if not is_instance_valid(boundary_center_entry["collision"]):
				_fail("Boundary regression probe center chunk lacked collision")
			elif bool(player.call("_is_collision_ready_for_position", boundary_probe)):
				_fail("Movement safety gate ignored an uncollided chunk overlapping the player footprint")

	if world.loaded_chunks.size() < 9:
		_fail("Fewer than nine collision-priority chunks were loaded")
	if world.get_block(Vector3i(0, 0, 0)) == 0:
		_fail("Base terrain is unexpectedly empty")

	if player != null:
		var centers: Array[Vector2i] = [Vector2i(1, 0), Vector2i(3, 0), Vector2i(5, 0)]
		for expected_center in centers:
			var travel_position := Vector3(expected_center.x * CHUNK_SIZE + 1.5, 0.0, 6.5)
			travel_position = world.get_recovery_position(travel_position)
			player.global_position = travel_position
			var streamed := await _wait_for_center(world, expected_center, 600)
			if not streamed:
				_fail("World center did not follow the player to chunk %s" % expected_center)
				break
			var collision_ready := await _wait_for_collision_ring(world, expected_center, 600)
			if not collision_ready:
				_fail("Collision safety ring did not complete at chunk %s" % expected_center)
				break
			if not bool(player.call("_is_collision_ready_for_position", player.global_position)):
				_fail("Movement safety gate rejected streamed footprint %s" % expected_center)
				break

		if world.loaded_chunks.has(Vector2i.ZERO):
			_fail("Origin chunk remained loaded beyond the configured unload radius")
		if world.loaded_chunks.size() > 81:
			_fail("Loaded chunk count exceeded the bounded streaming envelope")

	var persistence_cell := _find_air_cell_above_surface(world, 6, 6)
	world.call("_set_block", persistence_cell, 2)
	if world.get_block(persistence_cell) != 2:
		_fail("Placed block did not enter authoritative world data")
	world.call("_save_world")

	if not bool(main.call("write_session_summary", true)):
		_fail("Session summary could not be written")
	_validate_session_summary()

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

func _validate_session_summary() -> void:
	if not FileAccess.file_exists(SUMMARY_PATH):
		_fail("Session summary file was not created")
		return
	var file := FileAccess.open(SUMMARY_PATH, FileAccess.READ)
	if file == null:
		_fail("Session summary file could not be opened")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Session summary is not valid JSON")
		return
	var summary: Dictionary = parsed
	if int(summary.get("schema", 0)) != 1:
		_fail("Session summary schema is incorrect")
	if not bool(summary.get("clean_shutdown", false)):
		_fail("Session summary did not record clean shutdown")
	if int(summary.get("session_frame_count", 0)) <= 0:
		_fail("Session summary did not record frame samples")
	if not summary.has("session_peak_frame_ms"):
		_fail("Session summary is missing peak frame time")
	if not summary.has("peak_build_queue"):
		_fail("Session summary is missing peak build queue")
	if not summary.has("renderer_name"):
		_fail("Session summary is missing renderer identity")

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
	_remove_test_files()
	quit(1 if failed else 0)

func _remove_test_files() -> void:
	for path in [SAVE_PATH, SUMMARY_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	failed = true
	push_error(message)
