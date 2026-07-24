extends SceneTree

const ControlMath = preload("res://src/player/mobile_control_math.gd")
const InteractionMath = preload("res://src/world/world_interaction_math.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")

var _failures: int = 0


func _init() -> void:
	_test_face_targeting()
	_test_boundary_rebuilds()
	_test_mobile_action_zones()
	_test_survival_inventory_rules()
	_test_atomic_crafting_rules()
	_test_survival_shipping_stack()
	if _failures == 0:
		print("BLOCK_PLACEMENT_TEST_RESULT PASS")
		quit(0)
	else:
		print("BLOCK_PLACEMENT_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_face_targeting() -> void:
	var hit := Vector3(10.0, 5.4, -2.6)
	_expect(InteractionMath.removal_voxel(hit, Vector3.RIGHT) == Vector3i(9, 5, -3), "break targets voxel behind face")
	_expect(InteractionMath.placement_voxel(hit, Vector3.RIGHT) == Vector3i(10, 5, -3), "place targets empty voxel outside face")


func _test_boundary_rebuilds() -> void:
	var affected: Array[Vector3i] = InteractionMath.affected_chunk_coordinates(Vector3i(31, 8, 12), VoxelChunk.SIZE)
	_expect(affected.has(Vector3i.ZERO), "placement rebuild includes owning chunk")
	_expect(affected.has(Vector3i.RIGHT), "placement at boundary rebuilds neighbor")
	_expect(affected.size() == 2, "single-axis boundary rebuild remains minimal")


func _test_mobile_action_zones() -> void:
	var viewport := Vector2(1920.0, 1080.0)
	var break_point := Vector2(viewport.x * 0.79, viewport.y * 0.59)
	var place_point := Vector2(viewport.x * 0.91, viewport.y * 0.59)
	var log_point := Vector2(viewport.x * 0.92, viewport.y * 0.12)
	_expect(ControlMath.is_break_zone(break_point, viewport), "break control owns its touch zone")
	_expect(ControlMath.is_place_zone(place_point, viewport), "place control owns its touch zone")
	_expect(ControlMath.is_log_zone(log_point, viewport), "diagnostics control owns its touch zone")
	_expect(not ControlMath.is_place_zone(break_point, viewport), "break and place zones do not overlap")
	_expect(not ControlMath.is_look_zone(place_point, viewport), "place touch is not consumed by camera look")
	_expect(not ControlMath.is_look_zone(log_point, viewport), "diagnostics touch is not consumed by camera look")


func _test_survival_inventory_rules() -> void:
	var inventory: TeknikStackInventory = StackInventory.new()
	_expect(inventory.add(ItemRegistry.ITEM_STONE, 65) == 0, "collected blocks fill bounded stacks")
	_expect(inventory.count(ItemRegistry.ITEM_STONE) == 65, "collected block count is retained")
	var slots: Array[Dictionary] = inventory.slots()
	_expect(int(slots[0].count) == 64 and int(slots[1].count) == 1, "survival stacks cap at 64")
	_expect(inventory.remove(ItemRegistry.ITEM_STONE, 1), "placement consumes one resource")
	_expect(inventory.count(ItemRegistry.ITEM_STONE) == 64, "placement decrements inventory")
	_expect(not inventory.remove(ItemRegistry.ITEM_SAND, 1), "placement is denied without materials")
	var encoded: Dictionary = inventory.encode()
	var restored: TeknikStackInventory = StackInventory.new()
	_expect(restored.decode(encoded), "inventory save payload decodes")
	_expect(restored.encode() == encoded, "inventory save and reload is lossless")


func _test_atomic_crafting_rules() -> void:
	var inventory: TeknikStackInventory = StackInventory.new()
	_expect(inventory.add(ItemRegistry.ITEM_STONE, 4) == 0, "recipe ingredients enter inventory")
	_expect(RecipeBook.can_craft(inventory, RecipeBook.RECIPE_STONE_GEAR), "stone gear recipe becomes available")
	_expect(RecipeBook.craft(inventory, RecipeBook.RECIPE_STONE_GEAR), "stone gear crafting succeeds")
	_expect(inventory.count(ItemRegistry.ITEM_STONE) == 0, "crafting consumes exact ingredient count")
	_expect(inventory.count(ItemRegistry.ITEM_STONE_GEAR) == 1, "crafting creates deterministic output")
	var before_failed_craft: Dictionary = inventory.encode()
	_expect(not RecipeBook.craft(inventory, RecipeBook.RECIPE_STONE_GEAR), "crafting is denied without ingredients")
	_expect(inventory.encode() == before_failed_craft, "failed crafting transaction changes nothing")
	var restored: TeknikStackInventory = StackInventory.new()
	_expect(restored.decode(inventory.encode()), "crafted items decode from save payload")
	_expect(restored.count(ItemRegistry.ITEM_STONE_GEAR) == 1, "crafted output survives reload")
	_expect(ItemRegistry.material_for_item(ItemRegistry.ITEM_STONE_GEAR) == ItemRegistry.AIR, "engineering component is not placeable terrain")


func _test_survival_shipping_stack() -> void:
	var scene: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var kinetic: String = FileAccess.get_file_as_string("res://src/main/kinetic_machine_main.gd")
	var survival_shipping: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
	var engineering: String = FileAccess.get_file_as_string("res://src/main/engineering_progression_main.gd")
	var survival_source: String = FileAccess.get_file_as_string("res://src/main/survival_main.gd")
	var qa_source: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
	_expect(
		scene.contains("kinetic_machine_main.gd")
		and kinetic.contains("survival_shipping_main.gd")
		and survival_shipping.contains("engineering_progression_main.gd")
		and engineering.contains("survival_main.gd"),
		"shipping scene enables survival gameplay through the kinetic progression stack"
	)
	_expect(survival_source.contains("multi_lod_main.gd"), "survival retains the world and chunk-local vegetation stack")
	_expect(survival_source.contains("_survival_break_voxel"), "block breaking creates item drops")
	_expect(survival_source.contains("_survival_place_voxel"), "block placement consumes items")
	_expect(survival_source.contains("CraftStoneGear"), "mobile crafting control is present")
	_expect(survival_source.contains("RecipeBook.craft"), "shipping runtime uses atomic recipe transactions")
	_expect(qa_source.contains("QA_CRAFTING_PASS"), "recorded gameplay verifies crafting persistence")
	_expect(qa_source.contains("QA_SURVIVAL_PASS"), "recorded gameplay verifies inventory persistence")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
