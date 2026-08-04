extends Node

# Drives an existing ScrollContainer from Android screen-touch events without
# replacing the container or taking ownership of its content. Taps continue to
# reach recipe buttons; once a vertical drag crosses the deadzone, descendants
# receive the same scroll notifications Godot uses to cancel armed buttons.
const TOUCH_DEADZONE: float = 10.0
const QA_TOUCH_ID: int = 97

var _scroll: ScrollContainer
var _active_touch_id: int = -1
var _drag_accumulator: Vector2 = Vector2.ZERO
var _dragging: bool = false


func attach(scroll: ScrollContainer) -> void:
	_scroll = scroll
	set_process_input(_scroll != null)


func _exit_tree() -> void:
	_reset_touch(false)


func _input(event: InputEvent) -> void:
	if _scroll == null or not is_instance_valid(_scroll) or not _scroll.is_visible_in_tree():
		if _active_touch_id != -1:
			_reset_touch(false)
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _active_touch_id == -1 and _scroll.get_global_rect().has_point(touch.position):
				_begin_touch(touch.index)
		elif touch.index == _active_touch_id:
			var consumed: bool = _dragging
			_end_touch()
			if consumed:
				get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _active_touch_id:
			return
		var moved: bool = _drag_touch(drag.relative)
		if moved or _dragging:
			get_viewport().set_input_as_handled()


func _begin_touch(touch_id: int) -> void:
	_active_touch_id = touch_id
	_drag_accumulator = Vector2.ZERO
	_dragging = false


func _drag_touch(relative: Vector2) -> bool:
	if _active_touch_id == -1 or _scroll == null:
		return false

	var movement_y: float = relative.y
	if not _dragging:
		_drag_accumulator += relative
		if (
			absf(_drag_accumulator.y) < TOUCH_DEADZONE
			or absf(_drag_accumulator.y) <= absf(_drag_accumulator.x)
			or _maximum_vertical_scroll() <= 0
		):
			return false
		_dragging = true
		movement_y = _drag_accumulator.y
		_drag_accumulator = Vector2.ZERO
		_notify_scroll_state(Control.NOTIFICATION_SCROLL_BEGIN)

	var before: int = _scroll.scroll_vertical
	var target: int = clampi(
		before - roundi(movement_y),
		0,
		_maximum_vertical_scroll()
	)
	_scroll.scroll_vertical = target
	return target != before


func _end_touch() -> void:
	if _dragging:
		_notify_scroll_state(Control.NOTIFICATION_SCROLL_END)
	_reset_touch(false)


func _reset_touch(notify_end: bool) -> void:
	if notify_end and _dragging:
		_notify_scroll_state(Control.NOTIFICATION_SCROLL_END)
	_active_touch_id = -1
	_drag_accumulator = Vector2.ZERO
	_dragging = false


func _notify_scroll_state(notification: int) -> void:
	if _scroll == null:
		return
	for child: Node in _scroll.get_children():
		child.propagate_notification(notification)


func _maximum_vertical_scroll() -> int:
	if _scroll == null:
		return 0
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	if bar == null:
		return 0
	return maxi(0, floori(bar.max_value - bar.page))


func qa_drag_vertical(distance: float = 120.0) -> bool:
	# Exercises the same drag state machine used for InputEventScreenDrag without
	# relying on desktop touch emulation in CI.
	if _maximum_vertical_scroll() <= 0:
		return false
	_scroll.scroll_vertical = 0
	_begin_touch(QA_TOUCH_ID)
	var moved: bool = _drag_touch(Vector2(0.0, -absf(distance)))
	_end_touch()
	return moved and _scroll.scroll_vertical > 0
