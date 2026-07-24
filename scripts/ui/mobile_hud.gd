extends CanvasLayer

const VirtualJoystickScript := preload("res://scripts/ui/virtual_joystick.gd")

var player: Node
var world: Node
var stats_label: Label
var status_label: Label
var look_touch := -1
var last_look_position := Vector2.ZERO

func _ready() -> void:
	layer = 20
	_build_ui()
	set_process_input(true)

func attach_player(value: Node) -> void:
	player = value
	status_label.text = "WORLD READY"

func attach_world(value: Node) -> void:
	world = value

func _process(_delta: float) -> void:
	if is_instance_valid(world):
		stats_label.text = "FPS %d\n%s" % [Engine.get_frames_per_second(), world.get_status_text()]

func _build_ui() -> void:
	stats_label = Label.new()
	stats_label.position = Vector2(18, 14)
	stats_label.add_theme_font_size_override("font_size", 17)
	stats_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	stats_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	stats_label.add_theme_constant_override("shadow_offset_x", 2)
	stats_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(stats_label)

	status_label = Label.new()
	status_label.text = "BUILDING SAFE SPAWN..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.position = Vector2(-180, 18)
	status_label.size = Vector2(360, 36)
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-18, -18)
	crosshair.size = Vector2(36, 36)
	crosshair.add_theme_font_size_override("font_size", 26)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	add_child(crosshair)

	var joystick := VirtualJoystickScript.new()
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(0, -310)
	joystick.size = Vector2(420, 310)
	joystick.changed.connect(_on_move_changed)
	add_child(joystick)

	var jump_button := _make_button("JUMP", Vector2(-154, -158), Vector2(124, 92))
	jump_button.pressed.connect(_on_jump_pressed)
	var mine_button := _make_button("MINE", Vector2(-292, -102), Vector2(124, 76))
	mine_button.pressed.connect(_on_mine_pressed)
	var place_button := _make_button("PLACE", Vector2(-154, -264), Vector2(124, 76))
	place_button.pressed.connect(_on_place_pressed)

	var hint := Label.new()
	hint.text = "Drag right side to look"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-300, -28)
	hint.size = Vector2(280, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	add_child(hint)

func _make_button(text: String, offset: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = offset
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.modulate = Color(1, 1, 1, 0.78)
	add_child(button)
	return button

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > viewport_size.x * 0.46 and event.position.y < viewport_size.y * 0.80 and look_touch < 0:
			look_touch = event.index
			last_look_position = event.position
		elif not event.pressed and event.index == look_touch:
			look_touch = -1
	elif event is InputEventScreenDrag and event.index == look_touch:
		var delta_value := event.position - last_look_position
		last_look_position = event.position
		player.apply_touch_look(delta_value)

func _on_move_changed(value: Vector2) -> void:
	if is_instance_valid(player):
		player.set_mobile_move(value)

func _on_jump_pressed() -> void:
	if is_instance_valid(player):
		player.request_jump()

func _on_mine_pressed() -> void:
	if is_instance_valid(player):
		player.request_mine()

func _on_place_pressed() -> void:
	if is_instance_valid(player):
		player.request_place()
