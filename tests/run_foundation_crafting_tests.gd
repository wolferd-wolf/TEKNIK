extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const FurnaceRecipeBook = preload("res://src/survival/furnace_recipe_book.gd")
const TreeHarvestState = preload("res://src/world/tree_harvest_state.gd")
const MiningController = preload("res://src/player/mining_controller.gd")

var _failures: int = 0


func _init() -> void:
	_test_tree_state()
	_test_crafting_bench_and_furnace_recipes()
	_test_furnace_processing()
	_test_tree_mining_duration()
	if _failures == 0:
		print("FOUNDATION_CRAFTING_TESTS_PASS wood_yield_item=true crafting_bench=true furnace=true mineable_tree_state=true")
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
	_expect(state.is_mined(tree_id), "mined tree id is retained")
	_expect(state.near_mined_tree(transform.origin + Vector3(2.0, 6.0, 0.0), 3.35), "canopy filter follows mined trunk horizontally")
	var encoded: Dictionary = state.encode()
	var restored := TreeHarvestState.new()
	_expect(restored.decode(encoded), "tree harvest save decodes")
	_expect(restored.encode() == encoded, "tree harvest persistence is deterministic")


func _test_crafting_bench_and_furnace_recipes() -> void:
	var bench: Dictionary = RecipeBook.recipe(RecipeBook.RECIPE_WORKBENCH)
	_expect(StringName(str(bench.output_item)) == ItemRegistry.ITEM_WORKBENCH, "bench recipe produces crafting bench")
	_expect(int(bench.ingredients[ItemRegistry.ITEM_WOOD]) == 4, "crafting bench consumes four wood")
	var furnace: Dictionary = RecipeBook.recipe(RecipeBook.RECIPE_FURNACE)
	_expect(StringName(str(furnace.output_item)) == ItemRegistry.ITEM_FURNACE, "furnace recipe produces furnace")
	_expect(int(furnace.ingredients[ItemRegistry.ITEM_STONE]) == 8, "furnace consumes eight stone")


func _test_furnace_processing() -> void:
	var inventory := StackInventory.new()
	inventory.add(ItemRegistry.ITEM_WOOD, 2)
	inventory.add(ItemRegistry.ITEM_IRON_CONCENTRATE, 1)
	var report: Dictionary = FurnaceRecipeBook.smelt_one(inventory)
	_expect(not report.is_empty(), "furnace smelts an available concentrate")
	_expect(StringName(str(report.output)) == ItemRegistry.ITEM_IRON_INGOT, "iron concentrate becomes iron ingot")
	_expect(inventory.count(ItemRegistry.ITEM_WOOD) == 1, "furnace consumes one wood fuel")
	_expect(inventory.count(ItemRegistry.ITEM_IRON_CONCENTRATE) == 0, "furnace consumes one concentrate")
	_expect(inventory.count(ItemRegistry.ITEM_IRON_INGOT) == 1, "furnace produces one ingot")
	var no_fuel := StackInventory.new()
	no_fuel.add(ItemRegistry.ITEM_COPPER_CONCENTRATE, 1)
	_expect(FurnaceRecipeBook.smelt_one(no_fuel).is_empty(), "furnace refuses to smelt without fuel")


func _test_tree_mining_duration() -> void:
	_expect(is_equal_approx(MiningController.duration_for_material(MiningController.TREE_MATERIAL_ID), MiningController.TREE_SECONDS), "trees use the dedicated held-mining duration")
	_expect(MiningController.TREE_SECONDS > MiningController.STONE_SECONDS, "tree mining is deliberate rather than instant")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FOUNDATION_CRAFTING_TEST_FAIL: " + message)
