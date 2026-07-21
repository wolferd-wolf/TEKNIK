class_name TeknikMobileControls
extends Control

signal movement_changed(value: Vector2)
signal look_dragged(delta: Vector2)
signal jump_pressed
signal break_pressed
signal place_pressed

const ControlMath = preload("res://src/player/mobile_control_math.gd")
const STICK_RADIUS: float = 92.0
const KNOB_RADIUS: float = 38.0

var _move_touch_id: int = -1
var _look_touch_id: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_position: Vector2 = Vector2.ZERO
var _jump_active: bool = false
var _break_active: bool = false
var _place_active: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if event.pressed:
		if ControlMath.is_jump_zone(event.position, viewport_size):
			_jump_active = true
			jump_pressed.emit()
			queue_redraw()
			return
		if ControlMath.is_break_zone(event.position, viewport_size):
			_break_active = true
			break_pressed.emit()
			queue_redraw()
			return
		if ControlMath.is_place_zone(event.position, viewport_size):
			_place_active = true
			place_pressed.emit()
			queue_redraw()
			return
		if _move_touch_id == -1 and ControlMath.is_movement_zone(event.position, viewport_size):
			_move_touch_id = event.index
			_move_origin = event.position
			_move_position = event.position
			movement_changed.emit(Vector2.ZERO)
			queue_redraw()
			return
		if _look_touch_id == -1 and ControlMath.is_look_zone(event.position, viewport_size):
			_look_touch_id = event.index
	else:
		if event.index == _move_touch_id:
			_move_touch_id = -1
			_move_origin = Vector2.ZERO
			_move_position = Vector2.ZERO
			movement_changed.emit(Vector2.ZERO)
		if event.index == _look_touch_id:
			_look_touch_id = -1
		if ControlMath.is_jump_zone(event.position, viewport_size):
			_jump_active = false
		if ControlMath.is_break_zone(event.position, viewport_size):
			_break_active = false
		if ControlMath.is_place_zone(event.position, viewport_size):
			_place_active = false
		queue_redraw()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _move_touch_id:
		_move_position = event.position
		movement_changed.emit(ControlMath.stick_vector(_move_origin, _move_position, STICK_RADIUS))
		queue_redraw()
	elif event.index == _look_touch_id:
		look_dragged.emit(event.relative)


func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var jump_center := Vector2(viewport_size.x * 0.87, viewport_size.y * 0.80)
	var jump_radius: float = minf(viewport_size.x, viewport_size.y) * 0.088
	draw_circle(jump_center, jump_radius, Color(0.86, 0.9, 0.94, 0.32 if not _jump_active else 0.52))
	draw_arc(jump_center, jump_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.65), 3.0)
	draw_string(ThemeDB.fallback_font, jump_center + Vector2(-24.0, 9.0), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(1.0, 1.0, 1.0, 0.85))

	var break_center := Vector2(viewport_size.x * 0.79, viewport_size.y * 0.59)
	var action_radius: float = minf(viewport_size.x, viewport_size.y) * 0.075
	draw_circle(break_center, action_radius, Color(0.88, 0.56, 0.42, 0.34 if not _break_active else 0.58))
	draw_arc(break_center, action_radius, 0.0, TAU, 48, Color(1.0, 0.86, 0.76, 0.7), 3.0)
	draw_string(ThemeDB.fallback_font, break_center + Vector2(-27.0, 8.0), "BREAK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1.0, 0.92, 0.86, 0.9))

	var place_center := Vector2(viewport_size.x * 0.91, viewport_size.y * 0.59)
	draw_circle(place_center, action_radius, Color(0.42, 0.68, 0.9, 0.34 if not _place_active else 0.58))
	draw_arc(place_center, action_radius, 0.0, TAU, 48, Color(0.78, 0.9, 1.0, 0.72), 3.0)
	draw_string(ThemeDB.fallback_font, place_center + Vector2(-24.0, 8.0), "PLACE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.88, 0.96, 1.0, 0.92))

	if _move_touch_id != -1:
		draw_circle(_move_origin, STICK_RADIUS, Color(0.08, 0.12, 0.16, 0.34))
		draw_arc(_move_origin, STICK_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.42), 3.0)
		var knob_offset: Vector2 = _move_position - _move_origin
		if knob_offset.length() > STICK_RADIUS:
			knob_offset = knob_offset.normalized() * STICK_RADIUS
		draw_circle(_move_origin + knob_offset, KNOB_RADIUS, Color(0.9, 0.94, 0.98, 0.58))