extends CanvasLayer
class_name HUD

## In-game HUD: crosshair, hearts, hunger, hotbar, messages, touch controls,
## inventory screen, pause and death overlays.

signal quit_requested
signal respawn_requested

var player: Player
var world: World
var day_night: DayNight

var _hearts: Array[TextureRect] = []
var _food: Array[TextureRect] = []
var _hotbar: Array[Button] = []
var _crosshair: Control
var _msg_label: Label
var _msg_timer: Timer
var _touch: TouchControls
var _inv_screen: InventoryScreen
var _pause_panel: Panel
var _death_panel: Panel
var _time_label: Label
var _pos_label: Label

static var _tex_atlas: Texture2D


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	_build_crosshair(root)
	_build_stats(root)
	_build_hotbar(root)
	_build_labels(root)
	_build_touch(root)
	_build_inventory(root)
	_build_pause(root)
	_build_death(root)

	_msg_timer = Timer.new()
	_msg_timer.wait_time = 2.2
	_msg_timer.one_shot = true
	_msg_timer.timeout.connect(func() -> void: _msg_label.visible = false)
	root.add_child(_msg_timer)


static func _tile_icon(tile: int) -> AtlasTexture:
	if _tex_atlas == null:
		_tex_atlas = ChunkMesher.atlas_texture()
	var at := AtlasTexture.new()
	at.atlas = _tex_atlas
	@warning_ignore("integer_division")
	at.region = Rect2((tile % AtlasTiles.COLS) * AtlasTiles.TILE_PX, (tile / AtlasTiles.COLS) * AtlasTiles.TILE_PX, AtlasTiles.TILE_PX, AtlasTiles.TILE_PX)
	return at


func _build_crosshair(root: Control) -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)
	var v := ColorRect.new()
	v.color = Color(1, 1, 1, 0.75)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.position = Vector2(-1, -7)
	v.size = Vector2(2, 14)
	_crosshair.add_child(v)
	var h := ColorRect.new()
	h.color = Color(1, 1, 1, 0.75)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.position = Vector2(-7, -1)
	h.size = Vector2(14, 2)
	_crosshair.add_child(h)


func _build_stats(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 14
	bar.offset_top = -108
	bar.offset_bottom = -76
	bar.offset_right = 380
	bar.add_theme_constant_override("separation", 1)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	for i in range(10):
		var tr := TextureRect.new()
		tr.texture = HUD._tile_icon(47)
		tr.custom_minimum_size = Vector2(26, 26)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(tr)
		_hearts.append(tr)

	var food_bar := HBoxContainer.new()
	food_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	food_bar.offset_left = -380
	food_bar.offset_top = -108
	food_bar.offset_bottom = -76
	food_bar.offset_right = -14
	food_bar.alignment = BoxContainer.ALIGNMENT_END
	food_bar.add_theme_constant_override("separation", 1)
	food_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(food_bar)
	for i in range(10):
		var tr := TextureRect.new()
		tr.texture = HUD._tile_icon(49)
		tr.custom_minimum_size = Vector2(26, 26)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		food_bar.add_child(tr)
		_food.append(tr)


func _build_hotbar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_top = -66
	bar.offset_bottom = -12
	bar.offset_left = -306
	bar.offset_right = 306
	bar.add_theme_constant_override("separation", 6)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bar)
	for i in range(9):
		var b := Button.new()
		b.custom_minimum_size = Vector2(60, 54)
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.08, 0.1, 0.72)
		sb.border_color = Color(1, 1, 1, 0.35)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		var sb_sel := sb.duplicate() as StyleBoxFlat
		sb_sel.border_color = Color(1.0, 0.9, 0.4)
		sb_sel.set_border_width_all(3)
		b.add_theme_stylebox_override("focus", sb_sel)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 5
		icon.offset_top = 3
		icon.offset_right = -5
		icon.offset_bottom = -14
		b.add_child(icon)
		var count := Label.new()
		count.name = "Count"
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 13)
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.offset_left = -28
		count.offset_top = -18
		count.offset_right = -3
		count.offset_bottom = -2
		b.add_child(count)
		var dur := ProgressBar.new()
		dur.name = "Dur"
		dur.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dur.show_percentage = false
		dur.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		dur.offset_left = 4
		dur.offset_right = -4
		dur.offset_top = -7
		dur.offset_bottom = -3
		dur.modulate = Color(0.4, 1.0, 0.4)
		b.add_child(dur)
		b.pressed.connect(_on_hotbar_pressed.bind(i))
		bar.add_child(b)
		_hotbar.append(b)


func _on_hotbar_pressed(i: int) -> void:
	if player != null:
		player.hotbar_index = i
		player.held_changed.emit()
		refresh_hotbar()


func _build_labels(root: Control) -> void:
	_msg_label = Label.new()
	_msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_msg_label.offset_top = 64
	_msg_label.offset_bottom = 96
	_msg_label.offset_left = -300
	_msg_label.offset_right = 300
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 18)
	_msg_label.visible = false
	_msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_msg_label)

	_time_label = Label.new()
	_time_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_time_label.offset_left = -220
	_time_label.offset_right = -12
	_time_label.offset_top = 8
	_time_label.add_theme_font_size_override("font_size", 14)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_label.modulate = Color(1, 1, 1, 0.8)
	root.add_child(_time_label)

	_pos_label = Label.new()
	_pos_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pos_label.offset_left = 12
	_pos_label.offset_top = 8
	_pos_label.add_theme_font_size_override("font_size", 14)
	_pos_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pos_label.modulate = Color(1, 1, 1, 0.8)
	root.add_child(_pos_label)


func _build_touch(root: Control) -> void:
	_touch = TouchControls.new()
	_touch.name = "Touch"
	_touch.hud = self
	root.add_child(_touch)


func _build_inventory(root: Control) -> void:
	_inv_screen = InventoryScreen.new()
	_inv_screen.name = "InventoryScreen"
	_inv_screen.visible = false
	_inv_screen.closed.connect(close_inventory)
	root.add_child(_inv_screen)


func _build_pause(root: Control) -> void:
	_pause_panel = Panel.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.65)
	_pause_panel.add_theme_stylebox_override("panel", sb)
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_pause_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(280, 220)
	box.position = Vector2(-140, -110)
	box.add_theme_constant_override("separation", 14)
	_pause_panel.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume := Button.new()
	resume.text = "Resume"
	resume.focus_mode = Control.FOCUS_NONE
	resume.custom_minimum_size = Vector2(280, 44)
	resume.pressed.connect(close_pause)
	box.add_child(resume)

	var save := Button.new()
	save.text = "Save World"
	save.focus_mode = Control.FOCUS_NONE
	save.custom_minimum_size = Vector2(280, 44)
	save.pressed.connect(func() -> void:
		get_viewport().set_input_as_handled()
		var gw := _find_game_world()
		if gw != null and gw.save_all():
			show_message("World saved")
		else:
			show_message("Save failed!")
		close_pause())
	box.add_child(save)

	var quit := Button.new()
	quit.text = "Save & Quit to Menu"
	quit.focus_mode = Control.FOCUS_NONE
	quit.custom_minimum_size = Vector2(280, 44)
	quit.pressed.connect(func() -> void:
		var gw := _find_game_world()
		if gw != null:
			gw.save_all()
		close_pause()
		quit_requested.emit())
	box.add_child(quit)


func _find_game_world() -> GameWorld:
	var p := get_parent()
	return p as GameWorld


func _build_death(root: Control) -> void:
	_death_panel = Panel.new()
	_death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.4, 0.05, 0.05, 0.6)
	_death_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_death_panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(320, 160)
	box.position = Vector2(-160, -80)
	box.add_theme_constant_override("separation", 18)
	_death_panel.add_child(box)

	var title := Label.new()
	title.text = "You died"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var btn := Button.new()
	btn.text = "Respawn"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(320, 48)
	btn.pressed.connect(func() -> void: respawn_requested.emit())
	box.add_child(btn)


# ---------------------------------------------------------------- public API

func show_message(text: String) -> void:
	_msg_label.text = text
	_msg_label.visible = true
	_msg_timer.start()


func refresh_stats() -> void:
	if player == null:
		return
	var hp := player.health
	for i in range(10):
		var full := hp > float(i) * 2.0
		_hearts[i].texture = HUD._tile_icon(47 if full else 48)
	var food := player.hunger
	for i in range(10):
		var full := food > float(i) * 2.0
		_food[i].texture = HUD._tile_icon(49 if full else 50)


func refresh_hotbar() -> void:
	if player == null:
		return
	for i in range(9):
		var b := _hotbar[i]
		var s := player.inventory.get_slot(i)
		var icon := b.get_node("Icon") as TextureRect
		var count := b.get_node("Count") as Label
		var dur := b.get_node("Dur") as ProgressBar
		if s.is_empty():
			icon.texture = null
			count.text = ""
			dur.visible = false
		else:
			var id := int(s["id"])
			icon.texture = HUD._tile_icon(ItemRegistry.tile_of(id))
			var n := int(s["count"])
			count.text = str(n) if n > 1 else ""
			if ItemRegistry.is_tool_item(id):
				var max_dur := ItemRegistry.tool_durability(id)
				dur.max_value = float(max_dur)
				dur.value = float(int(s.get("dur", 0)))
				dur.visible = true
			else:
				dur.visible = false
		var sel_sb := b.get_theme_stylebox("focus") as StyleBoxFlat
		sel_sb.border_color = Color(1.0, 0.9, 0.4) if i == player.hotbar_index else Color(1, 1, 1, 0.35)
		b.queue_redraw()


func refresh_time() -> void:
	if day_night == null:
		return
	var t := day_night.time_of_day
	var hours := int(floorf(t * 24.0))
	var minutes := int(fmod(t * 24.0 * 60.0, 60.0))
	_time_label.text = "%02d:%02d %s" % [(hours + 6) % 24, minutes, "day" if day_night.is_day() else "night"]


func refresh_pos() -> void:
	if player == null:
		return
	var p := player.global_position
	_pos_label.text = "x %d  y %d  z %d" % [floori(p.x), floori(p.y), floori(p.z)]


func open_inventory() -> void:
	if _inv_screen.visible or player == null or _pause_panel.visible or player.dead:
		return
	_inv_screen.player = player
	_inv_screen.world = world
	_inv_screen.refresh()
	_inv_screen.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_inventory() -> void:
	_inv_screen.visible = false
	_picked_reset()
	get_tree().paused = false
	if _should_capture_mouse():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _picked_reset() -> void:
	pass  # ghost visibility handled inside InventoryScreen


func inventory_open() -> bool:
	return _inv_screen.visible


func open_pause() -> void:
	_pause_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_pause() -> void:
	_pause_panel.visible = false
	get_tree().paused = false
	if _should_capture_mouse():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func pause_open() -> bool:
	return _pause_panel.visible


func show_death(show: bool) -> void:
	_death_panel.visible = show


func enable_touch(on: bool) -> void:
	_touch.visible = on


func toggle_touch() -> void:
	_touch.visible = not _touch.visible
	if _touch.visible:
		show_message("Touch controls on")
	else:
		show_message("Touch controls off")


func _should_capture_mouse() -> bool:
	if _pause_panel.visible or _inv_screen.visible or _death_panel.visible:
		return false
	return true
