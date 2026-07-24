class_name TeknikMiningBlockVisual
extends Node3D

# The selection feedback intentionally mirrors the readable parts of classic
# voxel games: one thin dark outline and a crack overlay on the selected block.
# No filled cube, second placement box, target colour cycling, or screen-sized
# debug geometry is used.
const OUTLINE_RADIUS: float = 0.503
const CRACK_BOX_SIZE: float = 1.008

var _outline: MeshInstance3D
var _cracks: MeshInstance3D
var _crack_material: ShaderMaterial


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
	if _crack_material != null:
		_crack_material.set_shader_parameter("progress", value)
	if _cracks != null:
		_cracks.visible = value > 0.001


func outline_visible() -> bool:
	return visible and _outline != null and _outline.visible


func cracks_visible() -> bool:
	return visible and _cracks != null and _cracks.visible


func _build_outline() -> void:
	_outline = MeshInstance3D.new()
	_outline.name = "MiningSelectionOutline"
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.035, 0.04, 0.045, 0.96)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	var box := BoxMesh.new()
	box.size = Vector3.ONE * CRACK_BOX_SIZE
	_crack_material = ShaderMaterial.new()
	_crack_material.shader = Shader.new()
	_crack_material.shader.code = _crack_shader_code()
	_crack_material.set_shader_parameter("progress", 0.0)
	box.material = _crack_material
	_cracks.mesh = box
	_cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cracks.visible = false
	add_child(_cracks)


func _crack_shader_code() -> String:
	# Original procedural crack pattern. It avoids copyrighted game textures while
	# retaining the familiar behaviour of cracks spreading as progress increases.
	return """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return length(pa - ba * h);
}

void add_segment(inout float distance_value, vec2 p, vec2 a, vec2 b, float threshold) {
	if (progress >= threshold) {
		distance_value = min(distance_value, segment_distance(p, a, b));
	}
}

void fragment() {
	vec2 p = UV;
	float d = 2.0;
	add_segment(d, p, vec2(0.50, 0.48), vec2(0.36, 0.34), 0.05);
	add_segment(d, p, vec2(0.50, 0.48), vec2(0.66, 0.31), 0.10);
	add_segment(d, p, vec2(0.50, 0.48), vec2(0.31, 0.58), 0.16);
	add_segment(d, p, vec2(0.50, 0.48), vec2(0.69, 0.61), 0.22);
	add_segment(d, p, vec2(0.36, 0.34), vec2(0.25, 0.18), 0.30);
	add_segment(d, p, vec2(0.66, 0.31), vec2(0.79, 0.16), 0.38);
	add_segment(d, p, vec2(0.31, 0.58), vec2(0.17, 0.73), 0.46);
	add_segment(d, p, vec2(0.69, 0.61), vec2(0.84, 0.76), 0.54);
	add_segment(d, p, vec2(0.36, 0.34), vec2(0.18, 0.42), 0.62);
	add_segment(d, p, vec2(0.66, 0.31), vec2(0.74, 0.46), 0.69);
	add_segment(d, p, vec2(0.31, 0.58), vec2(0.38, 0.82), 0.76);
	add_segment(d, p, vec2(0.69, 0.61), vec2(0.58, 0.85), 0.82);
	add_segment(d, p, vec2(0.25, 0.18), vec2(0.09, 0.09), 0.87);
	add_segment(d, p, vec2(0.79, 0.16), vec2(0.93, 0.27), 0.90);
	add_segment(d, p, vec2(0.17, 0.73), vec2(0.08, 0.92), 0.93);
	add_segment(d, p, vec2(0.84, 0.76), vec2(0.95, 0.94), 0.96);
	add_segment(d, p, vec2(0.38, 0.82), vec2(0.28, 0.96), 0.98);
	add_segment(d, p, vec2(0.58, 0.85), vec2(0.67, 0.98), 0.99);
	float width = mix(0.011, 0.021, progress);
	float crack = 1.0 - smoothstep(width, width + 0.010, d);
	ALBEDO = vec3(0.025, 0.028, 0.032);
	ALPHA = crack * 0.86 * step(0.001, progress);
}
"""
