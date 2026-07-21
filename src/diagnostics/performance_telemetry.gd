class_name TeknikPerformanceTelemetry
extends RefCounted

const MAX_FRAME_SAMPLES: int = 600

var _frame_usec: Array[int] = []
var _stream_main_peak_usec: int = 0
var _stream_worker_peak_usec: int = 0
var _collision_peak_usec: int = 0
var _stream_events: int = 0
var _collision_events: int = 0


func record_frame(delta_seconds: float) -> void:
	var usec: int = maxi(0, roundi(delta_seconds * 1_000_000.0))
	_frame_usec.append(usec)
	if _frame_usec.size() > MAX_FRAME_SAMPLES:
		_frame_usec.pop_front()


func record_stream(main_usec: int, worker_usec: int) -> void:
	_stream_main_peak_usec = maxi(_stream_main_peak_usec, main_usec)
	_stream_worker_peak_usec = maxi(_stream_worker_peak_usec, worker_usec)
	_stream_events += 1


func record_collision(usec: int) -> void:
	_collision_peak_usec = maxi(_collision_peak_usec, usec)
	_collision_events += 1


func reset_event_peaks() -> void:
	_stream_main_peak_usec = 0
	_stream_worker_peak_usec = 0
	_collision_peak_usec = 0
	_stream_events = 0
	_collision_events = 0


func snapshot() -> Dictionary:
	var sorted: Array[int] = _frame_usec.duplicate()
	sorted.sort()
	return {
		"sample_count": sorted.size(),
		"frame_p50_ms": _percentile_ms(sorted, 0.50),
		"frame_p95_ms": _percentile_ms(sorted, 0.95),
		"frame_p99_ms": _percentile_ms(sorted, 0.99),
		"fps_p50": _fps_from_ms(_percentile_ms(sorted, 0.50)),
		"fps_p95_floor": _fps_from_ms(_percentile_ms(sorted, 0.95)),
		"stream_main_peak_ms": float(_stream_main_peak_usec) / 1000.0,
		"stream_worker_peak_ms": float(_stream_worker_peak_usec) / 1000.0,
		"collision_peak_ms": float(_collision_peak_usec) / 1000.0,
		"stream_events": _stream_events,
		"collision_events": _collision_events
	}


func _percentile_ms(sorted: Array[int], ratio: float) -> float:
	if sorted.is_empty():
		return 0.0
	var index: int = clampi(ceili(float(sorted.size()) * ratio) - 1, 0, sorted.size() - 1)
	return float(sorted[index]) / 1000.0


func _fps_from_ms(milliseconds: float) -> float:
	if milliseconds <= 0.0:
		return 0.0
	return 1000.0 / milliseconds
