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

	var main := await _instantiate_main()
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

	main.write_session_summary(true)
	_validate_session_summary()
	await _finish(main)

	var reloaded_main := await _instantiate_main()
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
	if int(summary.get("schema", 0)) != 3:
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
	for field_name in [
		"peak_static_memory_bytes",
		"engine_static_memory_peak_bytes",
		"peak_draw_calls",
		"peak_rendered_primitives",
		"peak_node_count",
		"stream_hold_episodes",
		"stream_hold_total_msec",
		"stream_hold_last_msec",
		"stream_hold_max_msec"
	]:
		if not summary.has(field_name):
			_fail("Session summary is missing telemetry field %s" % field_name)
		elif int(summary[field_name]) < 0:
			_fail("Session summary telemetry field %s is negative" % field_name)

func _instantiate_main() -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Main scene could not be loaded")
		return null
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	return main

func _wait_for_player(main: Node, max_frames: int) -> Node3D:
	for _frame in range(max_frames):
		var candidate: Node3D = main.get_node_or_null("Player")
		if candidate != null:
			return candidate
		await process_frame
	return null

func _wait_for_center(world: Node, expected_center: Vector2i, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if world.current_center == expected_center:
			return true
		await process_frame
	return false

func _wait_for_collision_ring(world: Node, center: Vector2i, max_frames: int) -> bool:
	for _frame in range(max_frames):
		var ready := true
		for z in range(center.y - COLLISION_RADIUS, center.y + COLLISION_RADIUS + 1):
			for x in range(center.x - COLLISION_RADIUS, center.x + COLLISION_RADIUS + 1):
				var coord := Vector2i(x, z)
				if not world.loaded_chunks.has(coord):
					ready = false
					break
				var entry: Dictionary = world.loaded_chunks[coord]
				if not is_instance_valid(entry["collision"]):
					ready = false
					break
			if not ready:
				break
		if ready:
			return true
		await process_frame
	return false

func _assert_collision_ring(world: Node, center: Vector2i, context: String) -> void:
	for z in range(center.y - COLLISION_RADIUS, center.y + COLLISION_RADIUS + 1):
		for x in range(center.x - COLLISION_RADIUS, center.x + COLLISION_RADIUS + 1):
			var coord := Vector2i(x, z)
			if not world.loaded_chunks.has(coord):
				_fail("Missing collision-ring chunk %s at %s" % [coord, context])
				continue
			var entry: Dictionary = world.loaded_chunks[coord]
			if not is_instance_valid(entry["collision"]):
				_fail("Missing collider for chunk %s at %s" % [coord, context])

func _find_air_cell_above_surface(world: Node, x: int, z: int) -> Vector3i:
	var y: int = world._terrain_height(x, z) + 1
	return Vector3i(x, y, z)

func _remove_test_files() -> void:
	for path in [SAVE_PATH, SUMMARY_PATH, "user://teknik_world_v1.backup.json", "user://teknik_world_v1.backup.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	failed = true
	push_error(message)

func _finish(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame
	if failed:
		print("WORLD_SMOKE_FAILED")
		quit(1)
	else:
		print("WORLD_SMOKE_PASSED")
		quit(0)
