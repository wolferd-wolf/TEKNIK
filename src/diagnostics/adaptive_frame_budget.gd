class_name TeknikAdaptiveFrameBudget
extends RefCounted

const SAMPLE_CAPACITY: int = 60
const DEFAULT_TARGET_USEC: int = 16_667
const MIN_SLOW_USEC: int = 20_000
const MAX_SLOW_USEC: int = 26_000
const MIN_CRITICAL_USEC: int = 28_000
const MAX_CRITICAL_USEC: int = 36_000

var _samples: PackedInt32Array = PackedInt32Array()
var _cursor: int = 0
var _target_usec: int = DEFAULT_TARGET_USEC
var _p50_usec: int = DEFAULT_TARGET_USEC
var _p90_usec: int = DEFAULT_TARGET_USEC
var _slow_usec: int = 22_000
var _critical_usec: int = 30_000


func configure(target_fps: int = 60) -> void:
	_target_usec = maxi(1_000_000 / maxi(target_fps, 1), 1)
	_recalculate()


func record(frame_usec: int) -> void:
	if frame_usec <= 0:
		return
	if _samples.size() < SAMPLE_CAPACITY:
		_samples.append(frame_usec)
	else:
		_samples[_cursor] = frame_usec
		_cursor = (_cursor + 1) % SAMPLE_CAPACITY
	_recalculate()


func target_usec() -> int:
	return _target_usec


func p50_usec() -> int:
	return _p50_usec


func p90_usec() -> int:
	return _p90_usec


func slow_usec() -> int:
	return _slow_usec


func critical_usec() -> int:
	return _critical_usec


func sample_count() -> int:
	return _samples.size()


func _recalculate() -> void:
	if _samples.is_empty():
		_p50_usec = _target_usec
		_p90_usec = _target_usec
	else:
		var ordered: Array[int] = []
		for value: int in _samples:
			ordered.append(value)
		ordered.sort()
		_p50_usec = ordered[clampi(roundi(float(ordered.size() - 1) * 0.50), 0, ordered.size() - 1)]
		_p90_usec = ordered[clampi(roundi(float(ordered.size() - 1) * 0.90), 0, ordered.size() - 1)]

	# Follow the device's stable baseline, but keep hard bounds so sustained bad
	# performance never trains the policy to accept severe frame stalls.
	var baseline: int = maxi(_target_usec, _p50_usec)
	_slow_usec = clampi(roundi(float(baseline) * 1.30), MIN_SLOW_USEC, MAX_SLOW_USEC)
	_critical_usec = clampi(maxi(roundi(float(baseline) * 1.75), roundi(float(_p90_usec) * 1.20)), MIN_CRITICAL_USEC, MAX_CRITICAL_USEC)
