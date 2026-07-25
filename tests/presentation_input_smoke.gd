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
		_fail("Color-only world was not created")
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

		var player_camera := player.get_node_or_null("Head/Camera") as Camera3D
		if player_camera == null or player_camera.near < 0.09:
			_fail("First-person near plane was not raised above the clipping-artifact threshold")

		var outline := player.get_node_or_null("TargetOutline") as MeshInstance3D
		if outline == null:
			_fail("Block target outline was not created")
		else:
			player.call("_rebuild_face_outline_mesh", Vector3i.UP)
			if int(player.call("get_target_outline_edge_count")) != 4:
				_fail("Block selector is not limited to four edges on one targeted face")
			if outline.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				_fail("Block target outline unexpectedly casts a shadow")
			var outline_mesh := outline.mesh as ImmediateMesh
			if outline_mesh == null or outline_mesh.get_surface_count() != 1:
				_fail("Face-only target outline has invalid line geometry")
			var outline_material := outline.material_override as StandardMaterial3D
			if outline_material == null or outline_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				_fail("Block target outline is not using an unshaded material")
			elif outline_material.no_depth_test:
				_fail("Block target outline still draws hidden edges through terrain")
		if not player.has_method("get_target_status_text"):
			_fail("Block target telemetry method is missing")

		for node: Node in player.find_children("*", "GeometryInstance3D", true, false):
			var geometry := node as GeometryInstance3D
			if geometry != null and geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				_fail("First-person helper geometry still casts a camera-facing shadow")

	if world.shared_material.albedo_texture != null:
		_fail("Color-only terrain unexpectedly retained a texture atlas")
	if not world.shared_material.vertex_color_use_as_albedo:
		_fail("Terrain material is not using vertex colors")

	var colored_mesh_found := false
	for coord_value: Variant in world.loaded_chunks.keys():
		var entry: Dictionary = world.loaded_chunks[coord_value]
		var mesh: ArrayMesh = entry["mesh"]
		if mesh.get_surface_count() == 0:
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if not vertices.is_empty() and colors.size() == vertices.size():
			colored_mesh_found = true
			break
	if not colored_mesh_found:
		_fail("Loaded terrain mesh does not contain complete color data")

	var water := world.get_node_or_null("Water") as MeshInstance3D
	if water == null:
		_fail("Foundation water plane was not created")
	else:
		if water.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_fail("Water plane still casts the giant near-camera shadow artifact")
		var plane := water.mesh as PlaneMesh
		var water_material: StandardMaterial3D = null
		if plane != null:
			water_material = plane.material as StandardMaterial3D
		if plane == null or water_material == null:
			_fail("Foundation water does not use the expected simple color material")
		else:
			if water_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				_fail("Water plane remains vulnerable to black back-face lighting")
			if water_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				_fail("Water plane still uses the problematic transparent mobile path")
			if water_material.cull_mode != BaseMaterial3D.CULL_BACK:
				_fail("Water plane still renders its underside toward the player camera")

	var environment_node := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node == null or environment_node.environment == null:
		_fail("Daylight world environment was not created")
	else:
		var environment := environment_node.environment
		if environment.ambient_light_energy < 1.0 or environment.ambient_light_energy > 1.2:
			_fail("Ambient lighting is outside the readable non-washed-out range")
		var sky_material: ProceduralSkyMaterial = null
		if environment.sky != null:
			sky_material = environment.sky.sky_material as ProceduralSkyMaterial
		if sky_material == null:
			_fail("Procedural daylight sky was not created")
		else:
			if sky_material.sky_top_color.b - sky_material.sky_top_color.r < 0.45:
				_fail("Upper sky does not have a strong blue daylight gradient")
			if sky_material.sky_horizon_color.b <= sky_material.sky_horizon_color.r:
				_fail("Sky horizon is not cooler than the washed-out previous version")

	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		_fail("Sun light was not created")
	elif sun.shadow_enabled:
		_fail("Real-time directional shadows remain enabled")

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
