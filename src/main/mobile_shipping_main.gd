extends "res://src/main/shipping_main.gd"

const AutoJumpAssistant = preload("res://src/player/auto_jump_assistant.gd")
const MeshVisualSanitizer = preload("res://src/world/mesh_visual_sanitizer.gd")

var _auto_jump_count: int = 0


func _ready() -> void:
	super._ready()
	_flatten_loaded_terrain_colors()
	if OS.has_feature("mobile") and _player != null:
		_player.floor_snap_length = 0.35
		var auto_jump: TeknikAutoJumpAssistant = AutoJumpAssistant.new()
		auto_jump.name = "AutoJumpAssistant"
		_player.add_child(auto_jump)
		auto_jump.configure(_player)
		auto_jump.auto_jump_triggered.connect(_on_auto_jump_triggered)
		_runtime_log.event("info", "mobile", "runtime_configured", {
			"orientation": int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)),
			"emulate_mouse_from_touch": bool(ProjectSettings.get_setting(
				"input_devices/pointing/emulate_mouse_from_touch",
				true
			)),
			"viewport": str(get_viewport().get_visible_rect().size),
			"floor_snap_length": _player.floor_snap_length,
		})


func _input(event: InputEvent) -> void:
	# Android can synthesize left-mouse events from touches. The desktop
	# controller maps left mouse to block breaking, so consume every synthesized
	# mouse event on mobile and let MobileControls handle the real touch event.
	if OS.has_feature("mobile") and (
		event is InputEventMouseButton
		or event is InputEventMouseMotion
	):
		get_viewport().set_input_as_handled()


func _build_environment() -> void:
	super._build_environment()
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		# Prevent shadow-map self-intersection from drawing dotted seams directly
		# under exposed voxel edges.
		sun.shadow_bias = 0.14
		sun.shadow_normal_bias = 1.6


func _commit_terrain_chunk(report: Dictionary) -> void:
	var arrays: Array = report.get("arrays", [])
	MeshVisualSanitizer.flatten_quad_colors(arrays)
	report["arrays"] = arrays
	super._commit_terrain_chunk(report)


func _flatten_loaded_terrain_colors() -> void:
	for value: Variant in _terrain_nodes.values():
		var terrain := value as MeshInstance3D
		if terrain == null or not (terrain.mesh is ArrayMesh):
			continue
		var source := terrain.mesh as ArrayMesh
		if source.get_surface_count() == 0:
			continue
		var arrays: Array = source.surface_get_arrays(0)
		MeshVisualSanitizer.flatten_quad_colors(arrays)
		var replacement := ArrayMesh.new()
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		replacement.surface_set_material(0, source.surface_get_material(0))
		terrain.mesh = replacement


func _on_auto_jump_triggered(position: Vector3, upward_velocity: float) -> void:
	_auto_jump_count += 1
	_runtime_log.event("info", "mobile", "auto_jump_triggered", {
		"position": str(position),
		"upward_velocity": upward_velocity,
		"count": _auto_jump_count,
	})
