extends "res://src/main/multi_lod_main.gd"

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const HotbarSelectionState = preload("res://src/survival/hotbar_selection_state.gd")

const INVENTORY_PATH: String = "user://teknik-inventory.json"
const HOTBAR_STATE_PATH: String = "user://teknik-hotbar-state.json"
const PLACED_OBJECTS_PATH: String = "user://teknik-placed-objects.json"
const INVENTORY_SAVE_DELAY_MS: int = 700

var _inventory: TeknikStackInventory = StackInventory.new()
var _hotbar_selection: TeknikHotbarSelectionState = HotbarSelectionState.new()
var _selected_item: StringName = ItemRegistry.ITEM_STONE
var _inventory_save_due_ms: int = 0
var _inventory_label: Label
var _hotbar_buttons: Dictionary = {}
var _craft_button: Button
var _craft_status: Label
var _gameplay_hud_layer: CanvasLayer
var _left_hud_column: VBoxContainer
var _inventory_window: PanelContainer
var _inventory_grid: GridContainer
var _placed_object_root: Node3D
var _placed_objects: Dictionary = {}


func _ready() -> void:
	_load_inventory()
	_load_hotbar_selection()
	_selected_item = _hotbar_selection.choose_available(Callable(_inventory, "count"))
	super._ready()
	_build_inventory_hud()
	_load_placed_objects()
	_refresh_inventory_hud()
	_runtime_log.event("info", "survival", "inventory_ready", {
		"slots": StackInventory.SLOT_COUNT,
		"items": _inventory.encode(),
		"selected_item": str(_selected_item),
		"recipes": RecipeBook.registered_recipes(),
		"placed_objects": _placed_objects.size(),
		"creative_mode": false,
	})


func _process(delta: float) -> void:
	super._process(delta)
	if _inventory_save_due_ms > 0 and Time.get_ticks_msec() >= _inventory_save_due_ms:
		_save_inventory_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_inventory_now()
		_save_hotbar_selection_now()
		_save_placed_objects_now()
	super._notification(what)


func _on_break_requested(origin: Vector3, direction: Vector3) -> void:
	var object_hit: Dictionary = _raycast_placed_object(origin, direction)
	if not object_hit.is_empty():
		_break_placed_object(String(object_hit.key))
		return
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
	if ItemRegistry.is_object_placeable(_selected_item):
		_place_engineering_object(voxel, _selected_item, true)
		return
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
		return false
	_apply_voxel_edit(voxel, material, action)
	_mark_inventory_changed("consumed", item_id, -1)
	return true


func _place_engineering_object(voxel: Vector3i, item_id: StringName, consume_item: bool) -> bool:
	if not ItemRegistry.is_object_placeable(item_id):
		return false
	if _current_material(voxel) != VoxelChunk.AIR or _placement_intersects_player(voxel):
		return false
	var key := _object_key(voxel)
	if _placed_objects.has(key):
		return false
	if consume_item and not _inventory.remove(item_id, 1):
		return false
	_ensure_placed_object_root()
	var node := _build_engineering_object(item_id, voxel)
	_placed_object_root.add_child(node)
	_placed_objects[key] = {"item": str(item_id), "position": [voxel.x, voxel.y, voxel.z], "node": node}
	_save_placed_objects_now()
	if consume_item:
		_mark_inventory_changed("object_placed", item_id, -1)
	_runtime_log.event("info", "survival", "engineering_object_placed", {"item": str(item_id), "voxel": str(voxel)})
	return true


func _break_placed_object(key: String) -> bool:
	if not _placed_objects.has(key):
		return false
	var entry: Dictionary = _placed_objects[key]
	var item_id := StringName(str(entry.item))
	if _inventory.add(item_id, 1) != 0:
		return false
	var node := entry.get("node") as Node
	if is_instance_valid(node):
		node.queue_free()
	_placed_objects.erase(key)
	_save_placed_objects_now()
	_mark_inventory_changed("object_collected", item_id, 1)
	return true


func _build_engineering_object(item_id: StringName, voxel: Vector3i) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Placed_%s_%s" % [str(item_id), _object_key(voxel)]
	body.position = Vector3(voxel) + Vector3(0.5, 0.5, 0.5)
	body.set_meta("placed_object_key", _object_key(voxel))
	var dimensions := _object_dimensions(item_id)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.position.y = (dimensions.y - 1.0) * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = _object_color(item_id)
	material.roughness = 0.82
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	collision.position = mesh.position
	body.add_child(collision)
	return body


func _object_dimensions(item_id: StringName) -> Vector3:
	match item_id:
		ItemRegistry.ITEM_STONE_SHAFT:
			return Vector3(0.35, 1.0, 0.35)
		ItemRegistry.ITEM_HAND_CRANK:
			return Vector3(0.8, 0.75, 0.35)
		ItemRegistry.ITEM_STONE_CRUSHER:
			return Vector3(1.0, 1.5, 1.0)
		_:
			return Vector3(1.0, 0.8, 1.0)


func _object_color(item_id: StringName) -> Color:
	match item_id:
		ItemRegistry.ITEM_STONE_SHAFT:
			return Color(0.56, 0.58, 0.62)
		ItemRegistry.ITEM_HAND_CRANK:
			return Color(0.48, 0.36, 0.24)
		ItemRegistry.ITEM_STONE_CRUSHER:
			return Color(0.32, 0.34, 0.38)
		_:
			return Color(0.46, 0.43, 0.38)


func _raycast_placed_object(origin: Vector3, direction: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * 7.0)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {}
	var collider := result.get("collider") as Node
	if collider != null and collider.has_meta("placed_object_key"):
		return {"key": collider.get_meta("placed_object_key")}
	return {}


func _ensure_placed_object_root() -> void:
	if is_instance_valid(_placed_object_root):
		return
	_placed_object_root = Node3D.new()
	_placed_object_root.name = "PlacedEngineeringObjects"
	add_child(_placed_object_root)


func _object_key(voxel: Vector3i) -> String:
	return "%d,%d,%d" % [voxel.x, voxel.y, voxel.z]


func _load_placed_objects() -> void:
	_ensure_placed_object_root()
	if not FileAccess.file_exists(PLACED_OBJECTS_PATH):
		return
	var file := FileAccess.open(PLACED_OBJECTS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		return
	for value: Variant in parsed:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var position_data: Array = entry.get("position", [])
		var item_id := StringName(str(entry.get("item", "")))
		if position_data.size() != 3 or not ItemRegistry.is_object_placeable(item_id):
			continue
		var voxel := Vector3i(int(position_data[0]), int(position_data[1]), int(position_data[2]))
		var key := _object_key(voxel)
		var node := _build_engineering_object(item_id, voxel)
		_placed_object_root.add_child(node)
		_placed_objects[key] = {"item": str(item_id), "position": position_data, "node": node}


func _save_placed_objects_now() -> void:
	var payload: Array[Dictionary] = []
	for key: String in _placed_objects:
		var entry: Dictionary = _placed_objects[key]
		payload.append({"item": str(entry.item), "position": entry.position})
	var file := FileAccess.open(PLACED_OBJECTS_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file = null
	var target := ProjectSettings.globalize_path(PLACED_OBJECTS_PATH)
	var temporary := ProjectSettings.globalize_path(PLACED_OBJECTS_PATH + ".tmp")
	if FileAccess.file_exists(PLACED_OBJECTS_PATH):
		DirAccess.remove_absolute(target)
	DirAccess.rename_absolute(temporary, target)


func _craft_recipe(recipe_id: StringName) -> bool:
	var definition: Dictionary = RecipeBook.recipe(recipe_id)
	if definition.is_empty() or not RecipeBook.craft(_inventory, recipe_id):
		if _craft_status != null:
			_craft_status.text = "Missing materials"
		_refresh_inventory_hud()
		return false
	var output_item := StringName(definition.output_item)
	var output_count: int = int(definition.output_count)
	if _craft_status != null:
		_craft_status.text = "+%d %s" % [output_count, ItemRegistry.display_name(output_item)]
	_mark_inventory_changed("crafted", output_item, output_count)
	return true


func _select_hotbar_item(item_id: StringName) -> bool:
	if not ItemRegistry.is_placeable(item_id) or _inventory.count(item_id) <= 0:
		return false
	if not _hotbar_selection.select(item_id):
		return false
	_selected_item = _hotbar_selection.selected_item
	_save_hotbar_selection_now()
	_refresh_inventory_hud()
	return true


func _current_material(voxel: Vector3i) -> int:
	var generated: int = TerrainGenerator.voxel_at(WORLD_SEED, voxel)
	return _world_edits.get_override(voxel, generated)


func _mark_inventory_changed(event_name: String, item_id: StringName, delta: int) -> void:
	_inventory_save_due_ms = Time.get_ticks_msec() + INVENTORY_SAVE_DELAY_MS
	var previous_selection: StringName = _selected_item
	_selected_item = _hotbar_selection.choose_available(Callable(_inventory, "count"))
	if previous_selection != _selected_item:
		_save_hotbar_selection_now()
	_refresh_inventory_hud()
	_runtime_log.event("info", "survival", event_name, {"item": str(item_id), "delta": delta, "count": _inventory.count(item_id)})


func _ensure_left_hud_column() -> VBoxContainer:
	if is_instance_valid(_left_hud_column):
		return _left_hud_column
	_gameplay_hud_layer = CanvasLayer.new()
	_gameplay_hud_layer.name = "GameplayHUD"
	_gameplay_hud_layer.layer = 6
	add_child(_gameplay_hud_layer)
	_left_hud_column = VBoxContainer.new()
	_left_hud_column.name = "LeftHUDColumn"
	_left_hud_column.position = Vector2(12.0, 54.0)
	_left_hud_column.custom_minimum_size = Vector2(330.0, 0.0)
	_left_hud_column.add_theme_constant_override("separation", 8)
	_gameplay_hud_layer.add_child(_left_hud_column)
	return _left_hud_column


func _add_left_hud_panel(panel: Control, order: int) -> void:
	var column: VBoxContainer = _ensure_left_hud_column()
	panel.set_meta("hud_order", order)
	column.add_child(panel)
	var target_index: int = 0
	for child: Node in column.get_children():
		if child != panel and int(child.get_meta("hud_order", 0)) < order:
			target_index += 1
	column.move_child(panel, target_index)


func _build_inventory_hud() -> void:
	_ensure_left_hud_column()
	var inventory_button := Button.new()
	inventory_button.name = "InventoryButton"
	inventory_button.text = "INVENTORY"
	inventory_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	inventory_button.position = Vector2(12.0, -72.0)
	inventory_button.custom_minimum_size = Vector2(128.0, 56.0)
	inventory_button.pressed.connect(_toggle_inventory_window)
	_gameplay_hud_layer.add_child(inventory_button)

	var hotbar_panel := PanelContainer.new()
	hotbar_panel.name = "BottomHotbar"
	hotbar_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_panel.position = Vector2(-420.0, -76.0)
	hotbar_panel.custom_minimum_size = Vector2(760.0, 64.0)
	_gameplay_hud_layer.add_child(hotbar_panel)
	var hotbar := HBoxContainer.new()
	hotbar.name = "PlaceableHotbar"
	hotbar.add_theme_constant_override("separation", 4)
	hotbar_panel.add_child(hotbar)
	var slot_number := 1
	for item_id: StringName in ItemRegistry.placeable_items():
		var button := Button.new()
		button.name = "Hotbar_%s" % str(item_id)
		button.custom_minimum_size = Vector2(90.0, 58.0)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: _select_hotbar_item(item_id))
		hotbar.add_child(button)
		_hotbar_buttons[item_id] = button
		button.set_meta("slot_number", slot_number)
		slot_number += 1

	_inventory_window = PanelContainer.new()
	_inventory_window.name = "InventoryScreen"
	_inventory_window.set_anchors_preset(Control.PRESET_CENTER)
	_inventory_window.position = Vector2(-310.0, -220.0)
	_inventory_window.custom_minimum_size = Vector2(620.0, 440.0)
	_inventory_window.visible = false
	_gameplay_hud_layer.add_child(_inventory_window)
	var inventory_content := VBoxContainer.new()
	inventory_content.add_theme_constant_override("separation", 10)
	_inventory_window.add_child(inventory_content)
	var title := Label.new()
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	inventory_content.add_child(title)
	_inventory_label = Label.new()
	_inventory_label.name = "InventorySummary"
	inventory_content.add_child(_inventory_label)
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 3
	inventory_content.add_child(_inventory_grid)
	for item_id: StringName in ItemRegistry.registered_items():
		var row := Label.new()
		row.name = "Inventory_%s" % str(item_id)
		row.custom_minimum_size = Vector2(180.0, 34.0)
		row.set_meta("item_id", item_id)
		_inventory_grid.add_child(row)
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(140.0, 48.0)
	close_button.pressed.connect(_toggle_inventory_window)
	inventory_content.add_child(close_button)


func _toggle_inventory_window() -> void:
	if _inventory_window != null:
		_inventory_window.visible = not _inventory_window.visible


func _refresh_inventory_hud() -> void:
	if _inventory_label == null:
		return
	_inventory_label.text = "Selected: %s" % ItemRegistry.display_name(_selected_item)
	for item_id: StringName in ItemRegistry.placeable_items():
		var button := _hotbar_buttons.get(item_id) as Button
		if button == null:
			continue
		var amount := _inventory.count(item_id)
		button.text = "%d\n%s\n%d" % [int(button.get_meta("slot_number", 0)), ItemRegistry.display_name(item_id), amount]
		button.disabled = amount <= 0
		button.button_pressed = item_id == _selected_item
	if _inventory_grid != null:
		for child: Node in _inventory_grid.get_children():
			var label := child as Label
			if label == null:
				continue
			var item_id := StringName(label.get_meta("item_id"))
			var suffix := "PLACEABLE" if ItemRegistry.is_placeable(item_id) else "ITEM"
			label.text = "%s  x%d  [%s]" % [ItemRegistry.display_name(item_id), _inventory.count(item_id), suffix]


func _load_inventory() -> void:
	if not FileAccess.file_exists(INVENTORY_PATH):
		return
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and _inventory.decode(parsed):
		return
	_inventory.clear()


func _load_hotbar_selection() -> void:
	if not FileAccess.file_exists(HOTBAR_STATE_PATH):
		return
	var file := FileAccess.open(HOTBAR_STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and _hotbar_selection.decode(parsed):
		return
	_hotbar_selection = HotbarSelectionState.new()


func _save_inventory_now() -> void:
	if _inventory_save_due_ms == 0 and FileAccess.file_exists(INVENTORY_PATH):
		return
	var file := FileAccess.open(INVENTORY_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_inventory.encode(), "\t"))
	file.flush()
	file = null
	var target := ProjectSettings.globalize_path(INVENTORY_PATH)
	var temporary := ProjectSettings.globalize_path(INVENTORY_PATH + ".tmp")
	if FileAccess.file_exists(INVENTORY_PATH):
		DirAccess.remove_absolute(target)
	if DirAccess.rename_absolute(temporary, target) == OK:
		_inventory_save_due_ms = 0


func _save_hotbar_selection_now() -> void:
	var file := FileAccess.open(HOTBAR_STATE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_hotbar_selection.encode(), "\t"))
	file.flush()
	file = null
	var target := ProjectSettings.globalize_path(HOTBAR_STATE_PATH)
	var temporary := ProjectSettings.globalize_path(HOTBAR_STATE_PATH + ".tmp")
	if FileAccess.file_exists(HOTBAR_STATE_PATH):
		DirAccess.remove_absolute(target)
	DirAccess.rename_absolute(temporary, target)


func qa_survival_break(voxel: Vector3i, action: String = "qa_survival_removed") -> bool:
	return _survival_break_voxel(voxel, action)


func qa_survival_place(voxel: Vector3i, material: int, action: String = "qa_survival_placed") -> bool:
	return _survival_place_voxel(voxel, material, action, false)


func qa_place_engineering_object(voxel: Vector3i, item_id: StringName) -> bool:
	return _place_engineering_object(voxel, item_id, false)


func qa_placed_object_count() -> int:
	return _placed_objects.size()


func qa_inventory_count(item_id: StringName) -> int:
	return _inventory.count(item_id)


func qa_grant_item(item_id: StringName, amount: int) -> bool:
	var remainder: int = _inventory.add(item_id, amount)
	if remainder != 0:
		return false
	_mark_inventory_changed("qa_granted", item_id, amount)
	return true


func qa_select_hotbar_item(item_id: StringName) -> bool:
	return _select_hotbar_item(item_id)


func qa_craft_recipe(recipe_id: StringName) -> bool:
	return _craft_recipe(recipe_id)


func qa_save_inventory_now() -> void:
	_inventory_save_due_ms = maxi(_inventory_save_due_ms, 1)
	_save_inventory_now()
	_save_hotbar_selection_now()
	_save_placed_objects_now()


func qa_reload_inventory_for_test() -> bool:
	var expected: Dictionary = _inventory.encode()
	var restored: TeknikStackInventory = StackInventory.new()
	var file := FileAccess.open(INVENTORY_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed is Dictionary and restored.decode(parsed) and restored.encode() == expected


func qa_reload_hotbar_for_test() -> bool:
	var restored := HotbarSelectionState.new()
	var file := FileAccess.open(HOTBAR_STATE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed is Dictionary and restored.decode(parsed) and restored.selected_item == _selected_item


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["inventory"] = _inventory.encode()
	snapshot["selected_item"] = str(_selected_item)
	snapshot["survival_only"] = true
	snapshot["stone_gears"] = _inventory.count(ItemRegistry.ITEM_STONE_GEAR)
	snapshot["placed_objects"] = _placed_objects.size()
	return snapshot
