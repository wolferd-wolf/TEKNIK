extends SceneTree

const SAVE_PATH := "user://teknik_world_v1.json"
const SAVE_TEMP_PATH := "user://teknik_world_v1.pending.json"
const SAVE_ROLLBACK_PATH := "user://teknik_world_v1.rollback.json"

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_files()
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Main scene could not be loaded")
		quit(1)
		return

	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	var world: Node = main.get_node_or_null("World")
	if world == null:
		_fail("World node was not created")
		await _finish(main)
		return

	var pause_cell := Vector3i(7, world._terrain_height(7, 7) + 1, 7)
	world._set_block(pause_cell, world.BLOCK_DIRT)
	if not world.dirty_save:
		_fail("Block edit did not mark the world dirty")
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_assert_lifecycle_commit(world, 1, 1, "application-paused", pause_cell, world.BLOCK_DIRT)

	var focus_cell := Vector3i(8, world._terrain_height(8, 8) + 1, 8)
	world._set_block(focus_cell, world.BLOCK_STONE)
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_assert_lifecycle_commit(world, 2, 2, "focus-out", focus_cell, world.BLOCK_STONE)

	# A lifecycle notification with no pending edit should be harmless and should not create another commit.
	main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	if world.lifecycle_flush_requests != 3:
		_fail("Clean close request was not recorded")
	if world.lifecycle_flush_commits != 2:
		_fail("Clean close request created an unnecessary save commit")
	if world.save_commit_count != 2:
		_fail("Clean close request changed the transactional commit count")
	if world.lifecycle_flush_failures != 0 or world.save_commit_failures != 0:
		_fail("Lifecycle save path recorded a failure")

	await _finish(main)

func _assert_lifecycle_commit(world: Node, expected_requests: int, expected_commits: int, expected_reason: String, cell: Vector3i, expected_block: int) -> void:
	if world.lifecycle_flush_requests != expected_requests:
		_fail("Lifecycle flush request counter is incorrect for %s" % expected_reason)
	if world.lifecycle_flush_commits != expected_commits:
		_fail("Lifecycle flush did not commit for %s" % expected_reason)
	if world.last_lifecycle_flush_reason != expected_reason:
		_fail("Lifecycle flush reason was not recorded for %s" % expected_reason)
	if world.dirty_save:
		_fail("World remained dirty after %s" % expected_reason)
	if not FileAccess.file_exists(SAVE_PATH):
		_fail("Lifecycle flush did not create the authoritative save")
	if FileAccess.file_exists(SAVE_TEMP_PATH) or FileAccess.file_exists(SAVE_ROLLBACK_PATH):
		_fail("Lifecycle flush left transaction files behind")

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail("Lifecycle save could not be opened")
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_fail("Lifecycle save is invalid JSON")
		return
	var data: Dictionary = parser.data
	var overrides: Dictionary = data.get("overrides", {})
	var key := "%d,%d,%d" % [cell.x, cell.y, cell.z]
	if int(overrides.get(key, -1)) != expected_block:
		_fail("Lifecycle save did not preserve the latest edit for %s" % expected_reason)

func _remove_test_files() -> void:
	for path in [SAVE_PATH, SAVE_TEMP_PATH, SAVE_ROLLBACK_PATH, "user://teknik_world_v1.backup.json", "user://teknik_world_v1.backup.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	failed = true
	push_error("LIFECYCLE SAVE SMOKE: %s" % message)

func _finish(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame
	_remove_test_files()
	if failed:
		print("LIFECYCLE_SAVE_SMOKE_FAILED")
		quit(1)
	else:
		print("LIFECYCLE_SAVE_SMOKE_PASSED")
		quit(0)
