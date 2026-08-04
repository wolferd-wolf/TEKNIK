class_name TeknikMiningController
extends RefCounted

# One authoritative state machine owns the entire mining interaction. A block is
# never removed on button-down: the held input must fill its material-specific
# duration, and completion waits for the rebuilt terrain mesh before another
# target may begin.
enum Phase {
	IDLE,
	TARGETED,
	MINING,
	WAITING_FOR_COMMIT,
}

const STONE_SECONDS: float = 1.45
const SOIL_SECONDS: float = 0.58
const GRASS_SECONDS: float = 0.62
const SAND_SECONDS: float = 0.48
const MIN_DURATION_SECONDS: float = 0.05

var _phase: int = Phase.IDLE
var _pressed: bool = false
var _has_target: bool = false
var _target_voxel: Vector3i = Vector3i.ZERO
var _target_material: int = 0
var _duration_seconds: float = 1.0
var _elapsed_seconds: float = 0.0


static func duration_for_material(material: int) -> float:
	match material:
		1:
			return STONE_SECONDS
		2:
			return SOIL_SECONDS
		3:
			return GRASS_SECONDS
		4:
			return SAND_SECONDS
		_:
			return 1.0


func set_target(voxel: Vector3i, material: int, duration_seconds: float) -> bool:
	if _phase == Phase.WAITING_FOR_COMMIT:
		return false
	var safe_duration: float = maxf(duration_seconds, MIN_DURATION_SECONDS)
	if (
		_has_target
		and _target_voxel == voxel
		and _target_material == material
		and is_equal_approx(_duration_seconds, safe_duration)
	):
		return false
	_target_voxel = voxel
	_target_material = material
	_duration_seconds = safe_duration
	_elapsed_seconds = 0.0
	_has_target = true
	_phase = Phase.MINING if _pressed else Phase.TARGETED
	return true


func clear_target() -> bool:
	if _phase == Phase.WAITING_FOR_COMMIT:
		return false
	var changed: bool = _has_target or _elapsed_seconds > 0.0 or _phase != Phase.IDLE
	_has_target = false
	_target_voxel = Vector3i.ZERO
	_target_material = 0
	_duration_seconds = 1.0
	_elapsed_seconds = 0.0
	_phase = Phase.IDLE
	return changed


func set_pressed(pressed: bool) -> void:
	if pressed == _pressed:
		return
	_pressed = pressed
	if _phase == Phase.WAITING_FOR_COMMIT:
		return
	if not pressed:
		_elapsed_seconds = 0.0
		_phase = Phase.TARGETED if _has_target else Phase.IDLE
	elif _has_target:
		_elapsed_seconds = 0.0
		_phase = Phase.MINING


func update(delta: float) -> Dictionary:
	if _phase != Phase.MINING or not _pressed or not _has_target:
		return {}
	_elapsed_seconds += maxf(delta, 0.0)
	if _elapsed_seconds + 0.000001 < _duration_seconds:
		return {}
	_elapsed_seconds = _duration_seconds
	_phase = Phase.WAITING_FOR_COMMIT
	return {
		"voxel": _target_voxel,
		"material": _target_material,
		"duration_seconds": _duration_seconds,
	}


func cancel_failed_completion() -> void:
	if _phase != Phase.WAITING_FOR_COMMIT:
		return
	_elapsed_seconds = 0.0
	if _pressed and _has_target:
		_phase = Phase.MINING
	elif _has_target:
		_phase = Phase.TARGETED
	else:
		_phase = Phase.IDLE


func notify_visible_commit() -> void:
	if _phase != Phase.WAITING_FOR_COMMIT:
		return
	_has_target = false
	_target_voxel = Vector3i.ZERO
	_target_material = 0
	_duration_seconds = 1.0
	_elapsed_seconds = 0.0
	_phase = Phase.IDLE


func phase() -> int:
	return _phase


func is_pressed() -> bool:
	return _pressed


func has_target() -> bool:
	return _has_target


func is_mining() -> bool:
	return _phase == Phase.MINING


func is_waiting_for_commit() -> bool:
	return _phase == Phase.WAITING_FOR_COMMIT


func target_voxel() -> Vector3i:
	return _target_voxel


func target_material() -> int:
	return _target_material


func duration_seconds() -> float:
	return _duration_seconds


func progress() -> float:
	if not _has_target or _duration_seconds <= 0.0:
		return 0.0
	return clampf(_elapsed_seconds / _duration_seconds, 0.0, 1.0)
