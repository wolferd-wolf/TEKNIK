extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const HotbarSelectionState = preload("res://src/survival/hotbar_selection_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_registry()
	_test_stacking_and_removal()
	_test_capacity_codec_and_migrations()
	_test_hotbar_selection()
	if _failures == 0:
		print("SURVIVAL_INVENTORY_TEST_RESULT PASS slots=64 registered=57 schema=4")
		quit(0)
	else:
		print("SURVIVAL_INVENTORY_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_registry() -> void:
	for material: int in [ItemRegistry.STONE, ItemRegistry.SOIL, ItemRegistry.GRASS, ItemRegistry.SAND]:
		var item_id: StringName = ItemRegistry.item_for_material(material)
		_expect(item_id != &"", "terrain material maps to an item")
		_expect(ItemRegistry.material_for_item(item_id) == material, "item mapping round-trips")
	var expected_voxels: Array[StringName] = [ItemRegistry.ITEM_STONE, ItemRegistry.ITEM_SOIL, ItemRegistry.ITEM_GRASS, ItemRegistry.ITEM_SAND]
	var expected_objects: Array[StringName] = [ItemRegistry.ITEM_WORKBENCH, ItemRegistry.ITEM_FURNACE, ItemRegistry.ITEM_STONE_SHAFT, ItemRegistry.ITEM_HAND_CRANK, ItemRegistry.ITEM_STONE_CRUSHER]
	var expected_placeables: Array[StringName] = expected_voxels.duplicate()
	expected_placeables.append_array(expected_objects)
	_expect(ItemRegistry.voxel_placeable_items() == expected_voxels, "voxel hotbar order is deterministic")
	_expect(ItemRegistry.object_placeable_items() == expected_objects, "station hotbar order is deterministic")
	_expect(ItemRegistry.placeable_items() == expected_placeables, "combined hotbar order is deterministic")
	_expect(ItemRegistry.registered_items().size() == 57, "Create dependencies expand the catalog")
	for item_id: StringName in [ItemRegistry.ITEM_WOOD, ItemRegistry.ITEM_PLANKS, ItemRegistry.ITEM_ANDESITE_ALLOY, ItemRegistry.ITEM_ELECTRON_TUBE]:
		_expect(not ItemRegistry.is_placeable(item_id), "ingredient remains outside placement hotbar: " + str(item_id))


func _test_stacking_and_removal() -> void:
	var inventory: TeknikStackInventory = StackInventory.new()
	_expect(inventory.add(ItemRegistry.ITEM_STONE, 65) == 0, "items span bounded stacks")
	_expect(inventory.count(ItemRegistry.ITEM_STONE) == 65, "stack total is counted")
	var slots: Array[Dictionary] = inventory.slots()
	_expect(int(slots[0].count) == 64 and int(slots[1].count) == 1, "stack size is capped at 64")
	_expect(inventory.remove(ItemRegistry.ITEM_STONE, 64), "available resources can be consumed")
	_expect(inventory.count(ItemRegistry.ITEM_STONE) == 1, "consumption updates the total")
	_expect(not inventory.remove(ItemRegistry.ITEM_STONE, 2), "missing resources cannot be consumed")


func _test_capacity_codec_and_migrations() -> void:
	var inventory: TeknikStackInventory = StackInventory.new()
	for item_id: StringName in ItemRegistry.registered_items():
		var amount: int = mini(ItemRegistry.max_stack(item_id), 8)
		_expect(inventory.add(item_id, amount) == 0, "registered item fits one bounded test stack")
	_expect(inventory.slots().size() == 64, "inventory has sixty-four slots")
	var encoded: Dictionary = inventory.encode()
	_expect(int(encoded.schema) == 4, "current inventory schema is four")
	var restored: TeknikStackInventory = StackInventory.new()
	_expect(restored.decode(encoded), "inventory save payload decodes")
	_expect(restored.encode() == encoded, "inventory persistence is lossless")
	for migration: Dictionary in [
		{"schema": StackInventory.LEGACY_SCHEMA, "count": StackInventory.LEGACY_SLOT_COUNT},
		{"schema": StackInventory.OLDER_SCHEMA, "count": StackInventory.OLDER_SLOT_COUNT},
		{"schema": StackInventory.PREVIOUS_SCHEMA, "count": StackInventory.PREVIOUS_SLOT_COUNT},
	]:
		var slots: Array[Dictionary] = []
		for _index: int in range(int(migration.count)):
			slots.append({"item": "", "count": 0})
		slots[0] = {"item": str(ItemRegistry.ITEM_WOOD), "count": 4}
		var migrated := StackInventory.new()
		_expect(migrated.decode({"schema": int(migration.schema), "slots": slots}), "older inventory schema migrates")
		_expect(migrated.slots().size() == 64 and migrated.count(ItemRegistry.ITEM_WOOD) == 4, "migration expands and preserves contents")
	var invalid: Dictionary = encoded.duplicate(true)
	invalid.schema = 999
	_expect(not restored.decode(invalid), "unknown inventory schema is rejected")


func _test_hotbar_selection() -> void:
	var inventory: TeknikStackInventory = StackInventory.new()
	inventory.add(ItemRegistry.ITEM_SOIL, 3)
	inventory.add(ItemRegistry.ITEM_FURNACE, 1)
	var state := HotbarSelectionState.new()
	_expect(state.choose_available(Callable(inventory, "count")) == ItemRegistry.ITEM_SOIL, "empty selection chooses first available placeable")
	_expect(state.select(ItemRegistry.ITEM_FURNACE), "furnace can be selected")
	_expect(not state.select(ItemRegistry.ITEM_PLANKS), "crafting ingredients cannot enter placement hotbar")
	var encoded: Dictionary = state.encode()
	var restored := HotbarSelectionState.new()
	_expect(restored.decode(encoded), "hotbar selection save decodes")
	_expect(restored.selected_item == ItemRegistry.ITEM_FURNACE, "furnace selection survives reload")
	inventory.remove(ItemRegistry.ITEM_FURNACE, 1)
	_expect(restored.choose_available(Callable(inventory, "count")) == ItemRegistry.ITEM_SOIL, "depleted selection falls back")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
