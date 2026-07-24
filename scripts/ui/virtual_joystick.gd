extends Control

signal changed(value: Vector2)

const MAX_RADIUS := 72.0
var active_touch := -1
var base_position := Vector2.ZERO
var knob_position := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and active_touch < 0:
		base_position = size * Vector2(0.42, 0.60)
		knob_position = base_position
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch < 0:
			active_touch = event.index
			base_position = event.position
			_update_knob(event.position)
			accept_event()
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			knob_position = base_position
			changed.emit(Vector2.ZERO)
			queue_redraw()
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_knob(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				active_touch = -2
				base_position = event.position
				_update_knob(event.position)
			else:
				active_touch = -1
				knob_position = base_position
				changed.emit(Vector2.ZERO)
				queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and active_touch == -2:
		_update_knob(event.position)
		accept_event()

func _update_knob(position: Vector2) -> void:
	var offset := position - base_position
	knob_position = base_position + offset.limit_length(MAX_RADIUS)
	var normalized := (knob_position - base_position) / MAX_RADIUS
	changed.emit(Vector2(normalized.x, -normalized.y))
	queue_redraw()

func _draw() -> void:
	draw_circle(base_position, MAX_RADIUS, Color(0.04, 0.06, 0.08, 0.42))
	draw_arc(base_position, MAX_RADIUS, 0.0, TAU, 48, Color(0.86, 0.90, 0.92, 0.45), 3.0)
	draw_circle(knob_position, 30.0, Color(0.78, 0.84, 0.88, 0.68))
