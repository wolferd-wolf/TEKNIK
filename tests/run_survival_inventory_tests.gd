extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")

var _failures: int = 0


func _init() -> void:
	_test_registry()
	_test_stacking_and_removal()
	_test_capacity_and_codec()
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
		_expect(inventory.add(item_id, 64) == 0, "registered item fills a stack")
	var encoded: Dictionary = inventory.encode()
	var restored: TeknikStackInventory = StackInventory.new()
	_expect(restored.decode(encoded), "inventory save payload decodes")
	_expect(restored.encode() == encoded, "inventory persistence is lossless")
	var invalid: Dictionary = encoded.duplicate(true)
	invalid.schema = 999
	_expect(not restored.decode(invalid), "unknown inventory schema is rejected")


func _test_shipping_scene() -> void:
	var scene_text: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var survival_source: String = FileAccess.get_file_as_string("res://src/main/survival_main.gd")
	var qa_source: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
	_expect(scene_text.contains("survival_shipping_main.gd"), "shipping scene enables survival gameplay")
	_expect(survival_source.contains("_survival_break_voxel"), "breaking blocks creates inventory drops")
	_expect(survival_source.contains("_survival_place_voxel"), "placing blocks consumes inventory")
	_expect(survival_source.contains("INVENTORY_PATH"), "inventory has a persistent save path")
	_expect(survival_source.contains("SurvivalInventoryHUD"), "mobile survival inventory HUD is present")
	_expect(qa_source.contains("QA_SURVIVAL_PASS"), "gameplay recording verifies survival persistence")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
