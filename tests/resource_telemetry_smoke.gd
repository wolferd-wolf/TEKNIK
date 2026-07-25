extends SceneTree

const SUMMARY_PATH := "user://teknik_telemetry_summary.json"

var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(SUMMARY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SUMMARY_PATH))

	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Main scene could not be loaded")
		quit(1)
		return

	var main: Node = packed.instantiate()
	root.add_child(main)
	var player: Node = await _wait_for_player(main, 900)
	if player == null:
		_fail("Player was not created for telemetry validation")
	else:
		player.call("_begin_stream_hold")
		player.stream_hold_active = true
		player.stream_hold_started_msec = Time.get_ticks_msec() - 125
		player.call("_finish_stream_hold")

	var snapshot: Dictionary = main.call("_capture_telemetry_snapshot")
	var required_snapshot_keys: Array[String] = [
		"static_memory_bytes",
		"static_memory_peak_bytes",
		"draw_calls",
		"rendered_primitives",
		"node_count",
		"stream_hold_episodes",
		"stream_hold_total_msec",
		"stream_hold_last_msec",
		"stream_hold_max_msec"
	]
	for key in required_snapshot_keys:
		if not snapshot.has(key):
			_fail("Telemetry snapshot is missing %s" % key)
		elif int(snapshot[key]) < 0:
			_fail("Telemetry snapshot contains a negative %s" % key)
	if int(snapshot.get("schema", 0)) != 4:
		_fail("Telemetry snapshot schema was not upgraded to version 4")
	if int(snapshot.get("stream_hold_episodes", 0)) < 1:
		_fail("Telemetry did not record a stream-hold episode")
	if int(snapshot.get("stream_hold_max_msec", 0)) < 100:
		_fail("Telemetry did not preserve stream-hold duration")

	main.call("_update_session_peaks", snapshot)
	if not bool(main.call("write_session_summary", true)):
		_fail("Resource telemetry summary could not be written")
	elif not FileAccess.file_exists(SUMMARY_PATH):
		_fail("Resource telemetry summary file was not created")
	else:
		var file := FileAccess.open(SUMMARY_PATH, FileAccess.READ)
		var parser := JSON.new()
		if file == null or parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
			_fail("Resource telemetry summary is not valid JSON")
		else:
			var summary: Dictionary = parser.data
			var required_summary_keys: Array[String] = [
				"peak_static_memory_bytes",
				"engine_static_memory_peak_bytes",
				"peak_draw_calls",
				"peak_rendered_primitives",
				"peak_node_count",
				"stream_hold_episodes",
				"stream_hold_total_msec",
				"stream_hold_last_msec",
				"stream_hold_max_msec"
			]
			for key in required_summary_keys:
				if not summary.has(key):
					_fail("Telemetry summary is missing %s" % key)
			if int(summary.get("schema", 0)) != 3:
				_fail("Telemetry summary schema was not upgraded to version 3")
			if int(summary.get("stream_hold_max_msec", 0)) < 100:
				_fail("Telemetry summary lost stream-hold duration")

	main.queue_free()
	await process_frame
	if failed:
		print("RESOURCE_TELEMETRY_SMOKE_FAILED")
		quit(1)
	else:
		print("RESOURCE_TELEMETRY_SMOKE_PASSED")
		quit(0)

func _wait_for_player(main: Node, max_frames: int) -> Node:
	for _frame in range(max_frames):
		var candidate: Node = main.get_node_or_null("Player")
		if candidate != null:
			return candidate
		await process_frame
	return null

func _fail(message: String) -> void:
	failed = true
	push_error("RESOURCE TELEMETRY SMOKE: %s" % message)
