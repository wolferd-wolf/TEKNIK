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

	var first_cell := Vector3i(3, world._terrain_height(3, 3) + 1, 3)
	world._set_block(first_cell, world.BLOCK_DIRT)
	world._save_world()
	_assert_clean_commit(world, 1, first_cell, world.BLOCK_DIRT, "first commit")

	var second_cell := Vector3i(4, world._terrain_height(4, 4) + 1, 4)
	world._set_block(second_cell, world.BLOCK_STONE)
	world._save_world()
	_assert_clean_commit(world, 2, second_cell, world.BLOCK_STONE, "replacement commit")

	await _finish(main)

func _assert_clean_commit(world: Node, expected_commits: int, cell: Vector3i, expected_block: int, label: String) -> void:
	if world.save_commit_count != expected_commits:
		_fail("%s did not increment the transactional commit counter" % label)
	if world.save_commit_failures != 0:
		_fail("%s recorded a transactional save failure" % label)
	if not FileAccess.file_exists(SAVE_PATH):
		_fail("%s did not produce the authoritative save" % label)
	if FileAccess.file_exists(SAVE_TEMP_PATH):
		_fail("%s left a pending save behind" % label)
	if FileAccess.file_exists(SAVE_ROLLBACK_PATH):
		_fail("%s left a rollback save behind" % label)

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail("%s authoritative save could not be opened" % label)
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_fail("%s authoritative save is invalid JSON" % label)
		return
	var data: Dictionary = parser.data
	var overrides: Dictionary = data.get("overrides", {})
	var key := "%d,%d,%d" % [cell.x, cell.y, cell.z]
	if int(overrides.get(key, -1)) != expected_block:
		_fail("%s did not preserve the latest block edit" % label)

func _remove_test_files() -> void:
	for path in [SAVE_PATH, SAVE_TEMP_PATH, SAVE_ROLLBACK_PATH, "user://teknik_world_v1.backup.json", "user://teknik_world_v1.backup.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	failed = true
	push_error("TRANSACTIONAL SAVE SMOKE: %s" % message)

func _finish(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame
	_remove_test_files()
	if failed:
		print("TRANSACTIONAL_SAVE_SMOKE_FAILED")
		quit(1)
	else:
		print("TRANSACTIONAL_SAVE_SMOKE_PASSED")
		quit(0)
