class_name TeknikAutoJumpAssistant
extends Node

signal auto_jump_triggered(position: Vector3, upward_velocity: float)

const AUTO_JUMP_VELOCITY: float = 5.8
const AUTO_JUMP_HEIGHT: float = 1.08
const AUTO_JUMP_PROBE_DISTANCE: float = 0.62
const AUTO_JUMP_MIN_SPEED: float = 0.75
const AUTO_JUMP_COOLDOWN_SECONDS: float = 0.28

var _controller: CharacterBody3D
var _cooldown_seconds: float = 0.0


func configure(controller: CharacterBody3D) -> void:
	_controller = controller


func _physics_process(delta: float) -> void:
	_cooldown_seconds = maxf(0.0, _cooldown_seconds - delta)
	if _controller == null or not is_instance_valid(_controller):
		return
	if _cooldown_seconds > 0.0 or not _controller.is_on_floor():
		return

	var horizontal_velocity := Vector3(
		_controller.velocity.x,
		0.0,
		_controller.velocity.z
	)
	var horizontal_speed: float = horizontal_velocity.length()
	if horizontal_speed < AUTO_JUMP_MIN_SPEED:
		return

	var direction: Vector3 = horizontal_velocity / horizontal_speed
	var forward_motion: Vector3 = direction * maxf(
		AUTO_JUMP_PROBE_DISTANCE,
		horizontal_speed * delta * 1.5
	)
	if not _controller.test_move(_controller.global_transform, forward_motion):
		return
	if _controller.test_move(
		_controller.global_transform,
		Vector3.UP * AUTO_JUMP_HEIGHT
	):
		return

	var raised_transform: Transform3D = _controller.global_transform
	raised_transform.origin += Vector3.UP * AUTO_JUMP_HEIGHT
	if _controller.test_move(raised_transform, forward_motion):
		return

	_controller.velocity.y = maxf(
		_controller.velocity.y,
		AUTO_JUMP_VELOCITY
	)
	_cooldown_seconds = AUTO_JUMP_COOLDOWN_SECONDS
	auto_jump_triggered.emit(_controller.global_position, _controller.velocity.y)
