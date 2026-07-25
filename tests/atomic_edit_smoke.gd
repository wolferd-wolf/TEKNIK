extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Main scene failed to load")
		quit(1)
		return

	var main := packed.instantiate()
	root.add_child(main)
	var world: Node = null
	var player: Node3D = null
	for _frame in range(900):
		await process_frame
		world = main.get_node_or_null("World")
		player = main.get_node_or_null("Player")
		if world != null and player != null:
			break

	if world == null or player == null:
		_fail("World or player did not become ready")
		_finish(main)
		return

	var coord: Vector2i = world.world_to_chunk(player.global_position)
	if not world.loaded_chunks.has(coord):
		_fail("Player chunk was not loaded")
		_finish(main)
		return

	var old_entry: Dictionary = world.loaded_chunks[coord]
	var old_root: Node3D = old_entry["root"]
	var old_collision: Node = old_entry["collision"]
	if not is_instance_valid(old_collision):
		_fail("Player chunk had no collision before edit")
		_finish(main)
		return

	var x := floori(player.global_position.x)
	var z := floori(player.global_position.z)
	var y: int = world._terrain_height(x, z)
	var cell := Vector3i(x, y, z)
	var original_block: int = world.get_block(cell)
	world._set_block(cell, world.BLOCK_AIR)

	var immediate_entry: Dictionary = world.loaded_chunks[coord]
	if immediate_entry["root"] != old_root:
		_fail("Chunk root changed before replacement was built")
	if not is_instance_valid(immediate_entry["collision"]):
		_fail("Collision disappeared immediately after edit")

	var replacement_ready := false
	for _frame in range(600):
		await process_frame
		if world.loaded_chunks.has(coord):
			var entry: Dictionary = world.loaded_chunks[coord]
			if entry["root"] != old_root and is_instance_valid(entry["collision"]):
				replacement_ready = true
				break

	if not replacement_ready:
		_fail("Replacement chunk and collision did not become ready")
	if world.atomic_swap_count < 1:
		_fail("Atomic swap counter did not advance")
	if world.atomic_swap_failures != 0:
		_fail("Atomic swap reported a failure")

	world._set_block(cell, original_block)
	for _frame in range(300):
		await process_frame

	_finish(main)

func _finish(main: Node) -> void:
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _fail(message: String) -> void:
	failed = true
	push_error(message)
