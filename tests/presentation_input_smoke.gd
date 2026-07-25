extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var orientation := int(ProjectSettings.get_setting("display/window/handheld/orientation", -1))
	if orientation != DisplayServer.SCREEN_SENSOR_LANDSCAPE:
		_fail("Project orientation is not sensor landscape")

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		quit(1)
		return

	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame

	var world: Node = main.get_node_or_null("World")
	if world == null:
		_fail("Textured world was not created")
		await _finish(main)
		return

	var player: Node = await _wait_for_player(main, 900)
	if player == null:
		_fail("Safe mobile player was not created")
	else:
		player.force_mobile_input_for_test = true
		player.mine_requested = false
		var emulated_tap := InputEventMouseButton.new()
		emulated_tap.button_index = MOUSE_BUTTON_LEFT
		emulated_tap.pressed = true
		player._unhandled_input(emulated_tap)
		if player.mine_requested:
			_fail("Emulated Android mouse tap triggered mining")

		player.last_interaction_msec = Time.get_ticks_msec() - 1000
		player.request_mine()
		if not player.mine_requested:
			_fail("Explicit MINE button request was rejected")
		player.mine_requested = false

		player.last_interaction_msec = Time.get_ticks_msec() - 1000
		player.request_place()
		if not player.place_requested:
			_fail("Explicit PLACE button request was rejected")
		player.place_requested = false

	if world.shared_material.albedo_texture == null:
		_fail("Terrain material has no texture atlas")

	var textured_mesh_found := false
	for coord_value: Variant in world.loaded_chunks.keys():
		var entry: Dictionary = world.loaded_chunks[coord_value]
		var mesh: ArrayMesh = entry["mesh"]
		if mesh.get_surface_count() == 0:
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if not vertices.is_empty() and uvs.size() == vertices.size():
			textured_mesh_found = true
			break
	if not textured_mesh_found:
		_fail("Loaded terrain mesh does not contain complete UV data")

	var environment_node := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node == null or environment_node.environment == null:
		_fail("Bright world environment was not created")
	elif environment_node.environment.ambient_light_energy <= 1.0:
		_fail("Ambient lighting remains below the brighter presentation gate")

	await _finish(main)

func _wait_for_player(main: Node, max_frames: int) -> Node:
	for _frame in range(max_frames):
		var candidate: Node = main.get_node_or_null("Player")
		if candidate != null:
			return candidate
		await process_frame
	return null

func _fail(message: String) -> void:
	failed = true
	push_error("PRESENTATION/INPUT SMOKE: %s" % message)

func _finish(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame
	if failed:
		print("PRESENTATION_INPUT_SMOKE_FAILED")
		quit(1)
	else:
		print("PRESENTATION_INPUT_SMOKE_PASSED")
		quit(0)
