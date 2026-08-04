class_name TeknikMiningHoldState
extends RefCounted

const DEFAULT_REPEAT_SECONDS: float = 0.28

var repeat_seconds: float = DEFAULT_REPEAT_SECONDS
var _held: bool = false
var _elapsed: float = 0.0
var _target: Variant = null


func set_held(held: bool) -> void:
	if held == _held:
		return
	_held = held
	if not held:
		reset_progress()


func is_held() -> bool:
	return _held


func update(delta: float, target: Variant) -> bool:
	if not _held or target == null:
		reset_progress()
		return false
	var safe_delta: float = maxf(delta, 0.0)
	if _target == null or _target != target:
		_target = target
		_elapsed = safe_delta
	else:
		_elapsed += safe_delta
	if _elapsed < repeat_seconds:
		return false
	_elapsed = fmod(_elapsed, repeat_seconds)
	return true


func progress() -> float:
	if not _held or _target == null or repeat_seconds <= 0.0:
		return 0.0
	return clampf(_elapsed / repeat_seconds, 0.0, 1.0)


func reset_progress() -> void:
	_elapsed = 0.0
	_target = null
