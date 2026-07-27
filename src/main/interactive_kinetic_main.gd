extends "res://src/main/kinetic_machine_main.gd"

const MACHINE_INTERACTION_DISTANCE: float = 4.75
const TARGET_REFRESH_SECONDS: float = 0.10
const POWER_ANIMATION_SECONDS: float = 1.35
const ROTATION_SPEED_RAD: float = TAU * 1.6

var _interact_button: Button
var _interaction_hint: Label
var _target_refresh_remaining: float = 0.0
var _target_machine: StaticBody3D
var _animation_remaining: float = 0.0
var _rotating_visuals: Array[Node3D] = []


func _ready() -> void:
	super._ready()
	_build_interaction_hud()
	_disable_legacy_machine_actions()
	_refresh_target_machine()


func _process(delta: float) -> void:
	super._process(delta)
	_target_refresh_remaining -= delta
	if _target_refresh_remaining <= 0.0:
		_target_refresh_remaining = TARGET_REFRESH_SECONDS
		_refresh_target_machine()
	if _animation_remaining > 0.0:
		_animation_remaining = maxf(0.0, _animation_remaining - delta)
		for visual: Node3D in _rotating_visuals:
			if is_instance_valid(visual):
				visual.rotate_x(ROTATION_SPEED_RAD * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact_with_target()
		get_viewport().set_input_as_handled()


func _build_interaction_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MachineInteractionHUD"
	layer.layer = 21
	add_child(layer)
	_interaction_hint = Label.new()
	_interaction_hint.name = "MachineInteractionHint"
	_interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_hint.set_anchors_preset(Control.PRESET_CENTER)
	_interaction_hint.position = Vector2(-185.0, 34.0)
	_interaction_hint.size = Vector2(370.0, 34.0)
	_interaction_hint.add_theme_font_size_override("font_size", 17)
	_interaction_hint.visible = false
	layer.add_child(_interaction_hint)
	_interact_button = Button.new()
	_interact_button.name = "InteractMachine"
	_interact_button.text = "INTERACT"
	_interact_button.custom_minimum_size = Vector2(132.0, 54.0)
	_interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_interact_button.position = Vector2(-290.0, -154.0)
	_interact_button.visible = false
	_interact_button.pressed.connect(_interact_with_target)
	layer.add_child(_interact_button)


func _disable_legacy_machine_actions() -> void:
	if _assemble_button != null:
		_assemble_button.visible = false
	if _load_button != null:
		_load_button.visible = false
	if _crank_button != null:
		_crank_button.visible = false
	if _collect_button != null:
		_collect_button.visible = false


func _rebuild_machine_visuals() -> void:
	super._rebuild_machine_visuals()
	_rotating_visuals.clear()
	if _machine_root == null:
		return
	for child: Node in _machine_root.get_children():
		var body := child as StaticBody3D
		if body == null:
			continue
		var machine_id: String = str(body.get_meta("teknik_machine_id", ""))
		var row: Dictionary = _machines.machines.get(machine_id, {})
		var machine_type := StringName(str(row.get("type", "")))
		var primary := body.get_child(0) as Node3D if body.get_child_count() > 0 else null
		if machine_type == KineticMachineState.TYPE_CRANK or machine_type == KineticMachineState.TYPE_SHAFT:
			if primary != null:
				_rotating_visuals.append(primary)
		elif machine_type == KineticMachineState.TYPE_CRUSHER:
			_add_crusher_rollers(body)


func _add_crusher_rollers(body: StaticBody3D) -> void:
	for offset_x: float in [-0.22, 0.22]:
		var roller := MeshInstance3D.new()
		roller.name = "CrusherRoller"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.14
		mesh.bottom_radius = 0.14
		mesh.height = 0.70
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("9a8d70")
		material.metallic = 0.38
		material.roughness = 0.48
		mesh.material = material
		roller.mesh = mesh
		roller.position = Vector3(offset_x, 0.18, -0.48)
		roller.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		body.add_child(roller)
		_rotating_visuals.append(roller)


func _refresh_target_machine() -> void:
	_target_machine = _raycast_machine()
	var has_target: bool = _target_machine != null
	_set_machine_hud_targeted(has_target)
	if _interact_button != null:
		_interact_button.disabled = not has_target
		_interact_button.visible = has_target
	if _interaction_hint == null:
		return
	_interaction_hint.visible = has_target
	if not has_target:
		_interaction_hint.text = ""
		return
	var machine_type := StringName(_target_machine.get_meta("teknik_machine_type", &""))
	_interaction_hint.text = _interaction_prompt(machine_type)


func _raycast_machine() -> StaticBody3D:
	if _player == null:
		return null
	var camera := _player.get_node_or_null("CameraPivot/PlayerCamera") as Camera3D
	if camera == null:
		return null
	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * MACHINE_INTERACTION_DISTANCE
	)
	query.exclude = [_player.get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as StaticBody3D
	if collider == null or not collider.has_meta("teknik_machine_type"):
		return null
	return collider


func _interaction_prompt(machine_type: StringName) -> String:
	match machine_type:
		KineticMachineState.TYPE_CRANK:
			return "INTERACT: turn hand crank"
		KineticMachineState.TYPE_CRUSHER:
			return "INTERACT: collect output" if _machines.crusher_output > 0 else "INTERACT: load 2 Stone"
		KineticMachineState.TYPE_SHAFT:
			return "Shaft: connected at %.0f RPM" % float(_machines.network_report().get("source_rpm", 0.0))
		_:
			return "INTERACT: open workbench blueprints"


func _interact_with_target() -> bool:
	_refresh_target_machine()
	if _target_machine == null:
		_set_machine_message("No machine in range")
		return false
	var machine_type := StringName(_target_machine.get_meta("teknik_machine_type", &""))
	return _interact_with_machine_type(machine_type)


func _interact_with_machine_type(machine_type: StringName) -> bool:
	match machine_type:
		KineticMachineState.TYPE_CRANK:
			var report: Dictionary = _machines.crank(KineticMachineState.PROCESS_TURNS)
			var processed: bool = _machines.process()
			if int(report.get("turns_added", 0)) <= 0:
				_set_machine_message("Crank is not connected")
				return false
			_animation_remaining = POWER_ANIMATION_SECONDS
			_set_machine_message("Crusher produced 3 Crushed Stone" if processed else "Power stored; load Stone to process")
			_save_machines_now()
			_refresh_machine_status()
			return true
		KineticMachineState.TYPE_CRUSHER:
			if _machines.crusher_output > 0:
				var collected: int = _collect_machine_output()
				_set_machine_message("Collected %d Crushed Stone" % collected if collected > 0 else "Inventory is full")
				_refresh_machine_status()
				return collected > 0
			var loaded: bool = _load_stone_into_machine(2)
			_set_machine_message("Loaded 2 Stone" if loaded else "Need 2 Stone or crusher input space")
			_refresh_machine_status()
			return loaded
		KineticMachineState.TYPE_SHAFT:
			_set_machine_message("Shaft connection is healthy")
			return true
		_:
			# A workbench is an interactive station. The old branch only printed
			# "Workbench ready", so touch input succeeded without opening anything.
			_open_engineering_station()
			var industrial_ui := get_node_or_null("IndustrialBlueprintUI")
			if industrial_ui != null and industrial_ui.has_method("open_workbench"):
				industrial_ui.call("open_workbench")
			_set_machine_message("Workbench blueprints opened")
			return true


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	_rebuild_machine_visuals()
	_animation_remaining = POWER_ANIMATION_SECONDS
	var annotated: int = 0
	for child: Node in _machine_root.get_children() if _machine_root != null else []:
		if child.has_meta("teknik_machine_type"):
			annotated += 1
	if annotated != 4 or _rotating_visuals.size() < 4:
		push_error("QA_KINETIC_INTERACTION machine targeting or animation setup failed")
		get_tree().quit(1)
		return

	var workbench_opened: bool = _interact_with_machine_type(StringName(KineticMachineState.TYPE_WORKBENCH))
	var industrial_ui := get_node_or_null("IndustrialBlueprintUI")
	var workbench_page_visible: bool = (
		industrial_ui != null
		and industrial_ui.has_method("is_crafting_page_visible")
		and bool(industrial_ui.call("is_crafting_page_visible"))
	)
	if not workbench_opened or not workbench_page_visible:
		push_error("QA_KINETIC_INTERACTION workbench did not open the crafting workspace")
		get_tree().quit(1)
		return

	print(
		"QA_KINETIC_INTERACTION_PASS targetable=", annotated,
		" rotating_visuals=", _rotating_visuals.size(),
		" range=", MACHINE_INTERACTION_DISTANCE,
		" legacy_actions_hidden=", not _assemble_button.visible and not _load_button.visible and not _crank_button.visible and not _collect_button.visible,
		" idle_prompt_hidden=", not _interaction_hint.visible,
		" idle_machine_panel_hidden=", not _machine_hud_panel.visible,
		" workbench_workspace_visible=", workbench_page_visible
	)
