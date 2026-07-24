extends "res://src/main/survival_main.gd"

var _qa_collected_items: int = 0
var _qa_consumed_items: int = 0
var _qa_granted_items: int = 0


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
	super.qa_save_edits_now()
	qa_save_inventory_now()
	var persisted: bool = qa_reload_inventory_for_test()
	if not persisted or _qa_collected_items <= 0 or _qa_consumed_items <= 0:
		push_error(
			"QA_SURVIVAL failed collected=%d consumed=%d persisted=%s"
			% [_qa_collected_items, _qa_consumed_items, str(persisted)]
		)
		get_tree().quit(1)
		return
	print(
		"QA_SURVIVAL_PASS collected=", _qa_collected_items,
		" consumed=", _qa_consumed_items,
		" qa_granted=", _qa_granted_items,
		" persisted=", persisted,
		" inventory=", JSON.stringify(_inventory.encode())
	)


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["qa_collected_items"] = _qa_collected_items
	snapshot["qa_consumed_items"] = _qa_consumed_items
	snapshot["qa_granted_items"] = _qa_granted_items
	return snapshot
