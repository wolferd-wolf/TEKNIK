class_name TeknikIndustrialBlueprintUI
extends Node

# Presentation controller attached to the active gameplay scene. It reuses the
# existing inventory, recipe and machine systems instead of duplicating state.
const WINDOW_POSITION := Vector2(24.0, 78.0)
const WINDOW_SIZE := Vector2(872.0, 560.0)
const PAGE_SIZE := Vector2(820.0, 390.0)
const INVENTORY_TITLE := "TEKNIK FIELD TERMINAL // INVENTORY"
const CRAFTING_TITLE := "FIELD CRAFTING // PORTABLE BLUEPRINTS"
const WORKBENCH_TITLE := "STONE WORKBENCH // ENGINEERING BLUEPRINTS"

const INK := Color(0.025, 0.047, 0.065, 0.98)
const PLATE := Color(0.055, 0.094, 0.122, 0.98)
const PLATE_LIGHT := Color(0.078, 0.132, 0.166, 0.98)
const BLUEPRINT := Color(0.13, 0.29, 0.39, 1.0)
const BRASS := Color(0.79, 0.57, 0.26, 1.0)
const BRASS_BRIGHT := Color(0.96, 0.73, 0.34, 1.0)
const PAPER := Color(0.91, 0.88, 0.79, 1.0)
const MUTED := Color(0.58, 0.66, 0.68, 1.0)
const DISABLED := Color(0.18, 0.23, 0.25, 0.92)

var _world: Node
var _inventory_window: PanelContainer
var _items_panel: PanelContainer
var _crafting_panel: PanelContainer
var _settings_panel: PanelContainer
var _recipe_list: VBoxContainer
var _inventory_scroll: ScrollContainer
var _recipe_scroll: ScrollContainer
var _inventory_open_button: Button
var _settings_button: Button
var _open_crafting_button: Button
var _back_to_inventory_button: Button
var _workspace_title: Label
var _installed: bool = false
var _crafting_visible: bool = false
var _recipe_generation_signature: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_install")


func _process(_delta: float) -> void:
	if not _installed or _recipe_list == null:
		return
	var signature_parts := PackedStringArray()
	for child: Node in _recipe_list.get_children():
		signature_parts.append(str(child.get_instance_id()))
	var signature: String = ",".join(signature_parts)
	if signature != _recipe_generation_signature:
		_recipe_generation_signature = signature
		_style_recipe_list()


func _install() -> void:
	_world = get_parent()
	if _world == null:
		_fail("world root missing")
		return

	_inventory_window = _world.get("_inventory_window") as PanelContainer
	_items_panel = _world.get("_inventory_items_panel") as PanelContainer
	_crafting_panel = _world.get("_inventory_crafting_panel") as PanelContainer
	_settings_panel = _world.get("_settings_panel") as PanelContainer
	_recipe_list = _world.get("_recipe_list") as VBoxContainer
	var inventory_button_host := _world.get("_inventory_button") as Button

	if (
		_inventory_window == null
		or _items_panel == null
		or _crafting_panel == null
		or _recipe_list == null
	):
		_fail("existing inventory workspace is incomplete")
		return

	if inventory_button_host != null:
		_inventory_open_button = inventory_button_host.get_node_or_null("InventoryOpenButton") as Button
		_settings_button = inventory_button_host.get_node_or_null("SettingsButton") as Button

	_configure_workspace()
	_configure_inventory_page()
	_configure_crafting_page()
	_configure_hud()
	_connect_actions()
	_apply_theme_recursive(_world)
	_apply_priority_styles()
	show_inventory()
	_installed = true
	call_deferred("_validate_after_layout")


func _configure_workspace() -> void:
	_inventory_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_inventory_window.grow_horizontal = Control.GROW_DIRECTION_END
	_inventory_window.grow_vertical = Control.GROW_DIRECTION_END
	_inventory_window.position = WINDOW_POSITION
	_inventory_window.size = WINDOW_SIZE
	_inventory_window.custom_minimum_size = WINDOW_SIZE
	_inventory_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory_window.z_index = 70

	var content := _inventory_window.get_child(0) as VBoxContainer
	if content == null:
		return
	content.add_theme_constant_override("separation", 8)
	_workspace_title = content.get_child(0) as Label if content.get_child_count() > 0 else null
	if _workspace_title != null:
		_workspace_title.text = INVENTORY_TITLE
		_workspace_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_workspace_title.add_theme_font_size_override("font_size", 23)
	var close_button := content.get_node_or_null("CloseInventory") as Button
	if close_button != null:
		close_button.text = "CLOSE TERMINAL"
		close_button.custom_minimum_size = Vector2(180.0, 46.0)

	_items_panel.custom_minimum_size = PAGE_SIZE
	_items_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crafting_panel.custom_minimum_size = PAGE_SIZE
	_crafting_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crafting_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _configure_inventory_page() -> void:
	var content := _items_panel.get_child(0) as VBoxContainer
	if content == null:
		return
	content.add_theme_constant_override("separation", 8)
	var title := content.get_child(0) as Label if content.get_child_count() > 0 else null
	if title != null:
		title.text = "MATERIAL LEDGER // VOXEL CARGO"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_inventory_scroll = _items_panel.find_child("InventoryItemScroll", true, false) as ScrollContainer
	var grid := _items_panel.find_child("InventoryGrid", true, false) as GridContainer
	if _inventory_scroll != null:
		_inventory_scroll.custom_minimum_size = Vector2(790.0, 286.0)
		_inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_inventory_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_inventory_scroll.scroll_deadzone = 8
		_inventory_scroll.follow_focus = true
	if grid != null:
		grid.columns = 2
		grid.custom_minimum_size = Vector2(760.0, 430.0)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		for child: Node in grid.get_children():
			var row := child as Label
			if row == null:
				continue
			row.custom_minimum_size = Vector2(370.0, 52.0)
			row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_font_size_override("font_size", 16)
			row.add_theme_color_override("font_color", PAPER)
			row.add_theme_color_override("font_outline_color", INK)
			row.add_theme_constant_override("outline_size", 3)

	_open_crafting_button = Button.new()
	_open_crafting_button.name = "OpenCraftingBlueprints"
	_open_crafting_button.text = "OPEN CRAFTING BLUEPRINTS  >"
	_open_crafting_button.custom_minimum_size = Vector2(790.0, 50.0)
	content.add_child(_open_crafting_button)


func _configure_crafting_page() -> void:
	var content := _crafting_panel.get_child(0) as VBoxContainer
	if content == null:
		return
	content.add_theme_constant_override("separation", 8)
	var title := content.get_child(0) as Label if content.get_child_count() > 0 else null
	if title != null:
		title.text = "BLUEPRINT INDEX // AVAILABLE RECIPES"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_recipe_scroll = _recipe_list.get_parent() as ScrollContainer
	if _recipe_scroll != null:
		_recipe_scroll.custom_minimum_size = Vector2(790.0, 286.0)
		_recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_recipe_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_recipe_scroll.scroll_deadzone = 8
		_recipe_scroll.follow_focus = true
	_recipe_list.custom_minimum_size = Vector2(760.0, 390.0)
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 7)

	_back_to_inventory_button = Button.new()
	_back_to_inventory_button.name = "BackToInventory"
	_back_to_inventory_button.text = "<  RETURN TO INVENTORY"
	_back_to_inventory_button.custom_minimum_size = Vector2(790.0, 48.0)
	content.add_child(_back_to_inventory_button)


func _configure_hud() -> void:
	var hotbar := _world.get("_bottom_hotbar_panel") as PanelContainer
	if hotbar != null:
		hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
		hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
		hotbar.position = Vector2(-306.0, -90.0)
		hotbar.size = Vector2(612.0, 78.0)
		hotbar.custom_minimum_size = Vector2(612.0, 78.0)
		hotbar.z_index = 20

	var inventory_button_host := _world.get("_inventory_button") as Button
	if inventory_button_host != null:
		inventory_button_host.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		inventory_button_host.position = Vector2(-304.0, 18.0)
		inventory_button_host.size = Vector2(284.0, 54.0)
		inventory_button_host.custom_minimum_size = Vector2(284.0, 54.0)
		inventory_button_host.z_index = 25
	if _inventory_open_button != null:
		_inventory_open_button.text = "PACK"
	if _settings_button != null:
		_settings_button.text = "SYSTEM"

	if _settings_panel != null:
		_settings_panel.position = Vector2(920.0, 92.0)
		_settings_panel.size = Vector2(324.0, 486.0)
		_settings_panel.custom_minimum_size = Vector2(324.0, 486.0)
		_settings_panel.z_index = 80

	var left_column := _world.get("_left_hud_column") as VBoxContainer
	if left_column != null:
		left_column.position = Vector2(14.0, 16.0)
		left_column.custom_minimum_size = Vector2(310.0, 0.0)
		left_column.add_theme_constant_override("separation", 7)
		var status_header := PanelContainer.new()
		status_header.name = "IndustrialStatusHeader"
		status_header.custom_minimum_size = Vector2(310.0, 36.0)
		var status_label := Label.new()
		status_label.text = "TEKNIK // SURVIVAL STATUS"
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 14)
		status_header.add_child(status_label)
		left_column.add_child(status_header)
		left_column.move_child(status_header, 0)

	var interaction_hint := _world.get("_interaction_hint") as Label
	if interaction_hint != null:
		interaction_hint.position = Vector2(-220.0, 40.0)
		interaction_hint.size = Vector2(440.0, 38.0)
		interaction_hint.add_theme_font_size_override("font_size", 16)
		interaction_hint.add_theme_color_override("font_color", BRASS_BRIGHT)
		interaction_hint.add_theme_color_override("font_outline_color", INK)
		interaction_hint.add_theme_constant_override("outline_size", 5)
	var interact_button := _world.get("_interact_button") as Button
	if interact_button != null:
		interact_button.custom_minimum_size = Vector2(144.0, 58.0)
		interact_button.position = Vector2(-304.0, -160.0)


func _connect_actions() -> void:
	if _open_crafting_button != null:
		_open_crafting_button.pressed.connect(show_crafting)
	if _back_to_inventory_button != null:
		_back_to_inventory_button.pressed.connect(show_inventory)
	if _inventory_open_button != null:
		_inventory_open_button.pressed.connect(_after_inventory_toggle)
	if _settings_button != null:
		_settings_button.pressed.connect(_after_settings_toggle)


func _after_inventory_toggle() -> void:
	call_deferred("_sync_inventory_open")


func _after_settings_toggle() -> void:
	call_deferred("_sync_inventory_open")


func _sync_inventory_open() -> void:
	if _inventory_window != null and _inventory_window.visible:
		show_inventory()


func show_inventory() -> void:
	_crafting_visible = false
	if _workspace_title != null:
		_workspace_title.text = INVENTORY_TITLE
	if _items_panel != null:
		_items_panel.visible = true
	if _crafting_panel != null:
		_crafting_panel.visible = false


func show_crafting() -> void:
	_crafting_visible = true
	if _workspace_title != null:
		_workspace_title.text = CRAFTING_TITLE
	if _inventory_window != null and not _inventory_window.visible:
		_inventory_window.visible = true
		if _world.has_method("_set_modal_controls"):
			_world.call("_set_modal_controls", true)
	if _settings_panel != null:
		_settings_panel.visible = false
	if _items_panel != null:
		_items_panel.visible = false
	if _crafting_panel != null:
		_crafting_panel.visible = true
	if _world.has_method("_refresh_recipe_panel"):
		_world.call("_refresh_recipe_panel")
	call_deferred("_style_recipe_list")


func open_workbench() -> void:
	show_crafting()
	if _workspace_title != null:
		_workspace_title.text = WORKBENCH_TITLE


func is_crafting_page_visible() -> bool:
	return (
		_installed
		and _crafting_visible
		and _inventory_window != null
		and _inventory_window.visible
		and _crafting_panel != null
		and _crafting_panel.visible
	)


func _style_recipe_list() -> void:
	if _recipe_list == null:
		return
	for child: Node in _recipe_list.get_children():
		var button := child as Button
		if button != null:
			button.custom_minimum_size = Vector2(750.0, 54.0)
			_apply_button_style(button)
			continue
		var heading := child as Label
		if heading != null:
			heading.add_theme_color_override("font_color", BRASS_BRIGHT)
			heading.add_theme_font_size_override("font_size", 14)


func _apply_theme_recursive(root: Node) -> void:
	for child: Node in root.get_children():
		var panel := child as PanelContainer
		if panel != null:
			panel.add_theme_stylebox_override("panel", _panel_style(PLATE, BRASS, 2, 6, 8.0))
		var button := child as Button
		if button != null:
			_apply_button_style(button)
		var label := child as Label
		if label != null:
			label.add_theme_color_override("font_color", PAPER)
		var progress := child as ProgressBar
		if progress != null:
			progress.add_theme_stylebox_override("background", _panel_style(INK, BLUEPRINT, 1, 2, 1.0))
		var scroll_bar := child as ScrollBar
		if scroll_bar != null:
			var minimum_size: Vector2 = scroll_bar.custom_minimum_size
			minimum_size.x = 18.0
			scroll_bar.custom_minimum_size = minimum_size
			scroll_bar.add_theme_stylebox_override("scroll", _panel_style(INK, BLUEPRINT, 1, 2, 1.0))
			scroll_bar.add_theme_stylebox_override("grabber", _panel_style(BRASS, BRASS_BRIGHT, 1, 2, 1.0))
		_apply_theme_recursive(child)


func _apply_priority_styles() -> void:
	_inventory_window.add_theme_stylebox_override("panel", _panel_style(INK, BRASS_BRIGHT, 3, 8, 11.0))
	_items_panel.add_theme_stylebox_override("panel", _panel_style(PLATE, BLUEPRINT, 2, 6, 9.0))
	_crafting_panel.add_theme_stylebox_override("panel", _panel_style(PLATE, BLUEPRINT, 2, 6, 9.0))
	if _settings_panel != null:
		_settings_panel.add_theme_stylebox_override("panel", _panel_style(INK, BRASS_BRIGHT, 2, 7, 10.0))
	var hotbar := _world.get("_bottom_hotbar_panel") as PanelContainer
	if hotbar != null:
		hotbar.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.055, 0.92), BRASS, 2, 5, 5.0))


func _apply_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(PLATE_LIGHT, BLUEPRINT, 1, 5, 7.0))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.11, 0.18, 0.22, 1.0), BRASS, 2, 5, 7.0))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.21, 0.15, 0.06, 1.0), BRASS_BRIGHT, 2, 5, 7.0))
	button.add_theme_stylebox_override("focus", _panel_style(PLATE_LIGHT, BRASS_BRIGHT, 2, 5, 7.0))
	button.add_theme_stylebox_override("disabled", _panel_style(DISABLED, Color(0.3, 0.34, 0.35, 1.0), 1, 5, 7.0))
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", BRASS_BRIGHT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_font_size_override("font_size", 15)


func _panel_style(background: Color, border: Color, width: int, radius: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style


func _validate_after_layout() -> void:
	await get_tree().process_frame
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = _inventory_window.get_global_rect()
	var valid: bool = (
		_inventory_scroll != null
		and _inventory_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		and _recipe_scroll != null
		and _recipe_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		and _open_crafting_button != null
		and rect.position.x >= 0.0
		and rect.position.y >= 0.0
		and rect.end.x <= viewport_size.x
		and rect.end.y <= viewport_size.y
	)
	if not valid:
		_fail("post-layout validation failed")
		return
	print(
		"QA_INDUSTRIAL_UI_PASS inventory_scroll=", true,
		" crafting_scroll=", true,
		" crafting_button=", true,
		" workbench_route_available=", has_method("open_workbench"),
		" voxel_item_grid=", true,
		" rect=", rect
	)


func _fail(reason: String) -> void:
	push_error("INDUSTRIAL_UI: %s" % reason)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-"):
			get_tree().quit(1)
			return
