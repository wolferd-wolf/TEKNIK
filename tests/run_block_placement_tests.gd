extends SceneTree

const ControlMath = preload("res://src/player/mobile_control_math.gd")
const ExplorationController = preload("res://src/player/exploration_controller.gd")
const MiningController = preload("res://src/player/mining_controller.gd")
const InteractionMath = preload("res://src/world/world_interaction_math.gd")
const VoxelRaycast = preload("res://src/world/voxel_raycast.gd")
const EditRebuildScheduler = preload("res://src/world/edit_rebuild_scheduler.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const ItemRegistry = preload("res://src/survival/item_registry.gd")
const StackInventory = preload("res://src/survival/stack_inventory.gd")
const RecipeBook = preload("res://src/survival/recipe_book.gd")

var _failures: int = 0


class BusyProbe:
	extends RefCounted
	var coordinates: Dictionary = {}

	func has_coordinate(coordinate: Vector3i) -> bool:
		return coordinates.has(coordinate)


func _init() -> void:
	_test_face_targeting()
	_test_straight_down_mining_aim()
	_test_authoritative_voxel_raycast()
	_test_rapid_sequential_mining()
	_test_hold_to_mine_timing()
	_test_busy_rebuild_retention()
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


func _test_straight_down_mining_aim() -> void:
	var pitch: float = ExplorationController.clamp_look_pitch(-PI * 0.5)
	var direction: Vector3 = Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD
	_expect(rad_to_deg(pitch) <= -89.0, "camera can aim almost vertically downward")
	_expect(direction.normalized().dot(Vector3.DOWN) > 0.9999, "mining ray points at the block directly below the player")
	var floor_hit := Vector3(12.5, 4.0, 8.5)
	_expect(
		InteractionMath.removal_voxel(floor_hit, Vector3.UP) == Vector3i(12, 3, 8),
		"downward mining removes the floor voxel below the hit face"
	)


func _test_authoritative_voxel_raycast() -> void:
	var solids: Dictionary = {Vector3i(2, 1, -4): true}
	var hit: Dictionary = VoxelRaycast.cast(
		Vector3(2.5, 4.5, -3.5),
		Vector3.DOWN,
		7.0,
		func(voxel: Vector3i) -> bool: return solids.has(voxel)
	)
	_expect(hit.get("voxel", Vector3i.ZERO) == Vector3i(2, 1, -4), "center ray selects the exact block below")
	_expect(float(hit.get("distance", 99.0)) < 4.0, "targeted block is inside interaction range")
	_expect(VoxelRaycast.outline_center(Vector3i(2, 1, -4)) == Vector3(2.5, 1.5, -3.5), "selection outline is centered on the targeted voxel")


func _test_rapid_sequential_mining() -> void:
	var solids: Dictionary = {
		Vector3i(0, 2, 0): true,
		Vector3i(0, 1, 0): true,
	}
	var lookup: Callable = func(voxel: Vector3i) -> bool: return solids.has(voxel)
	var first: Dictionary = VoxelRaycast.cast(Vector3(0.5, 4.5, 0.5), Vector3.DOWN, 7.0, lookup)
	_expect(first.get("voxel", Vector3i.ZERO) == Vector3i(0, 2, 0), "authoritative ray selects the top block")
	solids.erase(Vector3i(0, 2, 0))
	var second: Dictionary = VoxelRaycast.cast(Vector3(0.5, 4.5, 0.5), Vector3.DOWN, 7.0, lookup)
	_expect(second.get("voxel", Vector3i.ZERO) == Vector3i(0, 1, 0), "authoritative ray finds the next block after a visible edit")


func _test_hold_to_mine_timing() -> void:
	var mining = MiningController.new()
	var first_target := Vector3i(0, 2, 0)
	mining.set_target(first_target, ItemRegistry.STONE, 1.0)
	mining.set_pressed(true)
	_expect(mining.update(0.0).is_empty(), "pressing BREAK does not instantly remove a block")
	_expect(mining.update(0.72).is_empty(), "held mining remains incomplete before its duration")
	_expect(mining.progress() > 0.7 and mining.progress() < 0.74, "block crack progress follows the held duration")
	var completed: Dictionary = mining.update(0.28)
	_expect(completed.get("voxel", Vector3i.ZERO) == first_target, "one locked block completes at full progress")
	_expect(mining.is_waiting_for_commit(), "completed mining waits for the block to disappear visibly")
	_expect(mining.update(2.0).is_empty(), "continued holding cannot remove hidden deeper blocks")
	_expect(not mining.set_target(Vector3i(0, 1, 0), ItemRegistry.STONE, 1.0), "the target stays locked until the visible mesh commit")
	mining.notify_visible_commit()
	var next_target := Vector3i(0, 1, 0)
	_expect(mining.set_target(next_target, ItemRegistry.STONE, 1.0), "next exposed block can be acquired after visible commit")
	_expect(is_zero_approx(mining.progress()), "the next block starts from zero progress")
	mining.update(0.4)
	mining.set_pressed(false)
	_expect(mining.progress() == 0.0, "releasing BREAK cancels unfinished progress")


func _test_busy_rebuild_retention() -> void:
	var busy_coordinate := Vector3i(4, 0, -2)
	var ready_coordinate := Vector3i(5, 0, -2)
	var queue: Array[Vector3i] = [busy_coordinate, ready_coordinate]
	var resident: Dictionary = {busy_coordinate: true, ready_coordinate: true}
	var probe := BusyProbe.new()
	probe.coordinates[busy_coordinate] = true
	var selected: Vector3i = EditRebuildScheduler.take_ready(queue, resident, Callable(probe, "has_coordinate"))
	_expect(selected == ready_coordinate, "a ready edited chunk can rebuild while another is in flight")
	_expect(queue.has(busy_coordinate), "edits made during an in-flight rebuild remain queued")
	probe.coordinates.clear()
	selected = EditRebuildScheduler.take_ready(queue, resident, Callable(probe, "has_coordinate"))
	_expect(selected == busy_coordinate, "retained dirty chunk rebuilds after its stale worker completes")


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
	var capture: String = FileAccess.get_file_as_string("res://src/main/kinetic_capture_shipping_main.gd")
	var vitals: String = FileAccess.get_file_as_string("res://src/main/survival_vitals_main.gd")
	var placement: String = FileAccess.get_file_as_string("res://src/main/placement_preview_main.gd")
	var targeting: String = FileAccess.get_file_as_string("res://src/main/targeted_interaction_main.gd")
	var kinetic: String = FileAccess.get_file_as_string("res://src/main/kinetic_machine_main.gd")
	var survival_shipping: String = FileAccess.get_file_as_string("res://src/main/survival_shipping_main.gd")
	var engineering: String = FileAccess.get_file_as_string("res://src/main/engineering_progression_main.gd")
	var survival_source: String = FileAccess.get_file_as_string("res://src/main/survival_main.gd")
	var crosshair: String = FileAccess.get_file_as_string("res://src/player/block_target_crosshair.gd")
	var controller: String = FileAccess.get_file_as_string("res://src/player/exploration_controller.gd")
	var mining_controller: String = FileAccess.get_file_as_string("res://src/player/mining_controller.gd")
	var mining_visual: String = FileAccess.get_file_as_string("res://src/player/mining_block_visual.gd")
	_expect(
		scene.contains("kinetic_capture_shipping_main.gd")
		and capture.contains("survival_vitals_main.gd")
		and vitals.contains("placement_preview_main.gd")
		and placement.contains("targeted_interaction_main.gd")
		and targeting.contains("interactive_kinetic_main.gd")
		and kinetic.contains("survival_shipping_main.gd")
		and survival_shipping.contains("engineering_progression_main.gd")
		and engineering.contains("survival_main.gd"),
		"shipping scene enables placement preview and precise targeting through the complete survival stack"
	)
	_expect(survival_source.contains("multi_lod_main.gd"), "survival retains the world and chunk-local vegetation stack")
	_expect(survival_source.contains("_survival_break_voxel"), "block breaking creates item drops")
	_expect(survival_source.contains("_survival_place_voxel"), "block placement consumes items")
	_expect(survival_source.contains("RecipeBook.craft"), "shipping runtime uses atomic recipe transactions")
	_expect(targeting.contains("VoxelRaycast.cast"), "shipping break targeting uses authoritative voxel traversal")
	_expect(targeting.contains("_survival_break_voxel(voxel"), "break completion removes the same locked voxel shown by feedback")
	_expect(targeting.contains("MiningController") and targeting.contains("_process_mining"), "shipping mining uses one deterministic hold-to-break state machine")
	_expect(mining_controller.contains("WAITING_FOR_COMMIT") and mining_controller.contains("set_pressed"), "mining lifecycle includes hold, cancel and visible-commit phases")
	_expect(targeting.contains("MiningBlockVisual") and mining_visual.contains("Mesh.PRIMITIVE_LINES"), "selected block receives one thin world-space outline")
	_expect(mining_visual.contains("MiningCrackOverlay") and mining_visual.contains("progress"), "selected block shows progressive procedural cracks")
	_expect(targeting.contains("QA_MINING_SYSTEM_PASS"), "recorded gameplay verifies replacement mining feedback")
	_expect(crosshair.contains("PRESET_FULL_RECT") and crosshair.contains("RETICLE_COLOR"), "center crosshair remains small and stable")
	_expect(controller.contains("break_hold_changed") and controller.contains("break_hold_changed.connect"), "mouse and mobile break holds reach the shipping interaction layer")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
