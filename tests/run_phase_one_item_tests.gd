extends SceneTree

const ItemRegistry = preload("res://src/survival/item_registry.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")
const FurnaceRecipeBook = preload("res://src/survival/furnace_recipe_book.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const ProgressionState = preload("res://src/survival/progression_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_catalog()
	_test_inventory_migration_and_capacity()
	_test_recipe_coverage_and_create_relationships()
	_test_station_progression_chain()
	if _failures == 0:
		print(
			"PHASE_ONE_ITEM_TESTS_PASS phase_one_items=", ItemRegistry.phase_one_items().size(),
			" registered=", ItemRegistry.registered_items().size(),
			" recipes=", RecipeBook.registered_recipes().size(),
			" inventory_slots=", StackInventory.SLOT_COUNT,
			" hand_recipes=", RecipeBook.station_recipes(RecipeBook.STATION_HAND).size(),
			" table_recipes=", RecipeBook.station_recipes(RecipeBook.STATION_TABLE).size(),
			" furnace_recipes=", RecipeBook.station_recipes(RecipeBook.STATION_FURNACE).size(),
			" create_relationships_verified=true"
		)
		quit(0)
	else:
		push_error("PHASE_ONE_ITEM_TESTS_FAILED count=%d" % _failures)
		quit(1)


func _test_catalog() -> void:
	var expected: Array[StringName] = [
		ItemRegistry.ITEM_ANDESITE_ALLOY, ItemRegistry.ITEM_ZINC_INGOT,
		ItemRegistry.ITEM_BRASS_INGOT, ItemRegistry.ITEM_COPPER_SHEET,
		ItemRegistry.ITEM_BRASS_SHEET, ItemRegistry.ITEM_IRON_SHEET,
		ItemRegistry.ITEM_GOLD_SHEET, ItemRegistry.ITEM_ANDESITE_CASING,
		ItemRegistry.ITEM_BRASS_CASING, ItemRegistry.ITEM_SHAFT,
		ItemRegistry.ITEM_COGWHEEL, ItemRegistry.ITEM_LARGE_COGWHEEL,
		ItemRegistry.ITEM_BELT_CONNECTOR, ItemRegistry.ITEM_MECHANICAL_BEARING,
		ItemRegistry.ITEM_HAND_CRANK, ItemRegistry.ITEM_WRENCH,
		ItemRegistry.ITEM_ELECTRON_TUBE, ItemRegistry.ITEM_PRECISION_MECHANISM,
		ItemRegistry.ITEM_EMPTY_BLAZE_BURNER,
	]
	_expect(ItemRegistry.phase_one_items() == expected, "Phase 1 order is complete and deterministic")
	_expect(expected.size() == 19, "Phase 1 contains nineteen requested items")
	_expect(ItemRegistry.registered_items().size() == 57, "all Create recipe dependencies are registered")
	_expect(ItemRegistry.placeable_items().size() == 9, "station and voxel hotbar remains bounded")
	_expect(ItemRegistry.display_name(ItemRegistry.ITEM_WORKBENCH) == "Crafting Table", "workbench is presented as Crafting Table")
	for dependency: StringName in [
		ItemRegistry.ITEM_PLANKS, ItemRegistry.ITEM_STRIPPED_WOOD,
		ItemRegistry.ITEM_WOODEN_SLAB, ItemRegistry.ITEM_WOODEN_ROD,
		ItemRegistry.ITEM_ANDESITE, ItemRegistry.ITEM_DRIED_KELP,
		ItemRegistry.ITEM_SAND_PAPER, ItemRegistry.ITEM_POLISHED_ROSE_QUARTZ,
		ItemRegistry.ITEM_NETHERRACK, ItemRegistry.ITEM_IRON_NUGGET,
		ItemRegistry.ITEM_INCOMPLETE_PRECISION_MECHANISM,
	]:
		_expect(ItemRegistry.is_registered(dependency), "missing Create dependency was added: " + str(dependency))
	for item_id: StringName in ItemRegistry.registered_items():
		_expect(ItemRegistry.is_registered(item_id), "registered item resolves: " + str(item_id))
		_expect(not ItemRegistry.display_name(item_id).is_empty(), "item has display name: " + str(item_id))
		_expect(not ItemRegistry.category(item_id).is_empty(), "item has category: " + str(item_id))
		_expect(not ItemRegistry.description(item_id).is_empty(), "item has description: " + str(item_id))
		_expect(ItemRegistry.max_stack(item_id) > 0, "item has stack limit: " + str(item_id))
	_expect(ItemRegistry.max_stack(ItemRegistry.ITEM_WRENCH) == 1, "wrench remains a single durable tool")


func _test_inventory_migration_and_capacity() -> void:
	var legacy_slots: Array[Dictionary] = _empty_slots(StackInventory.LEGACY_SLOT_COUNT)
	legacy_slots[0] = {"item": str(ItemRegistry.ITEM_STONE), "count": 12}
	var legacy := StackInventory.new()
	_expect(legacy.decode({"schema": StackInventory.LEGACY_SCHEMA, "slots": legacy_slots}), "twelve-slot save migrates")
	_expect(legacy.slots().size() == 64, "legacy save expands to sixty-four slots")

	var older_slots: Array[Dictionary] = _empty_slots(StackInventory.OLDER_SLOT_COUNT)
	older_slots[0] = {"item": str(ItemRegistry.ITEM_GRASS), "count": 5}
	var older := StackInventory.new()
	_expect(older.decode({"schema": StackInventory.OLDER_SCHEMA, "slots": older_slots}), "thirty-six-slot save migrates")
	_expect(older.count(ItemRegistry.ITEM_GRASS) == 5, "thirty-six-slot migration preserves items")

	var previous_slots: Array[Dictionary] = _empty_slots(StackInventory.PREVIOUS_SLOT_COUNT)
	previous_slots[0] = {"item": str(ItemRegistry.ITEM_WOOD), "count": 4}
	var previous := StackInventory.new()
	_expect(previous.decode({"schema": StackInventory.PREVIOUS_SCHEMA, "slots": previous_slots}), "forty-slot save migrates")
	_expect(previous.count(ItemRegistry.ITEM_WOOD) == 4, "forty-slot migration preserves wood")

	var full := StackInventory.new()
	for item_id: StringName in ItemRegistry.registered_items():
		_expect(full.add(item_id, 1) == 0, "catalog item fits inventory: " + str(item_id))
	_expect(full.slots().size() == 64, "inventory exposes sixty-four slots")
	var encoded: Dictionary = full.encode()
	_expect(int(encoded.schema) == StackInventory.SCHEMA, "inventory writes schema four")
	var restored := StackInventory.new()
	_expect(restored.decode(encoded), "schema-four inventory decodes")
	_expect(restored.encode() == encoded, "inventory persistence is lossless")


func _empty_slots(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index: int in range(count):
		result.append({"item": "", "count": 0})
	return result


func _test_recipe_coverage_and_create_relationships() -> void:
	var output_items: Dictionary = {}
	var progression := ProgressionState.new()
	for unlock_id: StringName in [
		ProgressionState.UNLOCK_WORKBENCH,
		ProgressionState.UNLOCK_STONE_PROCESSING,
		ProgressionState.UNLOCK_ANDESITE_ENGINEERING,
		ProgressionState.UNLOCK_BRASS_ENGINEERING,
		ProgressionState.UNLOCK_PRECISION_ENGINEERING,
		ProgressionState.UNLOCK_KINETIC_STARTER,
	]:
		progression.unlock(unlock_id)
	for recipe_id: StringName in RecipeBook.registered_recipes():
		var definition: Dictionary = RecipeBook.recipe(recipe_id)
		_expect(not definition.is_empty(), "recipe definition exists: " + str(recipe_id))
		var station := StringName(str(definition.get("station", "")))
		_expect(station in [RecipeBook.STATION_HAND, RecipeBook.STATION_TABLE, RecipeBook.STATION_FURNACE], "recipe declares a valid station: " + str(recipe_id))
		var output := StringName(str(definition.get("output_item", "")))
		output_items[output] = true
		_expect(ItemRegistry.is_registered(output), "recipe output is registered: " + str(recipe_id))
		_expect(int(definition.get("output_count", 0)) > 0, "recipe output count is positive: " + str(recipe_id))
		for ingredient_variant: Variant in (definition.ingredients as Dictionary).keys():
			_expect(ItemRegistry.is_registered(StringName(str(ingredient_variant))), "recipe ingredient is registered: " + str(ingredient_variant))
	for item_id: StringName in ItemRegistry.phase_one_items():
		_expect(output_items.has(item_id), "Phase 1 item has an obtainable recipe: " + str(item_id))

	_expect(_ingredients(RecipeBook.RECIPE_SHAFT) == {ItemRegistry.ITEM_ANDESITE_ALLOY: 2}, "shaft keeps Create's two-alloy relationship")
	_expect(int(RecipeBook.recipe(RecipeBook.RECIPE_SHAFT).output_count) == 8, "shaft recipe yields eight")
	_expect(_ingredients(RecipeBook.RECIPE_COGWHEEL) == {ItemRegistry.ITEM_SHAFT: 1, ItemRegistry.ITEM_PLANKS: 1}, "cogwheel uses shaft plus planks")
	_expect(_ingredients(RecipeBook.RECIPE_LARGE_COGWHEEL) == {ItemRegistry.ITEM_SHAFT: 1, ItemRegistry.ITEM_PLANKS: 2}, "large cogwheel uses shaft plus two planks")
	_expect(_ingredients(RecipeBook.RECIPE_BELT_CONNECTOR) == {ItemRegistry.ITEM_DRIED_KELP: 6}, "belt connector uses six dried kelp")
	_expect(_ingredients(RecipeBook.RECIPE_MECHANICAL_BEARING) == {ItemRegistry.ITEM_WOODEN_SLAB: 1, ItemRegistry.ITEM_ANDESITE_CASING: 1, ItemRegistry.ITEM_SHAFT: 1}, "mechanical bearing preserves slab-casing-shaft structure")
	_expect(_ingredients(RecipeBook.RECIPE_WRENCH) == {ItemRegistry.ITEM_GOLD_SHEET: 3, ItemRegistry.ITEM_COGWHEEL: 1, ItemRegistry.ITEM_WOODEN_ROD: 1}, "wrench preserves gold-sheet cogwheel handle structure")
	_expect(_ingredients(RecipeBook.RECIPE_ELECTRON_TUBE) == {ItemRegistry.ITEM_POLISHED_ROSE_QUARTZ: 1, ItemRegistry.ITEM_IRON_SHEET: 1}, "electron tube uses polished rose quartz and iron sheet")
	_expect(_ingredients(RecipeBook.RECIPE_EMPTY_BLAZE_BURNER) == {ItemRegistry.ITEM_IRON_SHEET: 4, ItemRegistry.ITEM_NETHERRACK: 1}, "empty burner uses four iron sheets around netherrack")
	_expect(_ingredients(RecipeBook.RECIPE_PRECISION_MECHANISM) == {ItemRegistry.ITEM_INCOMPLETE_PRECISION_MECHANISM: 1, ItemRegistry.ITEM_COGWHEEL: 5, ItemRegistry.ITEM_LARGE_COGWHEEL: 5, ItemRegistry.ITEM_IRON_NUGGET: 5}, "precision mechanism represents five assembly loops")


func _ingredients(recipe_id: StringName) -> Dictionary:
	return RecipeBook.recipe(recipe_id).ingredients


func _test_station_progression_chain() -> void:
	var progression := ProgressionState.new()
	var inventory := StackInventory.new()
	inventory.add(ItemRegistry.ITEM_WOOD, 1)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_PLANKS, progression, RecipeBook.STATION_HAND), "portable crafting makes planks")
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_WORKBENCH, progression, RecipeBook.STATION_HAND), "portable crafting makes Crafting Table")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_WORKBENCH), "Crafting Table grants workbench unlock")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_STONE, 2)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_CRUSHED_STONE, progression, RecipeBook.STATION_TABLE), "table starts stone processing")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_STONE_PROCESSING), "stone processing unlock granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_ANDESITE, 2)
	inventory.add(ItemRegistry.ITEM_IRON_NUGGET, 2)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_ANDESITE_ALLOY, progression, RecipeBook.STATION_TABLE), "table crafts Create-derived andesite alloy")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_ANDESITE_ENGINEERING), "andesite engineering unlock granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_WOOD, 1)
	inventory.add(ItemRegistry.ITEM_COPPER_INGOT, 1)
	inventory.add(ItemRegistry.ITEM_ZINC_INGOT, 1)
	var brass: Dictionary = FurnaceRecipeBook.smelt(inventory, RecipeBook.RECIPE_BRASS_INGOT, progression)
	_expect(not brass.is_empty(), "furnace performs heated brass alloying")
	_expect(inventory.count(ItemRegistry.ITEM_BRASS_INGOT) == 2, "heated alloying yields two brass ingots")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_BRASS_ENGINEERING), "brass engineering unlock granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_PLANKS, 3)
	inventory.add(ItemRegistry.ITEM_ANDESITE_ALLOY, 1)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_HAND_CRANK, progression, RecipeBook.STATION_TABLE), "table crafts Create-derived hand crank")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_KINETIC_STARTER), "kinetic starter unlock granted")

	inventory.clear()
	inventory.add(ItemRegistry.ITEM_INCOMPLETE_PRECISION_MECHANISM, 1)
	inventory.add(ItemRegistry.ITEM_COGWHEEL, 5)
	inventory.add(ItemRegistry.ITEM_LARGE_COGWHEEL, 5)
	inventory.add(ItemRegistry.ITEM_IRON_NUGGET, 5)
	_expect(RecipeBook.craft_at_station(inventory, RecipeBook.RECIPE_PRECISION_MECHANISM, progression, RecipeBook.STATION_TABLE), "table completes five-loop precision mechanism adaptation")
	_expect(progression.is_unlocked(ProgressionState.UNLOCK_PRECISION_ENGINEERING), "precision engineering unlock granted")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("PHASE_ONE_TEST_FAIL: " + message)
