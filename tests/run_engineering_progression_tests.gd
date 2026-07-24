extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_gated_progression_chain()
	_test_atomic_failure_and_persistence()
	_test_shipping_stack()
	if _failures == 0:
		print("ENGINEERING_PROGRESSION_TEST_RESULT PASS")
		quit(0)
	else:
		print("ENGINEERING_PROGRESSION_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_gated_progression_chain() -> void:
	var inventory := StackInventory.new()
	var progression := ProgressionState.new()
	_expect(RecipeBook.available_recipes(progression) == [RecipeBook.RECIPE_STONE_GEAR, RecipeBook.RECIPE_WORKBENCH], "only hand recipes are initially visible")
	_expect(not RecipeBook.can_craft(inventory, RecipeBook.RECIPE_CRUSHED_STONE, progression), "processing is progression-gated")
	_expect(inventory.add(ItemRegistry.ITEM_STONE, 24) == 0, "starter stone enters inventory")
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_STONE_GEAR, progression), "starter gear crafts")
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_WORKBENCH, progression), "workbench crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_WORKBENCH), "workbench unlock is granted")
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_CRUSHED_STONE, progression), "raw stone processes into crushed stone")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_STONE_PROCESSING), "processing unlock is granted")
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_STONE_SHAFT, progression), "processed material crafts a shaft")
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_STONE_GEAR, progression), "second gear crafts")
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_HAND_CRANK, progression), "starter kinetic assembly crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_KINETIC_STARTER), "kinetic starter unlock is granted")
	_expect(inventory.count(ItemRegistry.ITEM_HAND_CRANK) == 1, "hand crank output exists")


func _test_atomic_failure_and_persistence() -> void:
	var inventory := StackInventory.new()
	var progression := ProgressionState.new()
	var before: Dictionary = inventory.encode()
	_expect(not RecipeBook.craft(inventory, RecipeBook.RECIPE_WORKBENCH, progression), "missing-material craft fails")
	_expect(inventory.encode() == before, "failed progression craft remains atomic")
	progression.unlock(ProgressionState.UNLOCK_WORKBENCH)
	var encoded: Dictionary = progression.encode()
	var restored := ProgressionState.new()
	_expect(restored.decode(encoded), "progression payload decodes")
	_expect(restored.encode() == encoded, "progression persistence is lossless")


func _test_shipping_stack() -> void:
	var scene_text: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var runtime: String = FileAccess.get_file_as_string("res://src/main/engineering_progression_main.gd")
	var shipping: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
	_expect(scene_text.contains("survival_shipping_main.gd"), "shipping scene retains survival entry point")
	_expect(runtime.contains("EngineeringRecipeHUD"), "scalable mobile recipe panel is present")
	_expect(runtime.contains("PROGRESSION_PATH"), "recipe unlocks have a persistent save path")
	_expect(shipping.contains("QA_ENGINEERING_PASS"), "recorded gameplay verifies engineering chain")
	_expect(shipping.contains("engineering_progression_main.gd"), "shipping runtime enables progression layer")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
