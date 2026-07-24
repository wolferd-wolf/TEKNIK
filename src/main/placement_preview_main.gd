extends "res://src/main/targeted_interaction_main.gd"

# Placement feedback must never compete with the mining target. It appears only
# for a short confirmation after PLACE is pressed, instead of drawing a second
# red or green cube permanently beside the selected mining block.
const PREVIEW_VISIBLE_SECONDS: float = 0.28
const PREVIEW_RADIUS: float = 0.506
const PREVIEW_THICKNESS: float = 0.014
const PREVIEW_LENGTH: float = 1.012
const PREVIEW_VALID_COLOR := Color(0.28, 1.0, 0.52, 0.92)
const PREVIEW_INVALID_COLOR := Color(1.0, 0.28, 0.22, 0.92)

var _placement_preview: Dictionary = {}
var _placement_preview_root: Node3D
var _placement_preview_material: StandardMaterial3D
var _placement_preview_remaining: float = 0.0


func _ready() -> void:
	super._ready()
	_build_placement_preview()


func _process(delta: float) -> void:
	super._process(delta)
	if _placement_preview_remaining <= 0.0:
		return
	_placement_preview_remaining = maxf(0.0, _placement_preview_remaining - delta)
	if _placement_preview_remaining <= 0.0 and _placement_preview_root != null:
		_placement_preview_root.visible = false


func _on_place_requested(origin: Vector3, direction: Vector3) -> void:
	var preview: Dictionary = _find_placement_preview(origin, direction)
	_set_placement_preview(preview)
	_placement_preview_remaining = PREVIEW_VISIBLE_SECONDS
	if preview.is_empty() or not bool(preview.get("valid", false)):
		_runtime_log.event("info", "interaction", "placement_preview_rejected", {
			"voxel": str(preview.get("voxel", Vector3i.ZERO)),
			"reason": str(preview.get("reason", "no_target")),
			"item": str(_selected_item),
		})
		return
	var voxel: Vector3i = preview.get("voxel", Vector3i.ZERO)
	var material: int = ItemRegistry.material_for_item(_selected_item)
	if not _survival_place_voxel(voxel, material, "placed", true):
		return
	_runtime_log.event("info", "interaction", "previewed_block_placed", {
		"voxel": str(voxel),
		"item": str(_selected_item),
		"exact_preview": true,
	})


func _build_placement_preview() -> void:
	_placement_preview_root = Node3D.new()
	_placement_preview_root.name = "BlockPlacementPreview"
	_placement_preview_root.top_level = true
	_placement_preview_root.visible = false
	add_child(_placement_preview_root)

	_placement_preview_material = StandardMaterial3D.new()
	_placement_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_placement_preview_material.albedo_color = PREVIEW_VALID_COLOR
	_placement_preview_material.metallic = 0.0
	_placement_preview_material.roughness = 1.0

	for y: float in [-PREVIEW_RADIUS, PREVIEW_RADIUS]:
		for z: float in [-PREVIEW_RADIUS, PREVIEW_RADIUS]:
			_add_preview_edge(Vector3(0.0, y, z), Vector3(PREVIEW_LENGTH, PREVIEW_THICKNESS, PREVIEW_THICKNESS))
	for x: float in [-PREVIEW_RADIUS, PREVIEW_RADIUS]:
		for z: float in [-PREVIEW_RADIUS, PREVIEW_RADIUS]:
			_add_preview_edge(Vector3(x, 0.0, z), Vector3(PREVIEW_THICKNESS, PREVIEW_LENGTH, PREVIEW_THICKNESS))
	for x: float in [-PREVIEW_RADIUS, PREVIEW_RADIUS]:
		for y: float in [-PREVIEW_RADIUS, PREVIEW_RADIUS]:
			_add_preview_edge(Vector3(x, y, 0.0), Vector3(PREVIEW_THICKNESS, PREVIEW_THICKNESS, PREVIEW_LENGTH))


func _add_preview_edge(position_value: Vector3, size_value: Vector3) -> void:
	var edge := MeshInstance3D.new()
	edge.name = "BlockPlacementPreviewEdge"
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = _placement_preview_material
	edge.mesh = mesh
	edge.position = position_value
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_placement_preview_root.add_child(edge)


func _find_placement_preview(origin: Vector3, direction: Vector3) -> Dictionary:
	var hit: Dictionary = _find_break_target(origin, direction)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	var face := Vector3i(roundi(normal.x), roundi(normal.y), roundi(normal.z))
	if face == Vector3i.ZERO:
		return {}
	var voxel: Vector3i = hit.get("voxel", Vector3i.ZERO) + face
	var material: int = ItemRegistry.material_for_item(_selected_item)
	var reason: String = ""
	var valid: bool = true
	if material == ItemRegistry.AIR or _inventory.count(_selected_item) <= 0:
		valid = false
		reason = "missing_selected_item"
	elif _current_material(voxel) != VoxelChunk.AIR:
		valid = false
		reason = "occupied"
	elif _placement_intersects_player(voxel):
		valid = false
		reason = "player_overlap"
	return {
		"voxel": voxel,
		"normal": normal,
		"valid": valid,
		"reason": reason,
		"distance": float(hit.get("distance", 0.0)),
	}


func _set_placement_preview(preview: Dictionary) -> void:
	_placement_preview = preview
	if _placement_preview_root == null:
		return
	var visible: bool = not preview.is_empty()
	_placement_preview_root.visible = visible
	if not visible:
		return
	var voxel: Vector3i = preview.get("voxel", Vector3i.ZERO)
	_placement_preview_root.global_position = VoxelRaycast.outline_center(voxel)
	if _placement_preview_material != null:
		_placement_preview_material.albedo_color = PREVIEW_VALID_COLOR if bool(preview.get("valid", false)) else PREVIEW_INVALID_COLOR


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	if _placement_preview_root == null or _placement_preview_root.get_child_count() != 12:
		push_error("QA_PLACEMENT_PREVIEW expected 12 wireframe edges")
		get_tree().quit(1)
		return
	if _placement_preview_root.visible:
		push_error("QA_PLACEMENT_PREVIEW must stay hidden until PLACE input")
		get_tree().quit(1)
		return
	print(
		"QA_PLACEMENT_PREVIEW_PASS edges=", _placement_preview_root.get_child_count(),
		" idle_hidden=", true,
		" confirmation_seconds=", PREVIEW_VISIBLE_SECONDS,
		" selected_item=", _selected_item
	)
