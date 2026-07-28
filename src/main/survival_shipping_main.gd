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
	var supplies: Dictionary = {
		ItemRegistry.ITEM_PLANKS: 7,
		ItemRegistry.ITEM_STONE: 10,
		ItemRegistry.ITEM_ANDESITE: 2,
		ItemRegistry.ITEM_IRON_NUGGET: 2,
	}
	for item_variant: Variant in supplies.keys():
		var item_id := StringName(str(item_variant))
		var needed: int = maxi(0, int(supplies[item_variant]) - _inventory.count(item_id))
		if needed > 0:
			if _inventory.add(item_id, needed) != 0:
				push_error("QA_ENGINEERING could not grant Create recipe material: %s" % item_id)
				get_tree().quit(1)
				return
			_qa_granted_items += needed
			_mark_inventory_changed("qa_engineering_supply", item_id, needed)

	var sequence: Array[StringName] = [
		RecipeBook.RECIPE_WORKBENCH,
		RecipeBook.RECIPE_CRUSHED_STONE,
		RecipeBook.RECIPE_CRUSHED_STONE,
		RecipeBook.RECIPE_STONE_SHAFT,
		RecipeBook.RECIPE_ANDESITE_ALLOY,
		RecipeBook.RECIPE_HAND_CRANK,
		RecipeBook.RECIPE_STONE_CRUSHER,
	]
	for recipe_id: StringName in sequence:
		if not qa_craft_recipe(recipe_id):
			push_error("QA_ENGINEERING station recipe failed: %s" % recipe_id)
			get_tree().quit(1)
			return
		_qa_crafted_items += 1
	if _inventory.count(ItemRegistry.ITEM_GRASS) <= 0:
		if _inventory.add(ItemRegistry.ITEM_GRASS, 1) != 0:
			push_error("QA_SURVIVAL could not grant hotbar proof item")
			get_tree().quit(1)
			return
		_qa_granted_items += 1
		_mark_inventory_changed("qa_hotbar_supply", ItemRegistry.ITEM_GRASS, 1)
	if not qa_select_hotbar_item(ItemRegistry.ITEM_GRASS):
		push_error("QA_SURVIVAL could not select Grass in the placeable hotbar")
		get_tree().quit(1)
		return
	super.qa_save_edits_now()
	qa_save_inventory_now()
	qa_save_progression_now()
	var inventory_persisted: bool = qa_reload_inventory_for_test()
	var hotbar_persisted: bool = qa_reload_hotbar_for_test()
	var progression_persisted: bool = qa_reload_progression_for_test()
	var passed: bool = (
		inventory_persisted
		and hotbar_persisted
		and progression_persisted
		and _qa_collected_items > 0
		and _qa_consumed_items > 0
		and _selected_item == ItemRegistry.ITEM_GRASS
		and _inventory.count(ItemRegistry.ITEM_WORKBENCH) == 1
		and _inventory.count(ItemRegistry.ITEM_HAND_CRANK) == 1
		and _inventory.count(ItemRegistry.ITEM_STONE_SHAFT) == 1
		and _inventory.count(ItemRegistry.ITEM_STONE_CRUSHER) == 1
		and qa_progression_unlocked(ProgressionState.UNLOCK_STONE_PROCESSING)
		and qa_progression_unlocked(ProgressionState.UNLOCK_ANDESITE_ENGINEERING)
		and qa_progression_unlocked(ProgressionState.UNLOCK_KINETIC_STARTER)
	)
	if not passed:
		push_error("QA_ENGINEERING station progression, hotbar, or persistence failed")
		get_tree().quit(1)
		return
	print(
		"QA_CRAFTING_PASS crafted=", _qa_crafted_items,
		" table=", _inventory.count(ItemRegistry.ITEM_WORKBENCH),
		" hand_cranks=", _inventory.count(ItemRegistry.ITEM_HAND_CRANK),
		" shafts=", _inventory.count(ItemRegistry.ITEM_STONE_SHAFT),
		" crushers=", _inventory.count(ItemRegistry.ITEM_STONE_CRUSHER),
		" create_recipe_chain=true persisted=", inventory_persisted and progression_persisted
	)
	print(
		"QA_ENGINEERING_PASS processing_unlocked=", qa_progression_unlocked(ProgressionState.UNLOCK_STONE_PROCESSING),
		" andesite_unlocked=", qa_progression_unlocked(ProgressionState.UNLOCK_ANDESITE_ENGINEERING),
		" kinetic_unlocked=", qa_progression_unlocked(ProgressionState.UNLOCK_KINETIC_STARTER),
		" persisted=", inventory_persisted and progression_persisted
	)
	print(
		"QA_HOTBAR_PASS selected=", _selected_item,
		" placeables=", ItemRegistry.placeable_items().size(),
		" persisted=", hotbar_persisted
	)
	print(
		"QA_SURVIVAL_PASS collected=", _qa_collected_items,
		" consumed=", _qa_consumed_items,
		" qa_granted=", _qa_granted_items,
		" crafted=", _qa_crafted_items,
		" persisted=", inventory_persisted and hotbar_persisted,
		" inventory=", JSON.stringify(_inventory.encode())
	)


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["qa_collected_items"] = _qa_collected_items
	snapshot["qa_consumed_items"] = _qa_consumed_items
	snapshot["qa_granted_items"] = _qa_granted_items
	snapshot["qa_crafted_items"] = _qa_crafted_items
	snapshot["qa_hotbar_selected"] = str(_selected_item)
	return snapshot
