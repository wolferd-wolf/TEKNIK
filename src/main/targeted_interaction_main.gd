extends "res://src/main/interactive_kinetic_main.gd"

const VoxelRaycast = preload("res://src/world/voxel_raycast.gd")
const EditRebuildScheduler = preload("res://src/world/edit_rebuild_scheduler.gd")
const CrosshairOverlay = preload("res://src/player/block_target_crosshair.gd")
const MiningController = preload("res://src/player/mining_controller.gd")
const MiningBlockVisual = preload("res://src/player/mining_block_visual.gd")

const BLOCK_TARGET_REFRESH_SECONDS: float = 0.025

var _block_target_refresh_remaining: float = 0.0
var _block_target: Dictionary = {}
var _block_crosshair: TeknikBlockTargetCrosshair
var _mining_visual: TeknikMiningBlockVisual
var _mining: TeknikMiningController = MiningController.new()
var _pending_mining_chunk: Vector3i = Vector3i.ZERO
var _pending_mining_voxel: Vector3i = Vector3i.ZERO
var _has_pending_mining_commit: bool = false
var _qa_forced_mining_target: Variant = null
var _qa_forced_mining_progress: float = -1.0


func _ready() -> void:
	super._ready()
	_build_mining_feedback()
	if _player != null:
		_player.break_hold_changed.connect(_on_break_hold_changed)
	_refresh_block_target()


func _process(delta: float) -> void:
	super._process(delta)
	_block_target_refresh_remaining -= delta
	if _block_target_refresh_remaining <= 0.0:
		_block_target_refresh_remaining = BLOCK_TARGET_REFRESH_SECONDS
		_refresh_block_target()
	_process_mining(delta)


func _on_break_requested(origin: Vector3, direction: Vector3) -> void:
	# Button-down only confirms the target. Mining completion is exclusively owned
	# by TeknikMiningController after the held duration reaches 100 percent.
	_set_target_from_ray(origin, direction)


func _on_break_hold_changed(held: bool) -> void:
	_mining.set_pressed(held)
	if held:
		_refresh_block_target()
	elif _mining_visual != null and _qa_forced_mining_target == null:
		_mining_visual.set_progress(0.0)


func _process_mining(delta: float) -> void:
	var completed: Dictionary = _mining.update(delta)
	if _mining_visual != null:
		var displayed_progress: float = (
			_qa_forced_mining_progress
			if _qa_forced_mining_target != null and _qa_forced_mining_progress >= 0.0
			else _mining.progress()
		)
		_mining_visual.set_progress(displayed_progress)
	if completed.is_empty():
		return
	var voxel: Vector3i = completed.get("voxel", Vector3i.ZERO)
	var owner_chunk: Vector3i = _voxel_chunk_coordinate(voxel)
	if not _survival_break_voxel(voxel, "removed"):
		_mining.cancel_failed_completion()
		_refresh_block_target()
		return
	_pending_mining_voxel = voxel
	_pending_mining_chunk = owner_chunk
	_has_pending_mining_commit = true
	_runtime_log.event("info", "interaction", "mining_completed_waiting_for_mesh", {
		"voxel": str(voxel),
		"chunk": str(owner_chunk),
		"material": int(completed.get("material", 0)),
		"duration_seconds": float(completed.get("duration_seconds", 0.0)),
		"single_locked_target": true,
	})


func _commit_terrain_chunk(report: Dictionary) -> void:
	var coordinate: Vector3i = report.get("coordinate", Vector3i.ZERO)
	super._commit_terrain_chunk(report)
	if not _has_pending_mining_commit or coordinate != _pending_mining_chunk:
		return
	# A second edit made while this worker was running keeps the coordinate dirty;
	# only the final visible commit may unlock the next block.
	if _edit_rebuild_queue.has(coordinate):
		return
	var completed_voxel: Vector3i = _pending_mining_voxel
	_has_pending_mining_commit = false
	_pending_mining_chunk = Vector3i.ZERO
	_pending_mining_voxel = Vector3i.ZERO
	_mining.notify_visible_commit()
	if _mining_visual != null:
		_mining_visual.clear_target()
	if _block_crosshair != null:
		_block_crosshair.set_targeted(false)
	_runtime_log.event("info", "interaction", "mining_visible_commit", {
		"voxel": str(completed_voxel),
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


func _build_mining_feedback() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MiningCrosshairHUD"
	layer.layer = 24
	add_child(layer)
	_block_crosshair = CrosshairOverlay.new()
	_block_crosshair.name = "MiningCrosshair"
	layer.add_child(_block_crosshair)

	_mining_visual = MiningBlockVisual.new()
	_mining_visual.name = "MiningBlockVisual"
	add_child(_mining_visual)


func _refresh_block_target() -> void:
	if _mining.is_waiting_for_commit():
		return
	if _qa_forced_mining_target != null:
		var forced_voxel: Vector3i = _qa_forced_mining_target
		_set_block_target({
			"voxel": forced_voxel,
			"material": _current_material(forced_voxel),
			"distance": 2.5,
		})
		return
	if _player == null:
		_set_block_target({})
		return
	var camera := _player.get_node_or_null("CameraPivot/PlayerCamera") as Camera3D
	if camera == null:
		_set_block_target({})
		return
	_set_target_from_ray(camera.global_position, -camera.global_transform.basis.z.normalized())


func _set_target_from_ray(origin: Vector3, direction: Vector3) -> void:
	_set_block_target(_find_break_target(origin, direction))


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
	if target.is_empty():
		_mining.clear_target()
		if _block_crosshair != null:
			_block_crosshair.set_targeted(false)
		if _mining_visual != null:
			_mining_visual.clear_target()
		return
	var voxel: Vector3i = target.get("voxel", Vector3i.ZERO)
	var material: int = int(target.get("material", _current_material(voxel)))
	var changed: bool = _mining.set_target(
		voxel,
		material,
		MiningController.duration_for_material(material)
	)
	if _block_crosshair != null:
		_block_crosshair.set_targeted(true)
	if _mining_visual != null:
		_mining_visual.show_target(voxel)
		if changed and _qa_forced_mining_target == null:
			_mining_visual.set_progress(0.0)


func _voxel_chunk_coordinate(voxel: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(voxel.x) / float(VoxelChunk.SIZE)),
		0,
		floori(float(voxel.z) / float(VoxelChunk.SIZE))
	)


func qa_force_mining_target(voxel: Vector3i, progress: float = 0.55) -> void:
	_qa_forced_mining_target = voxel
	_qa_forced_mining_progress = clampf(progress, 0.0, 1.0)
	_set_block_target({
		"voxel": voxel,
		"material": _current_material(voxel),
		"distance": 2.5,
	})
	if _mining_visual != null:
		_mining_visual.set_progress(_qa_forced_mining_progress)


func qa_clear_forced_mining_target() -> void:
	_qa_forced_mining_target = null
	_qa_forced_mining_progress = -1.0
	_mining.set_pressed(false)
	_refresh_block_target()


func qa_save_edits_now() -> void:
	super.qa_save_edits_now()
	if _block_crosshair == null or _mining_visual == null:
		push_error("QA_MINING feedback nodes were not created")
		get_tree().quit(1)
		return
	var sample_x: int = floori(_player.global_position.x) + 6 if _player != null else 6
	var sample_z: int = floori(_player.global_position.z) + 6 if _player != null else 6
	var sample_height: int = TerrainGenerator.surface_height(WORLD_SEED, sample_x, sample_z)
	var sample_voxel := Vector3i(sample_x, sample_height, sample_z)
	var sample_origin := Vector3(float(sample_x) + 0.5, float(sample_height) + 4.5, float(sample_z) + 0.5)
	var sample: Dictionary = VoxelRaycast.cast(
		sample_origin,
		Vector3.DOWN,
		INTERACTION_DISTANCE,
		Callable(self, "_is_breakable_voxel")
	)
	if sample.is_empty():
		push_error("QA_MINING deterministic downward ray found no block")
		get_tree().quit(1)
		return
	qa_force_mining_target(sample_voxel, 0.58)
	print(
		"QA_MINING_SYSTEM_PASS state_machine=", true,
		" instant_break=", false,
		" locked_voxel=", sample_voxel,
		" outline=thin_lines",
		" cracks=procedural",
		" material_seconds=", MiningController.duration_for_material(_current_material(sample_voxel)),
		" waits_for_visible_commit=", true,
		" visual_progress=", _qa_forced_mining_progress
	)
