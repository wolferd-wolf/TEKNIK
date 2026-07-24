extends Node

const SAVE_PATH := "user://teknik_world_v1.json"
const BACKUP_PATH := "user://teknik_world_v1.backup.json"
const TEMP_BACKUP_PATH := "user://teknik_world_v1.backup.tmp"
const CHECK_INTERVAL_SECONDS := 1.0
const EXPECTED_VERSION := 1
const EXPECTED_SEED := 734921

var check_elapsed := 0.0
var last_primary_signature := ""
var recovery_count := 0
var backup_write_failures := 0

func _ready() -> void:
	recover_primary_if_needed()
	capture_valid_save()
	last_primary_signature = _file_signature(SAVE_PATH)

func _process(delta: float) -> void:
	check_elapsed += delta
	if check_elapsed < CHECK_INTERVAL_SECONDS:
		return
	check_elapsed = fmod(check_elapsed, CHECK_INTERVAL_SECONDS)
	var signature := _file_signature(SAVE_PATH)
	if signature == last_primary_signature:
		return
	last_primary_signature = signature
	capture_valid_save()

func recover_primary_if_needed() -> bool:
	if _is_valid_world_save(SAVE_PATH):
		return false
	if not _is_valid_world_save(BACKUP_PATH):
		return false
	if not _copy_atomically(BACKUP_PATH, SAVE_PATH):
		backup_write_failures += 1
		return false
	recovery_count += 1
	last_primary_signature = _file_signature(SAVE_PATH)
	return true

func capture_valid_save() -> bool:
	if not _is_valid_world_save(SAVE_PATH):
		return false
	if _files_match(SAVE_PATH, BACKUP_PATH):
		return true
	if not _copy_atomically(SAVE_PATH, BACKUP_PATH):
		backup_write_failures += 1
		return false
	return true

func _copy_atomically(source_path: String, destination_path: String) -> bool:
	var temp_absolute := ProjectSettings.globalize_path(TEMP_BACKUP_PATH)
	var destination_absolute := ProjectSettings.globalize_path(destination_path)
	if FileAccess.file_exists(TEMP_BACKUP_PATH):
		DirAccess.remove_absolute(temp_absolute)
	var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), temp_absolute)
	if copy_error != OK:
		return false
	if not _is_valid_world_save(TEMP_BACKUP_PATH):
		DirAccess.remove_absolute(temp_absolute)
		return false
	if FileAccess.file_exists(destination_path):
		var remove_error := DirAccess.remove_absolute(destination_absolute)
		if remove_error != OK:
			DirAccess.remove_absolute(temp_absolute)
			return false
	var rename_error := DirAccess.rename_absolute(temp_absolute, destination_absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_absolute)
		return false
	return true

func _is_valid_world_save(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != EXPECTED_VERSION:
		return false
	if int(data.get("seed", -1)) != EXPECTED_SEED:
		return false
	return data.get("overrides", null) is Dictionary

func _files_match(first_path: String, second_path: String) -> bool:
	if not FileAccess.file_exists(first_path) or not FileAccess.file_exists(second_path):
		return false
	var first := FileAccess.open(first_path, FileAccess.READ)
	var second := FileAccess.open(second_path, FileAccess.READ)
	if first == null or second == null:
		return false
	return first.get_as_text() == second.get_as_text()

func _file_signature(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "unreadable"
	return "%d:%d" % [FileAccess.get_modified_time(path), file.get_length()]

func get_status() -> Dictionary:
	return {
		"primary_valid": _is_valid_world_save(SAVE_PATH),
		"backup_valid": _is_valid_world_save(BACKUP_PATH),
		"recovery_count": recovery_count,
		"backup_write_failures": backup_write_failures
	}
