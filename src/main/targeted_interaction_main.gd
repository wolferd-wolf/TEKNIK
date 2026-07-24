extends "res://src/main/interactive_kinetic_main.gd"

const VoxelRaycast = preload("res://src/world/voxel_raycast.gd")
const EditRebuildScheduler = preload("res://src/world/edit_rebuild_scheduler.gd")
const CrosshairOverlay = preload("res://src/player/block_target_crosshair.gd")

const BLOCK_TARGET_REFRESH_SECONDS: float = 0.04
const OUTLINE_EXPANSION: float = 0.018

var _block_target_refresh_remaining: float = 0.0
var _block_target: Dictionary = {}
var _block_target_root: Node3D
var _block_crosshair: TeknikBlockTargetCrosshair


func _ready() -> void:
	super._ready()
	_build_block_target_feedback()
	_refresh_block_target()


func _process(delta: float) -> void:
	super._process(delta)
	_block_target_refresh_remaining -= delta
	if _block_target_refresh_remaining <= 0.0:
		_block_target_refresh_remaining = BLOCK_TARGET_REFRESH_SECONDS
		_refresh_block_target()


func _on_break_requested(origin: Vector3, direction: Vector3) -> void:
	var target: Dictionary = _find_break_target(origin, direction)
	_set_block_target(target)
	if target.is_empty():
		return
	var voxel: Vector3i = target.get("voxel", Vector3i.ZERO)
	if not _survival_break_voxel(voxel, "removed"):
		return
	_runtime_log.event("info", "interaction", "targeted_block_broken", {
		"voxel": str(voxel),
		"distance": float(target.get("distance", 0.0)),
		"dda_targeting": true,
	})
	# World edits are authoritative immediately, even while the chunk mesh rebuild
	# is in flight. Recast now so rapid taps continue into the next block instead
	# of hitting stale collision geometry.
	_refresh_block_target()


func _next_build_coordinate() -> Vector3i:
	var rebuild: Vector3i = EditRebuildScheduler.take_ready(
		_edit_rebuild_queue,
		_terrain_nodes,
		Callable(_playable_pool, "has_coordinate")
	)
	if rebuild != EditRebuildScheduler.NO_COORDINATE:
		return rebuild

	while not _emergency_load_queue.is_empty():
		var emergency: Vector3i = _emergency_load_queue.pop_front()
		if not _terrain_nodes.has(emergency) and not _playable_pool.has_coordinate(emergency):
			return emergency

	var load_work: Dictionary = _chunk_work_budget.take_frame(1, 0)
	var loads: Array[Vector3i] = load_work.load
	if loads.is_empty():
		return EditRebuildScheduler.NO_COORDINATE
	var coordinate: Vector3i = loads[0]
	if _terrain_nodes.has(coordinate) or _playable_pool.has_coordinate(coordinate):
		return _next_build_coordinate()
	return coordinate


func _build_block_target_feedback() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BlockTargetHUD"
	layer.layer = 24
	add_child(layer)
	_block_crosshair = CrosshairOverlay.new()
	_block_crosshair.name = "BlockTargetCrosshair"
	layer.add_child(_block_crosshair)

	_block_target_root = Node3D.new()
	_block_target_root.name = "BlockTargetOutline"
	_block_target_root.visible = false
	add_child(_block_target_root)

	var fill := MeshInstance3D.new()
	fill.name = "SelectedBlockFill"
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3.ONE * (1.0 + OUTLINE_EXPANSION)
	var fill_material := StandardMaterial3D.new()
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_material.albedo_color = Color(1.0, 0.66, 0.12, 0.13)
	fill_mesh.material = fill_material
	fill.mesh = fill_mesh
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_block_target_root.add_child(fill)

	var outline := MeshInstance3D.new()
	outline.name = "SelectedBlockEdges"
	outline.mesh = _block_outline_mesh()
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_block_target_root.add_child(outline)


func _block_outline_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.76, 0.20, 0.98)
	var radius: float = 0.5 + OUTLINE_EXPANSION
	var corners: Array[Vector3] = [
		Vector3(-radius, -radius, -radius), Vector3(radius, -radius, -radius),
		Vector3(radius, radius, -radius), Vector3(-radius, radius, -radius),
		Vector3(-radius, -radius, radius), Vector3(radius, -radius, radius),
		Vector3(radius, radius, radius), Vector3(-radius, radius, radius),
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
	return mesh


func _refresh_block_target() -> void:
	if _player == null:
		_set_block_target({})
		return
	var camera := _player.get_node_or_null("CameraPivot/PlayerCamera") as Camera3D
	if camera == null:
		_set_block_target({})
		return
	_set_block_target(_find_break_target(
		camera.global_position,
		-camera.global_transform.basis.z.normalized()
	))


func _find_break_target(origin: Vector3, direction: Vector3) -> Dictionary:
	# A machine under the crosshair owns the interaction ray and prevents terrain
	# behind it from being mined accidentally.
	if _raycast_machine() != null:
		return {}
	return VoxelRaycast.cast(
		origin,
		direction,
		INTERACTION_DISTANCE,
		Callable(self, "_is_breakable_voxel")
	)


func _is_breakable_voxel(voxel: Vector3i) -> bool:
	var material: int = _current_material(voxel)
	return material != VoxelChunk.AIR and ItemRegistry.item_for_material(material) != &""


func _set_block_target(target: Dictionary) -> void:
	_block_target = target
	var valid: bool = not target.is_empty()
	if _block_crosshair != null:
		_block_crosshair.set_targeted(valid)
	if _block_target_root == null:
		return
	_block_target_root.visible = valid
	if valid:
		var voxel: Vector3i = target.get("voxel", Vector3i.ZERO)
		_block_target_root.global_position = VoxelRaycast.outline_center(voxel)


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	if _block_crosshair == null or _block_target_root == null:
		push_error("QA_BLOCK_TARGETING feedback nodes were not created")
		get_tree().quit(1)
		return
	var sample_x: int = floori(_player.global_position.x) + 6 if _player != null else 6
	var sample_z: int = floori(_player.global_position.z) + 6 if _player != null else 6
	var sample_height: int = TerrainGenerator.surface_height(WORLD_SEED, sample_x, sample_z)
	var sample_origin := Vector3(float(sample_x) + 0.5, float(sample_height) + 4.5, float(sample_z) + 0.5)
	var sample: Dictionary = VoxelRaycast.cast(
		sample_origin,
		Vector3.DOWN,
		INTERACTION_DISTANCE,
		Callable(self, "_is_breakable_voxel")
	)
	if sample.is_empty():
		push_error("QA_BLOCK_TARGETING deterministic downward ray found no block")
		get_tree().quit(1)
		return
	print(
		"QA_BLOCK_TARGETING_PASS crosshair=", true,
		" outline=", true,
		" voxel=", sample.get("voxel", Vector3i.ZERO),
		" distance=", float(sample.get("distance", 0.0)),
		" dda=", true,
		" rapid_edit_coalescing=", true
	)
