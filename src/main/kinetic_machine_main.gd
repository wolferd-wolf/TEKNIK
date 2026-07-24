extends "res://src/main/survival_shipping_main.gd"

const KineticMachineState = preload("res://src/simulation/kinetic_machine_state.gd")
const MACHINE_SAVE_PATH: String = "user://teknik-machines.json"

var _machines: TeknikKineticMachineState = KineticMachineState.new()
var _machine_root: Node3D
var _machine_status: Label


func _ready() -> void:
	_load_machines()
	super._ready()
	_build_machine_hud()
	_rebuild_machine_visuals()


func _build_machine_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "KineticMachineHUD"
	layer.layer = 8
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(360.0, 12.0)
	panel.custom_minimum_size = Vector2(300.0, 118.0)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	_machine_status = Label.new()
	_machine_status.text = "KINETICS: not assembled"
	content.add_child(_machine_status)
	var button := Button.new()
	button.text = "Turn Crank / Process Stone"
	button.pressed.connect(_on_machine_button_pressed)
	content.add_child(button)
	_refresh_machine_status()


func _on_machine_button_pressed() -> void:
	if _machines.machines.is_empty():
		_assemble_starter_machine()
	if _machines.crusher_input < 2 and _inventory.count(ItemRegistry.ITEM_STONE) >= 2:
		_inventory.remove(ItemRegistry.ITEM_STONE, 2)
		_machines.insert_stone(2)
	_machines.crank(4)
	if _machines.process():
		var output: int = _machines.collect_output()
		_inventory.add(ItemRegistry.ITEM_CRUSHED_STONE, output)
		_mark_inventory_changed("machine_output", ItemRegistry.ITEM_CRUSHED_STONE, output)
	_save_machines_now()
	_refresh_machine_status()


func _assemble_starter_machine() -> bool:
	if _inventory.count(ItemRegistry.ITEM_WORKBENCH) < 1 or _inventory.count(ItemRegistry.ITEM_HAND_CRANK) < 1:
		return false
	_inventory.remove(ItemRegistry.ITEM_WORKBENCH, 1)
	_inventory.remove(ItemRegistry.ITEM_HAND_CRANK, 1)
	var origin := Vector3i(roundi(_planned_spawn.x) + 3, TerrainGenerator.surface_height(WORLD_SEED, roundi(_planned_spawn.x) + 3, roundi(_planned_spawn.z)) + 1, roundi(_planned_spawn.z))
	var placed: bool = (
		_machines.place(&"crank", KineticMachineState.TYPE_CRANK, origin)
		and _machines.place(&"shaft_a", KineticMachineState.TYPE_SHAFT, origin + Vector3i.RIGHT)
		and _machines.place(&"crusher", KineticMachineState.TYPE_CRUSHER, origin + Vector3i.RIGHT * 2)
		and _machines.place(&"workbench", KineticMachineState.TYPE_WORKBENCH, origin + Vector3i.FORWARD)
	)
	if placed:
		_rebuild_machine_visuals()
		_save_machines_now()
	return placed


func _rebuild_machine_visuals() -> void:
	if _machine_root != null:
		_machine_root.queue_free()
	_machine_root = Node3D.new()
	_machine_root.name = "PlacedKineticMachines"
	add_child(_machine_root)
	for id_variant: Variant in _machines.machines.keys():
		var id := StringName(id_variant)
		var row: Dictionary = _machines.machines[id]
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.9, 0.9, 0.9)
		var material := StandardMaterial3D.new()
		match StringName(row.type):
			KineticMachineState.TYPE_CRANK:
				material.albedo_color = Color("b87942")
			KineticMachineState.TYPE_SHAFT:
				material.albedo_color = Color("777d78")
			KineticMachineState.TYPE_CRUSHER:
				material.albedo_color = Color("4f5755")
			_:
				material.albedo_color = Color("816e55")
		mesh.material = material
		mesh_instance.mesh = mesh
		mesh_instance.position = Vector3(row.position) + Vector3(0.5, 0.5, 0.5)
		_machine_root.add_child(mesh_instance)


func _refresh_machine_status() -> void:
	if _machine_status == null:
		return
	var report: Dictionary = _machines.network_report()
	_machine_status.text = "KINETICS\nConnected: %s  RPM: %.0f\nInput: %d  Output: %d  Turns: %d" % [
		str(bool(report.connected)), float(report.source_rpm), _machines.crusher_input,
		_machines.crusher_output, _machines.stored_turns,
	]


func _save_machines_now() -> void:
	var file := FileAccess.open(MACHINE_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("KINETICS machine save could not open")
		return
	file.store_string(JSON.stringify(_machines.encode(), "\t"))
	file.flush()


func _load_machines() -> void:
	if not FileAccess.file_exists(MACHINE_SAVE_PATH):
		return
	var file := FileAccess.open(MACHINE_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_machines.decode(parsed)


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	if _machines.machines.is_empty() and not _assemble_starter_machine():
		push_error("QA_KINETIC could not assemble starter machine")
		get_tree().quit(1)
		return
	var before_stone: int = _inventory.count(ItemRegistry.ITEM_STONE)
	if before_stone < 2:
		_inventory.add(ItemRegistry.ITEM_STONE, 2 - before_stone)
	_inventory.remove(ItemRegistry.ITEM_STONE, 2)
	var inserted: int = _machines.insert_stone(2)
	var report: Dictionary = _machines.crank(4)
	var processed: bool = _machines.process()
	var output: int = _machines.collect_output()
	_inventory.add(ItemRegistry.ITEM_CRUSHED_STONE, output)
	_save_machines_now()
	var encoded: Dictionary = _machines.encode()
	var restored := KineticMachineState.new()
	var persisted: bool = restored.decode(encoded) and restored.encode() == encoded
	if not (inserted == 2 and bool(report.connected) and processed and output == 3 and persisted):
		push_error("QA_KINETIC functional loop failed")
		get_tree().quit(1)
		return
	print("QA_KINETIC_MACHINE_PASS connected=", report.connected, " rpm=", report.source_rpm, " output=", output, " persisted=", persisted)


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["kinetic_machines"] = _machines.encode()
	snapshot["kinetic_report"] = _machines.network_report()
	return snapshot
