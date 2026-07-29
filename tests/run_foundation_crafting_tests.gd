extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const FurnaceRecipeBook = preload("res://src/survival/furnace_recipe_book.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")
const TreeHarvestState = preload("res://src/world/tree_harvest_state.gd")
const MiningController = preload("res://src/player/mining_controller.gd")

var _failures: int = 0


func _init() -> void:
	_test_tree_state()
	_test_station_recipes()
	_test_furnace_recipe_selection()
	_test_tree_mining_duration()
	if _failures == 0:
		print("FOUNDATION_CRAFTING_TESTS_PASS mineable_trees=true portable_crafting=true crafting_table=true furnace_selection=true")
		quit(0)
	else:
		push_error("FOUNDATION_CRAFTING_TESTS_FAILED count=%d" % _failures)
		quit(1)


func _test_tree_state() -> void:
	var transform := Transform3D(Basis.IDENTITY.scaled(Vector3(0.7, 3.1, 0.7)), Vector3(12.5, 9.2, -4.5))
	var tree_id: String = TreeHarvestState.id_for_transform(transform)
	_expect(tree_id == TreeHarvestState.id_for_position(transform.origin), "tree id is deterministic")
	var state := TreeHarvestState.new()
	_expect(state.mark_mined(tree_id, transform.origin), "tree can be marked mined")
	_expect(not state.mark_mined(tree_id, transform.origin), "tree cannot be mined twice")
	_expect(state.near_mined_tree(transform.origin + Vector3(2.0, 6.0, 0.0), 3.35), "canopy filter follows mined trunk horizontally")
	var encoded: Dictionary = state.encode()
	var restored := TreeHarvestState.new()
	_expect(restored.decode(encoded) and restored.encode() == encoded, "tree harvest persistence is deterministic")


func _test_station_recipes() -> void:
	var planks: Dictionary = RecipeBook.recipe(RecipeBook.RECIPE_PLANKS)
	_expect(StringName(str(planks.station)) == RecipeBook.STATION_HAND, "planks use portable crafting")
	_expect(int(planks.ingredients[ItemRegistry.ITEM_WOOD]) == 1 and int(planks.output_count) == 4, "one tree wood becomes four planks")
	var table: Dictionary = RecipeBook.recipe(RecipeBook.RECIPE_WORKBENCH)
	_expect(StringName(str(table.station)) == RecipeBook.STATION_HAND, "Crafting Table is portable-crafted")
	_expect(int(table.ingredients[ItemRegistry.ITEM_PLANKS]) == 4, "Crafting Table consumes four planks")
	var alloy: Dictionary = RecipeBook.recipe(RecipeBook.RECIPE_ANDESITE_ALLOY)
	_expect(StringName(str(alloy.station)) == RecipeBook.STATION_TABLE, "andesite alloy requires Crafting Table")
	var furnace: Dictionary = RecipeBook.recipe(RecipeBook.RECIPE_FURNACE)
	_expect(StringName(str(furnace.output_item)) == ItemRegistry.ITEM_FURNACE, "furnace recipe produces furnace")
	_expect(int(furnace.ingredients[ItemRegistry.ITEM_STONE]) == 8, "furnace consumes eight stone")
	_expect(RecipeBook.station_recipes(RecipeBook.STATION_HAND).size() > 8, "portable crafting has a useful recipe set")
	_expect(RecipeBook.station_recipes(RecipeBook.STATION_TABLE).size() >= 20, "Crafting Table contains Phase 1 engineering recipes")
	_expect(FurnaceRecipeBook.recipe_ids().size() == 6, "furnace exposes four smelts, kelp drying and brass alloying")


func _test_furnace_recipe_selection() -> void:
	var progression := ProgressionState.new()
	progression.unlock(ProgressionState.UNLOCK_WORKBENCH)
	var inventory := StackInventory.new()
	inventory.add(ItemRegistry.ITEM_WOOD, 2)
	inventory.add(ItemRegistry.ITEM_IRON_CONCENTRATE, 1)
	inventory.add(ItemRegistry.ITEM_KELP, 1)
	var iron: Dictionary = FurnaceRecipeBook.smelt(inventory, RecipeBook.RECIPE_IRON_INGOT, progression)
	_expect(not iron.is_empty(), "specific iron recipe runs")
	_expect(StringName(str(iron.output)) == ItemRegistry.ITEM_IRON_INGOT, "iron concentrate becomes iron ingot")
	_expect(inventory.count(ItemRegistry.ITEM_WOOD) == 1, "furnace consumes one wood fuel per operation")
	_expect(inventory.count(ItemRegistry.ITEM_KELP) == 1, "selected recipe does not consume unrelated input")
	var kelp: Dictionary = FurnaceRecipeBook.smelt(inventory, RecipeBook.RECIPE_DRIED_KELP, progression)
	_expect(not kelp.is_empty(), "specific kelp drying recipe runs")
	_expect(inventory.count(ItemRegistry.ITEM_DRIED_KELP) == 1, "kelp becomes dried kelp")
	var no_fuel := StackInventory.new()
	no_fuel.add(ItemRegistry.ITEM_COPPER_CONCENTRATE, 1)
	_expect(not FurnaceRecipeBook.can_smelt(no_fuel, RecipeBook.RECIPE_COPPER_INGOT, progression), "furnace refuses operation without fuel")
	var wrong_recipe := StackInventory.new()
	wrong_recipe.add(ItemRegistry.ITEM_WOOD, 1)
	wrong_recipe.add(ItemRegistry.ITEM_IRON_CONCENTRATE, 1)
	_expect(FurnaceRecipeBook.smelt(wrong_recipe, RecipeBook.RECIPE_COPPER_INGOT, progression).is_empty(), "furnace does not auto-substitute a different recipe")


func _test_tree_mining_duration() -> void:
	_expect(is_equal_approx(MiningController.duration_for_material(MiningController.TREE_MATERIAL_ID), MiningController.TREE_SECONDS), "trees use dedicated held-mining duration")
	_expect(MiningController.TREE_SECONDS > MiningController.STONE_SECONDS, "tree mining remains deliberate")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FOUNDATION_CRAFTING_TEST_FAIL: " + message)
