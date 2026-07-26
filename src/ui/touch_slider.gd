class_name TeknikTouchSlider
extends HSlider

var _active_touch_id: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch_id == -1:
			_active_touch_id = event.index
			apply_touch_position(event.position.x)
			accept_event()
		elif not event.pressed and event.index == _active_touch_id:
			apply_touch_position(event.position.x)
			_active_touch_id = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == _active_touch_id:
		apply_touch_position(event.position.x)
		accept_event()


func apply_touch_position(local_x: float) -> void:
	value = value_for_position(local_x, size.x, min_value, max_value, step)


static func value_for_position(
	local_x: float,
	width: float,
	minimum: float,
	maximum: float,
	step_value: float
) -> float:
	if maximum <= minimum:
		return minimum
	var fraction: float = clampf(local_x / maxf(width, 1.0), 0.0, 1.0)
	var raw_value: float = lerpf(minimum, maximum, fraction)
	if step_value > 0.0:
		raw_value = minimum + round((raw_value - minimum) / step_value) * step_value
	return clampf(raw_value, minimum, maximum)
