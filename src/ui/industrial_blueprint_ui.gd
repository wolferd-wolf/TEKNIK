class_name TeknikIndustrialBlueprintUI
extends Node

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const FurnaceRecipeBook = preload("res://src/survival/furnace_recipe_book.gd")

const WINDOW_POSITION := Vector2(24.0, 78.0)
const INVENTORY_SIZE := Vector2(840.0, 520.0)
const STATION_SIZE := Vector2(780.0, 520.0)
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
var _inventory_items_panel: PanelContainer
var _inventory_crafting_panel: PanelContainer
var _crafting_table_screen: PanelContainer
var _table_recipe_list: VBoxContainer
var _settings_panel: PanelContainer
var _portable_screen: PanelContainer
var _portable_recipe_list: VBoxContainer
var _portable_status: Label
var _furnace_screen: PanelContainer
var _furnace_recipe_list: VBoxContainer
var _furnace_status: Label
var _furnace_fuel_label: Label
var _craft_open_button: Button
var _inventory_open_button: Button
var _settings_button: Button
var _installed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_install")


func _install() -> void:
	await get_tree().process_frame
	_world = get_parent()
	if _world == null:
		_fail("world root missing")
		return
	_inventory_window = _world.get("_inventory_window") as PanelContainer
	_inventory_items_panel = _world.get("_inventory_items_panel") as PanelContainer
	_inventory_crafting_panel = _world.get("_inventory_crafting_panel") as PanelContainer
	_crafting_table_screen = _world.get("_engineering_screen") as PanelContainer
	_table_recipe_list = _world.get("_recipe_list") as VBoxContainer
	_settings_panel = _world.get("_settings_panel") as PanelContainer
	if _inventory_window == null or _inventory_items_panel == null or _crafting_table_screen == null or _table_recipe_list == null:
		_fail("required inventory or station controls missing")
		return
	_restore_separate_inventory_and_table()
	_build_portable_crafting_screen()
	_build_furnace_screen()
	_configure_hud_buttons()
	_rewire_close_buttons()
	_apply_all_ui_theme()
	close_all()
	_installed = true
	refresh_all()
	call_deferred("_validate_separate_interfaces")


func _restore_separate_inventory_and_table() -> void:
	_inventory_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_inventory_window.position = WINDOW_POSITION
	_inventory_window.size = INVENTORY_SIZE
	_inventory_window.custom_minimum_size = INVENTORY_SIZE
	_inventory_window.z_index = 70
	_inventory_window.mouse_filter = Control.MOUSE_FILTER_STOP
	if _inventory_crafting_panel != null:
		_inventory_crafting_panel.visible = false
		_inventory_crafting_panel.custom_minimum_size = Vector2.ZERO
	_inventory_items_panel.custom_minimum_size = Vector2(800.0, 404.0)
	var item_scroll := _inventory_items_panel.find_child("InventoryItemScroll", true, false) as ScrollContainer
	if item_scroll != null:
		item_scroll.custom_minimum_size = Vector2(772.0, 330.0)
		item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		item_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var inventory_grid := _inventory_items_panel.find_child("InventoryGrid", true, false) as GridContainer
	if inventory_grid != null:
		inventory_grid.columns = 2
		inventory_grid.custom_minimum_size = Vector2(744.0, 700.0)
		inventory_grid.add_theme_constant_override("h_separation", 10)
		inventory_grid.add_theme_constant_override("v_separation", 6)
		for child: Node in inventory_grid.get_children():
			var row := child as Label
			if row != null:
				row.custom_minimum_size = Vector2(360.0, 42.0)

	_crafting_table_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_crafting_table_screen.position = WINDOW_POSITION
	_crafting_table_screen.size = STATION_SIZE
	_crafting_table_screen.custom_minimum_size = STATION_SIZE
	_crafting_table_screen.z_index = 72
	var table_content := _crafting_table_screen.get_child(0) as VBoxContainer
	if table_content == null:
		return
	var progression_label := _world.get("_progression_label") as Label
	var craft_status := _world.get("_craft_status") as Label
	var recipe_scroll := _table_recipe_list.get_parent() as ScrollContainer
	if progression_label != null and progression_label.get_parent() != table_content:
		progression_label.reparent(table_content)
	if recipe_scroll != null and recipe_scroll.get_parent() != table_content:
		recipe_scroll.reparent(table_content)
	if craft_status != null and craft_status.get_parent() != table_content:
		craft_status.reparent(table_content)
	if progression_label != null:
		table_content.move_child(progression_label, mini(1, table_content.get_child_count() - 1))
	if recipe_scroll != null:
		recipe_scroll.custom_minimum_size = Vector2(744.0, 372.0)
		recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		recipe_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		table_content.move_child(recipe_scroll, mini(2, table_content.get_child_count() - 1))
	if craft_status != null:
		craft_status.custom_minimum_size = Vector2(744.0, 30.0)
		table_content.move_child(craft_status, mini(3, table_content.get_child_count() - 1))


func _build_portable_crafting_screen() -> void:
	_portable_screen = _make_station_window("PortableCraftingScreen", "PORTABLE CRAFTING", "Recipes that can be made without placing a station.")
	var content := _portable_screen.get_child(0) as VBoxContainer
	var scroll := ScrollContainer.new()
	scroll.name = "PortableCraftingScroll"
	scroll.custom_minimum_size = Vector2(744.0, 362.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(scroll)
	_portable_recipe_list = VBoxContainer.new()
	_portable_recipe_list.name = "PortableCraftingRecipeList"
	_portable_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portable_recipe_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_portable_recipe_list)
	_portable_status = Label.new()
	_portable_status.name = "PortableCraftingStatus"
	_portable_status.custom_minimum_size = Vector2(744.0, 30.0)
	content.add_child(_portable_status)
	content.add_child(_close_button("ClosePortableCrafting"))


func _build_furnace_screen() -> void:
	_furnace_screen = _make_station_window("FurnaceScreen", "FURNACE", "Select a smelting or heated-alloying recipe. Each operation consumes 1 Wood fuel.")
	var content := _furnace_screen.get_child(0) as VBoxContainer
	_furnace_fuel_label = Label.new()
	_furnace_fuel_label.name = "FurnaceFuelSummary"
	_furnace_fuel_label.add_theme_font_size_override("font_size", 16)
	content.add_child(_furnace_fuel_label)
	var scroll := ScrollContainer.new()
	scroll.name = "FurnaceRecipeScroll"
	scroll.custom_minimum_size = Vector2(744.0, 336.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(scroll)
	_furnace_recipe_list = VBoxContainer.new()
	_furnace_recipe_list.name = "FurnaceRecipeList"
	_furnace_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_furnace_recipe_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_furnace_recipe_list)
	_furnace_status = Label.new()
	_furnace_status.name = "FurnaceStatus"
	_furnace_status.custom_minimum_size = Vector2(744.0, 30.0)
	content.add_child(_furnace_status)
	content.add_child(_close_button("CloseFurnace"))


func _make_station_window(node_name: String, title_text: String, subtitle_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = WINDOW_POSITION
	panel.size = STATION_SIZE
	panel.custom_minimum_size = STATION_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 74
	panel.visible = false
	_world.get("_gameplay_hud_layer").add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	content.add_child(subtitle)
	return panel


func _close_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = "CLOSE"
	button.custom_minimum_size = Vector2(180.0, 46.0)
	button.pressed.connect(close_all)
	return button


func _configure_hud_buttons() -> void:
	var host := _world.get("_inventory_button") as Button
	if host == null:
		return
	host.custom_minimum_size = Vector2(432.0, 56.0)
	host.size = host.custom_minimum_size
	_inventory_open_button = host.get_node_or_null("InventoryOpenButton") as Button
	_settings_button = host.get_node_or_null("SettingsButton") as Button
	if _inventory_open_button != null:
		var old_toggle := Callable(_world, "_toggle_inventory_window")
		if _inventory_open_button.pressed.is_connected(old_toggle):
			_inventory_open_button.pressed.disconnect(old_toggle)
		_inventory_open_button.text = "PACK"
		_inventory_open_button.position = Vector2.ZERO
		_inventory_open_button.size = Vector2(136.0, 56.0)
		_inventory_open_button.pressed.connect(show_inventory)
	_craft_open_button = Button.new()
	_craft_open_button.name = "PortableCraftingButton"
	_craft_open_button.text = "CRAFT"
	_craft_open_button.position = Vector2(148.0, 0.0)
	_craft_open_button.size = Vector2(136.0, 56.0)
	_craft_open_button.custom_minimum_size = _craft_open_button.size
	_craft_open_button.pressed.connect(show_crafting)
	host.add_child(_craft_open_button)
	if _settings_button != null:
		_settings_button.text = "SYSTEM"
		_settings_button.position = Vector2(296.0, 0.0)
		_settings_button.size = Vector2(136.0, 56.0)


func _rewire_close_buttons() -> void:
	var close_inventory := _inventory_window.find_child("CloseInventory", true, false) as Button
	if close_inventory != null:
		var old_toggle := Callable(_world, "_toggle_inventory_window")
		if close_inventory.pressed.is_connected(old_toggle):
			close_inventory.pressed.disconnect(old_toggle)
		close_inventory.text = "CLOSE INVENTORY"
		close_inventory.pressed.connect(close_all)


func show_inventory() -> void:
	_hide_station_windows()
	if _settings_panel != null:
		_settings_panel.visible = false
	_inventory_window.visible = true
	if _inventory_crafting_panel != null:
		_inventory_crafting_panel.visible = false
	_set_modal(true)
	refresh_all()


func show_crafting() -> void:
	_hide_station_windows()
	_portable_screen.visible = true
	_set_modal(true)
	refresh_all()


func open_workbench() -> void:
	_hide_station_windows()
	_crafting_table_screen.visible = true
	_set_modal(true)
	if _world.has_method("_refresh_recipe_panel"):
		_world.call("_refresh_recipe_panel")
	refresh_all()


func open_furnace() -> void:
	_hide_station_windows()
	_furnace_screen.visible = true
	_set_modal(true)
	refresh_all()


func close_all() -> void:
	_hide_station_windows()
	_set_modal(_settings_panel != null and _settings_panel.visible)


func _hide_station_windows() -> void:
	if _inventory_window != null:
		_inventory_window.visible = false
	if _portable_screen != null:
		_portable_screen.visible = false
	if _crafting_table_screen != null:
		_crafting_table_screen.visible = false
	if _furnace_screen != null:
		_furnace_screen.visible = false


func _set_modal(open: bool) -> void:
	if _world.has_method("_set_modal_controls"):
		_world.call("_set_modal_controls", open)


func refresh_all() -> void:
	if not _installed:
		return
	if _world.has_method("_refresh_recipe_panel"):
		_world.call("_refresh_recipe_panel")
	_rebuild_station_recipe_list(_portable_recipe_list, RecipeBook.STATION_HAND)
	_rebuild_furnace_recipe_list()
	_style_recipe_list(_table_recipe_list)
	_style_recipe_list(_portable_recipe_list)
	_style_recipe_list(_furnace_recipe_list)
	var inventory: Variant = _world.get("_inventory")
	if _furnace_fuel_label != null and inventory != null:
		_furnace_fuel_label.text = "FUEL SLOT // Wood x%d // Cost: 1 per operation" % inventory.count(ItemRegistry.ITEM_WOOD)


func _rebuild_station_recipe_list(list: VBoxContainer, station: StringName) -> void:
	if list == null:
		return
	for child: Node in list.get_children():
		child.queue_free()
	var inventory: Variant = _world.get("_inventory")
	var progression: Variant = _world.get("_progression")
	if inventory == null or progression == null:
		return
	var current_category: String = ""
	for recipe_id: StringName in RecipeBook.available_recipes_for_station(progression, station):
		var definition: Dictionary = RecipeBook.recipe(recipe_id)
		var category: String = str(definition.category)
		if category != current_category:
			current_category = category
			var heading := Label.new()
			heading.text = category.to_upper()
			list.add_child(heading)
		var button := Button.new()
		button.name = "%s_%s" % [str(station), str(recipe_id)]
		button.text = _recipe_button_text(definition)
		button.custom_minimum_size = Vector2(720.0, 58.0)
		button.disabled = not RecipeBook.can_craft_at_station(inventory, recipe_id, progression, station)
		button.pressed.connect(func() -> void: _craft_from_station(recipe_id, station))
		list.add_child(button)


func _rebuild_furnace_recipe_list() -> void:
	if _furnace_recipe_list == null:
		return
	for child: Node in _furnace_recipe_list.get_children():
		child.queue_free()
	var inventory: Variant = _world.get("_inventory")
	var progression: Variant = _world.get("_progression")
	if inventory == null or progression == null:
		return
	var current_category: String = ""
	for recipe_id: StringName in RecipeBook.available_recipes_for_station(progression, RecipeBook.STATION_FURNACE):
		var definition: Dictionary = RecipeBook.recipe(recipe_id)
		var category: String = str(definition.category)
		if category != current_category:
			current_category = category
			var heading := Label.new()
			heading.text = category.to_upper()
			_furnace_recipe_list.add_child(heading)
		var button := Button.new()
		button.name = "FurnaceRecipe_" + str(recipe_id)
		button.text = _recipe_button_text(definition) + "\nFuel: 1 Wood"
		button.custom_minimum_size = Vector2(720.0, 68.0)
		button.disabled = not FurnaceRecipeBook.can_smelt(inventory, recipe_id, progression)
		button.pressed.connect(func() -> void: _smelt_recipe(recipe_id))
		_furnace_recipe_list.add_child(button)


func _recipe_button_text(definition: Dictionary) -> String:
	var ingredients: Array[String] = []
	for value: Variant in (definition.ingredients as Dictionary).keys():
		var item_id := StringName(str(value))
		ingredients.append("%d %s" % [int(definition.ingredients[value]), ItemRegistry.display_name(item_id)])
	var output := StringName(str(definition.output_item))
	return "%s → %d %s\n%s // %s" % [
		" + ".join(ingredients),
		int(definition.output_count),
		ItemRegistry.display_name(output),
		str(definition.display_name),
		str(definition.get("source_process", "TEKNIK crafting")),
	]


func _craft_from_station(recipe_id: StringName, station: StringName) -> void:
	var crafted: bool = false
	if _world.has_method("_craft_recipe_at_station"):
		crafted = bool(_world.call("_craft_recipe_at_station", recipe_id, station))
	if _portable_status != null:
		_portable_status.text = "CRAFT COMPLETE" if crafted else "MISSING MATERIALS OR UNLOCK"
	refresh_all()


func _smelt_recipe(recipe_id: StringName) -> void:
	var completed: bool = false
	if _world.has_method("_smelt_furnace_recipe"):
		completed = bool(_world.call("_smelt_furnace_recipe", recipe_id))
	if _furnace_status != null:
		_furnace_status.text = "FURNACE OPERATION COMPLETE" if completed else "NEED FUEL, INGREDIENTS OR UNLOCK"
	refresh_all()


func is_crafting_page_visible() -> bool:
	return is_portable_crafting_visible() or is_workbench_visible()


func is_portable_crafting_visible() -> bool:
	return _installed and _portable_screen != null and _portable_screen.visible


func is_workbench_visible() -> bool:
	return _installed and _crafting_table_screen != null and _crafting_table_screen.visible


func is_furnace_visible() -> bool:
	return _installed and _furnace_screen != null and _furnace_screen.visible


func is_inventory_visible() -> bool:
	return _installed and _inventory_window != null and _inventory_window.visible


func _style_recipe_list(list: VBoxContainer) -> void:
	if list == null:
		return
	for child: Node in list.get_children():
		var button := child as Button
		if button != null:
			_apply_button_style(button)
			continue
		var label := child as Label
		if label != null:
			label.add_theme_color_override("font_color", BRASS_BRIGHT)
			label.add_theme_font_size_override("font_size", 14)


func _apply_all_ui_theme() -> void:
	_apply_theme_recursive(_world)
	for panel: PanelContainer in [_inventory_window, _portable_screen, _crafting_table_screen, _furnace_screen]:
		if panel != null:
			panel.add_theme_stylebox_override("panel", _panel_style(INK, BRASS_BRIGHT, 3, 8, 10.0))
	if _inventory_items_panel != null:
		_inventory_items_panel.add_theme_stylebox_override("panel", _panel_style(PLATE, BLUEPRINT, 2, 6, 8.0))


func _apply_theme_recursive(root: Node) -> void:
	for child: Node in root.get_children():
		var panel := child as PanelContainer
		if panel != null:
			panel.add_theme_stylebox_override("panel", _panel_style(PLATE, BLUEPRINT, 2, 6, 8.0))
		var button := child as Button
		if button != null:
			_apply_button_style(button)
		var label := child as Label
		if label != null:
			label.add_theme_color_override("font_color", PAPER)
		_apply_theme_recursive(child)


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
	button.add_theme_font_size_override("font_size", 14)


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


func _validate_separate_interfaces() -> void:
	await get_tree().process_frame
	var valid: bool = (
		_inventory_window != null
		and _portable_screen != null
		and _crafting_table_screen != null
		and _furnace_screen != null
		and _portable_recipe_list != null
		and _table_recipe_list != null
		and _furnace_recipe_list != null
		and _craft_open_button != null
		and _inventory_crafting_panel != null
		and not _inventory_crafting_panel.visible
	)
	if not valid:
		_fail("separate station UI wiring incomplete")
		return
	print("QA_SEPARATE_STATION_UI_PASS inventory=true portable_crafting=true crafting_table=true furnace=true station_recipe_lists=true")


func _fail(reason: String) -> void:
	push_error("SEPARATE_STATION_UI: %s" % reason)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-"):
			get_tree().quit(1)
			return
