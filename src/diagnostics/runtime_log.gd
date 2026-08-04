class_name TeknikRuntimeLog
extends RefCounted

const SCHEMA_VERSION: int = 1
const DEFAULT_DIRECTORY: String = "user://logs"
const LATEST_NAME: String = "teknik-latest.jsonl"
const PREVIOUS_NAME: String = "teknik-previous.jsonl"
const SUPPORT_NAME: String = "teknik-support-latest.txt"
const MAX_RECENT_LINES: int = 240
const FLUSH_EVERY_LINES: int = 8

var _file: FileAccess
var _directory_path: String = DEFAULT_DIRECTORY
var _session_id: String = ""
var _started_ms: int = 0
var _recent_lines: Array[String] = []
var _lines_since_flush: int = 0
var _closed: bool = true


func start_session(context: Dictionary = {}, directory_path: String = DEFAULT_DIRECTORY) -> Error:
	_directory_path = directory_path
	var absolute_directory: String = ProjectSettings.globalize_path(_directory_path)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return directory_error

	var latest_absolute: String = ProjectSettings.globalize_path(latest_path())
	var previous_absolute: String = ProjectSettings.globalize_path(previous_path())
	if FileAccess.file_exists(previous_absolute):
		var remove_error: Error = DirAccess.remove_absolute(previous_absolute)
		if remove_error != OK:
			return remove_error
	if FileAccess.file_exists(latest_absolute):
		var rotate_error: Error = DirAccess.rename_absolute(latest_absolute, previous_absolute)
		if rotate_error != OK:
			return rotate_error

	_file = FileAccess.open(latest_absolute, FileAccess.WRITE)
	if _file == null:
		return FileAccess.get_open_error()
	_started_ms = Time.get_ticks_msec()
	_session_id = "%d-%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
	_recent_lines.clear()
	_lines_since_flush = 0
	_closed = false

	var session_context: Dictionary = context.duplicate(true)
	session_context["platform"] = OS.get_name()
	session_context["model"] = OS.get_model_name()
	session_context["processor_count"] = OS.get_processor_count()
	session_context["engine"] = Engine.get_version_info()
	session_context["renderer"] = RenderingServer.get_video_adapter_name()
	session_context["renderer_vendor"] = RenderingServer.get_video_adapter_vendor()
	session_context["screen_size"] = str(DisplayServer.screen_get_size())
	event("info", "session", "started", session_context)
	flush()
	return OK


func event(level: String, category: String, name: String, data: Dictionary = {}) -> void:
	if _closed or _file == null:
		return
	var record: Dictionary = {
		"schema": SCHEMA_VERSION,
		"timestamp_unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"monotonic_ms": Time.get_ticks_msec() - _started_ms,
		"session_id": _session_id,
		"frame": Engine.get_process_frames(),
		"level": level,
		"category": category,
		"event": name,
		"data": data,
	}
	var line: String = JSON.stringify(record)
	_file.store_line(line)
	_recent_lines.append(line)
	while _recent_lines.size() > MAX_RECENT_LINES:
		_recent_lines.pop_front()
	_lines_since_flush += 1
	if level == "error" or level == "warning" or _lines_since_flush >= FLUSH_EVERY_LINES:
		flush()


func flush() -> void:
	if _file != null:
		_file.flush()
	_lines_since_flush = 0


func close_session(reason: String = "shutdown") -> void:
	if _closed:
		return
	event("info", "session", "closed", {"reason": reason})
	flush()
	_file = null
	_closed = true


func recent_text(max_lines: int = 120) -> String:
	var first: int = maxi(0, _recent_lines.size() - maxi(max_lines, 1))
	var selected: PackedStringArray = PackedStringArray()
	for index: int in range(first, _recent_lines.size()):
		selected.append(_recent_lines[index])
	return "\n".join(selected)


func write_support_snapshot(context: Dictionary = {}) -> String:
	var support_path: String = _directory_path.path_join(SUPPORT_NAME)
	var absolute_path: String = ProjectSettings.globalize_path(support_path)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_line("TEKNIK SUPPORT SNAPSHOT")
	file.store_line(JSON.stringify({
		"schema": SCHEMA_VERSION,
		"session_id": _session_id,
		"created_unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"context": context,
	}))
	file.store_line("")
	file.store_string(recent_text(MAX_RECENT_LINES))
	file.flush()
	return support_path


func copy_recent_to_clipboard(context: Dictionary = {}) -> String:
	var header: String = JSON.stringify({
		"schema": SCHEMA_VERSION,
		"session_id": _session_id,
		"context": context,
	})
	var payload: String = header + "\n" + recent_text(120)
	DisplayServer.clipboard_set(payload)
	return payload


func latest_path() -> String:
	return _directory_path.path_join(LATEST_NAME)


func previous_path() -> String:
	return _directory_path.path_join(PREVIOUS_NAME)


func support_path() -> String:
	return _directory_path.path_join(SUPPORT_NAME)
