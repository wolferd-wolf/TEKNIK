extends "res://src/main/survival_main.gd"

const ProgressionState = preload("res://src/survival/progression_state.gd")

const PROGRESSION_PATH: String = "user://teknik-progression.json"
const ENGINEERING_SCREEN_SIZE := Vector2(760.0, 520.0)

var _progression: TeknikProgressionState = ProgressionState.new()
var _engineering_screen: PanelContainer
var _recipe_list: VBoxContainer
var _progression_label: Label


func _ready() -> void:
	_load_progression()
	super._ready()
	_build_recipe_panel()
	_refresh_recipe_panel()


func _craft_recipe(recipe_id: StringName) -> bool:
	var definition: Dictionary = RecipeBook.recipe(recipe_id)
	if definition.is_empty():
		return false
	return _craft_recipe_at_station(
		recipe_id,
		StringName(str(definition.get("station", "")))
	)


func _craft_recipe_at_station(recipe_id: StringName, station: StringName) -> bool:
	var definition: Dictionary = RecipeBook.recipe(recipe_id)
	if definition.is_empty():
		return false
	if not RecipeBook.craft_at_station(
		_inventory,
		recipe_id,
		_progression,
		station
	):
		if _craft_status != null:
			_craft_status.text = "Missing materials, station or progression"
		_refresh_inventory_hud()
		_refresh_recipe_panel()
		return false
	var output_item := StringName(str(definition.output_item))
	var output_count: int = int(definition.output_count)
	if _craft_status != null:
		_craft_status.text = "+%d %s" % [output_count, ItemRegistry.display_name(output_item)]
	_mark_inventory_changed("crafted", output_item, output_count)
	_save_progression_now()
	_refresh_recipe_panel()
	_runtime_log.event("info", "survival", "station_recipe_crafted", {
		"recipe": str(recipe_id),
		"station": str(station),
		"source_process": str(definition.get("source_process", "")),
		"unlocks": _progression.encode(),
	})
	return true


func _build_recipe_panel() -> void:
	_ensure_left_hud_column()
	_engineering_screen = PanelContainer.new()
	_engineering_screen.name = "CraftingTableScreen"
	_engineering_screen.set_anchors_preset(Control.PRESET_CENTER)
	_engineering_screen.position = Vector2(-380.0, -260.0)
	_engineering_screen.custom_minimum_size = ENGINEERING_SCREEN_SIZE
	_engineering_screen.visible = false
	_gameplay_hud_layer.add_child(_engineering_screen)

	var content := VBoxContainer.new()
	content.name = "CraftingTableContent"
	content.add_theme_constant_override("separation", 8)
	_engineering_screen.add_child(content)

	var title := Label.new()
	title.name = "CraftingTableTitle"
	title.text = "CRAFTING TABLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)

	_progression_label = Label.new()
	_progression_label.name = "EngineeringProgressionSummary"
	_progression_label.add_theme_font_size_override("font_size", 15)
	content.add_child(_progression_label)

	var scroll := ScrollContainer.new()
	scroll.name = "CraftingTableRecipeScroll"
	scroll.custom_minimum_size = Vector2(720.0, 370.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(scroll)

	_recipe_list = VBoxContainer.new()
	_recipe_list.name = "CraftingTableRecipeList"
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_recipe_list)

	var close_button := Button.new()
	close_button.name = "CloseCraftingTableScreen"
	close_button.text = "CLOSE CRAFTING TABLE"
	close_button.custom_minimum_size = Vector2(220.0, 48.0)
	close_button.pressed.connect(_close_engineering_station)
	content.add_child(close_button)


func _open_engineering_station() -> void:
	if _inventory_window != null:
		_inventory_window.visible = false
	if _engineering_screen != null:
		_engineering_screen.visible = true
		_refresh_recipe_panel()


func _close_engineering_station() -> void:
	if _engineering_screen != null:
		_engineering_screen.visible = false
	var ui := get_node_or_null("IndustrialBlueprintUI")
	if ui != null and ui.has_method("close_all"):
		ui.call("close_all")


func _refresh_recipe_panel() -> void:
	if _recipe_list == null:
		return
	for child: Node in _recipe_list.get_children():
		child.queue_free()
	_progression_label.text = "Unlocked: " + ", ".join(
		Array(_progression.unlocked_ids()).map(
			func(value: StringName) -> String: return str(value)
		)
	)
	var current_category: String = ""
	for recipe_id: StringName in RecipeBook.available_recipes_for_station(
		_progression,
		RecipeBook.STATION_TABLE
	):
		var definition: Dictionary = RecipeBook.recipe(recipe_id)
		var category: String = str(definition.category)
		if category != current_category:
			current_category = category
			var heading := Label.new()
			heading.text = category.to_upper()
			heading.add_theme_font_size_override("font_size", 14)
			_recipe_list.add_child(heading)
		var button := Button.new()
		button.name = "TableRecipe_" + str(recipe_id)
		button.text = _recipe_button_text(definition)
		button.custom_minimum_size = Vector2(700.0, 54.0)
		button.disabled = not RecipeBook.can_craft_at_station(
			_inventory,
			recipe_id,
			_progression,
			RecipeBook.STATION_TABLE
		)
		button.pressed.connect(
			func() -> void:
				_craft_recipe_at_station(recipe_id, RecipeBook.STATION_TABLE)
		)
		_recipe_list.add_child(button)


func _recipe_button_text(definition: Dictionary) -> String:
	var ingredients: Array[String] = []
	for item_variant: Variant in (definition.ingredients as Dictionary).keys():
		var item_id := StringName(str(item_variant))
		ingredients.append("%d %s" % [
			int(definition.ingredients[item_variant]),
			ItemRegistry.display_name(item_id),
		])
	var process: String = str(definition.get("source_process", ""))
	return "%s  [%s]\n%s" % [
		str(definition.display_name),
		" + ".join(ingredients),
		process,
	]


func _refresh_inventory_hud() -> void:
	super._refresh_inventory_hud()
	_refresh_recipe_panel()
	if has_method("_refresh_machine_status"):
		call("_refresh_machine_status")
	var ui := get_node_or_null("IndustrialBlueprintUI")
	if ui != null and ui.has_method("refresh_all"):
		ui.call_deferred("refresh_all")


func _load_progression() -> void:
	if not FileAccess.file_exists(PROGRESSION_PATH):
		return
	var file := FileAccess.open(PROGRESSION_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_progression.decode(parsed)


func _save_progression_now() -> void:
	var temporary_path: String = PROGRESSION_PATH + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("SURVIVAL progression save could not open temporary file")
		return
	file.store_string(JSON.stringify(_progression.encode(), "\t"))
	file.flush()
	file = null
	var target: String = ProjectSettings.globalize_path(PROGRESSION_PATH)
	var temporary: String = ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(PROGRESSION_PATH):
		DirAccess.remove_absolute(target)
	var result: Error = DirAccess.rename_absolute(temporary, target)
	if result != OK:
		push_error("SURVIVAL progression save rename failed: %s" % error_string(result))


func qa_progression_unlocked(unlock_id: StringName) -> bool:
	return _progression.is_unlocked(unlock_id)


func qa_save_progression_now() -> void:
	_save_progression_now()


func qa_reload_progression_for_test() -> bool:
	var file := FileAccess.open(PROGRESSION_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var restored := ProgressionState.new()
	return parsed is Dictionary and restored.decode(parsed) and restored.encode() == _progression.encode()


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["progression"] = _progression.encode()
	snapshot["hand_recipes"] = RecipeBook.available_recipes_for_station(_progression, RecipeBook.STATION_HAND)
	snapshot["table_recipes"] = RecipeBook.available_recipes_for_station(_progression, RecipeBook.STATION_TABLE)
	snapshot["furnace_recipes"] = RecipeBook.available_recipes_for_station(_progression, RecipeBook.STATION_FURNACE)
	snapshot["engineering_screen_visible"] = _engineering_screen != null and _engineering_screen.visible
	return snapshot
