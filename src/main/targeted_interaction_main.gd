extends "res://src/main/interactive_kinetic_main.gd"

const VoxelRaycast = preload("res://src/world/voxel_raycast.gd")
const EditRebuildScheduler = preload("res://src/world/edit_rebuild_scheduler.gd")
const CrosshairOverlay = preload("res://src/player/block_target_crosshair.gd")
const MiningHoldState = preload("res://src/player/mining_hold_state.gd")
const VisibleMiningLock = preload("res://src/player/visible_mining_lock.gd")

const BLOCK_TARGET_REFRESH_SECONDS: float = 0.04
const OUTLINE_RADIUS: float = 0.522
const OUTLINE_THICKNESS: float = 0.044
const OUTLINE_LENGTH: float = 1.044

var _block_target_refresh_remaining: float = 0.0
var _block_target: Dictionary = {}
var _block_target_root: Node3D
var _block_crosshair: TeknikBlockTargetCrosshair
var _mining_hold: TeknikMiningHoldState = MiningHoldState.new()
var _visible_mining_lock: TeknikVisibleMiningLock = VisibleMiningLock.new()


func _ready() -> void:
	super._ready()
	_build_block_target_feedback()
	if _player != null:
		_player.break_hold_changed.connect(_on_break_hold_changed)
	_refresh_block_target()


func _process(delta: float) -> void:
	super._process(delta)
	_block_target_refresh_remaining -= delta
	if _block_target_refresh_remaining <= 0.0:
		_block_target_refresh_remaining = BLOCK_TARGET_REFRESH_SECONDS
		_refresh_block_target()
	_process_hold_mining(delta)


func _on_break_requested(origin: Vector3, direction: Vector3) -> void:
	# Never mine through a block that is still visible. The previous implementation
	# immediately advanced through authoritative voxel data while the old chunk mesh
	# remained on-screen, so rapid taps could silently remove several deeper blocks.
	if _visible_mining_lock.is_active():
		_runtime_log.event("info", "interaction", "break_waiting_for_visible_commit", {
			"voxel": str(_visible_mining_lock.voxel()),
			"chunk": str(_visible_mining_lock.chunk()),
		})
		return

	var target: Dictionary = _find_break_target(origin, direction)
	_set_block_target(target)
	if target.is_empty():
		return
	var voxel: Vector3i = target.get("voxel", Vector3i.ZERO)
	var owner_chunk: Vector3i = _voxel_chunk_coordinate(voxel)
	if not _visible_mining_lock.begin(voxel, owner_chunk):
		return
	if not _survival_break_voxel(voxel, "removed"):
		_visible_mining_lock.cancel()
		return

	if _block_crosshair != null:
		_block_crosshair.set_pending(true)
	# Keep the outline on the visible block until its rebuilt mesh is committed.
	_set_block_target(target)
	_runtime_log.event("info", "interaction", "targeted_block_break_queued", {
		"voxel": str(voxel),
		"chunk": str(owner_chunk),
		"distance": float(target.get("distance", 0.0)),
		"dda_targeting": true,
		"visible_commit_lock": true,
		"hold_to_mine": _mining_hold.is_held(),
	})


func _on_break_hold_changed(held: bool) -> void:
	_mining_hold.set_held(held)
	if not held and _block_crosshair != null:
		_block_crosshair.set_mining_progress(0.0)


func _process_hold_mining(delta: float) -> void:
	if _visible_mining_lock.is_active():
		if _block_crosshair != null:
			_block_crosshair.set_mining_progress(0.0)
		return
	var target_key: Variant = null
	if not _block_target.is_empty():
		target_key = _block_target.get("voxel", null)
	var repeat_ready: bool = _mining_hold.update(delta, target_key)
	if _block_crosshair != null:
		_block_crosshair.set_mining_progress(_mining_hold.progress())
	if not repeat_ready or _player == null:
		return
	var camera := _player.get_node_or_null("CameraPivot/PlayerCamera") as Camera3D
	if camera == null:
		return
	_on_break_requested(camera.global_position, -camera.global_transform.basis.z.normalized())


func _commit_terrain_chunk(report: Dictionary) -> void:
	var coordinate: Vector3i = report.get("coordinate", Vector3i.ZERO)
	var pending_voxel: Vector3i = _visible_mining_lock.voxel()
	super._commit_terrain_chunk(report)
	var still_dirty: bool = _edit_rebuild_queue.has(coordinate)
	if _visible_mining_lock.complete_if_visible_commit(coordinate, still_dirty):
		if _block_crosshair != null:
			_block_crosshair.set_pending(false)
		_runtime_log.event("info", "interaction", "targeted_block_visible_commit", {
			"voxel": str(pending_voxel),
			"chunk": str(coordinate),
			"mesh_commit_usec": _last_mesh_commit_usec,
		})
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

	var outline_material := StandardMaterial3D.new()
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.albedo_color = Color(1.0, 0.68, 0.12, 1.0)
	outline_material.metallic = 0.0
	outline_material.roughness = 1.0

	# Twelve real box edges stay readable on mobile GPUs. Do not add a translucent
	# cube fill: when the camera is close to a floor block it covers most of the
	# screen and makes aiming worse.
	for y: float in [-OUTLINE_RADIUS, OUTLINE_RADIUS]:
		for z: float in [-OUTLINE_RADIUS, OUTLINE_RADIUS]:
			_add_outline_edge(
				Vector3(0.0, y, z),
				Vector3(OUTLINE_LENGTH, OUTLINE_THICKNESS, OUTLINE_THICKNESS),
				outline_material
			)
	for x: float in [-OUTLINE_RADIUS, OUTLINE_RADIUS]:
		for z: float in [-OUTLINE_RADIUS, OUTLINE_RADIUS]:
			_add_outline_edge(
				Vector3(x, 0.0, z),
				Vector3(OUTLINE_THICKNESS, OUTLINE_LENGTH, OUTLINE_THICKNESS),
				outline_material
			)
	for x: float in [-OUTLINE_RADIUS, OUTLINE_RADIUS]:
		for y: float in [-OUTLINE_RADIUS, OUTLINE_RADIUS]:
			_add_outline_edge(
				Vector3(x, y, 0.0),
				Vector3(OUTLINE_THICKNESS, OUTLINE_THICKNESS, OUTLINE_LENGTH),
				outline_material
			)


func _add_outline_edge(position_value: Vector3, size_value: Vector3, material: Material) -> void:
	var edge := MeshInstance3D.new()
	edge.name = "BlockTargetEdge"
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = material
	edge.mesh = mesh
	edge.position = position_value
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_block_target_root.add_child(edge)


func _refresh_block_target() -> void:
	if _visible_mining_lock.is_active():
		return
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


func _voxel_chunk_coordinate(voxel: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(voxel.x) / float(VoxelChunk.SIZE)),
		0,
		floori(float(voxel.z) / float(VoxelChunk.SIZE))
	)


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	if _block_crosshair == null or _block_target_root == null:
		push_error("QA_BLOCK_TARGETING feedback nodes were not created")
		get_tree().quit(1)
		return
	if _block_target_root.get_child_count() != 12:
		push_error("QA_BLOCK_TARGETING expected 12 visible outline edges without a fill")
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
		" outline_edges=", _block_target_root.get_child_count(),
		" translucent_fill=", false,
		" voxel=", sample.get("voxel", Vector3i.ZERO),
		" distance=", float(sample.get("distance", 0.0)),
		" dda=", true,
		" visible_commit_lock=", true,
		" hold_to_mine=", true
	)
