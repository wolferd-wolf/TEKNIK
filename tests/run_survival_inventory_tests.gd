extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const HotbarSelectionState = preload("res://src/survival/hotbar_selection_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_registry()
	_test_stacking_and_removal()
	_test_capacity_and_codec()
	_test_hotbar_selection()
	if _failures == 0:
		print("SURVIVAL_INVENTORY_TEST_RESULT PASS")
		quit(0)
	else:
		print("SURVIVAL_INVENTORY_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_registry() -> void:
	for material: int in [ItemRegistry.STONE, ItemRegistry.SOIL, ItemRegistry.GRASS, ItemRegistry.SAND]:
		var item_id: StringName = ItemRegistry.item_for_material(material)
		_expect(item_id != &"", "terrain material maps to an item")
		_expect(ItemRegistry.material_for_item(item_id) == material, "item mapping round-trips")
	_expect(ItemRegistry.item_for_material(ItemRegistry.AIR) == &"", "air never becomes an item")
	var expected_voxels: Array[StringName] = [
		ItemRegistry.ITEM_STONE,
		ItemRegistry.ITEM_SOIL,
		ItemRegistry.ITEM_GRASS,
		ItemRegistry.ITEM_SAND,
	]
	var expected_objects: Array[StringName] = [
		ItemRegistry.ITEM_WORKBENCH,
		ItemRegistry.ITEM_STONE_SHAFT,
		ItemRegistry.ITEM_HAND_CRANK,
		ItemRegistry.ITEM_STONE_CRUSHER,
	]
	var expected_placeables: Array[StringName] = expected_voxels.duplicate()
	expected_placeables.append_array(expected_objects)
	_expect(ItemRegistry.voxel_placeable_items() == expected_voxels, "voxel hotbar order is deterministic")
	_expect(ItemRegistry.object_placeable_items() == expected_objects, "engineering hotbar order is deterministic")
	_expect(ItemRegistry.placeable_items() == expected_placeables, "combined hotbar order is deterministic")
	for item_id: StringName in expected_objects:
		_expect(ItemRegistry.is_object_placeable(item_id), "engineering item is object-placeable")
		_expect(ItemRegistry.material_for_item(item_id) == ItemRegistry.AIR, "engineering object stays outside the voxel material path")
	_expect(not ItemRegistry.is_placeable(ItemRegistry.ITEM_STONE_GEAR), "ingredient-only gear stays out of the hotbar")


func _test_stacking_and_removal() -> void:
	var inventory: TeknikStackInventory = StackInventory.new()
	_expect(inventory.add(ItemRegistry.ITEM_STONE, 65) == 0, "items span bounded stacks")
	_expect(inventory.count(ItemRegistry.ITEM_STONE) == 65, "stack total is counted")
	var slots: Array[Dictionary] = inventory.slots()
	_expect(int(slots[0].count) == 64 and int(slots[1].count) == 1, "stack size is capped at 64")
	_expect(inventory.remove(ItemRegistry.ITEM_STONE, 64), "available resources can be consumed")
	_expect(inventory.count(ItemRegistry.ITEM_STONE) == 1, "consumption updates the total")
	_expect(not inventory.remove(ItemRegistry.ITEM_STONE, 2), "placement cannot consume missing resources")


func _test_capacity_and_codec() -> void:
	var inventory: TeknikStackInventory = StackInventory.new()
	for item_id: StringName in ItemRegistry.registered_items():
		var amount: int = mini(ItemRegistry.max_stack(item_id), 8)
		_expect(inventory.add(item_id, amount) == 0, "registered item fills a bounded test stack")
	var encoded: Dictionary = inventory.encode()
	var restored: TeknikStackInventory = StackInventory.new()
	_expect(restored.decode(encoded), "inventory save payload decodes")
	_expect(restored.encode() == encoded, "inventory persistence is lossless")
	var invalid: Dictionary = encoded.duplicate(true)
	invalid.schema = 999
	_expect(not restored.decode(invalid), "unknown inventory schema is rejected")


func _test_hotbar_selection() -> void:
	var inventory: TeknikStackInventory = StackInventory.new()
	inventory.add(ItemRegistry.ITEM_SOIL, 3)
	inventory.add(ItemRegistry.ITEM_GRASS, 2)
	inventory.add(ItemRegistry.ITEM_STONE_CRUSHER, 1)
	var state := HotbarSelectionState.new()
	_expect(state.choose_available(Callable(inventory, "count")) == ItemRegistry.ITEM_SOIL, "empty default selection falls back to the first available placeable")
	_expect(state.select(ItemRegistry.ITEM_STONE_CRUSHER), "engineering object can be selected in the hotbar")
	_expect(not state.select(ItemRegistry.ITEM_STONE_GEAR), "ingredient-only item cannot enter the hotbar")
	var encoded: Dictionary = state.encode()
	var restored := HotbarSelectionState.new()
	_expect(restored.decode(encoded), "engineering hotbar selection save decodes")
	_expect(restored.selected_item == ItemRegistry.ITEM_STONE_CRUSHER, "engineering hotbar selection survives reload")
	inventory.remove(ItemRegistry.ITEM_STONE_CRUSHER, 1)
	_expect(restored.choose_available(Callable(inventory, "count")) == ItemRegistry.ITEM_SOIL, "depleted selected stack switches to an available placeable")
	var invalid := {"schema": HotbarSelectionState.SCHEMA, "selected_item": str(ItemRegistry.ITEM_STONE_GEAR)}
	_expect(not restored.decode(invalid), "invalid non-placeable hotbar save is rejected")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
