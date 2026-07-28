extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const FurnaceRecipeBook = preload("res://src/survival/furnace_recipe_book.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_station_gating_and_progression_chain()
	_test_atomic_failure_and_persistence()
	if _failures == 0:
		print("ENGINEERING_PROGRESSION_TEST_RESULT PASS station_gating=true furnace_unlocks=true")
		quit(0)
	else:
		print("ENGINEERING_PROGRESSION_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_station_gating_and_progression_chain() -> void:
	var inventory := StackInventory.new()
	var progression := ProgressionState.new()
	var hand_recipes: Array[StringName] = RecipeBook.available_recipes_for_station(progression, RecipeBook.STATION_HAND)
	var table_recipes: Array[StringName] = RecipeBook.available_recipes_for_station(progression, RecipeBook.STATION_TABLE)
	var furnace_recipes: Array[StringName] = RecipeBook.available_recipes_for_station(progression, RecipeBook.STATION_FURNACE)
	_expect(RecipeBook.RECIPE_PLANKS in hand_recipes, "portable crafting initially exposes planks")
	_expect(RecipeBook.RECIPE_WORKBENCH in hand_recipes, "portable crafting exposes Crafting Table")
	_expect(RecipeBook.RECIPE_FURNACE in hand_recipes, "portable crafting exposes Furnace")
	_expect(table_recipes.is_empty(), "table recipes remain unavailable before Crafting Table unlock")
	_expect(RecipeBook.RECIPE_DRIED_KELP in furnace_recipes, "basic furnace drying is visible from hand-crafting stage")
	_expect(not RecipeBook.can_craft_at_station(inventory, RecipeBook.RECIPE_PLANKS, progression, RecipeBook.STATION_TABLE), "hand recipe cannot be used at Crafting Table")

	inventory.add(ItemRegistry.ITEM_WOOD, 1)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_PLANKS, progression, RecipeBook.STATION_HAND), "portable crafting makes four planks")
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_WORKBENCH, progression, RecipeBook.STATION_HAND), "Crafting Table is made from planks")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_WORKBENCH), "Crafting Table unlock is granted")
	_expect(RecipeBook.RECIPE_CRUSHED_STONE in RecipeBook.available_recipes_for_station(progression, RecipeBook.STATION_TABLE), "Crafting Table exposes stone processing")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_STONE, 2)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_CRUSHED_STONE, progression, RecipeBook.STATION_TABLE), "Crafting Table starts stone processing")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_STONE_PROCESSING), "stone processing unlock is granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_ANDESITE, 2)
	inventory.add(ItemRegistry.ITEM_IRON_NUGGET, 2)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_ANDESITE_ALLOY, progression, RecipeBook.STATION_TABLE), "Crafting Table makes andesite alloy")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_ANDESITE_ENGINEERING), "andesite engineering unlock is granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_WOOD, 1)
	inventory.add(ItemRegistry.ITEM_COPPER_INGOT, 1)
	inventory.add(ItemRegistry.ITEM_ZINC_INGOT, 1)
	_expect(not RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_BRASS_INGOT, progression, RecipeBook.STATION_TABLE), "heated brass cannot be crafted at table")
	var brass: Dictionary = FurnaceRecipeBook.smelt(inventory, RecipeBook.RECIPE_BRASS_INGOT, progression)
	_expect(not brass.is_empty(), "furnace performs heated brass operation")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_BRASS_ENGINEERING), "furnace operation grants brass engineering")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_PLANKS, 3)
	inventory.add(ItemRegistry.ITEM_ANDESITE_ALLOY, 1)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_HAND_CRANK, progression, RecipeBook.STATION_TABLE), "Create-derived hand crank crafts at table")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_KINETIC_STARTER), "kinetic starter unlock is granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_STONE, 6)
	inventory.add(ItemRegistry.ITEM_CRUSHED_STONE, 2)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_STONE_CRUSHER, progression, RecipeBook.STATION_TABLE), "stone crusher remains connected to kinetic progression")
	_expect(inventory.count(ItemRegistry.ITEM_STONE_CRUSHER) == 1, "crusher item is produced")


func _test_atomic_failure_and_persistence() -> void:
	var inventory := StackInventory.new()
	var progression := ProgressionState.new()
	var before: Dictionary = inventory.encode()
	_expect(not RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_WORKBENCH, progression, RecipeBook.STATION_HAND), "missing-material craft fails")
	_expect(inventory.encode() == before, "failed craft remains atomic")
	inventory.add(ItemRegistry.ITEM_WOOD, 1)
	_expect(not RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_PLANKS, progression, RecipeBook.STATION_FURNACE), "wrong-station craft fails")
	for unlock_id: StringName in [
		ProgressionState.UNLOCK_WORKBENCH,
		ProgressionState.UNLOCK_STONE_PROCESSING,
		ProgressionState.UNLOCK_ANDESITE_ENGINEERING,
		ProgressionState.UNLOCK_BRASS_ENGINEERING,
		ProgressionState.UNLOCK_PRECISION_ENGINEERING,
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
