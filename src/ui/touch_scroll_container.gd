class_name TeknikTouchScrollContainer
extends ScrollContainer

# ScrollContainer's native touch path depends on GUI event propagation through
# every child Control. Inventory rows and recipe buttons can consume that path,
# so this container tracks screen touches at the input layer while still leaving
# taps available to buttons. Once a vertical drag begins, scroll notifications
# cancel armed child buttons in the same way as Godot's native touch scrolling.
const TOUCH_DEADZONE: float = 10.0
const NATIVE_TOUCH_DEADZONE: int = 100_000
const QA_TOUCH_ID: int = 97

var _active_touch_id: int = -1
var _drag_accumulator: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Keep wheel and scrollbar input native, but prevent the engine's touch path
	# from double-applying movement beside the deterministic handler below.
	scroll_deadzone = NATIVE_TOUCH_DEADZONE
	set_process_input(true)


func _exit_tree() -> void:
	_reset_touch(false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if _active_touch_id != -1:
			_reset_touch(false)
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _active_touch_id == -1 and get_global_rect().has_point(touch.position):
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
	if _active_touch_id == -1:
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
		scroll_started.emit()

	var before: int = scroll_vertical
	var target: int = clampi(
		before - roundi(movement_y),
		0,
		_maximum_vertical_scroll()
	)
	scroll_vertical = target
	return target != before


func _end_touch() -> void:
	if _dragging:
		_notify_scroll_state(Control.NOTIFICATION_SCROLL_END)
		scroll_ended.emit()
	_reset_touch(false)


func _reset_touch(notify_end: bool) -> void:
	if notify_end and _dragging:
		_notify_scroll_state(Control.NOTIFICATION_SCROLL_END)
		scroll_ended.emit()
	_active_touch_id = -1
	_drag_accumulator = Vector2.ZERO
	_dragging = false


func _notify_scroll_state(notification: int) -> void:
	for child: Node in get_children():
		child.propagate_notification(notification)


func _maximum_vertical_scroll() -> int:
	var bar: VScrollBar = get_v_scroll_bar()
	if bar == null:
		return 0
	return maxi(0, floori(bar.max_value - bar.page))


func qa_drag_vertical(distance: float = 120.0) -> bool:
	# Exercises the exact drag state machine used by InputEventScreenDrag without
	# depending on desktop touch emulation in CI.
	if _maximum_vertical_scroll() <= 0:
		return false
	scroll_vertical = 0
	_begin_touch(QA_TOUCH_ID)
	var moved: bool = _drag_touch(Vector2(0.0, -absf(distance)))
	_end_touch()
	return moved and scroll_vertical > 0
