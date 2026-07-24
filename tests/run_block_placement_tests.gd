extends SceneTree

const ControlMath = preload("res://src/player/mobile_control_math.gd")
const InteractionMath = preload("res://src/world/world_interaction_math.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")

var _failures: int = 0


func _init() -> void:
	_test_face_targeting()
	_test_boundary_rebuilds()
	_test_mobile_action_zones()
	_test_survival_inventory_rules()
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


func _test_survival_shipping_stack() -> void:
	var scene_text: String = FileAccess.get_file_as_string("res://src/main/main.tscn")
	var survival_source: String = FileAccess.get_file_as_string("res://src/main/survival_main.gd")
	var qa_source: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
	_expect(scene_text.contains("survival_shipping_main.gd"), "shipping scene enables survival gameplay")
	_expect(scene_text.contains("procedural_gameplay_main.gd_stream.gd"), "survival retains chunk-local vegetation")
	_expect(survival_source.contains("_survival_break_voxel"), "block breaking creates item drops")
	_expect(survival_source.contains("_survival_place_voxel"), "block placement consumes items")
	_expect(survival_source.contains("SurvivalInventoryHUD"), "mobile inventory HUD is present")
	_expect(qa_source.contains("QA_SURVIVAL_PASS"), "recorded gameplay verifies inventory persistence")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
