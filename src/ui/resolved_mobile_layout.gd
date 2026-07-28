extends Node

const TouchScrollDriver = preload("res://src/ui/touch_scroll_driver.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")

# Late layout pass for the real phone viewport. The station UI controller builds
# four independent screens; this layer pins the shared HUD and gives every long
# inventory/recipe surface deterministic Android drag scrolling.
const HOTBAR_MIN_SIZE := Vector2(612.0, 78.0)
const HOTBAR_BOTTOM_MARGIN: float = 12.0
const INVENTORY_HOST_MIN_SIZE := Vector2(432.0, 54.0)
const INVENTORY_HOST_RIGHT_MARGIN: float = 20.0
const INVENTORY_HOST_TOP_MARGIN: float = 18.0
const SETTINGS_POSITION := Vector2(920.0, 120.0)
const SETTINGS_SIZE := Vector2(312.0, 430.0)
const SETTINGS_SCROLL_SIZE := Vector2(286.0, 398.0)
const WORKBENCH_TYPE: StringName = &"workbench"
const FURNACE_TYPE: StringName = &"furnace"
const NATIVE_TOUCH_DEADZONE: int = 100_000
const UI_SCREENSHOT_DIRECTORY: String = "res://build/screenshots"

var _world: Node
var _industrial_ui: Node
var _hotbar: PanelContainer
var _inventory_button_host: Button
var _settings_panel: PanelContainer
var _touch_drivers: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_finalize_after_theme")


func _finalize_after_theme() -> void:
	# IndustrialBlueprintUI also installs deferred. Wait until all station windows,
	# styles and reparenting operations have resolved before measuring controls.
	for _frame: int in range(4):
		await get_tree().process_frame
	_world = get_parent()
	if _world == null:
		_fail("world root missing")
		return
	_industrial_ui = _world.get_node_or_null("IndustrialBlueprintUI")
	_hotbar = _world.get("_bottom_hotbar_panel") as PanelContainer
	_inventory_button_host = _world.get("_inventory_button") as Button
	_settings_panel = _world.get("_settings_panel") as PanelContainer
	if _industrial_ui == null or _hotbar == null or _inventory_button_host == null or _settings_panel == null:
		_fail("HUD or station UI controls unavailable")
		return
	_contain_settings_content()
	_install_touch_scroll_drivers()
	_pin_resolved_controls()
	await get_tree().process_frame
	_pin_resolved_controls()
	await _validate_resolved_layout()


func _contain_settings_content() -> void:
	if _settings_panel.get_node_or_null("SettingsScroll") != null:
		return
	if _settings_panel.get_child_count() == 0:
		return
	var content := _settings_panel.get_child(0) as Control
	if content == null:
		return
	_settings_panel.remove_child(content)
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.custom_minimum_size = SETTINGS_SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 8
	scroll.follow_focus = true
	_settings_panel.add_child(scroll)
	scroll.add_child(content)
	var content_minimum: Vector2 = content.custom_minimum_size
	content_minimum.x = SETTINGS_SCROLL_SIZE.x - 20.0
	content.custom_minimum_size = content_minimum
	_settings_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_settings_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_settings_panel.grow_vertical = Control.GROW_DIRECTION_END
	_settings_panel.custom_minimum_size = SETTINGS_SIZE
	_settings_panel.position = SETTINGS_POSITION
	_settings_panel.size = SETTINGS_SIZE


func _install_touch_scroll_drivers() -> void:
	_touch_drivers.clear()
	var items_panel := _world.get("_inventory_items_panel") as PanelContainer
	var inventory_scroll: ScrollContainer = null
	if items_panel != null:
		inventory_scroll = items_panel.find_child("InventoryItemScroll", true, false) as ScrollContainer
	_register_driver("inventory", inventory_scroll, "InventoryTouchScrollDriver")
	_register_driver(
		"portable",
		_world.find_child("PortableCraftingScroll", true, false) as ScrollContainer,
		"PortableCraftingTouchScrollDriver"
	)
	_register_driver(
		"table",
		_world.find_child("CraftingTableRecipeScroll", true, false) as ScrollContainer,
		"CraftingTableTouchScrollDriver"
	)
	_register_driver(
		"furnace",
		_world.find_child("FurnaceRecipeScroll", true, false) as ScrollContainer,
		"FurnaceTouchScrollDriver"
	)


func _register_driver(key: String, scroll: ScrollContainer, driver_name: String) -> void:
	var driver: Node = _attach_touch_driver(scroll, driver_name)
	if driver != null:
		_touch_drivers[key] = driver


func _attach_touch_driver(scroll: ScrollContainer, driver_name: String) -> Node:
	if scroll == null:
		return null
	# Disable only Godot's native touch-drag path to prevent double movement. Mouse
	# wheel and the visible scrollbar remain active on desktop and in CI.
	scroll.scroll_deadzone = NATIVE_TOUCH_DEADZONE
	var driver := scroll.get_node_or_null(driver_name)
	if driver == null:
		driver = TouchScrollDriver.new()
		driver.name = driver_name
		scroll.add_child(driver)
	if driver.has_method("attach"):
		driver.call("attach", scroll)
	return driver


func _pin_resolved_controls() -> void:
	_pin_hotbar_to_bottom()
	_pin_inventory_controls_to_top_right()


func _pin_hotbar_to_bottom() -> void:
	var resolved_minimum: Vector2 = _hotbar.get_combined_minimum_size()
	var resolved_width: float = ceil(maxf(HOTBAR_MIN_SIZE.x, resolved_minimum.x))
	var resolved_height: float = ceil(maxf(HOTBAR_MIN_SIZE.y, resolved_minimum.y))
	_hotbar.anchor_left = 0.5
	_hotbar.anchor_right = 0.5
	_hotbar.anchor_top = 1.0
	_hotbar.anchor_bottom = 1.0
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.offset_left = -resolved_width * 0.5
	_hotbar.offset_right = resolved_width * 0.5
	_hotbar.offset_bottom = -HOTBAR_BOTTOM_MARGIN
	_hotbar.offset_top = -HOTBAR_BOTTOM_MARGIN - resolved_height


func _pin_inventory_controls_to_top_right() -> void:
	var resolved_minimum: Vector2 = _inventory_button_host.get_combined_minimum_size()
	var resolved_width: float = ceil(maxf(INVENTORY_HOST_MIN_SIZE.x, resolved_minimum.x))
	var resolved_height: float = ceil(maxf(INVENTORY_HOST_MIN_SIZE.y, resolved_minimum.y))
	_inventory_button_host.anchor_left = 1.0
	_inventory_button_host.anchor_right = 1.0
	_inventory_button_host.anchor_top = 0.0
	_inventory_button_host.anchor_bottom = 0.0
	_inventory_button_host.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_inventory_button_host.grow_vertical = Control.GROW_DIRECTION_END
	_inventory_button_host.offset_right = -INVENTORY_HOST_RIGHT_MARGIN
	_inventory_button_host.offset_left = -INVENTORY_HOST_RIGHT_MARGIN - resolved_width
	_inventory_button_host.offset_top = INVENTORY_HOST_TOP_MARGIN
	_inventory_button_host.offset_bottom = INVENTORY_HOST_TOP_MARGIN + resolved_height


func _validate_resolved_layout() -> void:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var hotbar_rect: Rect2 = _hotbar.get_global_rect()
	var inventory_rect: Rect2 = _inventory_button_host.get_global_rect()
	var settings_rect: Rect2 = _settings_panel.get_global_rect()
	var valid: bool = (
		viewport_rect.encloses(hotbar_rect)
		and viewport_rect.encloses(inventory_rect)
		and viewport_rect.encloses(settings_rect)
		and not hotbar_rect.intersects(inventory_rect)
		and hotbar_rect.end.x <= viewport_rect.size.x * 0.75
		and _settings_panel.get_node_or_null("SettingsScroll") is ScrollContainer
		and _touch_drivers.size() == 4
	)
	if not valid:
		_fail("resolved geometry or four touch drivers invalid hotbar=%s host=%s settings=%s drivers=%s viewport=%s" % [
			hotbar_rect,
			inventory_rect,
			settings_rect,
			_touch_drivers.keys(),
			viewport_rect,
		])
		return
	print(
		"QA_RESOLVED_MOBILE_LAYOUT_PASS hotbar=", hotbar_rect,
		" host=", inventory_rect,
		" settings=", settings_rect,
		" right_action_clearance=", viewport_rect.size.x * 0.75 - hotbar_rect.end.x,
		" settings_scrollable=", true,
		" station_touch_drivers=", _touch_drivers.size()
	)
	if not _focused_ui_qa_requested():
		return
	await _validate_four_station_interfaces(viewport_rect)


func _validate_four_station_interfaces(viewport_rect: Rect2) -> void:
	# Populate every gated station category for scroll testing without saving the QA
	# progression. Normal gameplay still reveals recipes through crafted unlocks.
	_unlock_all_for_ui_qa()
	if _world.has_method("_refresh_recipe_panel"):
		_world.call("_refresh_recipe_panel")
	if _industrial_ui.has_method("refresh_all"):
		_industrial_ui.call("refresh_all")
	await get_tree().process_frame

	_industrial_ui.call("show_inventory")
	await get_tree().process_frame
	var inventory_visible: bool = bool(_industrial_ui.call("is_inventory_visible"))
	var inventory_captured: bool = await _capture_ui_qa("inventory-ui")
	var inventory_dragged: bool = _qa_drag("inventory")

	_industrial_ui.call("show_crafting")
	await get_tree().process_frame
	var portable_visible: bool = bool(_industrial_ui.call("is_portable_crafting_visible"))
	var portable_captured: bool = await _capture_ui_qa("portable-crafting-ui")
	var portable_dragged: bool = _qa_drag("portable")

	var workbench_opened: bool = bool(_world.call("_interact_with_machine_type", WORKBENCH_TYPE))
	await get_tree().process_frame
	var table_visible: bool = bool(_industrial_ui.call("is_workbench_visible"))
	var table_captured: bool = await _capture_ui_qa("crafting-table-ui")
	var table_dragged: bool = _qa_drag("table")

	var furnace_opened: bool = bool(_world.call("_interact_with_machine_type", FURNACE_TYPE))
	await get_tree().process_frame
	var furnace_visible: bool = bool(_industrial_ui.call("is_furnace_visible"))
	var furnace_captured: bool = await _capture_ui_qa("furnace-ui")
	var furnace_dragged: bool = _qa_drag("furnace")

	var valid: bool = (
		inventory_visible
		and portable_visible
		and workbench_opened
		and table_visible
		and furnace_opened
		and furnace_visible
		and inventory_dragged
		and portable_dragged
		and table_dragged
		and furnace_dragged
		and inventory_captured
		and portable_captured
		and table_captured
		and furnace_captured
	)
	if not valid:
		_fail("four-screen QA failed inventory=%s portable=%s table=%s furnace=%s opened=%s/%s drags=%s/%s/%s/%s captures=%s/%s/%s/%s" % [
			inventory_visible,
			portable_visible,
			table_visible,
			furnace_visible,
			workbench_opened,
			furnace_opened,
			inventory_dragged,
			portable_dragged,
			table_dragged,
			furnace_dragged,
			inventory_captured,
			portable_captured,
			table_captured,
			furnace_captured,
		])
		return
	print(
		"QA_FOCUSED_UI_PASS inventory=true portable_crafting=true crafting_table=true furnace=true",
		" touch_drag_inventory=", inventory_dragged,
		" touch_drag_portable=", portable_dragged,
		" touch_drag_table=", table_dragged,
		" touch_drag_furnace=", furnace_dragged,
		" screenshots=4",
		" host_inside_viewport=", viewport_rect.encloses(_inventory_button_host.get_global_rect())
	)
	get_tree().quit(0)


func _capture_ui_qa(file_stem: String) -> bool:
	var directory_path: String = ProjectSettings.globalize_path(UI_SCREENSHOT_DIRECTORY)
	var directory_result: Error = DirAccess.make_dir_recursive_absolute(directory_path)
	if directory_result != OK and directory_result != ERR_ALREADY_EXISTS:
		push_error("UI screenshot directory failed: %s" % error_string(directory_result))
		return false
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("UI screenshot image was empty: %s" % file_stem)
		return false
	var path: String = UI_SCREENSHOT_DIRECTORY + "/" + file_stem + ".png"
	var result: Error = image.save_png(path)
	if result != OK:
		push_error("UI screenshot save failed %s: %s" % [path, error_string(result)])
		return false
	print("QA_STATION_UI_SCREENSHOT_PASS path=", path, " size=", image.get_size())
	return true


func _unlock_all_for_ui_qa() -> void:
	var progression: TeknikProgressionState = _world.get("_progression")
	if progression == null:
		return
	for unlock_id: StringName in [
		ProgressionState.UNLOCK_WORKBENCH,
		ProgressionState.UNLOCK_STONE_PROCESSING,
		ProgressionState.UNLOCK_ANDESITE_ENGINEERING,
		ProgressionState.UNLOCK_BRASS_ENGINEERING,
		ProgressionState.UNLOCK_PRECISION_ENGINEERING,
		ProgressionState.UNLOCK_KINETIC_STARTER,
	]:
		progression.unlock(unlock_id)


func _qa_drag(key: String) -> bool:
	var driver: Node = _touch_drivers.get(key)
	return driver != null and driver.has_method("qa_drag_vertical") and bool(driver.call("qa_drag_vertical", 120.0))


func _focused_ui_qa_requested() -> bool:
	return "--qa-ui-layout" in OS.get_cmdline_user_args()


func _fail(reason: String) -> void:
	push_error("RESOLVED_MOBILE_LAYOUT: %s" % reason)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-"):
			get_tree().quit(1)
			return
