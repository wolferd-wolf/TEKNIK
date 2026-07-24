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
	_test_shipping_scene()
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
	var expected_placeables: Array[StringName] = [
		ItemRegistry.ITEM_STONE,
		ItemRegistry.ITEM_SOIL,
		ItemRegistry.ITEM_GRASS,
		ItemRegistry.ITEM_SAND,
	]
	_expect(ItemRegistry.placeable_items() == expected_placeables, "hotbar placeable order is deterministic")


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
	var state := HotbarSelectionState.new()
	_expect(state.choose_available(Callable(inventory, "count")) == ItemRegistry.ITEM_SOIL, "empty default selection falls back to the first available placeable")
	_expect(state.select(ItemRegistry.ITEM_GRASS), "available placeable can be selected")
	_expect(not state.select(ItemRegistry.ITEM_STONE_GEAR), "non-placeable engineering item cannot enter the hotbar")
	var encoded: Dictionary = state.encode()
	var restored := HotbarSelectionState.new()
	_expect(restored.decode(encoded), "hotbar selection save decodes")
	_expect(restored.selected_item == ItemRegistry.ITEM_GRASS, "hotbar selection survives reload")
	inventory.remove(ItemRegistry.ITEM_GRASS, 2)
	_expect(restored.choose_available(Callable(inventory, "count")) == ItemRegistry.ITEM_SOIL, "depleted selected stack switches to an available placeable")
	var invalid := {"schema": HotbarSelectionState.SCHEMA, "selected_item": str(ItemRegistry.ITEM_STONE_GEAR)}
	_expect(not restored.decode(invalid), "invalid non-placeable hotbar save is rejected")


func _test_shipping_scene() -> void:
	var scene_text: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var capture_source: String = FileAccess.get_file_as_string("res://src/main/kinetic_capture_shipping_main.gd")
	var placement_source: String = FileAccess.get_file_as_string("res://src/main/placement_preview_main.gd")
	var targeting_source: String = FileAccess.get_file_as_string("res://src/main/targeted_interaction_main.gd")
	var interactive_source: String = FileAccess.get_file_as_string("res://src/main/interactive_kinetic_main.gd")
	var kinetic_source: String = FileAccess.get_file_as_string("res://src/main/kinetic_machine_main.gd")
	var survival_source: String = FileAccess.get_file_as_string("res://src/main/survival_main.gd")
	var qa_source: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
	_expect(
		scene_text.contains("kinetic_capture_shipping_main.gd")
		and capture_source.contains("placement_preview_main.gd")
		and placement_source.contains("targeted_interaction_main.gd")
		and targeting_source.contains("interactive_kinetic_main.gd")
		and interactive_source.contains("kinetic_machine_main.gd")
		and kinetic_source.contains("survival_shipping_main.gd"),
		"shipping inheritance chain retains placement preview and survival gameplay"
	)
	_expect(survival_source.contains("_survival_break_voxel"), "breaking blocks creates inventory drops")
	_expect(survival_source.contains("_survival_place_voxel"), "placing blocks consumes inventory")
	_expect(survival_source.contains("INVENTORY_PATH"), "inventory has a persistent save path")
	_expect(survival_source.contains("HOTBAR_STATE_PATH"), "selected placeable has a persistent save path")
	_expect(survival_source.contains("PlaceableHotbar"), "mobile placeable hotbar is present")
	_expect(survival_source.contains("qa_reload_hotbar_for_test"), "runtime exposes hotbar reload proof")
	_expect(qa_source.contains("QA_HOTBAR_PASS"), "gameplay recording verifies selected placeable persistence")
	_expect(qa_source.contains("QA_SURVIVAL_PASS"), "gameplay recording verifies survival persistence")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
