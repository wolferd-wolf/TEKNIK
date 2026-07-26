class_name TeknikExplorationController
extends CharacterBody3D

signal break_requested(origin: Vector3, direction: Vector3)
signal break_hold_changed(held: bool)
signal place_requested(origin: Vector3, direction: Vector3)
signal diagnostics_requested
signal terrain_wait_changed(waiting: bool)
signal recovered_from_fall(previous_position: Vector3, safe_position: Vector3)

const MobileControls = preload("res://src/player/mobile_controls.gd")
const VoxelPlayerMotion = preload("res://src/player/voxel_player_motion.gd")

const WALK_SPEED: float = 6.0
const ACCELERATION: float = 22.0
const AIR_CONTROL: float = 5.0
const JUMP_VELOCITY: float = 7.0
const MOUSE_SENSITIVITY: float = 0.0024
const TOUCH_LOOK_SENSITIVITY: float = 0.0042
const LOOK_SENSITIVITY_SCALE_MIN: float = 0.5
const LOOK_SENSITIVITY_SCALE_MAX: float = 2.0
const LOOK_DOWN_LIMIT_DEGREES: float = -89.5
const LOOK_UP_LIMIT_DEGREES: float = 70.0
const FALL_RECOVERY_DEPTH: float = 18.0
const ABSOLUTE_RECOVERY_Y: float = -12.0
const SHAFT_DRIFT_EPSILON: float = 0.002

var _gravity: float = 18.0
var _camera_pivot: Node3D
var _camera: Camera3D
var _look_enabled: bool = true
var _look_sensitivity_scale: float = 1.0
var _modal_ui_open: bool = false
var _mobile_move: Vector2 = Vector2.ZERO
var _mobile_jump_requested: bool = false
var _mobile_controls: TeknikMobileControls
var _scripted_mode: bool = false
var _scripted_move: Vector2 = Vector2.ZERO
var _movement_guard: Callable = Callable()
var _voxel_solid_query: Callable = Callable()
var _last_safe_position: Vector3 = Vector3.ZERO
var _has_safe_position: bool = false
var _waiting_for_terrain: bool = false
var _status_label: Label


func _ready() -> void:
	_build_body()
	_build_camera()
	_build_status_overlay()
	if OS.has_feature("mobile") or _force_touch_controls():
		_build_mobile_controls()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if _scripted_mode or _modal_ui_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		diagnostics_requested.emit()
	elif event is InputEventMouseMotion and _look_enabled:
		_apply_look(event.relative, MOUSE_SENSITIVITY * _look_sensitivity_scale)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			break_hold_changed.emit(event.pressed)
			if event.pressed:
				_emit_break_request()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_emit_place_request()
	elif event.is_action_pressed("ui_cancel"):
		_look_enabled = not _look_enabled
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _look_enabled else Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = Vector2.ZERO
	if _scripted_mode:
		input_vector = _scripted_move
	elif not _modal_ui_open:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not _scripted_mode and not _modal_ui_open and _mobile_move.length_squared() > input_vector.length_squared():
		input_vector = _mobile_move
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var direction := (global_transform.basis * local_direction).normalized()
	var target_velocity := direction * WALK_SPEED
	var response: float = ACCELERATION if is_on_floor() else AIR_CONTROL
	velocity.x = move_toward(velocity.x, target_velocity.x, response * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, response * delta)

	var horizontal_step := Vector3(velocity.x, 0.0, velocity.z) * delta * 1.35
	var can_enter: bool = true
	if horizontal_step.length_squared() > 0.000001 and _movement_guard.is_valid():
		can_enter = bool(_movement_guard.call(global_position + horizontal_step))
	if not can_enter:
		velocity.x = 0.0
		velocity.z = 0.0
	_set_waiting_for_terrain(not can_enter)

	if is_on_floor():
		if (Input.is_action_just_pressed("jump") or _mobile_jump_requested) and can_enter and not _modal_ui_open:
			velocity.y = JUMP_VELOCITY
		elif velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	_mobile_jump_requested = false

	var requested_motion: Vector3 = velocity * delta
	var clipped_motion: Vector3 = requested_motion
	if _voxel_solid_query.is_valid():
		clipped_motion = VoxelPlayerMotion.clip_motion(global_position, requested_motion, _voxel_solid_query)
		if delta > 0.0:
			velocity = clipped_motion / delta
	var position_before_move: Vector3 = global_position
	var preserve_vertical_column: bool = (
		input_vector.length_squared() <= 0.0001
		and clipped_motion.y < -SHAFT_DRIFT_EPSILON
		and absf(clipped_motion.x) <= SHAFT_DRIFT_EPSILON
		and absf(clipped_motion.z) <= SHAFT_DRIFT_EPSILON
	)
	move_and_slide()
	# Generic collision recovery must not turn straight gravity into a sideways or
	# upward ejection inside a valid one-block shaft. Voxel clipping has already
	# proved that the requested vertical movement fits, so preserve the column.
	if preserve_vertical_column and not is_on_floor():
		global_position.x = position_before_move.x
		global_position.z = position_before_move.z
		velocity.x = 0.0
		velocity.z = 0.0

	if is_on_floor() and can_enter:
		_last_safe_position = global_position
		_has_safe_position = true
	_recover_if_needed()


func set_camera_active(active: bool) -> void:
	if _camera != null:
		_camera.current = active


func set_scripted_mode(enabled: bool) -> void:
	_scripted_mode = enabled
	_scripted_move = Vector2.ZERO
	velocity = Vector3.ZERO
	if _mobile_controls != null:
		_mobile_controls.visible = not enabled and not _modal_ui_open
	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE
		if enabled or _modal_ui_open
		else Input.MOUSE_MODE_CAPTURED
	)


func set_scripted_move(value: Vector2) -> void:
	_scripted_move = value.limit_length(1.0)


func set_movement_guard(guard: Callable) -> void:
	_movement_guard = guard


func set_voxel_solid_query(query: Callable) -> void:
	_voxel_solid_query = query


func set_initial_safe_position(position_value: Vector3) -> void:
	_last_safe_position = position_value
	_has_safe_position = true


func set_look_sensitivity_scale(value: float) -> void:
	_look_sensitivity_scale = clampf(
		value,
		LOOK_SENSITIVITY_SCALE_MIN,
		LOOK_SENSITIVITY_SCALE_MAX
	)


func look_sensitivity_scale() -> float:
	return _look_sensitivity_scale


func set_modal_ui_open(open: bool) -> void:
	_modal_ui_open = open
	_mobile_move = Vector2.ZERO
	_mobile_jump_requested = false
	if open:
		break_hold_changed.emit(false)
	if _mobile_controls != null:
		_mobile_controls.visible = not open and not _scripted_mode
	if not _scripted_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func safe_position() -> Vector3:
	return _last_safe_position if _has_safe_position else global_position


func is_waiting_for_terrain() -> bool:
	return _waiting_for_terrain


static func clamp_look_pitch(pitch: float) -> float:
	return clampf(
		pitch,
		deg_to_rad(LOOK_DOWN_LIMIT_DEGREES),
		deg_to_rad(LOOK_UP_LIMIT_DEGREES)
	)


func look_at_world(target: Vector3) -> void:
	var eye: Vector3 = global_position + Vector3(0.0, 1.55, 0.0)
	var delta: Vector3 = target - eye
	var horizontal := Vector2(delta.x, delta.z)
	if horizontal.length_squared() > 0.0001:
		rotation.y = atan2(-delta.x, -delta.z)
	if _camera_pivot != null:
		_camera_pivot.rotation.x = clamp_look_pitch(atan2(delta.y, horizontal.length()))


func _recover_if_needed() -> void:
	if not _has_safe_position:
		return
	if global_position.y >= ABSOLUTE_RECOVERY_Y and global_position.y >= _last_safe_position.y - FALL_RECOVERY_DEPTH:
		return
	var fallen_position: Vector3 = global_position
	global_position = _last_safe_position + Vector3.UP * 0.35
	velocity = Vector3.ZERO
	recovered_from_fall.emit(fallen_position, _last_safe_position)


func _set_waiting_for_terrain(waiting: bool) -> void:
	if waiting == _waiting_for_terrain:
		return
	_waiting_for_terrain = waiting
	if _status_label != null:
		_status_label.visible = waiting
	terrain_wait_changed.emit(waiting)


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
	_camera_pivot.rotation.x = clamp_look_pitch(_camera_pivot.rotation.x)


func _build_body() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	safe_margin = 0.01
	floor_snap_length = 0.08
	floor_stop_on_slope = true
	var box := BoxShape3D.new()
	box.size = Vector3(
		VoxelPlayerMotion.BODY_WIDTH,
		VoxelPlayerMotion.BODY_HEIGHT,
		VoxelPlayerMotion.BODY_WIDTH
	)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position.y = VoxelPlayerMotion.BODY_HEIGHT * 0.5
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


func _build_status_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "StreamingStatusLayer"
	layer.layer = 30
	add_child(layer)
	_status_label = Label.new()
	_status_label.name = "TerrainStatus"
	_status_label.text = "GENERATING TERRAIN…"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_status_label.add_theme_constant_override("shadow_offset_x", 2)
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_label.position = Vector2(-150.0, 36.0)
	_status_label.size = Vector2(300.0, 40.0)
	_status_label.visible = false
	layer.add_child(_status_label)


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
	_mobile_controls.break_hold_changed.connect(_on_mobile_break_hold_changed)
	_mobile_controls.place_pressed.connect(_emit_place_request)
	_mobile_controls.log_pressed.connect(func() -> void: diagnostics_requested.emit())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_mobile_movement_changed(value: Vector2) -> void:
	_mobile_move = value


func _on_mobile_look_dragged(relative: Vector2) -> void:
	_apply_look(relative, TOUCH_LOOK_SENSITIVITY * _look_sensitivity_scale)


func _on_mobile_jump_pressed() -> void:
	_mobile_jump_requested = true


func _on_mobile_break_hold_changed(held: bool) -> void:
	break_hold_changed.emit(held)


func _force_touch_controls() -> bool:
	return "--qa-touch-controls" in OS.get_cmdline_user_args()
