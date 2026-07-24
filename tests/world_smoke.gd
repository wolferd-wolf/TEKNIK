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
	for _frame in range(240):
		await process_frame
	var world := main.get_node_or_null("World")
	if world == null:
		_fail("World node was not created")
	elif world.loaded_chunks.size() < 1:
		_fail("No procedural chunk was committed")
	elif world.get_block(Vector3i(0, 0, 0)) == 0:
		_fail("Base terrain is unexpectedly empty")
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _fail(message: String) -> void:
	failed = true
	push_error(message)
