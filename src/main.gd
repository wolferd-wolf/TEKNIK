extends Node
class_name Main

## Entry point: main menu (world slots), session lifecycle, global input map.

const SAVE_ROOT := "user://saves"
const SLOT_COUNT := 3

var _current: GameWorld
var _menu: Control


func _ready() -> void:
	_register_actions()
	_build_menu()
	_show_menu()


static func slot_dir(slot: int) -> String:
	return "%s/slot_%d" % [SAVE_ROOT, slot]


## Input actions are registered in code so desktop + touch bindings live in one place.
func _register_actions() -> void:
	_ensure_action("move_forward", [_key(KEY_W), _key(KEY_UP)])
	_ensure_action("move_back", [_key(KEY_S), _key(KEY_DOWN)])
	_ensure_action("move_left", [_key(KEY_A), _key(KEY_LEFT)])
	_ensure_action("move_right", [_key(KEY_D), _key(KEY_RIGHT)])
	_ensure_action("jump", [_key(KEY_SPACE)])
	_ensure_action("crouch", [_key(KEY_SHIFT)])
	_ensure_action("sprint", [_key(KEY_CTRL)])
	_ensure_action("mine", [_mouse(MOUSE_BUTTON_LEFT)])
	_ensure_action("place", [_mouse(MOUSE_BUTTON_RIGHT)])
	_ensure_action("inventory", [_key(KEY_E)])
	_ensure_action("pause", [_key(KEY_ESCAPE)])
	_ensure_action("toggle_touch", [_key(KEY_T)])


static func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev


func _ensure_action(name: String, events: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.4)
	for ev: InputEvent in events:
		InputMap.action_add_event(name, ev)


# ---------------------------------------------------------------- menu

func _build_menu() -> void:
	_menu = Control.new()
	_menu.name = "MainMenu"
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.1, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)

	var title := Label.new()
	title.text = "TEKNIK"
	title.add_theme_font_size_override("font_size", 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -300
	title.offset_right = 300
	title.offset_top = 60
	_menu.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "voxel survival engineering sandbox"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color(1, 1, 1, 0.6)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_left = -300
	subtitle.offset_right = 300
	subtitle.offset_top = 124
	_menu.add_child(subtitle)

	_rebuild_slot_box()

	var note := Label.new()
	note.text = "WASD move, Space jump, Shift crouch, Ctrl sprint, LMB mine, RMB place/use, E bag, Esc pause"
	note.add_theme_font_size_override("font_size", 13)
	note.modulate = Color(1, 1, 1, 0.5)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	note.offset_left = -460
	note.offset_right = 460
	note.offset_top = -50
	note.offset_bottom = -24
	_menu.add_child(note)


func _make_slot_row(slot: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var dir := slot_dir(slot)
	var meta := World.load_metadata(dir)
	var exists := not meta.is_empty()

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 54)
	btn.focus_mode = Control.FOCUS_NONE
	if exists:
		var saved_at := int(meta.get("saved_at", 0))
		var date := Time.get_datetime_string_from_unix_time(saved_at) if saved_at > 0 else "older save"
		btn.text = "World %d  -  seed %d  (%s)" % [slot + 1, int(meta.get("seed", 0)), date]
	else:
		btn.text = "World %d  -  New" % [slot + 1]
	btn.pressed.connect(_on_slot_pressed.bind(slot, exists))
	row.add_child(btn)

	if exists:
		var del := Button.new()
		del.text = "Delete"
		del.focus_mode = Control.FOCUS_NONE
		del.custom_minimum_size = Vector2(110, 54)
		del.pressed.connect(_on_delete_pressed.bind(slot))
		row.add_child(del)
	return row


func _on_slot_pressed(slot: int, _exists: bool) -> void:
	_start_session(slot, not _is_empty_dir(slot_dir(slot)))


func _is_empty_dir(dir: String) -> bool:
	if not DirAccess.dir_exists_absolute(dir):
		return true
	var meta := World.load_metadata(dir)
	return meta.is_empty()


func _on_delete_pressed(slot: int) -> void:
	var dir := slot_dir(slot)
	if DirAccess.dir_exists_absolute(dir):
		_recursive_delete(dir)
	_refresh_menu()


func _recursive_delete(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	var f := da.get_next()
	while not f.is_empty():
		var full := path.path_join(f)
		if da.current_is_dir():
			_recursive_delete(full)
		else:
			DirAccess.remove_absolute(full)
		f = da.get_next()
	da.list_dir_end()
	DirAccess.remove_absolute(path)


func _refresh_menu() -> void:
	# deferred so the old rows release before the new ones take their place
	_rebuild_slot_box.call_deferred()


func _rebuild_slot_box() -> void:
	for c in _menu.get_children():
		if c is VBoxContainer:
			_menu.remove_child(c)
			c.queue_free()
	var slots_box := VBoxContainer.new()
	slots_box.set_anchors_preset(Control.PRESET_CENTER)
	slots_box.custom_minimum_size = Vector2(420, 340)
	slots_box.position = Vector2(-210, -140)
	slots_box.add_theme_constant_override("separation", 12)
	_menu.add_child(slots_box)
	for slot in range(SLOT_COUNT):
		slots_box.add_child(_make_slot_row(slot))


# ---------------------------------------------------------------- session

func _start_session(slot: int, restore: bool) -> void:
	if _current != null:
		return
	var dir := slot_dir(slot)
	if not restore and DirAccess.dir_exists_absolute(dir):
		_recursive_delete(dir)  # fresh world = fresh player state
	_menu.visible = false
	_current = GameWorld.new("World %d" % (slot + 1), dir, restore)
	_current.quit_to_menu.connect(_show_menu)
	add_child(_current)


func _show_menu() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_menu()
	_menu.visible = true
