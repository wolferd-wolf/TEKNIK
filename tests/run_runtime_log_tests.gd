extends SceneTree

const RuntimeLog = preload("res://src/diagnostics/runtime_log.gd")

var _failures: int = 0


func _init() -> void:
	var directory: String = "user://runtime-log-test-%d" % Time.get_ticks_usec()
	var first: TeknikRuntimeLog = RuntimeLog.new()
	var start_result: Error = first.start_session({"test": true}, directory)
	_expect(start_result == OK, "runtime log opens a session")
	first.event("info", "test", "alpha", {"value": 1})
	first.event("warning", "test", "stall", {"frame_ms": 650.0})
	var support_path: String = first.write_support_snapshot({"phase": "first"})
	first.flush()
	var latest_absolute: String = ProjectSettings.globalize_path(first.latest_path())
	var support_absolute: String = ProjectSettings.globalize_path(support_path)
	_expect(FileAccess.file_exists(latest_absolute), "latest JSONL log is written")
	_expect(FileAccess.file_exists(support_absolute), "support snapshot is written")
	if FileAccess.file_exists(latest_absolute):
		var file := FileAccess.open(latest_absolute, FileAccess.READ)
		var text: String = file.get_as_text() if file != null else ""
		_expect(text.contains("\"event\":\"alpha\""), "structured event is present in JSONL")
		_expect(text.contains("\"event\":\"stall\""), "warning event is flushed immediately")
	first.close_session("test_complete")

	var second: TeknikRuntimeLog = RuntimeLog.new()
	var second_result: Error = second.start_session({"test": "rotation"}, directory)
	_expect(second_result == OK, "second runtime log session starts")
	_expect(FileAccess.file_exists(ProjectSettings.globalize_path(second.previous_path())), "previous session log is rotated")
	second.close_session("test_complete")

	if _failures == 0:
		print("RUNTIME_LOG_TEST_RESULT PASS")
		quit(0)
	else:
		print("RUNTIME_LOG_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
