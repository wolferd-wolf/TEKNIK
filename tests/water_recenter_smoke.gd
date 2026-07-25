extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		quit(1)
		return

	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	var world: Node = main.get_node_or_null("World")
	var player: Node3D = await _wait_for_player(main, 900)
	if world == null or player == null:
		_fail("World or player was not created")
		await _finish(main)
		return
	if not world.has_method("get_water_stream_metrics"):
		_fail("Water recenter telemetry is missing")
		await _finish(main)
		return

	var water := world.get_node_or_null("Water") as MeshInstance3D
	if water == null:
		_fail("Water plane was not created")
		await _finish(main)
		return

	var initial_metrics: Dictionary = world.call("get_water_stream_metrics")
	var initial_count := int(initial_metrics.get("water_recenter_count", -1))
	var grid := int(initial_metrics.get("water_recenter_grid", 0))
	if initial_count < 1:
		_fail("Initial water centre was not committed")
	if grid < world.CHUNK_SIZE:
		_fail("Water recenter grid is smaller than one chunk")

	world.call("_update_water_center", player.global_position)
	var stationary_metrics: Dictionary = world.call("get_water_stream_metrics")
	if int(stationary_metrics["water_recenter_count"]) != initial_count:
		_fail("Stationary player caused an unnecessary water transform update")

	var probe := Vector3(73.25, player.global_position.y, -61.75)
	world.call("_update_water_center", probe)
	var moved_metrics: Dictionary = world.call("get_water_stream_metrics")
	if int(moved_metrics["water_recenter_count"]) != initial_count + 1:
		_fail("Crossing the snap grid did not produce exactly one water recenter")
	if posmod(roundi(water.position.x), grid) != 0 or posmod(roundi(water.position.z), grid) != 0:
		_fail("Water position is not aligned to its recenter grid")
	var half_grid := float(grid) * 0.5 + 0.001
	if absf(water.position.x - probe.x) > half_grid or absf(water.position.z - probe.z) > half_grid:
		_fail("Snapped water centre moved too far from the player")

	world.call("_update_water_center", probe + Vector3(1.0, 0.0, 1.0))
	var same_cell_metrics: Dictionary = world.call("get_water_stream_metrics")
	if int(same_cell_metrics["water_recenter_count"]) != initial_count + 1:
		_fail("Movement inside one snap cell rewrote the water transform")

	await _finish(main)

func _wait_for_player(main: Node, max_frames: int) -> Node3D:
	for _frame in range(max_frames):
		var candidate := main.get_node_or_null("Player") as Node3D
		if candidate != null:
			return candidate
		await process_frame
	return null

func _fail(message: String) -> void:
	failed = true
	push_error("WATER RECENTER SMOKE: %s" % message)

func _finish(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame
	if failed:
		print("WATER_RECENTER_SMOKE_FAILED")
		quit(1)
	else:
		print("WATER_RECENTER_SMOKE_PASSED")
		quit(0)
