class_name TeknikExplorationController
extends CharacterBody3D

signal break_requested(origin: Vector3, direction: Vector3)
signal place_requested(origin: Vector3, direction: Vector3)
signal diagnostics_requested

const MobileControls = preload("res://src/player/mobile_controls.gd")

const WALK_SPEED: float = 6.0
const ACCELERATION: float = 22.0
const AIR_CONTROL: float = 5.0
const JUMP_VELOCITY: float = 7.0
const MOUSE_SENSITIVITY: float = 0.0024
const TOUCH_LOOK_SENSITIVITY: float = 0.0042

var _gravity: float = 18.0
var _camera_pivot: Node3D
var _camera: Camera3D
var _look_enabled: bool = true
var _mobile_move: Vector2 = Vector2.ZERO
var _mobile_jump_requested: bool = false
var _mobile_controls: TeknikMobileControls
var _scripted_mode: bool = false
var _scripted_move: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_body()
	_build_camera()
	if OS.has_feature("mobile") or _force_touch_controls():
		_build_mobile_controls()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if _scripted_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		diagnostics_requested.emit()
	elif event is InputEventMouseMotion and _look_enabled:
		_apply_look(event.relative, MOUSE_SENSITIVITY)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_emit_break_request()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_emit_place_request()
	elif event.is_action_pressed("ui_cancel"):
		_look_enabled = not _look_enabled
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _look_enabled else Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if _scripted_mode:
		var local_direction := Vector3(_scripted_move.x, 0.0, _scripted_move.y)
		var direction := (global_transform.basis * local_direction).normalized()
		global_position += direction * WALK_SPEED * delta
		velocity = Vector3.ZERO
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _mobile_move.length_squared() > input_vector.length_squared():
		input_vector = _mobile_move
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var direction := (global_transform.basis * local_direction).normalized()
	var target_velocity := direction * WALK_SPEED
	var response: float = ACCELERATION if is_on_floor() else AIR_CONTROL
	velocity.x = move_toward(velocity.x, target_velocity.x, response * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, response * delta)
	if is_on_floor():
		if Input.is_action_just_pressed("jump") or _mobile_jump_requested:
			velocity.y = JUMP_VELOCITY
		elif velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	_mobile_jump_requested = false
	move_and_slide()


func set_camera_active(active: bool) -> void:
	if _camera != null:
		_camera.current = active


func set_scripted_mode(enabled: bool) -> void:
	_scripted_mode = enabled
	_scripted_move = Vector2.ZERO
	velocity = Vector3.ZERO
	if _mobile_controls != null:
		_mobile_controls.visible = not enabled
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if enabled else Input.MOUSE_MODE_CAPTURED


func set_scripted_move(value: Vector2) -> void:
	_scripted_move = value.limit_length(1.0)


func look_at_world(target: Vector3) -> void:
	var eye: Vector3 = global_position + Vector3(0.0, 1.55, 0.0)
	var delta: Vector3 = target - eye
	var horizontal := Vector2(delta.x, delta.z)
	if horizontal.length_squared() > 0.0001:
		rotation.y = atan2(-delta.x, -delta.z)
	if _camera_pivot != null:
		_camera_pivot.rotation.x = clampf(atan2(delta.y, horizontal.length()), deg_to_rad(-75.0), deg_to_rad(70.0))


func _emit_break_request() -> void:
	if _camera == null:
		return
	break_requested.emit(_camera.global_position, -_camera.global_transform.basis.z.normalized())


func _emit_place_request() -> void:
	if _camera == null:
		return
	place_requested.emit(_camera.global_position, -_camera.global_transform.basis.z.normalized())


func _apply_look(relative: Vector2, sensitivity: float) -> void:
	rotate_y(-relative.x * sensitivity)
	_camera_pivot.rotate_x(-relative.y * sensitivity)
	_camera_pivot.rotation.x = clampf(_camera_pivot.rotation.x, deg_to_rad(-75.0), deg_to_rad(70.0))


func _build_body() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)


func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 1.55, 0.0)
	add_child(_camera_pivot)
	_camera = Camera3D.new()
	_camera.name = "PlayerCamera"
	_camera.fov = 68.0
	_camera.near = 0.05
	_camera.far = 280.0
	_camera_pivot.add_child(_camera)


func _build_mobile_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MobileControlLayer"
	layer.layer = 20
	add_child(layer)
	_mobile_controls = MobileControls.new()
	_mobile_controls.name = "MobileControls"
	layer.add_child(_mobile_controls)
	_mobile_controls.movement_changed.connect(_on_mobile_movement_changed)
	_mobile_controls.look_dragged.connect(_on_mobile_look_dragged)
	_mobile_controls.jump_pressed.connect(_on_mobile_jump_pressed)
	_mobile_controls.break_pressed.connect(_emit_break_request)
	_mobile_controls.place_pressed.connect(_emit_place_request)
	_mobile_controls.log_pressed.connect(func() -> void: diagnostics_requested.emit())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_mobile_movement_changed(value: Vector2) -> void:
	_mobile_move = value


func _on_mobile_look_dragged(relative: Vector2) -> void:
	_apply_look(relative, TOUCH_LOOK_SENSITIVITY)


func _on_mobile_jump_pressed() -> void:
	_mobile_jump_requested = true


func _force_touch_controls() -> bool:
	return "--qa-touch-controls" in OS.get_cmdline_user_args()
