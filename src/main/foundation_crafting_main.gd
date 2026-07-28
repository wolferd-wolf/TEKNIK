extends "res://src/main/kinetic_capture_shipping_main.gd"

const FoundationItemRegistry = preload("res://src/survival/item_registry.gd")
const FurnaceRecipeBook = preload("res://src/survival/furnace_recipe_book.gd")
const TreeHarvestState = preload("res://src/world/tree_harvest_state.gd")

const TREE_SAVE_PATH: String = "user://teknik-mined-trees.json"
const FURNACE_SAVE_PATH: String = "user://teknik-furnaces.json"
const FURNACE_SCHEMA: int = 1
const TREE_MATERIAL_ID: int = 9
const TREE_WOOD_YIELD: int = 4
const TREE_CANOPY_CLEAR_RADIUS: float = 3.35
const FURNACE_TYPE: StringName = &"furnace"
const STATION_BREAK_DISTANCE: float = 7.0

var _tree_harvest: TeknikTreeHarvestState = TreeHarvestState.new()
var _active_tree_target_id: String = ""
var _active_tree_target_center: Vector3 = Vector3.ZERO
var _ecology_group_being_committed: String = ""

var _furnaces: Dictionary = {}
var _furnace_root: Node3D


func _ready() -> void:
	_load_tree_harvest()
	_load_furnaces()
	super._ready()
	_rebuild_furnace_visuals()
	_fit_foundation_hotbar()
	_runtime_log.event("info", "foundation", "wood_stations_ready", {
		"mined_trees": _tree_harvest.count(),
		"furnaces": _furnaces.size(),
		"crafting_bench": true,
		"furnace_smelt_pairs": FurnaceRecipeBook.recipes().size(),
	})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_tree_harvest()
		_save_furnaces()
	super._notification(what)


# The adapted grass-side image is already authored with its green band at the top.
# Texture orientation is handled in the shader; ecology geometry remains unchanged.
func _ecology_mesh_for_group(group: Dictionary) -> Mesh:
	_ecology_group_being_committed = str(group.get("name", ""))
	return super._ecology_mesh_for_group(group)


func _add_tree_multimesh(
	mesh: Mesh,
	transforms: Array,
	cast_shadows: bool = true,
	streamed: bool = true
) -> void:
	super._add_tree_multimesh(mesh, transforms, cast_shadows, streamed)
	if (
		not streamed
		or _ecology_group_being_committed != "trunks"
		or _ecology_commit_parent == null
	):
		return
	for value: Variant in transforms:
		if value is Transform3D:
			_add_tree_collider(value)


func _add_tree_collider(transform: Transform3D) -> void:
	var tree_id: String = TreeHarvestState.id_for_transform(transform)
	if _tree_harvest.is_mined(tree_id):
		return
	var scale: Vector3 = transform.basis.get_scale()
	var body := StaticBody3D.new()
	body.name = "MineableTree_" + tree_id.replace(":", "_")
	body.transform = Transform3D(transform.basis.orthonormalized(), transform.origin)
	body.set_meta("teknik_tree_id", tree_id)
	body.set_meta("teknik_tree_center", transform.origin)
	var bottom_y: float = transform.origin.y - absf(scale.y) * 0.5
	var base_voxel := Vector3i(
		floori(transform.origin.x),
		floori(bottom_y),
		floori(transform.origin.z)
	)
	body.set_meta("teknik_tree_voxel", base_voxel)
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(absf(scale.x), 0.35),
		maxf(absf(scale.y), 1.0),
		maxf(absf(scale.z), 0.35)
	)
	collision.shape = shape
	body.add_child(collision)
	_ecology_commit_parent.add_child(body)


func _make_ecology_groups(plan: Dictionary) -> Array[Dictionary]:
	var filtered: Dictionary = plan.duplicate(true)
	var canopy_keys: Array[String] = [
		"broadleaf_lower",
		"broadleaf_upper",
		"broadleaf_side",
		"conifer_lower",
		"conifer_middle",
		"conifer_upper",
	]
	var filtered_keys: Array[String] = ["trunks"]
	filtered_keys.append_array(canopy_keys)
	for key: String in filtered_keys:
		var source: Array = filtered.get(key, [])
		var kept: Array = []
		for value: Variant in source:
			if not value is Transform3D:
				continue
			var transform: Transform3D = value
			if key == "trunks":
				if _tree_harvest.is_mined(TreeHarvestState.id_for_transform(transform)):
					continue
			elif _tree_harvest.near_mined_tree(
				transform.origin,
				TREE_CANOPY_CLEAR_RADIUS
			):
				continue
			kept.append(transform)
		filtered[key] = kept
	return super._make_ecology_groups(filtered)


func _find_break_target(origin: Vector3, direction: Vector3) -> Dictionary:
	var tree_target: Dictionary = _raycast_tree(origin, direction)
	var world_target: Dictionary = super._find_break_target(origin, direction)
	if tree_target.is_empty():
		return world_target
	if world_target.is_empty():
		return tree_target
	if float(tree_target.get("distance", INF)) <= float(world_target.get("distance", INF)):
		return tree_target
	return world_target


func _raycast_tree(origin: Vector3, direction: Vector3) -> Dictionary:
	if _player == null or direction.length_squared() <= 0.000001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction.normalized() * INTERACTION_DISTANCE
	)
	query.exclude = [_player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as StaticBody3D
	if collider == null or not collider.has_meta("teknik_tree_id"):
		return {}
	var tree_id: String = str(collider.get_meta("teknik_tree_id", ""))
	if tree_id.is_empty() or _tree_harvest.is_mined(tree_id):
		return {}
	var hit_position: Vector3 = hit.get("position", collider.global_position)
	return {
		"kind": "tree",
		"tree_id": tree_id,
		"tree_center": collider.get_meta("teknik_tree_center", collider.global_position),
		"voxel": collider.get_meta(
			"teknik_tree_voxel",
			Vector3i(floori(collider.global_position.x), floori(collider.global_position.y), floori(collider.global_position.z))
		),
		"material": TREE_MATERIAL_ID,
		"normal": hit.get("normal", Vector3.UP),
		"distance": origin.distance_to(hit_position),
		"collider": collider,
	}


func _set_block_target(target: Dictionary) -> void:
	if str(target.get("kind", "")) == "tree":
		_active_tree_target_id = str(target.get("tree_id", ""))
		_active_tree_target_center = target.get("tree_center", Vector3.ZERO)
	elif not _mining.is_waiting_for_commit():
		_active_tree_target_id = ""
		_active_tree_target_center = Vector3.ZERO
	super._set_block_target(target)


func _process_mining(delta: float) -> void:
	if _active_tree_target_id.is_empty() or _mining.target_material() != TREE_MATERIAL_ID:
		super._process_mining(delta)
		return
	var completed: Dictionary = _mining.update(delta)
	if _mining_visual != null:
		_mining_visual.set_progress(_mining.progress())
	if completed.is_empty():
		return
	if not _harvest_active_tree():
		_mining.cancel_failed_completion()


func _harvest_active_tree() -> bool:
	if _active_tree_target_id.is_empty():
		return false
	if _inventory.add(FoundationItemRegistry.ITEM_WOOD, TREE_WOOD_YIELD) != 0:
		_set_machine_message("Inventory full")
		return false
	var tree_id: String = _active_tree_target_id
	var tree_center: Vector3 = _active_tree_target_center
	if not _tree_harvest.mark_mined(tree_id, tree_center):
		_inventory.remove(FoundationItemRegistry.ITEM_WOOD, TREE_WOOD_YIELD)
		return false
	if not _save_tree_harvest():
		_tree_harvest = TreeHarvestState.new()
		_load_tree_harvest()
		_inventory.remove(FoundationItemRegistry.ITEM_WOOD, TREE_WOOD_YIELD)
		return false

	var coordinate := Vector3i(
		floori(tree_center.x / float(VoxelChunk.SIZE)),
		0,
		floori(tree_center.z / float(VoxelChunk.SIZE))
	)
	_remove_ecology_chunk(coordinate)
	_feature_refresh_pending = true
	_last_center_change_ms = 0

	_active_tree_target_id = ""
	_active_tree_target_center = Vector3.ZERO
	_mining.notify_visible_commit()
	if _mining_visual != null:
		_mining_visual.clear_target()
	if _block_crosshair != null:
		_block_crosshair.set_targeted(false)
	_mark_inventory_changed(
		"tree_harvested",
		FoundationItemRegistry.ITEM_WOOD,
		TREE_WOOD_YIELD
	)
	_runtime_log.event("info", "survival", "tree_harvested", {
		"tree_id": tree_id,
		"center": str(tree_center),
		"wood": TREE_WOOD_YIELD,
		"persistent": true,
	})
	call_deferred("_refresh_block_target")
	return true


func _can_place_engineering_item(voxel: Vector3i, item_id: StringName) -> bool:
	if item_id != FoundationItemRegistry.ITEM_FURNACE:
		if _furnace_at_position(voxel):
			return false
		return super._can_place_engineering_item(voxel, item_id)
	if _inventory.count(item_id) <= 0:
		return false
	if _current_material(voxel) != VoxelChunk.AIR:
		return false
	if _current_material(voxel - Vector3i.UP) == VoxelChunk.AIR:
		return false
	if _placement_intersects_player(voxel):
		return false
	return not _machine_at_position(voxel) and not _furnace_at_position(voxel)


func _place_engineering_item(
	voxel: Vector3i,
	item_id: StringName,
	consume_item: bool
) -> bool:
	if item_id != FoundationItemRegistry.ITEM_FURNACE:
		if _furnace_at_position(voxel):
			return false
		return super._place_engineering_item(voxel, item_id, consume_item)
	if not _can_place_engineering_item(voxel, item_id):
		return false
	if consume_item and not _inventory.remove(item_id, 1):
		return false
	var furnace_id: String = _furnace_id_for_position(voxel)
	_furnaces[furnace_id] = voxel
	if not _save_furnaces():
		_furnaces.erase(furnace_id)
		if consume_item:
			_inventory.add(item_id, 1)
		return false
	_rebuild_furnace_visuals()
	if consume_item:
		_mark_inventory_changed("furnace_placed", item_id, -1)
	_runtime_log.event("info", "foundation", "furnace_placed", {
		"id": furnace_id,
		"voxel": str(voxel),
		"persistent": true,
	})
	return true


func _try_break_engineering_item(origin: Vector3, direction: Vector3) -> bool:
	var body: StaticBody3D = _raycast_foundation_body(origin, direction)
	if (
		body == null
		or StringName(str(body.get_meta("teknik_machine_type", ""))) != FURNACE_TYPE
	):
		return super._try_break_engineering_item(origin, direction)
	var furnace_id: String = str(body.get_meta("teknik_machine_id", ""))
	if not _furnaces.has(furnace_id):
		return true
	if _inventory.add(FoundationItemRegistry.ITEM_FURNACE, 1) != 0:
		_set_machine_message("Inventory full")
		return true
	var position: Vector3i = _furnaces[furnace_id]
	_furnaces.erase(furnace_id)
	if not _save_furnaces():
		_furnaces[furnace_id] = position
		_inventory.remove(FoundationItemRegistry.ITEM_FURNACE, 1)
		return true
	_rebuild_furnace_visuals()
	_mark_inventory_changed(
		"furnace_collected",
		FoundationItemRegistry.ITEM_FURNACE,
		1
	)
	return true


func _raycast_foundation_body(origin: Vector3, direction: Vector3) -> StaticBody3D:
	if direction.length_squared() <= 0.000001:
		return null
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction.normalized() * STATION_BREAK_DISTANCE
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if _player != null:
		query.exclude = [_player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as StaticBody3D


func _interaction_prompt(machine_type: StringName) -> String:
	if machine_type == FURNACE_TYPE:
		var available: Dictionary = FurnaceRecipeBook.first_available(_inventory)
		if available.is_empty():
			return "Furnace: need Wood and ore concentrate"
		return "INTERACT: smelt %s" % FoundationItemRegistry.display_name(
			StringName(str(available.input))
		)
	return super._interaction_prompt(machine_type)


func _interact_with_machine_type(machine_type: StringName) -> bool:
	if machine_type == FURNACE_TYPE:
		var report: Dictionary = FurnaceRecipeBook.smelt_one(_inventory)
		if report.is_empty():
			_set_machine_message("Furnace needs 1 Wood and an ore concentrate")
			return false
		var output := StringName(str(report.output))
		_mark_inventory_changed("furnace_smelted", output, 1)
		_set_machine_message(
			"Smelted 1 %s" % FoundationItemRegistry.display_name(output)
		)
		_runtime_log.event("info", "foundation", "furnace_smelted", {
			"input": str(report.input),
			"fuel": str(report.fuel),
			"output": str(output),
		})
		return true
	return super._interact_with_machine_type(machine_type)


func _rebuild_machine_visuals() -> void:
	super._rebuild_machine_visuals()
	_decorate_crafting_benches()


func _decorate_crafting_benches() -> void:
	if _machine_root == null:
		return
	for child: Node in _machine_root.get_children():
		var body := child as StaticBody3D
		if body == null:
			continue
		if str(body.get_meta("teknik_machine_type", "")) != "workbench":
			continue
		var top := MeshInstance3D.new()
		var top_mesh := BoxMesh.new()
		top_mesh.size = Vector3(0.94, 0.08, 0.94)
		top_mesh.material = _station_material(Color("a97846"), 0.82)
		top.mesh = top_mesh
		top.position = Vector3(0.0, 0.37, 0.0)
		body.add_child(top)
		for offset: float in [-0.28, 0.0, 0.28]:
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(0.055, 0.025, 0.88)
			strip_mesh.material = _station_material(Color("533a29"), 0.9)
			strip.mesh = strip_mesh
			strip.position = Vector3(offset, 0.416, 0.0)
			body.add_child(strip)


func _rebuild_furnace_visuals() -> void:
	if _furnace_root != null:
		_furnace_root.queue_free()
	_furnace_root = Node3D.new()
	_furnace_root.name = "PlacedFurnaces"
	add_child(_furnace_root)
	var ids: Array = _furnaces.keys()
	ids.sort()
	for value: Variant in ids:
		var furnace_id: String = str(value)
		var voxel: Vector3i = _furnaces[furnace_id]
		var body := StaticBody3D.new()
		body.name = "Furnace_" + furnace_id.replace(":", "_")
		body.position = Vector3(
			float(voxel.x) + 0.5,
			float(voxel.y) + 0.5,
			float(voxel.z) + 0.5
		)
		body.set_meta("teknik_machine_id", furnace_id)
		body.set_meta("teknik_machine_type", FURNACE_TYPE)
		body.set_meta("teknik_foundation_item", FoundationItemRegistry.ITEM_FURNACE)
		_furnace_root.add_child(body)

		var shell := MeshInstance3D.new()
		var shell_mesh := BoxMesh.new()
		shell_mesh.size = Vector3(0.96, 0.96, 0.96)
		shell_mesh.material = _station_material(Color("626562"), 0.96)
		shell.mesh = shell_mesh
		body.add_child(shell)

		var opening := MeshInstance3D.new()
		var opening_mesh := BoxMesh.new()
		opening_mesh.size = Vector3(0.54, 0.36, 0.035)
		opening_mesh.material = _station_material(Color("171918"), 1.0)
		opening.mesh = opening_mesh
		opening.position = Vector3(0.0, -0.12, -0.495)
		body.add_child(opening)

		var rim := MeshInstance3D.new()
		var rim_mesh := BoxMesh.new()
		rim_mesh.size = Vector3(0.70, 0.08, 0.045)
		rim_mesh.material = _station_material(Color("8a8d88"), 0.9)
		rim.mesh = rim_mesh
		rim.position = Vector3(0.0, 0.22, -0.50)
		body.add_child(rim)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = shell_mesh.size
		collision.shape = shape
		body.add_child(collision)


func _station_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _furnace_id_for_position(position: Vector3i) -> String:
	return "furnace:%d:%d:%d" % [position.x, position.y, position.z]


func _furnace_at_position(position: Vector3i) -> bool:
	return _furnaces.has(_furnace_id_for_position(position))


func _fit_foundation_hotbar() -> void:
	if _bottom_hotbar_panel == null or _hotbar_buttons.is_empty():
		return
	var item_count: int = _hotbar_buttons.size()
	var available_width: float = 612.0 - float(maxi(item_count - 1, 0)) * 4.0
	var slot_width: float = floorf(available_width / float(item_count))
	for value: Variant in _hotbar_buttons.values():
		var button := value as Button
		if button != null:
			button.custom_minimum_size = Vector2(maxf(slot_width, 56.0), 58.0)


func _load_tree_harvest() -> void:
	if not FileAccess.file_exists(TREE_SAVE_PATH):
		return
	var file := FileAccess.open(TREE_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and _tree_harvest.decode(parsed):
		return
	push_warning("TREE_HARVEST save was invalid; using an empty state")
	_tree_harvest = TreeHarvestState.new()


func _save_tree_harvest() -> bool:
	var file := FileAccess.open(TREE_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("TREE_HARVEST could not open save file")
		return false
	file.store_string(JSON.stringify(_tree_harvest.encode(), "\t"))
	file.flush()
	return true


func _load_furnaces() -> void:
	if not FileAccess.file_exists(FURNACE_SAVE_PATH):
		return
	var file := FileAccess.open(FURNACE_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema", -1)) != FURNACE_SCHEMA:
		return
	var rows: Variant = parsed.get("furnaces", [])
	if not rows is Array:
		return
	var restored: Dictionary = {}
	for value: Variant in rows:
		if not value is Dictionary:
			return
		var row: Dictionary = value
		var position_data: Variant = row.get("position", [])
		if not position_data is Array or (position_data as Array).size() != 3:
			return
		var position := Vector3i(
			int(position_data[0]),
			int(position_data[1]),
			int(position_data[2])
		)
		var furnace_id: String = _furnace_id_for_position(position)
		if restored.has(furnace_id):
			return
		restored[furnace_id] = position
	_furnaces = restored


func _save_furnaces() -> bool:
	var rows: Array[Dictionary] = []
	var ids: Array = _furnaces.keys()
	ids.sort()
	for value: Variant in ids:
		var furnace_id: String = str(value)
		var position: Vector3i = _furnaces[furnace_id]
		rows.append({
			"id": furnace_id,
			"position": [position.x, position.y, position.z],
		})
	var file := FileAccess.open(FURNACE_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("FURNACE could not open save file")
		return false
	file.store_string(JSON.stringify({
		"schema": FURNACE_SCHEMA,
		"furnaces": rows,
	}, "\t"))
	file.flush()
	return true


func qa_mined_tree_count() -> int:
	return _tree_harvest.count()


func qa_furnace_count() -> int:
	return _furnaces.size()
