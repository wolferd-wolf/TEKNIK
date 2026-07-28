extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_catalog()
	_test_inventory_migration_and_capacity()
	_test_recipe_coverage_and_craftability()
	_test_progression_chain()
	if _failures == 0:
		print("PHASE_ONE_ITEM_TESTS_PASS items=", ItemRegistry.phase_one_items().size(), " registered=", ItemRegistry.registered_items().size(), " recipes=", RecipeBook.registered_recipes().size(), " inventory_slots=", StackInventory.SLOT_COUNT, " hotbar_slots=", ItemRegistry.placeable_items().size(), " wood_furnace_foundation=true original_assets_only=true")
		quit(0)
	else:
		push_error("PHASE_ONE_ITEM_TESTS_FAILED count=%d" % _failures)
		quit(1)


func _test_catalog() -> void:
	var expected: Array[StringName] = [ItemRegistry.ITEM_ANDESITE_ALLOY, ItemRegistry.ITEM_ZINC_INGOT, ItemRegistry.ITEM_BRASS_INGOT, ItemRegistry.ITEM_COPPER_SHEET, ItemRegistry.ITEM_BRASS_SHEET, ItemRegistry.ITEM_IRON_SHEET, ItemRegistry.ITEM_GOLD_SHEET, ItemRegistry.ITEM_ANDESITE_CASING, ItemRegistry.ITEM_BRASS_CASING, ItemRegistry.ITEM_SHAFT, ItemRegistry.ITEM_COGWHEEL, ItemRegistry.ITEM_LARGE_COGWHEEL, ItemRegistry.ITEM_BELT_CONNECTOR, ItemRegistry.ITEM_MECHANICAL_BEARING, ItemRegistry.ITEM_HAND_CRANK, ItemRegistry.ITEM_WRENCH, ItemRegistry.ITEM_ELECTRON_TUBE, ItemRegistry.ITEM_PRECISION_MECHANISM, ItemRegistry.ITEM_EMPTY_BLAZE_BURNER]
	_expect(ItemRegistry.phase_one_items() == expected, "Phase 1 order is complete and deterministic")
	_expect(expected.size() == 19, "Phase 1 contains the requested nineteen items")
	_expect(ItemRegistry.registered_items().size() == 38, "wood and furnace extend the catalog")
	_expect(ItemRegistry.placeable_items().size() == 9, "furnace extends the hotbar by one station")
	_expect(ItemRegistry.is_registered(ItemRegistry.ITEM_WOOD), "wood is registered")
	_expect(ItemRegistry.is_object_placeable(ItemRegistry.ITEM_FURNACE), "furnace is object-placeable")
	_expect(ItemRegistry.display_name(ItemRegistry.ITEM_WORKBENCH) == "Crafting Bench", "starter workbench is presented as a crafting bench")
	for item_id: StringName in ItemRegistry.registered_items():
		_expect(ItemRegistry.is_registered(item_id), "registered item resolves: " + str(item_id))
		_expect(not ItemRegistry.display_name(item_id).is_empty(), "item has display name: " + str(item_id))
		_expect(not ItemRegistry.category(item_id).is_empty(), "item has category: " + str(item_id))
		_expect(not ItemRegistry.description(item_id).is_empty(), "item has original description: " + str(item_id))
		_expect(ItemRegistry.max_stack(item_id) > 0, "item has stack limit: " + str(item_id))
	_expect(ItemRegistry.max_stack(ItemRegistry.ITEM_WRENCH) == 1, "wrench is a durable single tool")
	for material: int in [ItemRegistry.STONE, ItemRegistry.SOIL, ItemRegistry.GRASS, ItemRegistry.SAND]:
		var item_id: StringName = ItemRegistry.item_for_material(material)
		_expect(ItemRegistry.material_for_item(item_id) == material, "terrain material mapping round-trips")


func _test_inventory_migration_and_capacity() -> void:
	var legacy_slots: Array[Dictionary] = []
	for index: int in range(StackInventory.LEGACY_SLOT_COUNT):
		legacy_slots.append({"item": "", "count": 0})
	legacy_slots[0] = {"item": str(ItemRegistry.ITEM_STONE), "count": 12}
	legacy_slots[1] = {"item": str(ItemRegistry.ITEM_WORKBENCH), "count": 1}
	var migrated := StackInventory.new()
	_expect(migrated.decode({"schema": StackInventory.LEGACY_SCHEMA, "slots": legacy_slots}), "legacy twelve-slot save migrates")
	_expect(migrated.slots().size() == StackInventory.SLOT_COUNT, "migration expands to forty slots")
	_expect(migrated.count(ItemRegistry.ITEM_STONE) == 12, "migration preserves stone")
	_expect(migrated.count(ItemRegistry.ITEM_WORKBENCH) == 1, "migration preserves station items")
	var previous_slots: Array[Dictionary] = []
	for index: int in range(StackInventory.PREVIOUS_SLOT_COUNT):
		previous_slots.append({"item": "", "count": 0})
	previous_slots[0] = {"item": str(ItemRegistry.ITEM_GRASS), "count": 5}
	var previous := StackInventory.new()
	_expect(previous.decode({"schema": StackInventory.PREVIOUS_SCHEMA, "slots": previous_slots}), "thirty-six-slot save migrates")
	_expect(previous.slots().size() == StackInventory.SLOT_COUNT, "previous save expands to forty slots")
	_expect(previous.count(ItemRegistry.ITEM_GRASS) == 5, "previous save preserves items")
	var full := StackInventory.new()
	for item_id: StringName in ItemRegistry.registered_items():
		_expect(full.add(item_id, 1) == 0, "catalog item fits inventory: " + str(item_id))
	_expect(full.slots().size() == 40, "inventory exposes forty slots")
	var encoded: Dictionary = full.encode()
	_expect(int(encoded.schema) == StackInventory.SCHEMA, "expanded inventory writes schema three")
	var restored := StackInventory.new()
	_expect(restored.decode(encoded), "expanded inventory save decodes")
	_expect(restored.encode() == encoded, "expanded inventory persistence is lossless")


func _test_recipe_coverage_and_craftability() -> void:
	var output_items: Dictionary = {}
	var progression := ProgressionState.new()
	for unlock_id: StringName in [ProgressionState.UNLOCK_WORKBENCH, ProgressionState.UNLOCK_STONE_PROCESSING, ProgressionState.UNLOCK_ANDESITE_ENGINEERING, ProgressionState.UNLOCK_BRASS_ENGINEERING, ProgressionState.UNLOCK_PRECISION_ENGINEERING, ProgressionState.UNLOCK_KINETIC_STARTER]:
		progression.unlock(unlock_id)
	for recipe_id: StringName in RecipeBook.registered_recipes():
		var definition: Dictionary = RecipeBook.recipe(recipe_id)
		_expect(not definition.is_empty(), "recipe definition exists: " + str(recipe_id))
		var output := StringName(str(definition.get("output_item", "")))
		var output_count: int = int(definition.get("output_count", 0))
		output_items[output] = true
		_expect(ItemRegistry.is_registered(output), "recipe output is registered: " + str(recipe_id))
		_expect(output_count > 0, "recipe output count is positive: " + str(recipe_id))
		var inventory := StackInventory.new()
		for ingredient_variant: Variant in (definition.ingredients as Dictionary).keys():
			var ingredient := StringName(str(ingredient_variant))
			var amount: int = int(definition.ingredients[ingredient_variant])
			_expect(ItemRegistry.is_registered(ingredient), "ingredient is registered: " + str(ingredient))
			_expect(inventory.add(ingredient, amount) == 0, "ingredient fits recipe test inventory")
		_expect(RecipeBook.can_craft(inventory, recipe_id, progression), "recipe is craftable with declared ingredients: " + str(recipe_id))
		_expect(RecipeBook.craft(inventory, recipe_id, progression), "recipe craft succeeds: " + str(recipe_id))
		_expect(inventory.count(output) == output_count, "recipe creates declared output: " + str(recipe_id))
	for item_id: StringName in ItemRegistry.phase_one_items():
		_expect(output_items.has(item_id), "Phase 1 item has a recipe: " + str(item_id))
	_expect(output_items.has(ItemRegistry.ITEM_WORKBENCH), "crafting bench has a recipe")
	_expect(output_items.has(ItemRegistry.ITEM_FURNACE), "furnace has a recipe")


func _test_progression_chain() -> void:
	var progression := ProgressionState.new()
	var inventory := StackInventory.new()
	inventory.add(ItemRegistry.ITEM_WOOD, 4)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_WORKBENCH, progression), "crafting bench crafts from mined wood")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_WORKBENCH), "crafting bench unlock granted")
	inventory.clear()
	inventory.add(ItemRegistry.ITEM_STONE, 8)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_FURNACE, progression), "furnace crafts from stone")
	_expect(inventory.count(ItemRegistry.ITEM_FURNACE) == 1, "furnace recipe produces a placeable station")
	inventory.clear()
	inventory.add(ItemRegistry.ITEM_STONE, 2)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_CRUSHED_STONE, progression), "stone processing starts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_STONE_PROCESSING), "stone processing unlock granted")
	inventory.clear()
	inventory.add(ItemRegistry.ITEM_STONE, 2)
	inventory.add(ItemRegistry.ITEM_ZINC_INGOT, 1)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_ANDESITE_ALLOY, progression), "andesite alloy crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_ANDESITE_ENGINEERING), "andesite engineering unlock granted")
	inventory.clear()
	inventory.add(ItemRegistry.ITEM_COPPER_INGOT, 1)
	inventory.add(ItemRegistry.ITEM_ZINC_INGOT, 1)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_BRASS_INGOT, progression), "brass crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_BRASS_ENGINEERING), "brass engineering unlock granted")
	inventory.clear()
	inventory.add(ItemRegistry.ITEM_SHAFT, 1)
	inventory.add(ItemRegistry.ITEM_COGWHEEL, 1)
	inventory.add(ItemRegistry.ITEM_ANDESITE_ALLOY, 1)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_HAND_CRANK, progression), "Phase 1 hand crank crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_KINETIC_STARTER), "kinetic starter unlock remains connected")
	inventory.clear()
	inventory.add(ItemRegistry.ITEM_GOLD_SHEET, 1)
	inventory.add(ItemRegistry.ITEM_COGWHEEL, 1)
	inventory.add(ItemRegistry.ITEM_LARGE_COGWHEEL, 1)
	inventory.add(ItemRegistry.ITEM_ELECTRON_TUBE, 1)
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_PRECISION_MECHANISM, progression), "precision mechanism crafts")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_PRECISION_ENGINEERING), "precision engineering unlock granted")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("PHASE_ONE_TEST_FAIL: " + message)
