extends "res://src/main/engineering_progression_main.gd"

var _qa_collected_items: int = 0
var _qa_consumed_items: int = 0
var _qa_granted_items: int = 0
var _qa_crafted_items: int = 0


func qa_apply_voxel_edit(voxel: Vector3i, material: int, action: String) -> void:
	if "qa_" not in action:
		super.qa_apply_voxel_edit(voxel, material, action)
		return
	if material == VoxelChunk.AIR:
		if _survival_break_voxel(voxel, action):
			_qa_collected_items += 1
		return
	var item_id: StringName = ItemRegistry.item_for_material(material)
	if item_id == &"":
		push_error("QA_SURVIVAL unregistered placement material: %d" % material)
		return
	if _inventory.count(item_id) <= 0:
		var grant: int = mini(ItemRegistry.MAX_STACK, 64)
		if _inventory.add(item_id, grant) != 0:
			push_error("QA_SURVIVAL could not grant placement materials")
			return
		_qa_granted_items += grant
		_mark_inventory_changed("qa_build_supply", item_id, grant)
	if _survival_place_voxel(voxel, material, action, false):
		_qa_consumed_items += 1


func qa_save_edits_now() -> void:
	var needed: int = maxi(0, 24 - _inventory.count(ItemRegistry.ITEM_STONE))
	if needed > 0:
		if _inventory.add(ItemRegistry.ITEM_STONE, needed) != 0:
			push_error("QA_ENGINEERING could not grant progression materials")
			get_tree().quit(1)
			return
		_qa_granted_items += needed
		_mark_inventory_changed("qa_engineering_supply", ItemRegistry.ITEM_STONE, needed)
	var sequence: Array[StringName] = [
		RecipeBook.RECIPE_STONE_GEAR,
		RecipeBook.RECIPE_WORKBENCH,
		RecipeBook.RECIPE_CRUSHED_STONE,
		RecipeBook.RECIPE_STONE_SHAFT,
		RecipeBook.RECIPE_STONE_GEAR,
		RecipeBook.RECIPE_HAND_CRANK,
	]
	for recipe_id: StringName in sequence:
		if not qa_craft_recipe(recipe_id):
			push_error("QA_ENGINEERING recipe failed: %s" % recipe_id)
			get_tree().quit(1)
			return
		_qa_crafted_items += 1
	super.qa_save_edits_now()
	qa_save_inventory_now()
	qa_save_progression_now()
	var inventory_persisted: bool = qa_reload_inventory_for_test()
	var progression_persisted: bool = qa_reload_progression_for_test()
	var passed: bool = (
		inventory_persisted
		and progression_persisted
		and _qa_collected_items > 0
		and _qa_consumed_items > 0
		and _inventory.count(ItemRegistry.ITEM_WORKBENCH) == 1
		and _inventory.count(ItemRegistry.ITEM_HAND_CRANK) == 1
		and qa_progression_unlocked(ProgressionState.UNLOCK_STONE_PROCESSING)
		and qa_progression_unlocked(ProgressionState.UNLOCK_KINETIC_STARTER)
	)
	if not passed:
		push_error("QA_ENGINEERING progression or persistence failed")
		get_tree().quit(1)
		return
	print(
		"QA_CRAFTING_PASS crafted=", _qa_crafted_items,
		" workbenches=", _inventory.count(ItemRegistry.ITEM_WORKBENCH),
		" hand_cranks=", _inventory.count(ItemRegistry.ITEM_HAND_CRANK),
		" persisted=", inventory_persisted and progression_persisted
	)
	print(
		"QA_ENGINEERING_PASS crafted=", _qa_crafted_items,
		" workbenches=", _inventory.count(ItemRegistry.ITEM_WORKBENCH),
		" hand_cranks=", _inventory.count(ItemRegistry.ITEM_HAND_CRANK),
		" processing_unlocked=", qa_progression_unlocked(ProgressionState.UNLOCK_STONE_PROCESSING),
		" kinetic_unlocked=", qa_progression_unlocked(ProgressionState.UNLOCK_KINETIC_STARTER),
		" persisted=", inventory_persisted and progression_persisted
	)
	print(
		"QA_SURVIVAL_PASS collected=", _qa_collected_items,
		" consumed=", _qa_consumed_items,
		" qa_granted=", _qa_granted_items,
		" crafted=", _qa_crafted_items,
		" persisted=", inventory_persisted,
		" inventory=", JSON.stringify(_inventory.encode())
	)


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["qa_collected_items"] = _qa_collected_items
	snapshot["qa_consumed_items"] = _qa_consumed_items
	snapshot["qa_granted_items"] = _qa_granted_items
	snapshot["qa_crafted_items"] = _qa_crafted_items
	return snapshot
