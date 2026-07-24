extends "res://src/main/survival_main.gd"

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
	if _inventory.count(ItemRegistry.ITEM_STONE) < 4:
		var needed: int = 4 - _inventory.count(ItemRegistry.ITEM_STONE)
		if _inventory.add(ItemRegistry.ITEM_STONE, needed) != 0:
			push_error("QA_CRAFTING could not grant recipe ingredients")
			get_tree().quit(1)
			return
		_qa_granted_items += needed
		_mark_inventory_changed("qa_recipe_supply", ItemRegistry.ITEM_STONE, needed)
	var stone_before: int = _inventory.count(ItemRegistry.ITEM_STONE)
	if qa_craft_recipe(RecipeBook.RECIPE_STONE_GEAR):
		_qa_crafted_items += 1
	var gear_count: int = _inventory.count(ItemRegistry.ITEM_STONE_GEAR)
	var recipe_consumed: bool = _inventory.count(ItemRegistry.ITEM_STONE) == stone_before - 4
	super.qa_save_edits_now()
	qa_save_inventory_now()
	var persisted: bool = qa_reload_inventory_for_test()
	if (
		not persisted
		or _qa_collected_items <= 0
		or _qa_consumed_items <= 0
		or _qa_crafted_items != 1
		or gear_count <= 0
		or not recipe_consumed
	):
		push_error(
			"QA_SURVIVAL failed collected=%d consumed=%d crafted=%d gears=%d recipe_consumed=%s persisted=%s"
			% [
				_qa_collected_items,
				_qa_consumed_items,
				_qa_crafted_items,
				gear_count,
				str(recipe_consumed),
				str(persisted),
			]
		)
		get_tree().quit(1)
		return
	print(
		"QA_CRAFTING_PASS recipe=", RecipeBook.RECIPE_STONE_GEAR,
		" crafted=", _qa_crafted_items,
		" gears=", gear_count,
		" stone_consumed=4 persisted=", persisted
	)
	print(
		"QA_SURVIVAL_PASS collected=", _qa_collected_items,
		" consumed=", _qa_consumed_items,
		" qa_granted=", _qa_granted_items,
		" crafted=", _qa_crafted_items,
		" persisted=", persisted,
		" inventory=", JSON.stringify(_inventory.encode())
	)


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["qa_collected_items"] = _qa_collected_items
	snapshot["qa_consumed_items"] = _qa_consumed_items
	snapshot["qa_granted_items"] = _qa_granted_items
	snapshot["qa_crafted_items"] = _qa_crafted_items
	return snapshot
