extends "res://src/main/survival_vitals_main.gd"

const MiningDemoDirector = preload("res://src/qa/mining_demo_director.gd")
const TouchSlider = preload("res://src/ui/touch_slider.gd")

const SETTINGS_PATH: String = "user://teknik-settings.json"
const SETTINGS_SCHEMA: int = 1
const RENDER_DISTANCE_MIN: int = 2
const RENDER_DISTANCE_MAX: int = 5
const DEFAULT_RENDER_DISTANCE: int = 3
const LOOK_SENSITIVITY_MIN: float = 0.5
const LOOK_SENSITIVITY_MAX: float = 2.0
const DEFAULT_LOOK_SENSITIVITY: float = 1.0
const INVENTORY_WORKSPACE_SIZE := Vector2(840.0, 520.0)
const INVENTORY_WORKSPACE_POSITION := Vector2(24.0, 88.0)
const SETTINGS_PANEL_SIZE := Vector2(312.0, 430.0)
const SETTINGS_PANEL_POSITION := Vector2(920.0, 120.0)
const INVALID_SETTINGS_CENTER := Vector3i(2_000_000_000, 0, 2_000_000_000)

var _settings_render_distance: int = DEFAULT_RENDER_DISTANCE
var _settings_look_sensitivity: float = DEFAULT_LOOK_SENSITIVITY
var _settings_show_fps: bool = true
var _settings_panel: PanelContainer
var _settings_button: Button
var _render_distance_slider: TeknikTouchSlider
var _render_distance_label: Label
var _look_sensitivity_slider: TeknikTouchSlider
var _look_sensitivity_label: Label
var _fps_toggle: CheckButton
var _inventory_workspace: HBoxContainer
var _inventory_items_panel: PanelContainer
var _inventory_crafting_panel: PanelContainer


func _ready() -> void:
	_load_game_settings()
	# CHUNK_RADIUS is now runtime state rather than a compile-time constant. Apply
	# the saved value before the inherited world builds its first streaming window.
	CHUNK_RADIUS = _settings_render_distance
	super._ready()
	if is_instance_valid(_player):
		_player.set_look_sensitivity_scale(_settings_look_sensitivity)
		_player.set_voxel_solid_query(Callable(self, "_player_voxel_is_solid"))
	_build_inventory_crafting_workspace()
	_build_settings_ui()
	_apply_fps_visibility()
	if "--qa-mining-demo" in OS.get_cmdline_user_args() and is_instance_valid(_player):
		var director: TeknikMiningDemoDirector = MiningDemoDirector.new()
		director.name = "MiningDemoDirector"
		add_child(director)
		director.begin(self, _player)


func _player_voxel_is_solid(voxel: Vector3i) -> bool:
	return _current_material(voxel) != VoxelChunk.AIR


func _build_inventory_crafting_workspace() -> void:
	if _inventory_window == null or _inventory_window.get_child_count() == 0:
		return
	var inventory_content := _inventory_window.get_child(0) as VBoxContainer
	if inventory_content == null:
		return
	var inventory_grid := inventory_content.get_node_or_null("InventoryGrid") as GridContainer
	if inventory_grid == null or _recipe_list == null:
		return

	# The previous center-anchor offsets placed the window outside the phone canvas.
	# Use an explicit viewport-space rectangle so Inventory is always visible.
	_inventory_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_inventory_window.grow_horizontal = Control.GROW_DIRECTION_END
	_inventory_window.grow_vertical = Control.GROW_DIRECTION_END
	_inventory_window.position = INVENTORY_WORKSPACE_POSITION
	_inventory_window.size = INVENTORY_WORKSPACE_SIZE
	_inventory_window.custom_minimum_size = INVENTORY_WORKSPACE_SIZE
	_inventory_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_window.z_index = 40

	_inventory_workspace = HBoxContainer.new()
	_inventory_workspace.name = "InventoryWorkspace"
	_inventory_workspace.add_theme_constant_override("separation", 10)
	inventory_content.add_child(_inventory_workspace)
	inventory_content.move_child(_inventory_workspace, 2)

	_inventory_items_panel = PanelContainer.new()
	_inventory_items_panel.name = "InventoryItemsPanel"
	_inventory_items_panel.custom_minimum_size = Vector2(340.0, 390.0)
	_inventory_workspace.add_child(_inventory_items_panel)
	var items_content := VBoxContainer.new()
	items_content.add_theme_constant_override("separation", 6)
	_inventory_items_panel.add_child(items_content)
	var items_title := Label.new()
	items_title.text = "ITEMS & MATERIALS"
	items_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_title.add_theme_font_size_override("font_size", 18)
	items_content.add_child(items_title)
	_inventory_label.reparent(items_content)
	var item_scroll := ScrollContainer.new()
	item_scroll.name = "InventoryItemScroll"
	item_scroll.custom_minimum_size = Vector2(320.0, 315.0)
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_content.add_child(item_scroll)
	inventory_grid.reparent(item_scroll)
	inventory_grid.columns = 1
	for child: Node in inventory_grid.get_children():
		var row := child as Label
		if row != null:
			row.custom_minimum_size = Vector2(300.0, 34.0)

	_inventory_crafting_panel = PanelContainer.new()
	_inventory_crafting_panel.name = "InventoryCraftingPanel"
	_inventory_crafting_panel.custom_minimum_size = Vector2(470.0, 390.0)
	_inventory_workspace.add_child(_inventory_crafting_panel)
	var crafting_content := VBoxContainer.new()
	crafting_content.add_theme_constant_override("separation", 6)
	_inventory_crafting_panel.add_child(crafting_content)
	var crafting_title := Label.new()
	crafting_title.text = "CRAFTING"
	crafting_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crafting_title.add_theme_font_size_override("font_size", 18)
	crafting_content.add_child(crafting_title)

	if _progression_label != null:
		_progression_label.reparent(crafting_content)
	var recipe_scroll := _recipe_list.get_parent() as ScrollContainer
	if recipe_scroll != null:
		recipe_scroll.reparent(crafting_content)
		recipe_scroll.custom_minimum_size = Vector2(440.0, 290.0)
		recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _craft_status != null:
		_craft_status.reparent(crafting_content)
		_craft_status.custom_minimum_size = Vector2(440.0, 34.0)

	if _craft_button != null:
		var old_craft_row := _craft_button.get_parent() as Control
		_craft_button = null
		if old_craft_row != null:
			old_craft_row.queue_free()
	if _engineering_screen != null:
		_engineering_screen.visible = false

	_build_inventory_and_settings_buttons()
	_refresh_recipe_panel()


func _build_inventory_and_settings_buttons() -> void:
	if _inventory_button == null:
		return
	var original_toggle := Callable(self, "_toggle_inventory_window")
	if _inventory_button.pressed.is_connected(original_toggle):
		_inventory_button.pressed.disconnect(original_toggle)
	_inventory_button.text = ""
	_inventory_button.flat = true
	_inventory_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_button.custom_minimum_size = Vector2(284.0, 56.0)
	_inventory_button.size = Vector2(284.0, 56.0)

	var inventory_open_button := Button.new()
	inventory_open_button.name = "InventoryOpenButton"
	inventory_open_button.text = "INVENTORY"
	inventory_open_button.position = Vector2.ZERO
	inventory_open_button.size = Vector2(136.0, 56.0)
	inventory_open_button.custom_minimum_size = inventory_open_button.size
	inventory_open_button.pressed.connect(_toggle_inventory_window)
	_inventory_button.add_child(inventory_open_button)

	_settings_button = Button.new()
	_settings_button.name = "SettingsButton"
	_settings_button.text = "SETTINGS"
	_settings_button.position = Vector2(148.0, 0.0)
	_settings_button.size = Vector2(136.0, 56.0)
	_settings_button.custom_minimum_size = _settings_button.size
	_settings_button.pressed.connect(_toggle_settings_panel)
	_inventory_button.add_child(_settings_button)


func _build_settings_ui() -> void:
	if _gameplay_hud_layer == null:
		return
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_settings_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_settings_panel.grow_vertical = Control.GROW_DIRECTION_END
	_settings_panel.position = SETTINGS_PANEL_POSITION
	_settings_panel.size = SETTINGS_PANEL_SIZE
	_settings_panel.custom_minimum_size = SETTINGS_PANEL_SIZE
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.z_index = 50
	_settings_panel.visible = false
	_gameplay_hud_layer.add_child(_settings_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_settings_panel.add_child(content)
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)

	_render_distance_label = Label.new()
	_render_distance_label.name = "RenderDistanceLabel"
	content.add_child(_render_distance_label)
	_render_distance_slider = TouchSlider.new()
	_render_distance_slider.name = "RenderDistanceSlider"
	_render_distance_slider.min_value = RENDER_DISTANCE_MIN
	_render_distance_slider.max_value = RENDER_DISTANCE_MAX
	_render_distance_slider.step = 1.0
	_render_distance_slider.value = _settings_render_distance
	_render_distance_slider.custom_minimum_size = Vector2(280.0, 48.0)
	_render_distance_slider.value_changed.connect(_on_render_distance_changed)
	content.add_child(_render_distance_slider)
	var render_note := Label.new()
	render_note.text = "LOW 2  •  BALANCED 3  •  HIGH 5\nHigher values need Vivo T3x confirmation."
	render_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	render_note.add_theme_font_size_override("font_size", 13)
	content.add_child(render_note)

	_look_sensitivity_label = Label.new()
	_look_sensitivity_label.name = "LookSensitivityLabel"
	content.add_child(_look_sensitivity_label)
	_look_sensitivity_slider = TouchSlider.new()
	_look_sensitivity_slider.name = "LookSensitivitySlider"
	_look_sensitivity_slider.min_value = LOOK_SENSITIVITY_MIN
	_look_sensitivity_slider.max_value = LOOK_SENSITIVITY_MAX
	_look_sensitivity_slider.step = 0.1
	_look_sensitivity_slider.value = _settings_look_sensitivity
	_look_sensitivity_slider.custom_minimum_size = Vector2(280.0, 48.0)
	_look_sensitivity_slider.value_changed.connect(_on_look_sensitivity_changed)
	content.add_child(_look_sensitivity_slider)

	_fps_toggle = CheckButton.new()
	_fps_toggle.name = "ShowFpsToggle"
	_fps_toggle.text = "Show FPS counter"
	_fps_toggle.button_pressed = _settings_show_fps
	_fps_toggle.toggled.connect(_on_fps_toggled)
	content.add_child(_fps_toggle)

	var close_button := Button.new()
	close_button.name = "CloseSettings"
	close_button.text = "CLOSE SETTINGS"
	close_button.custom_minimum_size = Vector2(180.0, 48.0)
	close_button.pressed.connect(_toggle_settings_panel)
	content.add_child(close_button)
	_refresh_render_distance_label()
	_refresh_look_sensitivity_label()


func _refresh_recipe_panel() -> void:
	super._refresh_recipe_panel()
	if _recipe_list == null:
		return
	for child: Node in _recipe_list.get_children():
		var button := child as Button
		if button != null:
			button.custom_minimum_size = Vector2(420.0, 44.0)


func _open_engineering_station() -> void:
	if _inventory_window != null:
		_inventory_window.visible = true
	if _settings_panel != null:
		_settings_panel.visible = false
	if _engineering_screen != null:
		_engineering_screen.visible = false
	_set_modal_controls(true)
	_refresh_recipe_panel()


func _close_engineering_station() -> void:
	if _inventory_window != null:
		_inventory_window.visible = false
	if _settings_panel != null:
		_settings_panel.visible = false
	_set_modal_controls(false)


func _toggle_inventory_window() -> void:
	if _inventory_window == null:
		return
	var opening: bool = not _inventory_window.visible
	_inventory_window.visible = opening
	if _settings_panel != null:
		_settings_panel.visible = false
	_set_modal_controls(opening)


func _toggle_settings_panel() -> void:
	if _settings_panel == null:
		return
	var opening: bool = not _settings_panel.visible
	if opening and _inventory_window != null:
		_inventory_window.visible = true
	_settings_panel.visible = opening
	_set_modal_controls(_inventory_window != null and _inventory_window.visible)


func _set_modal_controls(open: bool) -> void:
	if is_instance_valid(_player):
		_player.set_modal_ui_open(open)


func _on_render_distance_changed(value: float) -> void:
	var radius: int = clampi(roundi(value), RENDER_DISTANCE_MIN, RENDER_DISTANCE_MAX)
	_settings_render_distance = radius
	_refresh_render_distance_label()
	if radius != CHUNK_RADIUS:
		_apply_render_distance_runtime(radius)
	_save_game_settings()


func _apply_render_distance_runtime(radius: int) -> void:
	var next_radius: int = clampi(radius, RENDER_DISTANCE_MIN, RENDER_DISTANCE_MAX)
	if next_radius == CHUNK_RADIUS:
		return
	var current_center: Vector3i = _world_center

	# A worker started with the old radius can otherwise look current because its
	# center did not change. Poison its target so the existing stale-result checks
	# discard it when the thread finishes.
	if _ecology_state == ECOLOGY_GENERATING:
		_feature_refresh_target = INVALID_SETTINGS_CENTER
	elif _ecology_state == ECOLOGY_COMMITTING:
		_cancel_ecology_commit("render_distance_changed")
	if _distant_state == DISTANT_GENERATING:
		_distant_target = INVALID_SETTINGS_CENTER
	elif _distant_state == DISTANT_READY:
		_distant_plan.clear()
		_distant_state = DISTANT_IDLE

	CHUNK_RADIUS = next_radius
	_world_center = INVALID_SETTINGS_CENTER
	_refresh_world_window(current_center, current_center)
	_last_center_change_ms = Time.get_ticks_msec()
	_feature_refresh_pending = true
	_distant_refresh_pending = true
	_runtime_log.event("info", "settings", "render_distance_changed", {
		"radius": CHUNK_RADIUS,
		"center": str(current_center),
		"near_window_reconciled": true,
		"ecology_refresh_requested": true,
		"lod_refresh_requested": true,
	})


func _on_look_sensitivity_changed(value: float) -> void:
	_settings_look_sensitivity = clampf(value, LOOK_SENSITIVITY_MIN, LOOK_SENSITIVITY_MAX)
	if is_instance_valid(_player):
		_player.set_look_sensitivity_scale(_settings_look_sensitivity)
	_refresh_look_sensitivity_label()
	_save_game_settings()


func _refresh_render_distance_label() -> void:
	if _render_distance_label != null:
		_render_distance_label.text = "Render distance: %d chunks" % _settings_render_distance


func _refresh_look_sensitivity_label() -> void:
	if _look_sensitivity_label != null:
		_look_sensitivity_label.text = "Look sensitivity: %.1fx" % _settings_look_sensitivity


func _on_fps_toggled(visible_value: bool) -> void:
	_settings_show_fps = visible_value
	_apply_fps_visibility()
	_save_game_settings()


func _apply_fps_visibility() -> void:
	var counter := get_node_or_null("/root/FPSCounter") as CanvasLayer
	if counter != null:
		counter.visible = _settings_show_fps


func _load_game_settings() -> void:
	_settings_render_distance = DEFAULT_RENDER_DISTANCE
	_settings_look_sensitivity = DEFAULT_LOOK_SENSITIVITY
	_settings_show_fps = true
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema", -1)) != SETTINGS_SCHEMA:
		return
	_settings_render_distance = clampi(
		int(parsed.get("render_distance", DEFAULT_RENDER_DISTANCE)),
		RENDER_DISTANCE_MIN,
		RENDER_DISTANCE_MAX
	)
	_settings_look_sensitivity = clampf(
		float(parsed.get("look_sensitivity", DEFAULT_LOOK_SENSITIVITY)),
		LOOK_SENSITIVITY_MIN,
		LOOK_SENSITIVITY_MAX
	)
	_settings_show_fps = bool(parsed.get("show_fps", true))


func _save_game_settings() -> void:
	var payload := {
		"schema": SETTINGS_SCHEMA,
		"render_distance": _settings_render_distance,
		"look_sensitivity": _settings_look_sensitivity,
		"show_fps": _settings_show_fps,
	}
	var temporary_path := SETTINGS_PATH + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file = null
	var target := ProjectSettings.globalize_path(SETTINGS_PATH)
	var temporary := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(target)
	DirAccess.rename_absolute(temporary, target)


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	if is_instance_valid(_player):
		_player.set_scripted_mode(true)
		_player.set_scripted_move(Vector2.ZERO)
		_player.velocity = Vector3.ZERO
		_player.set_physics_process(false)
	if _inventory_window != null:
		_inventory_window.visible = true
	if _settings_panel != null:
		_settings_panel.visible = true
	if _engineering_screen != null:
		_engineering_screen.visible = false
	_set_modal_controls(true)
	_refresh_recipe_panel()
	var recipe_controls: int = _recipe_list.get_child_count() if _recipe_list != null else 0
	var evidence_valid: bool = (
		_inventory_workspace != null
		and _inventory_items_panel != null
		and _inventory_crafting_panel != null
		and _inventory_items_panel.get_parent() == _inventory_workspace
		and _inventory_crafting_panel.get_parent() == _inventory_workspace
		and _render_distance_slider != null
		and int(_render_distance_slider.min_value) == RENDER_DISTANCE_MIN
		and int(_render_distance_slider.max_value) == RENDER_DISTANCE_MAX
		and int(_render_distance_slider.value) == CHUNK_RADIUS
		and _look_sensitivity_slider != null
		and is_instance_valid(_player)
		and is_equal_approx(_player.look_sensitivity_scale(), _settings_look_sensitivity)
		and _inventory_window.get_global_rect().position.x >= 0.0
		and _settings_panel.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x
		and recipe_controls > 0
	)
	if not evidence_valid:
		push_error("QA_SETTINGS_CRAFTING inventory/settings evidence setup failed")
		get_tree().quit(1)
		return
	print(
		"QA_SETTINGS_CRAFTING_PASS render_distance=", CHUNK_RADIUS,
		" range=", RENDER_DISTANCE_MIN, "-", RENDER_DISTANCE_MAX,
		" sensitivity=", _settings_look_sensitivity,
		" recipes=", recipe_controls,
		" crafting_separate=", _inventory_items_panel != _inventory_crafting_panel,
		" inventory_rect=", _inventory_window.get_global_rect(),
		" settings_rect=", _settings_panel.get_global_rect(),
		" settings_visible=", _settings_panel.visible,
		" fps_visible=", _settings_show_fps
	)
	_runtime_log.event("info", "qa", "kinetic_evidence_player_frozen", {
		"position": str(_player.global_position) if is_instance_valid(_player) else "unavailable",
		"machine_instances": _machine_root.get_child_count() if _machine_root != null else 0,
		"interaction_enabled": true,
		"animated_visuals": _rotating_visuals.size(),
	})


func qa_set_render_distance(radius: int) -> void:
	_settings_render_distance = clampi(radius, RENDER_DISTANCE_MIN, RENDER_DISTANCE_MAX)
	if _render_distance_slider != null:
		_render_distance_slider.set_value_no_signal(_settings_render_distance)
	_apply_render_distance_runtime(_settings_render_distance)
	_refresh_render_distance_label()


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["render_distance"] = CHUNK_RADIUS
	snapshot["look_sensitivity"] = _settings_look_sensitivity
	snapshot["settings_panel_visible"] = _settings_panel != null and _settings_panel.visible
	snapshot["inventory_workspace_visible"] = _inventory_window != null and _inventory_window.visible
	snapshot["crafting_panel_present"] = _inventory_crafting_panel != null
	snapshot["show_fps"] = _settings_show_fps
	return snapshot
