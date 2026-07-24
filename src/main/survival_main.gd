extends "res://src/main/multi_lod_main.gd"

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")

const INVENTORY_PATH: String = "user://teknik-inventory.json"
const INVENTORY_SAVE_DELAY_MS: int = 700

var _inventory: TeknikStackInventory = StackInventory.new()
var _selected_item: StringName = ItemRegistry.ITEM_STONE
var _inventory_save_due_ms: int = 0
var _inventory_label: Label
var _craft_button: Button
var _craft_status: Label


func _ready() -> void:
	_load_inventory()
	super._ready()
	_build_inventory_hud()
	_refresh_inventory_hud()
	_runtime_log.event("info", "survival", "inventory_ready", {
		"slots": StackInventory.SLOT_COUNT,
		"items": _inventory.encode(),
		"recipes": RecipeBook.registered_recipes(),
		"creative_mode": false,
	})


func _process(delta: float) -> void:
	super._process(delta)
	if _inventory_save_due_ms > 0 and Time.get_ticks_msec() >= _inventory_save_due_ms:
		_save_inventory_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_inventory_now()
	super._notification(what)


func _on_break_requested(origin: Vector3, direction: Vector3) -> void:
	var hit: Dictionary = _raycast_world(origin, direction)
	if hit.is_empty():
		return
	var voxel: Vector3i = InteractionMath.removal_voxel(hit.position, hit.normal)
	_survival_break_voxel(voxel, "removed")


func _on_place_requested(origin: Vector3, direction: Vector3) -> void:
	var hit: Dictionary = _raycast_world(origin, direction)
	if hit.is_empty():
		return
	var voxel: Vector3i = InteractionMath.placement_voxel(hit.position, hit.normal)
	var material: int = ItemRegistry.material_for_item(_selected_item)
	if material == ItemRegistry.AIR:
		return
	_survival_place_voxel(voxel, material, "placed", true)


func _survival_break_voxel(voxel: Vector3i, action: String) -> bool:
	var current: int = _current_material(voxel)
	if current == VoxelChunk.AIR:
		return false
	var item_id: StringName = ItemRegistry.item_for_material(current)
	if item_id == &"":
		return false
	if _inventory.add(item_id, 1) != 0:
		_runtime_log.event("warning", "survival", "drop_rejected_inventory_full", {
			"voxel": str(voxel),
			"item": str(item_id),
		})
		return false
	_apply_voxel_edit(voxel, VoxelChunk.AIR, action)
	_mark_inventory_changed("collected", item_id, 1)
	return true


func _survival_place_voxel(voxel: Vector3i, material: int, action: String, check_player: bool) -> bool:
	if _current_material(voxel) != VoxelChunk.AIR:
		return false
	if check_player and _placement_intersects_player(voxel):
		return false
	var item_id: StringName = ItemRegistry.item_for_material(material)
	if item_id == &"" or not _inventory.remove(item_id, 1):
		_runtime_log.event("info", "survival", "placement_denied_missing_item", {
			"voxel": str(voxel),
			"item": str(item_id),
		})
		return false
	_apply_voxel_edit(voxel, material, action)
	_mark_inventory_changed("consumed", item_id, -1)
	return true


func _craft_recipe(recipe_id: StringName) -> bool:
	var definition: Dictionary = RecipeBook.recipe(recipe_id)
	if definition.is_empty():
		return false
	if not RecipeBook.craft(_inventory, recipe_id):
		if _craft_status != null:
			_craft_status.text = "Need 4 Stone"
		_runtime_log.event("info", "survival", "craft_denied", {
			"recipe": str(recipe_id),
			"inventory": _inventory.encode(),
		})
		_refresh_inventory_hud()
		return false
	var output_item := StringName(definition.output_item)
	var output_count: int = int(definition.output_count)
	if _craft_status != null:
		_craft_status.text = "+%d %s" % [output_count, ItemRegistry.display_name(output_item)]
	_mark_inventory_changed("crafted", output_item, output_count)
	_runtime_log.event("info", "survival", "recipe_crafted", {
		"recipe": str(recipe_id),
		"output": str(output_item),
		"count": output_count,
	})
	return true


func _current_material(voxel: Vector3i) -> int:
	var generated: int = TerrainGenerator.voxel_at(WORLD_SEED, voxel)
	return _world_edits.get_override(voxel, generated)


func _mark_inventory_changed(event_name: String, item_id: StringName, delta: int) -> void:
	_inventory_save_due_ms = Time.get_ticks_msec() + INVENTORY_SAVE_DELAY_MS
	_refresh_inventory_hud()
	_runtime_log.event("info", "survival", event_name, {
		"item": str(item_id),
		"delta": delta,
		"count": _inventory.count(item_id),
	})


func _build_inventory_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SurvivalInventoryHUD"
	layer.layer = 6
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 54.0)
	panel.custom_minimum_size = Vector2(300.0, 124.0)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	_inventory_label = Label.new()
	_inventory_label.name = "InventorySummary"
	_inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_inventory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inventory_label.add_theme_font_size_override("font_size", 16)
	content.add_child(_inventory_label)
	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 8)
	content.add_child(craft_row)
	_craft_button = Button.new()
	_craft_button.name = "CraftStoneGear"
	_craft_button.text = "Craft Gear (4 Stone)"
	_craft_button.custom_minimum_size = Vector2(180.0, 42.0)
	_craft_button.pressed.connect(func() -> void: _craft_recipe(RecipeBook.RECIPE_STONE_GEAR))
	craft_row.add_child(_craft_button)
	_craft_status = Label.new()
	_craft_status.name = "CraftStatus"
	_craft_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	craft_row.add_child(_craft_status)


func _refresh_inventory_hud() -> void:
	if _inventory_label == null:
		return
	var parts: Array[String] = []
	for item_id: StringName in ItemRegistry.registered_items():
		var amount: int = _inventory.count(item_id)
		if amount > 0 or item_id == _selected_item:
			var marker: String = ">" if item_id == _selected_item else ""
			parts.append("%s%s %d" % [marker, ItemRegistry.display_name(item_id), amount])
	_inventory_label.text = "SURVIVAL INVENTORY\n" + "   ".join(parts)
	if _craft_button != null:
		_craft_button.disabled = not RecipeBook.can_craft(_inventory, RecipeBook.RECIPE_STONE_GEAR)


func _load_inventory() -> void:
	if not FileAccess.file_exists(INVENTORY_PATH):
		return
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and _inventory.decode(parsed):
		return
	push_warning("SURVIVAL inventory save was invalid; starting empty")
	_inventory.clear()


func _save_inventory_now() -> void:
	if _inventory_save_due_ms == 0 and FileAccess.file_exists(INVENTORY_PATH):
		return
	var temporary_path: String = INVENTORY_PATH + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("SURVIVAL inventory save could not open temporary file")
		return
	file.store_string(JSON.stringify(_inventory.encode(), "\t"))
	file.flush()
	file = null
	var absolute_target: String = ProjectSettings.globalize_path(INVENTORY_PATH)
	var absolute_temporary: String = ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(INVENTORY_PATH):
		DirAccess.remove_absolute(absolute_target)
	var result: Error = DirAccess.rename_absolute(absolute_temporary, absolute_target)
	if result != OK:
		push_error("SURVIVAL inventory save rename failed: %s" % error_string(result))
		return
	_inventory_save_due_ms = 0
	_runtime_log.event("info", "survival", "inventory_saved", {
		"path": INVENTORY_PATH,
		"items": _inventory.encode(),
	})


func qa_survival_break(voxel: Vector3i, action: String = "qa_survival_removed") -> bool:
	return _survival_break_voxel(voxel, action)


func qa_survival_place(voxel: Vector3i, material: int, action: String = "qa_survival_placed") -> bool:
	return _survival_place_voxel(voxel, material, action, false)


func qa_inventory_count(item_id: StringName) -> int:
	return _inventory.count(item_id)


func qa_grant_item(item_id: StringName, amount: int) -> bool:
	var remainder: int = _inventory.add(item_id, amount)
	if remainder != 0:
		return false
	_mark_inventory_changed("qa_granted", item_id, amount)
	return true


func qa_craft_recipe(recipe_id: StringName) -> bool:
	return _craft_recipe(recipe_id)


func qa_save_inventory_now() -> void:
	_inventory_save_due_ms = maxi(_inventory_save_due_ms, 1)
	_save_inventory_now()


func qa_reload_inventory_for_test() -> bool:
	var expected: Dictionary = _inventory.encode()
	var restored: TeknikStackInventory = StackInventory.new()
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not restored.decode(parsed):
		return false
	return restored.encode() == expected


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["inventory"] = _inventory.encode()
	snapshot["selected_item"] = str(_selected_item)
	snapshot["survival_only"] = true
	snapshot["stone_gears"] = _inventory.count(ItemRegistry.ITEM_STONE_GEAR)
	return snapshot
