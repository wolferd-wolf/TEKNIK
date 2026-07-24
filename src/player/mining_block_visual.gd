class_name TeknikMiningBlockVisual
extends Node3D

# One selected block owns all world-space mining feedback: a thin outline and
# staged crack ribbons. There is no filled cube, second target box, transparent
# shell, or texture copied from another game.
const OUTLINE_RADIUS: float = 0.504
const CRACK_FACE_OFFSET: float = 0.513
const CRACK_HALF_WIDTH: float = 0.010
const CRACK_STAGE_COUNT: int = 10

var _outline: MeshInstance3D
var _cracks: MeshInstance3D
var _crack_material: StandardMaterial3D
var _crack_stage: int = -1


func _ready() -> void:
	top_level = true
	_build_outline()
	_build_cracks()
	visible = false


func show_target(voxel: Vector3i) -> void:
	global_position = Vector3(voxel) + Vector3.ONE * 0.5
	visible = true


func clear_target() -> void:
	visible = false
	set_progress(0.0)


func set_progress(progress: float) -> void:
	var value: float = clampf(progress, 0.0, 1.0)
	var next_stage: int = 0 if value <= 0.001 else clampi(ceili(value * float(CRACK_STAGE_COUNT)), 1, CRACK_STAGE_COUNT)
	if next_stage == _crack_stage:
		return
	_crack_stage = next_stage
	if _cracks == null:
		return
	_cracks.visible = next_stage > 0
	_cracks.mesh = _build_crack_mesh(next_stage) if next_stage > 0 else null


func outline_visible() -> bool:
	return visible and _outline != null and _outline.visible


func cracks_visible() -> bool:
	return visible and _cracks != null and _cracks.visible and _crack_stage > 0


func crack_stage() -> int:
	return _crack_stage


func _build_outline() -> void:
	_outline = MeshInstance3D.new()
	_outline.name = "MiningSelectionOutline"
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.025, 0.03, 0.035, 0.96)
	var r: float = OUTLINE_RADIUS
	var corners: Array[Vector3] = [
		Vector3(-r, -r, -r), Vector3(r, -r, -r),
		Vector3(r, r, -r), Vector3(-r, r, -r),
		Vector3(-r, -r, r), Vector3(r, -r, r),
		Vector3(r, r, r), Vector3(-r, r, r),
	]
	var edges: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
		Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
		Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7),
	]
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for edge: Vector2i in edges:
		mesh.surface_add_vertex(corners[edge.x])
		mesh.surface_add_vertex(corners[edge.y])
	mesh.surface_end()
	_outline.mesh = mesh
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline)


func _build_cracks() -> void:
	_cracks = MeshInstance3D.new()
	_cracks.name = "MiningCrackOverlay"
	_crack_material = StandardMaterial3D.new()
	_crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crack_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_crack_material.albedo_color = Color(0.018, 0.022, 0.026, 0.94)
	_cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cracks.visible = false
	add_child(_cracks)
	set_progress(0.0)


func _build_crack_mesh(stage: int) -> ImmediateMesh:
	# Original procedural crack pattern. Geometry is expanded beyond every block
	# face, so it cannot z-fight into the large black triangles produced by the
	# previous transparent shell.
	var mesh := ImmediateMesh.new()
	var segments: Array[PackedVector2Array] = _crack_segments()
	var visible_segment_count: int = mini(segments.size(), stage * 2)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _crack_material)
	for index: int in range(visible_segment_count):
		var segment: PackedVector2Array = segments[index]
		for face: int in range(6):
			_add_crack_ribbon(mesh, segment[0], segment[1], face)
	mesh.surface_end()
	return mesh


func _crack_segments() -> Array[PackedVector2Array]:
	var center := Vector2.ZERO
	return [
		PackedVector2Array([center, Vector2(-0.14, -0.14)]),
		PackedVector2Array([center, Vector2(0.16, -0.17)]),
		PackedVector2Array([center, Vector2(-0.19, 0.10)]),
		PackedVector2Array([center, Vector2(0.19, 0.13)]),
		PackedVector2Array([Vector2(-0.14, -0.14), Vector2(-0.26, -0.31)]),
		PackedVector2Array([Vector2(0.16, -0.17), Vector2(0.30, -0.33)]),
		PackedVector2Array([Vector2(-0.19, 0.10), Vector2(-0.34, 0.24)]),
		PackedVector2Array([Vector2(0.19, 0.13), Vector2(0.35, 0.29)]),
		PackedVector2Array([Vector2(-0.14, -0.14), Vector2(-0.31, -0.06)]),
		PackedVector2Array([Vector2(0.16, -0.17), Vector2(0.25, -0.02)]),
		PackedVector2Array([Vector2(-0.19, 0.10), Vector2(-0.12, 0.35)]),
		PackedVector2Array([Vector2(0.19, 0.13), Vector2(0.08, 0.37)]),
		PackedVector2Array([Vector2(-0.26, -0.31), Vector2(-0.42, -0.42)]),
		PackedVector2Array([Vector2(0.30, -0.33), Vector2(0.43, -0.22)]),
		PackedVector2Array([Vector2(-0.34, 0.24), Vector2(-0.43, 0.43)]),
		PackedVector2Array([Vector2(0.35, 0.29), Vector2(0.44, 0.44)]),
		PackedVector2Array([Vector2(-0.12, 0.35), Vector2(-0.23, 0.45)]),
		PackedVector2Array([Vector2(0.08, 0.37), Vector2(0.18, 0.46)]),
	]


func _add_crack_ribbon(mesh: ImmediateMesh, start: Vector2, finish: Vector2, face: int) -> void:
	var delta: Vector2 = finish - start
	if delta.length_squared() <= 0.000001:
		return
	var perpendicular := Vector2(-delta.y, delta.x).normalized() * CRACK_HALF_WIDTH
	var a: Vector3 = _map_face_point(face, start - perpendicular)
	var b: Vector3 = _map_face_point(face, start + perpendicular)
	var c: Vector3 = _map_face_point(face, finish + perpendicular)
	var d: Vector3 = _map_face_point(face, finish - perpendicular)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(c)
	mesh.surface_add_vertex(d)


func _map_face_point(face: int, point: Vector2) -> Vector3:
	match face:
		0:
			return Vector3(point.x, point.y, CRACK_FACE_OFFSET)
		1:
			return Vector3(-point.x, point.y, -CRACK_FACE_OFFSET)
		2:
			return Vector3(CRACK_FACE_OFFSET, point.y, -point.x)
		3:
			return Vector3(-CRACK_FACE_OFFSET, point.y, point.x)
		4:
			return Vector3(point.x, CRACK_FACE_OFFSET, -point.y)
		_:
			return Vector3(point.x, -CRACK_FACE_OFFSET, point.y)
