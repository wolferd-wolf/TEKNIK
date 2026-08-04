extends "res://scripts/player/player_controller.gd"

const INTERACTION_COOLDOWN_MSEC := 110
const TARGET_REFRESH_SECONDS := 0.05
const FACE_OUTLINE_OFFSET := 0.018
const FACE_OUTLINE_INSET := 0.035
const FIRST_PERSON_NEAR_PLANE := 0.10

var force_mobile_input_for_test := false
var last_interaction_msec := -INTERACTION_COOLDOWN_MSEC
var target_refresh_elapsed := 0.0
var target_outline: MeshInstance3D
var target_outline_mesh: ImmediateMesh
var targeted_cell := Vector3i.ZERO
var targeted_face_normal := Vector3i.ZERO
var has_targeted_cell := false
var target_outline_edge_count := 0

func _ready() -> void:
	super._ready()
	if is_instance_valid(camera):
		camera.near = FIRST_PERSON_NEAR_PLANE
	_create_target_outline()
	_disable_first_person_shadow_casters()

func _process(delta: float) -> void:
	target_refresh_elapsed += delta
	if target_refresh_elapsed < TARGET_REFRESH_SECONDS:
		return
	target_refresh_elapsed = fmod(target_refresh_elapsed, TARGET_REFRESH_SECONDS)
	_refresh_target_outline()

func _unhandled_input(event: InputEvent) -> void:
	# Android converts screen taps into mouse-button events as well as touch events.
	# Never let those emulated mouse events enter the desktop mining/placement path.
	if _uses_touch_only_actions():
		return
	super._unhandled_input(event)

func request_mine() -> void:
	if not _consume_interaction_slot():
		return
	mine_requested = true

func request_place() -> void:
	if not _consume_interaction_slot():
		return
	place_requested = true

func _consume_interaction_slot() -> bool:
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_interaction_msec < INTERACTION_COOLDOWN_MSEC:
		return false
	last_interaction_msec = now_msec
	return true

func _uses_touch_only_actions() -> bool:
	return OS.has_feature("mobile") or force_mobile_input_for_test

func _create_target_outline() -> void:
	target_outline_mesh = ImmediateMesh.new()
	target_outline = MeshInstance3D.new()
	target_outline.name = "TargetOutline"
	target_outline.mesh = target_outline_mesh
	target_outline.visible = false
	target_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_outline.set_as_top_level(true)

	var outline_material := StandardMaterial3D.new()
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline_material.albedo_color = Color(1.0, 0.86, 0.20, 0.96)
	# Keep depth testing enabled so hidden edges never draw through terrain.
	outline_material.no_depth_test = false
	target_outline.material_override = outline_material
	add_child(target_outline)

func _disable_first_person_shadow_casters() -> void:
	# First-person helper geometry must never cast into the camera view.
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry != null:
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _refresh_target_outline() -> void:
	if not is_instance_valid(world) or not is_instance_valid(camera) or not is_instance_valid(target_outline):
		_clear_target_outline()
		return

	var origin: Vector3 = camera.global_position
	var direction: Vector3 = -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * INTERACTION_DISTANCE)
	query.collision_mask = 1
	query.hit_from_inside = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_clear_target_outline()
		return

	var hit_position: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var face_normal := Vector3i(roundi(normal.x), roundi(normal.y), roundi(normal.z))
	if face_normal == Vector3i.ZERO:
		_clear_target_outline()
		return

	var target_position: Vector3 = hit_position - normal * 0.02
	var cell := Vector3i(floori(target_position.x), floori(target_position.y), floori(target_position.z))
	if world.get_block(cell) == world.BLOCK_AIR:
		_clear_target_outline()
		return

	targeted_cell = cell
	targeted_face_normal = face_normal
	has_targeted_cell = true
	target_outline.global_position = Vector3(cell)
	_rebuild_face_outline_mesh(face_normal)
	target_outline.visible = true

func _clear_target_outline() -> void:
	has_targeted_cell = false
	targeted_face_normal = Vector3i.ZERO
	target_outline_edge_count = 0
	if is_instance_valid(target_outline):
		target_outline.visible = false

func _rebuild_face_outline_mesh(face_normal: Vector3i) -> void:
	if target_outline_mesh == null:
		return

	target_outline_mesh.clear_surfaces()
	var low := FACE_OUTLINE_INSET
	var high := 1.0 - FACE_OUTLINE_INSET
	var offset := FACE_OUTLINE_OFFSET
	var corners: Array[Vector3] = []

	match face_normal:
		Vector3i.UP:
			corners = [
				Vector3(low, 1.0 + offset, low),
				Vector3(high, 1.0 + offset, low),
				Vector3(high, 1.0 + offset, high),
				Vector3(low, 1.0 + offset, high)
			]
		Vector3i.DOWN:
			corners = [
				Vector3(low, -offset, high),
				Vector3(high, -offset, high),
				Vector3(high, -offset, low),
				Vector3(low, -offset, low)
			]
		Vector3i.RIGHT:
			corners = [
				Vector3(1.0 + offset, low, high),
				Vector3(1.0 + offset, low, low),
				Vector3(1.0 + offset, high, low),
				Vector3(1.0 + offset, high, high)
			]
		Vector3i.LEFT:
			corners = [
				Vector3(-offset, low, low),
				Vector3(-offset, low, high),
				Vector3(-offset, high, high),
				Vector3(-offset, high, low)
			]
		Vector3i.BACK:
			corners = [
				Vector3(low, low, 1.0 + offset),
				Vector3(high, low, 1.0 + offset),
				Vector3(high, high, 1.0 + offset),
				Vector3(low, high, 1.0 + offset)
			]
		Vector3i.FORWARD:
			corners = [
				Vector3(high, low, -offset),
				Vector3(low, low, -offset),
				Vector3(low, high, -offset),
				Vector3(high, high, -offset)
			]
		_:
			target_outline_edge_count = 0
			return

	var edge_indices: Array[int] = [0, 1, 1, 2, 2, 3, 3, 0]
	target_outline_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in edge_indices:
		target_outline_mesh.surface_add_vertex(corners[index])
	target_outline_mesh.surface_end()
	target_outline_edge_count = 4

func get_target_outline_edge_count() -> int:
	return target_outline_edge_count

func get_target_status_text() -> String:
	if not has_targeted_cell:
		return "target none"
	return "target %d,%d,%d face %d,%d,%d" % [
		targeted_cell.x,
		targeted_cell.y,
		targeted_cell.z,
		targeted_face_normal.x,
		targeted_face_normal.y,
		targeted_face_normal.z
	]
