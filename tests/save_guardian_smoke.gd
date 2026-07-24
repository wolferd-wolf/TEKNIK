extends SceneTree

const SAVE_PATH := "user://teknik_world_v1.json"
const BACKUP_PATH := "user://teknik_world_v1.backup.json"
const TEMP_BACKUP_PATH := "user://teknik_world_v1.backup.tmp"

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_files()
	var guardian := root.get_node_or_null("SaveGuardian")
	if guardian == null:
		_fail("SaveGuardian autoload was not created")
		quit(1)
		return

	_write_valid_primary()
	if not bool(guardian.call("capture_valid_save")):
		_fail("Valid primary save was not copied to backup")
	if not FileAccess.file_exists(BACKUP_PATH):
		_fail("Backup save file was not created")

	_write_corrupt_primary()
	if not bool(guardian.call("recover_primary_if_needed")):
		_fail("Corrupt primary save was not restored from backup")
	_validate_restored_primary()

	_write_wrong_seed_primary()
	if not bool(guardian.call("recover_primary_if_needed")):
		_fail("Wrong-seed primary save was not rejected and restored")
	_validate_restored_primary()

	var status: Dictionary = guardian.call("get_status")
	if not bool(status.get("primary_valid", false)):
		_fail("Guardian status reports an invalid primary after recovery")
	if not bool(status.get("backup_valid", false)):
		_fail("Guardian status reports an invalid backup after recovery")
	if int(status.get("recovery_count", 0)) < 2:
		_fail("Guardian did not count both recovery events")
	if int(status.get("backup_write_failures", 0)) != 0:
		_fail("Guardian reported backup write failures")

	_remove_test_files()
	quit(1 if failed else 0)

func _write_valid_primary() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not create valid primary save")
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"seed": 734921,
		"overrides": {"6,12,6": 2}
	}))

func _write_corrupt_primary() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not replace primary save with corrupt data")
		return
	file.store_string("{broken")

func _write_wrong_seed_primary() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not replace primary save with wrong-seed data")
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"seed": 1,
		"overrides": {}
	}))

func _validate_restored_primary() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_fail("Recovered primary save could not be opened")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Recovered primary save is not valid JSON")
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != 1:
		_fail("Recovered primary save has the wrong version")
	if int(data.get("seed", 0)) != 734921:
		_fail("Recovered primary save has the wrong seed")
	var overrides: Variant = data.get("overrides", null)
	if not overrides is Dictionary or int(overrides.get("6,12,6", 0)) != 2:
		_fail("Recovered primary save lost the block edit")

func _remove_test_files() -> void:
	for path in [SAVE_PATH, BACKUP_PATH, TEMP_BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	failed = true
	push_error(message)
