extends SceneTree

const PerformanceTelemetry = preload("res://src/diagnostics/performance_telemetry.gd")

var _failures: int = 0


func _init() -> void:
	_test_percentiles_and_event_peaks()
	_test_sample_window_is_bounded()
	if _failures == 0:
		print("PERFORMANCE_TELEMETRY_TEST_RESULT PASS")
		quit(0)
	else:
		print("PERFORMANCE_TELEMETRY_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_percentiles_and_event_peaks() -> void:
	var telemetry := PerformanceTelemetry.new()
	for milliseconds: int in [10, 12, 14, 16, 20, 30, 40, 50, 60, 100]:
		telemetry.record_frame(float(milliseconds) / 1000.0)
	telemetry.record_stream(4_500, 28_000)
	telemetry.record_stream(7_250, 22_000)
	telemetry.record_collision(3_200)
	telemetry.record_collision(5_900)
	var report: Dictionary = telemetry.snapshot()
	_expect(is_equal_approx(float(report.frame_p50_ms), 20.0), "p50 frame time is deterministic")
	_expect(is_equal_approx(float(report.frame_p95_ms), 100.0), "p95 frame time uses nearest-rank")
	_expect(is_equal_approx(float(report.stream_main_peak_ms), 7.25), "stream main-thread peak is retained")
	_expect(is_equal_approx(float(report.stream_worker_peak_ms), 28.0), "worker peak is retained")
	_expect(is_equal_approx(float(report.collision_peak_ms), 5.9), "collision peak is retained")
	_expect(int(report.stream_events) == 2 and int(report.collision_events) == 2, "event counters are retained")


func _test_sample_window_is_bounded() -> void:
	var telemetry := PerformanceTelemetry.new()
	for index: int in range(PerformanceTelemetry.MAX_FRAME_SAMPLES + 25):
		telemetry.record_frame(float(index + 1) / 1000.0)
	var report: Dictionary = telemetry.snapshot()
	_expect(int(report.sample_count) == PerformanceTelemetry.MAX_FRAME_SAMPLES, "frame sample window remains bounded")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		_failures += 1
		push_error("FAIL %s" % message)
