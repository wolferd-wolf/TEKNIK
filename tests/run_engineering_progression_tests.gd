extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_gated_progression_chain()
	_test_atomic_failure_and_persistence()
	if _failures == 0:
		print("ENGINEERING_PROGRESSION_TEST_RESULT PASS")
		quit(0)
	else:
		print("ENGINEERING_PROGRESSION_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_gated_progression_chain() -> void:
	var inventory := StackInventory.new()
	var progression := ProgressionState.new()
	_expect(
		RecipeBook.available_recipes(progression) == [
			RecipeBook.RECIPE_STONE_GEAR,
			RecipeBook.RECIPE_WORKBENCH,
			RecipeBook.RECIPE_PLANT_FIBER,
		],
		"only hand recipes are initially visible"
	)
	_expect(not RecipeBook.can_craft(inventory, RecipeBook.RECIPE_CRUSHED_STONE, progression), "processing is progression-gated")
	_expect(not RecipeBook.can_craft(inventory, RecipeBook.RECIPE_ANDESITE_ALLOY, progression), "andesite engineering starts locked")
	_expect(not RecipeBook.can_craft(inventory, RecipeBook.RECIPE_BRASS_INGOT, progression), "brass engineering starts locked")
	_expect(not RecipeBook.can_craft(inventory, RecipeBook.RECIPE_STONE_CRUSHER, progression), "crusher is kinetic-progression-gated")

	inventory.add(ItemRegistry.ITEM_STONE, 8)
	inventory.add(ItemRegistry.ITEM_STONE_GEAR, 1)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_WORKBENCH, progression), "workbench crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_WORKBENCH), "workbench unlock is granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_STONE, 2)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_CRUSHED_STONE, progression), "raw stone processes into crushed stone")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_STONE_PROCESSING), "processing unlock is granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_STONE, 2)
	inventory.add(ItemRegistry.ITEM_ZINC_INGOT, 1)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_ANDESITE_ALLOY, progression), "andesite alloy crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_ANDESITE_ENGINEERING), "andesite engineering unlock is granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_COPPER_INGOT, 1)
	inventory.add(ItemRegistry.ITEM_ZINC_INGOT, 1)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_BRASS_INGOT, progression), "brass crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_BRASS_ENGINEERING), "brass engineering unlock is granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_SHAFT, 1)
	inventory.add(ItemRegistry.ITEM_COGWHEEL, 1)
	inventory.add(ItemRegistry.ITEM_ANDESITE_ALLOY, 1)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_HAND_CRANK, progression), "Phase 1 hand crank crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_KINETIC_STARTER), "kinetic starter unlock is granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_STONE, 6)
	inventory.add(ItemRegistry.ITEM_CRUSHED_STONE, 2)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_STONE_CRUSHER, progression), "stone crusher remains connected to kinetic progression")
	_expect(inventory.count(ItemRegistry.ITEM_STONE_CRUSHER) == 1, "crusher part exists")


func _test_atomic_failure_and_persistence() -> void:
	var inventory := StackInventory.new()
	var progression := ProgressionState.new()
	var before: Dictionary = inventory.encode()
	_expect(not RecipeBook.craft(inventory, RecipeBook.RECIPE_WORKBENCH, progression), "missing-material craft fails")
	_expect(inventory.encode() == before, "failed progression craft remains atomic")
	for unlock_id: StringName in [
		ProgressionState.UNLOCK_WORKBENCH,
		ProgressionState.UNLOCK_STONE_PROCESSING,
		ProgressionState.UNLOCK_ANDESITE_ENGINEERING,
		ProgressionState.UNLOCK_BRASS_ENGINEERING,
	]:
		progression.unlock(unlock_id)
	var encoded: Dictionary = progression.encode()
	var restored := ProgressionState.new()
	_expect(restored.decode(encoded), "progression payload decodes")
	_expect(restored.encode() == encoded, "progression persistence is lossless")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
