extends "res://src/main/survival_shipping_main.gd"

const KineticMachineState = preload("res://src/simulation/kinetic_machine_state.gd")
const TerrainGeneratorLocal = preload("res://src/world/voxel_terrain_generator.gd")
const StackInventoryLocal = preload("res://src/survival/stack_inventory.gd")
const MACHINE_SAVE_PATH: String = "user://teknik-machines.json"
const PLACED_MACHINE_BREAK_DISTANCE: float = 7.0

var _machines = KineticMachineState.new()
var _machine_root: Node3D
var _machine_hud_panel: PanelContainer
var _machine_status: Label
var _assemble_button: Button
var _load_button: Button
var _crank_button: Button
var _collect_button: Button


func _ready() -> void:
	_load_machines()
	super._ready()
	_build_machine_hud()
	_rebuild_machine_visuals()
	_refresh_machine_status()
	_set_machine_hud_targeted(false)


func _build_machine_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "KineticMachineHUD"
	layer.layer = 8
	add_child(layer)
	_machine_hud_panel = PanelContainer.new()
	_machine_hud_panel.name = "KineticMachinePanel"
	_machine_hud_panel.position = Vector2(360.0, 12.0)
	_machine_hud_panel.custom_minimum_size = Vector2(330.0, 210.0)
	_machine_hud_panel.visible = false
	layer.add_child(_machine_hud_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_machine_hud_panel.add_child(content)
	_machine_status = Label.new()
	_machine_status.name = "KineticStatus"
	content.add_child(_machine_status)
	_assemble_button = Button.new()
	_assemble_button.name = "AssembleStarterKinetics"
	_assemble_button.text = "Assemble Starter Machine"
	_assemble_button.visible = false
	_assemble_button.pressed.connect(_on_assemble_pressed)
	content.add_child(_assemble_button)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 5)
	content.add_child(action_row)
	_load_button = Button.new()
	_load_button.name = "LoadCrusherStone"
	_load_button.text = "Load 2 Stone"
	_load_button.pressed.connect(_on_load_pressed)
	action_row.add_child(_load_button)
	_crank_button = Button.new()
	_crank_button.name = "TurnHandCrank"
	_crank_button.text = "Turn Crank"
	_crank_button.pressed.connect(_on_crank_pressed)
	action_row.add_child(_crank_button)
	_collect_button = Button.new()
	_collect_button.name = "CollectCrusherOutput"
	_collect_button.text = "Collect Output"
	_collect_button.pressed.connect(_on_collect_pressed)
	content.add_child(_collect_button)


func _set_machine_hud_targeted(targeted: bool) -> void:
	if _machine_hud_panel != null:
		_machine_hud_panel.visible = targeted and not _machines.machines.is_empty()


func _on_assemble_pressed() -> void:
	if _assemble_starter_machine():
		_set_machine_message("Starter line assembled")
	else:
		_set_machine_message("Place Workbench, Crank, Shaft and Crusher from the hotbar")
	_refresh_machine_status()


func _on_load_pressed() -> void:
	if _load_stone_into_machine(2):
		_set_machine_message("Loaded 2 Stone")
	else:
		_set_machine_message("Cannot load: need a connected crusher, space and 2 Stone")
	_refresh_machine_status()


func _on_crank_pressed() -> void:
	var report: Dictionary = _machines.crank(KineticMachineState.PROCESS_TURNS)
	var processed: bool = _machines.process()
	if int(report.get("turns_added", 0)) <= 0:
		_set_machine_message("Crank is not connected")
	elif processed:
		_set_machine_message("Crusher produced 3 Crushed Stone")
	else:
		_set_machine_message("Power stored; load Stone to process")
	_save_machines_now()
	_refresh_machine_status()


func _on_collect_pressed() -> void:
	var collected: int = _collect_machine_output()
	if collected > 0:
		_set_machine_message("Collected %d Crushed Stone" % collected)
	else:
		_set_machine_message("No output or inventory is full")
	_refresh_machine_status()


func _starter_parts() -> Array[StringName]:
	return [
		ItemRegistry.ITEM_WORKBENCH,
		ItemRegistry.ITEM_HAND_CRANK,
		ItemRegistry.ITEM_STONE_SHAFT,
		ItemRegistry.ITEM_STONE_CRUSHER,
	]


func _machine_type_for_item(item_id: StringName) -> StringName:
	match item_id:
		ItemRegistry.ITEM_WORKBENCH:
			return StringName(KineticMachineState.TYPE_WORKBENCH)
		ItemRegistry.ITEM_STONE_SHAFT:
			return StringName(KineticMachineState.TYPE_SHAFT)
		ItemRegistry.ITEM_HAND_CRANK:
			return StringName(KineticMachineState.TYPE_CRANK)
		ItemRegistry.ITEM_STONE_CRUSHER:
			return StringName(KineticMachineState.TYPE_CRUSHER)
		_:
			return &""


func _item_for_machine_type(machine_type: StringName) -> StringName:
	match str(machine_type):
		KineticMachineState.TYPE_WORKBENCH:
			return ItemRegistry.ITEM_WORKBENCH
		KineticMachineState.TYPE_SHAFT:
			return ItemRegistry.ITEM_STONE_SHAFT
		KineticMachineState.TYPE_CRANK:
			return ItemRegistry.ITEM_HAND_CRANK
		KineticMachineState.TYPE_CRUSHER:
			return ItemRegistry.ITEM_STONE_CRUSHER
		_:
			return &""


func _machine_id_for_position(machine_type: StringName, position: Vector3i) -> StringName:
	return StringName("%s_%d_%d_%d" % [str(machine_type), position.x, position.y, position.z])


func _machine_at_position(position: Vector3i) -> bool:
	for row_variant: Variant in _machines.machines.values():
		var row: Dictionary = row_variant
		if row.get("position", Vector3i.ZERO) == position:
			return true
	return false


func _can_place_engineering_item(voxel: Vector3i, item_id: StringName) -> bool:
	if _machine_type_for_item(item_id) == &"":
		return false
	if _inventory.count(item_id) <= 0:
		return false
	if _current_material(voxel) != VoxelChunk.AIR:
		return false
	if _placement_intersects_player(voxel):
		return false
	return not _machine_at_position(voxel)


func _place_engineering_item(voxel: Vector3i, item_id: StringName, consume_item: bool) -> bool:
	var machine_type: StringName = _machine_type_for_item(item_id)
	if machine_type == &"":
		return false
	if _current_material(voxel) != VoxelChunk.AIR or _placement_intersects_player(voxel) or _machine_at_position(voxel):
		return false
	if consume_item and _inventory.count(item_id) <= 0:
		return false
	var machine_id: StringName = _machine_id_for_position(machine_type, voxel)
	if not _machines.place(machine_id, machine_type, voxel):
		return false
	if consume_item and not _inventory.remove(item_id, 1):
		_machines.remove(machine_id)
		return false
	_rebuild_machine_visuals()
	if not _save_machines_now():
		_machines.remove(machine_id)
		if consume_item:
			_inventory.add(item_id, 1)
		_rebuild_machine_visuals()
		return false
	if consume_item:
		_mark_inventory_changed("engineering_object_placed", item_id, -1)
	_runtime_log.event("info", "kinetics", "machine_placed", {
		"id": str(machine_id),
		"type": str(machine_type),
		"item": str(item_id),
		"voxel": str(voxel),
		"persisted": true,
	})
	_refresh_machine_status()
	return true


func _try_break_engineering_item(origin: Vector3, direction: Vector3) -> bool:
	var body: StaticBody3D = _raycast_engineering_body(origin, direction)
	if body == null:
		return false
	var machine_id := StringName(body.get_meta("teknik_machine_id", &""))
	var row: Dictionary = _machines.machines.get(machine_id, {})
	var machine_type := StringName(str(row.get("type", "")))
	var item_id: StringName = _item_for_machine_type(machine_type)
	if row.is_empty() or item_id == &"":
		return true
	if _inventory.add(item_id, 1) != 0:
		_set_machine_message("Inventory full")
		return true
	var position: Vector3i = row.get("position", Vector3i.ZERO)
	if not _machines.remove(machine_id):
		_inventory.remove(item_id, 1)
		return true
	if not _save_machines_now():
		_machines.place(machine_id, machine_type, position)
		_inventory.remove(item_id, 1)
		_rebuild_machine_visuals()
		return true
	_rebuild_machine_visuals()
	_mark_inventory_changed("engineering_object_collected", item_id, 1)
	_runtime_log.event("info", "kinetics", "machine_collected", {
		"id": str(machine_id),
		"type": str(machine_type),
		"item": str(item_id),
		"voxel": str(position),
		"persisted": true,
	})
	_refresh_machine_status()
	return true


func _raycast_engineering_body(origin: Vector3, direction: Vector3) -> StaticBody3D:
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction.normalized() * PLACED_MACHINE_BREAK_DISTANCE
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if _player != null:
		query.exclude = [_player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as StaticBody3D
	if collider == null or not collider.has_meta("teknik_machine_id"):
		return null
	return collider


func _assemble_starter_machine() -> bool:
	if not _machines.machines.is_empty():
		return false
	var trial_inventory := StackInventoryLocal.new()
	if not trial_inventory.decode(_inventory.encode()):
		return false
	for item_id: StringName in _starter_parts():
		if not trial_inventory.remove(item_id, 1):
			return false
	var placement: Dictionary = _find_starter_placement()
	if not bool(placement.get("valid", false)):
		return false
	var origin: Vector3i = placement.get("origin", Vector3i.ZERO)
	var trial_machines = KineticMachineState.new()
	if not trial_machines.assemble_starter(origin):
		return false
	if not _inventory.decode(trial_inventory.encode()):
		return false
	_machines = trial_machines
	for item_id: StringName in _starter_parts():
		_mark_inventory_changed("machine_part_placed", item_id, -1)
	_rebuild_machine_visuals()
	if not _save_machines_now():
		return false
	return true


func _load_stone_into_machine(amount: int) -> bool:
	if not _machines.is_assembled() or amount <= 0:
		return false
	if _inventory.count(ItemRegistry.ITEM_STONE) < amount:
		return false
	if _machines.crusher_input + amount > KineticMachineState.MAX_CRUSHER_INPUT:
		return false
	if not _inventory.remove(ItemRegistry.ITEM_STONE, amount):
		return false
	var accepted: int = _machines.insert_stone(amount)
	if accepted != amount:
		_inventory.add(ItemRegistry.ITEM_STONE, amount)
		return false
	_mark_inventory_changed("machine_input", ItemRegistry.ITEM_STONE, -amount)
	_save_machines_now()
	return true


func _collect_machine_output() -> int:
	var available: int = _machines.crusher_output
	if available <= 0:
		return 0
	var trial_inventory := StackInventoryLocal.new()
	if not trial_inventory.decode(_inventory.encode()):
		return 0
	if trial_inventory.add(ItemRegistry.ITEM_CRUSHED_STONE, available) != 0:
		return 0
	var collected: int = _machines.collect_output(available)
	if collected != available or not _inventory.decode(trial_inventory.encode()):
		return 0
	_mark_inventory_changed("machine_output", ItemRegistry.ITEM_CRUSHED_STONE, collected)
	_save_machines_now()
	return collected


func _rebuild_machine_visuals() -> void:
	if _machine_root != null:
		_machine_root.queue_free()
	_machine_root = Node3D.new()
	_machine_root.name = "PlacedKineticMachines"
	add_child(_machine_root)
	for id_variant: Variant in _machines.machines.keys():
		var machine_id := StringName(id_variant)
		var row: Dictionary = _machines.machines[machine_id]
		var machine_type := StringName(str(row.get("type", "")))
		var grid_position: Vector3i = row.get("position", Vector3i.ZERO)
		var body := StaticBody3D.new()
		body.name = "Machine_" + str(machine_id)
		body.position = Vector3(
			float(grid_position.x) + 0.5,
			float(grid_position.y) + 0.5,
			float(grid_position.z) + 0.5
		)
		body.set_meta("teknik_machine_id", machine_id)
		body.set_meta("teknik_machine_type", machine_type)
		_machine_root.add_child(body)
		var mesh_instance := MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.roughness = 0.86
		var collision := CollisionShape3D.new()
		match str(machine_type):
			KineticMachineState.TYPE_CRANK:
				var crank_mesh := CylinderMesh.new()
				crank_mesh.top_radius = 0.28
				crank_mesh.bottom_radius = 0.28
				crank_mesh.height = 0.54
				material.albedo_color = Color("b87942")
				crank_mesh.material = material
				mesh_instance.mesh = crank_mesh
				mesh_instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
				var crank_shape := CylinderShape3D.new()
				crank_shape.radius = 0.30
				crank_shape.height = 0.58
				collision.shape = crank_shape
				collision.rotation_degrees = mesh_instance.rotation_degrees
			KineticMachineState.TYPE_SHAFT:
				var shaft_mesh := CylinderMesh.new()
				shaft_mesh.top_radius = 0.15
				shaft_mesh.bottom_radius = 0.15
				shaft_mesh.height = 0.92
				material.albedo_color = Color("777d78")
				shaft_mesh.material = material
				mesh_instance.mesh = shaft_mesh
				mesh_instance.rotation_degrees = Vector3(0.0, 0.0, 90.0)
				var shaft_shape := CylinderShape3D.new()
				shaft_shape.radius = 0.17
				shaft_shape.height = 0.92
				collision.shape = shaft_shape
				collision.rotation_degrees = mesh_instance.rotation_degrees
			KineticMachineState.TYPE_CRUSHER:
				var crusher_mesh := BoxMesh.new()
				crusher_mesh.size = Vector3(0.92, 1.18, 0.92)
				material.albedo_color = Color("4f5755")
				crusher_mesh.material = material
				mesh_instance.mesh = crusher_mesh
				var crusher_shape := BoxShape3D.new()
				crusher_shape.size = crusher_mesh.size
				collision.shape = crusher_shape
			_:
				var bench_mesh := BoxMesh.new()
				bench_mesh.size = Vector3(0.96, 0.68, 0.96)
				material.albedo_color = Color("816e55")
				bench_mesh.material = material
				mesh_instance.mesh = bench_mesh
				var bench_shape := BoxShape3D.new()
				bench_shape.size = bench_mesh.size
				collision.shape = bench_shape
		body.add_child(mesh_instance)
		body.add_child(collision)


func _set_machine_message(message: String) -> void:
	if _craft_status != null:
		_craft_status.text = message


func _refresh_machine_status() -> void:
	if _machine_status == null:
		return
	var report: Dictionary = _machines.network_report()
	var assembled: bool = _machines.is_assembled()
	_machine_status.text = "KINETICS\nPlaced: %d  Connected: %s  RPM: %.0f\nInput: %d/%d  Output: %d/%d  Turns: %d" % [
		_machines.machines.size(),
		str(bool(report.get("connected", false))),
		float(report.get("source_rpm", 0.0)),
		_machines.crusher_input,
		KineticMachineState.MAX_CRUSHER_INPUT,
		_machines.crusher_output,
		KineticMachineState.MAX_CRUSHER_OUTPUT,
		_machines.stored_turns,
	]
	if _assemble_button != null:
		_assemble_button.visible = false
		_assemble_button.disabled = true
	if _load_button != null:
		_load_button.disabled = not assembled or _inventory.count(ItemRegistry.ITEM_STONE) < 2 or _machines.crusher_input > KineticMachineState.MAX_CRUSHER_INPUT - 2
	if _crank_button != null:
		_crank_button.disabled = not assembled
	if _collect_button != null:
		_collect_button.disabled = _machines.crusher_output <= 0


func _has_all_starter_parts() -> bool:
	for item_id: StringName in _starter_parts():
		if _inventory.count(item_id) < 1:
			return false
	return true


func _find_starter_placement() -> Dictionary:
	var base_x: int = roundi(_planned_spawn.x) + 4
	var base_z: int = roundi(_planned_spawn.z)
	for radius: int in range(0, 13):
		for offset_z: int in range(-radius, radius + 1):
			for offset_x: int in range(-radius, radius + 1):
				if radius > 0 and absi(offset_x) != radius and absi(offset_z) != radius:
					continue
				var x: int = base_x + offset_x
				var z: int = base_z + offset_z
				var height: int = TerrainGeneratorLocal.surface_height(WORLD_SEED, x, z)
				var origin := Vector3i(x, height + 1, z)
				var positions: Array[Vector3i] = [
					origin,
					origin + Vector3i.RIGHT,
					origin + Vector3i.RIGHT * 2,
					origin + Vector3i.FORWARD,
				]
				var valid: bool = true
				for position: Vector3i in positions:
					var surface: int = TerrainGeneratorLocal.surface_height(WORLD_SEED, position.x, position.z)
					if surface != height or _current_material(position) != VoxelChunk.AIR or _machine_at_position(position):
						valid = false
						break
					if _current_material(position - Vector3i.UP) == VoxelChunk.AIR:
						valid = false
						break
				if valid:
					return {"valid": true, "origin": origin}
	return {"valid": false}


func _save_machines_now() -> bool:
	var temporary_path: String = MACHINE_SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_error("KINETICS machine save could not open temporary file")
		return false
	file.store_string(JSON.stringify(_machines.encode(), "\t"))
	file.flush()
	file = null
	var target: String = ProjectSettings.globalize_path(MACHINE_SAVE_PATH)
	var temporary: String = ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(MACHINE_SAVE_PATH):
		DirAccess.remove_absolute(target)
	var result: Error = DirAccess.rename_absolute(temporary, target)
	if result != OK:
		push_error("KINETICS machine save rename failed: %s" % error_string(result))
		return false
	return true


func _load_machines() -> void:
	if not FileAccess.file_exists(MACHINE_SAVE_PATH):
		return
	var file := FileAccess.open(MACHINE_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not _machines.decode(parsed):
		push_warning("KINETICS machine save was invalid; starting empty")
		_machines = KineticMachineState.new()


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	var parts_before: Dictionary = {}
	for item_id: StringName in _starter_parts():
		parts_before[str(item_id)] = _inventory.count(item_id)
	if _machines.machines.is_empty():
		var placement: Dictionary = _find_starter_placement()
		if not bool(placement.get("valid", false)):
			push_error("QA_KINETIC could not find a supported starter placement")
			get_tree().quit(1)
			return
		var origin: Vector3i = placement.get("origin", Vector3i.ZERO)
		var placements: Array[Dictionary] = [
			{"item": ItemRegistry.ITEM_HAND_CRANK, "position": origin},
			{"item": ItemRegistry.ITEM_STONE_SHAFT, "position": origin + Vector3i.RIGHT},
			{"item": ItemRegistry.ITEM_STONE_CRUSHER, "position": origin + Vector3i.RIGHT * 2},
			{"item": ItemRegistry.ITEM_WORKBENCH, "position": origin + Vector3i.FORWARD},
		]
		for placement_row: Dictionary in placements:
			var item_id := StringName(placement_row.item)
			var position: Vector3i = placement_row.position
			if not _place_engineering_item(position, item_id, true):
				push_error("QA_KINETIC could not place %s from the hotbar" % item_id)
				get_tree().quit(1)
				return
	var parts_consumed: bool = true
	for item_id: StringName in _starter_parts():
		parts_consumed = parts_consumed and int(parts_before[str(item_id)]) == 1 and _inventory.count(item_id) == 0
	if _inventory.count(ItemRegistry.ITEM_STONE_CRUSHER) <= 0:
		if _inventory.add(ItemRegistry.ITEM_STONE_CRUSHER, 1) != 0:
			push_error("QA_KINETIC could not grant selected crusher evidence item")
			get_tree().quit(1)
			return
		_mark_inventory_changed("qa_hotbar_engineering_evidence", ItemRegistry.ITEM_STONE_CRUSHER, 1)
	if not _select_hotbar_item(ItemRegistry.ITEM_STONE_CRUSHER):
		push_error("QA_KINETIC could not select Stone Crusher in the bottom hotbar")
		get_tree().quit(1)
		return
	var before_stone: int = _inventory.count(ItemRegistry.ITEM_STONE)
	if before_stone < 2:
		_inventory.add(ItemRegistry.ITEM_STONE, 2 - before_stone)
	if not _load_stone_into_machine(2):
		push_error("QA_KINETIC could not load crusher input")
		get_tree().quit(1)
		return
	var report: Dictionary = _machines.crank(KineticMachineState.PROCESS_TURNS)
	var processed: bool = _machines.process()
	var output_waiting: int = _machines.crusher_output
	var collected: int = _collect_machine_output()
	var persisted: bool = _save_machines_now() and qa_reload_machines_for_test()
	qa_save_inventory_now()
	var hotbar_persisted: bool = qa_reload_hotbar_for_test()
	if not (
		parts_consumed
		and _machines.machines.size() == 4
		and _machines.is_assembled()
		and bool(report.get("connected", false))
		and int(report.get("turns_added", 0)) == KineticMachineState.PROCESS_TURNS
		and processed
		and output_waiting == KineticMachineState.PROCESS_OUTPUT
		and collected == KineticMachineState.PROCESS_OUTPUT
		and persisted
		and hotbar_persisted
		and _selected_item == ItemRegistry.ITEM_STONE_CRUSHER
	):
		push_error("QA_KINETIC functional placed-object survival loop failed")
		get_tree().quit(1)
		return
	print(
		"QA_KINETIC_MACHINE_PASS assembled=", _machines.is_assembled(),
		" connected=", report.get("connected", false),
		" rpm=", report.get("source_rpm", 0.0),
		" placed_individually=", true,
		" parts_consumed=", parts_consumed,
		" output_waiting=", output_waiting,
		" collected=", collected,
		" selected=", _selected_item,
		" persisted=", persisted and hotbar_persisted
	)


func qa_reload_machines_for_test() -> bool:
	var file := FileAccess.open(MACHINE_SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var restored = KineticMachineState.new()
	return parsed is Dictionary and restored.decode(parsed) and restored.encode() == _machines.encode()


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["kinetic_machines"] = _machines.encode()
	snapshot["kinetic_report"] = _machines.network_report()
	return snapshot
