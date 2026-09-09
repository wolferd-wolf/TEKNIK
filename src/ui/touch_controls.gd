extends Control
class_name TouchControls

## Mobile input layer: left-side virtual joystick, right-side look-drag,
## hold-buttons for mine/place, tap-buttons for jump/crouch/inventory/pause.

const JOY_RADIUS := 64.0
const LOOK_SENSITIVITY := 0.0042
const PLACE_REPEAT := 0.28

var player: Player
var inventory_toggle: Callable

var _joy_touch := -1
var _joy_center := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _look_touch := -1
var _look_last := Vector2.ZERO

var _joy_base: Control
var _joy_knob: Control
var _btn_jump: Button
var _btn_crouch: Button
var _btn_mine: Button
var _btn_place: Button

var _place_timer := 0.0
var _crouch_toggle := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	visible = false  # enabled by the HUD when touch is detected


func _build() -> void:
	# joystick base + knob (hidden until touched)
	_joy_base = _make_circle(JOY_RADIUS, Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.35))
	_joy_knob = _make_circle(28.0, Color(1, 1, 1, 0.30), Color(1, 1, 1, 0.7))
	_joy_base.visible = false
	_joy_knob.visible = false
	add_child(_joy_base)
	add_child(_joy_knob)

	_btn_jump = _make_button("Jump", Vector2(-24, -120), false)
	_btn_crouch = _make_button("Duck", Vector2(-120, -32), true)
	_btn_jump.button_down.connect(func() -> void: _set_jump(true))
	_btn_jump.button_up.connect(func() -> void: _set_jump(false))
	_btn_crouch.toggled.connect(func(on: bool) -> void:
		_crouch_toggle = on
		_sync_touch_state())

	_btn_mine = _make_button("Mine", Vector2(-24, -216), false)
	_btn_place = _make_button("Place", Vector2(-120, -120), false)
	_btn_mine.button_down.connect(func() -> void: _set_mining(true))
	_btn_mine.button_up.connect(func() -> void: _set_mining(false))
	_btn_place.button_down.connect(func() -> void: _set_placing(true))
	_btn_place.button_up.connect(func() -> void: _set_placing(false))

	var btn_inv := _make_button("Bag", Vector2(-24, 24), false)
	btn_inv.pressed.connect(func() -> void: inventory_toggle.call())
	var btn_pause := _make_button("| |", Vector2(-70, 24), false)
	btn_pause.pressed.connect(func() -> void:
		var hud := get_parent() as Node
		if hud != null and hud.has_method("open_pause"):
			hud.open_pause())


func _make_circle(radius: float, fill: Color, border: Color) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(radius * 2, radius * 2)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(radius))
	panel.add_theme_stylebox_override("panel", sb)
	c.add_child(panel)
	c.pivot_offset = Vector2(radius, radius)
	return c


func _make_button(label: String, anchor_offset: Vector2, toggle_hold: bool) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(84, 84)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.12, 0.55)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	b.add_theme_stylebox_override("normal", sb)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.9, 0.9, 0.95, 0.5)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = anchor_offset.x - 84
	b.offset_top = anchor_offset.y - 84
	b.offset_right = anchor_offset.x
	b.offset_bottom = anchor_offset.y
	if toggle_hold:
		b.toggle_mode = true
	add_child(b)
	return b


func _set_jump(on: bool) -> void:
	if player != null:
		player.set_touch_state(on, _crouch_toggle)


func _set_mining(on: bool) -> void:
	if player != null:
		player.touch_mining = on


func _set_placing(on: bool) -> void:
	if player != null:
		player.touch_placing = on


func _sync_touch_state() -> void:
	if player != null:
		player.set_touch_state(_btn_jump.button_pressed, _crouch_toggle)


func _process(delta: float) -> void:
	if player == null:
		return
	player.joystick = _joy_vec
	if _btn_place.button_pressed:
		_place_timer -= delta
		if _place_timer <= 0.0:
			_place_timer = PLACE_REPEAT
			player.touch_placing = true


func _input(event: InputEvent) -> void:
	# raw touch events arrive here; Control buttons work via emulated mouse,
	# so touches starting on a button rect are ignored by the drag/joystick layer
	if not visible:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if not _over_button(st.position):
				_on_press(st.index, st.position)
		else:
			_on_release(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_touch:
			_update_joystick(sd.position)
		elif sd.index == _look_touch and player != null:
			var rel := sd.position - _look_last
			_look_last = sd.position
			player.apply_look(rel * LOOK_SENSITIVITY)


func _over_button(pos: Vector2) -> bool:
	for c in get_children():
		if c is BaseButton and (c as Control).visible:
			if (c as Control).get_global_rect().has_point(pos):
				return true
	return false


func _on_press(index: int, pos: Vector2) -> void:
	if pos.x < size.x * 0.42 and _joy_touch == -1:
		_joy_touch = index
		_joy_center = pos
		_update_joystick(pos)
	elif _look_touch == -1:
		_look_touch = index
		_look_last = pos


func _on_release(index: int) -> void:
	if index == _joy_touch:
		_joy_touch = -1
		_joy_vec = Vector2.ZERO
		_joy_base.visible = false
		_joy_knob.visible = false
	elif index == _look_touch:
		_look_touch = -1


func _update_joystick(pos: Vector2) -> void:
	var rel := pos - _joy_center
	if rel.length() > JOY_RADIUS:
		rel = rel.normalized() * JOY_RADIUS
	_joy_vec = rel / JOY_RADIUS
	if _joy_vec.length() < 0.16:
		_joy_vec = Vector2.ZERO
	_joy_base.visible = _joy_vec != Vector2.ZERO or _joy_touch != -1
	_joy_knob.visible = _joy_base.visible
	if _joy_base.visible:
		_joy_base.position = _joy_center - _joy_base.custom_minimum_size * 0.5
		_joy_knob.position = _joy_center + rel - _joy_knob.custom_minimum_size * 0.5
