extends "res://src/main/targeted_interaction_main.gd"

const PREVIEW_REFRESH_SECONDS: float = 0.05
const PREVIEW_RADIUS: float = 0.508
const PREVIEW_THICKNESS: float = 0.025
const PREVIEW_LENGTH: float = 1.016
const PREVIEW_VALID_COLOR := Color(0.28, 1.0, 0.52, 0.95)
const PREVIEW_INVALID_COLOR := Color(1.0, 0.28, 0.22, 0.95)

var _placement_preview_refresh_remaining: float = 0.0
var _placement_preview: Dictionary = {}
var _placement_preview_root: Node3D
var _placement_preview_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	_build_placement_preview()
	_refresh_placement_preview()


func _process(delta: float) -> void:
	super._process(delta)
	_placement_preview_refresh_remaining -= delta
	if _placement_preview_refresh_remaining <= 0.0:
		_placement_preview_refresh_remaining = PREVIEW_REFRESH_SECONDS
		_refresh_placement_preview()


func _on_place_requested(origin: Vector3, direction: Vector3) -> void:
	var preview: Dictionary = _find_placement_preview(origin, direction)
	_set_placement_preview(preview)
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
		_refresh_placement_preview()
		return
	_runtime_log.event("info", "interaction", "previewed_block_placed", {
		"voxel": str(voxel),
		"item": str(_selected_item),
		"exact_preview": true,
	})
	_refresh_placement_preview()


func _build_placement_preview() -> void:
	_placement_preview_root = Node3D.new()
	_placement_preview_root.name = "BlockPlacementPreview"
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


func _refresh_placement_preview() -> void:
	if _player == null:
		_set_placement_preview({})
		return
	var camera := _player.get_node_or_null("CameraPivot/PlayerCamera") as Camera3D
	if camera == null:
		_set_placement_preview({})
		return
	_set_placement_preview(_find_placement_preview(
		camera.global_position,
		-camera.global_transform.basis.z.normalized()
	))


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
	var hit := {
		"voxel": Vector3i(4, 3, -2),
		"normal": Vector3.UP,
	}
	var preview_voxel: Vector3i = hit.voxel + Vector3i(0, 1, 0)
	if preview_voxel != Vector3i(4, 4, -2):
		push_error("QA_PLACEMENT_PREVIEW face-adjacent voxel mismatch")
		get_tree().quit(1)
		return
	print(
		"QA_PLACEMENT_PREVIEW_PASS edges=", _placement_preview_root.get_child_count(),
		" exact_face_target=", true,
		" valid_color=", PREVIEW_VALID_COLOR,
		" invalid_color=", PREVIEW_INVALID_COLOR,
		" selected_item=", _selected_item
	)
