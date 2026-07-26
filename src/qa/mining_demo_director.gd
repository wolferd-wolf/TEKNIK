class_name TeknikMiningDemoDirector
extends Node

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const TARGET_TIMEOUT_MS: int = 12_000
const PROGRESS_TIMEOUT_MS: int = 18_000
const COMMIT_TIMEOUT_MS: int = 30_000
const WORLD_IDLE_TIMEOUT_MS: int = 40_000
const CANCEL_PROGRESS_MIN: float = 0.30
const CANCEL_PROGRESS_MAX: float = 0.65

var _world: Node
var _player: TeknikExplorationController


func begin(world: Node, player: TeknikExplorationController) -> void:
	_world = world
	_player = player
	call_deferred("_run")


func _run() -> void:
	if not await _wait_for_world_idle():
		return
	var mining_value: Variant = _world.get("_mining")
	if not mining_value is TeknikMiningController:
		_fail("mining controller is unavailable")
		return
	var mining := mining_value as TeknikMiningController

	var seed: int = int(_world.qa_world_seed())
	var base_x: int = floori(_player.global_position.x) + 3
	var base_z: int = floori(_player.global_position.z) - 4
	var surface_y: int = TerrainGenerator.surface_height(seed, base_x, base_z)
	var target := Vector3i(base_x, surface_y + 1, base_z)
	_world.qa_apply_voxel_edit(target, TerrainGenerator.STONE, "qa_mining_demo_target")
	if not await _wait_for_world_idle():
		return

	var target_center := Vector3(target) + Vector3.ONE * 0.5
	var camera_ground: int = TerrainGenerator.surface_height(seed, base_x, base_z + 4)
	_player.set_scripted_mode(true)
	_player.set_scripted_move(Vector2.ZERO)
	_player.global_position = Vector3(
		target_center.x,
		maxf(target_center.y + 1.15, float(camera_ground) + 2.3),
		target_center.z + 4.0
	)
	_player.velocity = Vector3.ZERO
	_player.look_at_world(target_center)
	_player.set_physics_process(false)
	await get_tree().create_timer(0.75).timeout

	if not bool(_world.call("qa_begin_mining_target", target)):
		_fail("could not begin mining the visible demonstration block")
		return
	if not await _wait_for_target(mining, target):
		_fail("crosshair did not lock the visible demonstration block")
		return

	if not await _wait_for_progress(mining, 0.42):
		_fail("cancellation sample never reached a visible middle crack stage")
		return
	var cancel_progress: float = mining.progress()
	_world.call("_on_break_hold_changed", false)
	await get_tree().create_timer(0.45).timeout
	if cancel_progress < CANCEL_PROGRESS_MIN or cancel_progress > CANCEL_PROGRESS_MAX:
		_fail("cancellation sample did not reach a visible middle crack stage")
		return
	if mining.progress() > 0.001 or int(_world.call("_current_material", target)) != TerrainGenerator.STONE:
		_fail("release did not cancel mining without removing the block")
		return
	print("QA_MINING_CANCEL_PASS voxel=", target, " progress_before_release=", cancel_progress)

	_world.call("_on_break_hold_changed", true)
	if not await _wait_for_progress(mining, 0.60):
		_fail("mining never reached the crack-poster stage")
		return
	if mining.is_waiting_for_commit():
		_fail("block completed before the visible crack poster could be captured")
		return
	if not await _save_poster():
		return
	print("QA_MINING_CRACK_PASS voxel=", target, " progress=", mining.progress())

	var completion_started_ms: int = Time.get_ticks_msec()
	while not mining.is_waiting_for_commit() and Time.get_ticks_msec() - completion_started_ms < COMMIT_TIMEOUT_MS:
		await get_tree().process_frame
	if not mining.is_waiting_for_commit():
		_fail("held mining never reached completion")
		return
	var locked_target: Vector3i = mining.target_voxel()
	if locked_target != target:
		_fail("mining target changed before completion")
		return

	var commit_started_ms: int = Time.get_ticks_msec()
	while mining.is_waiting_for_commit() and Time.get_ticks_msec() - commit_started_ms < COMMIT_TIMEOUT_MS:
		await get_tree().process_frame
	_world.call("_on_break_hold_changed", false)
	if mining.is_waiting_for_commit():
		_fail("visible terrain commit did not release the mining lock")
		return
	if int(_world.call("_current_material", target)) != VoxelChunk.AIR:
		_fail("completed mining did not remove exactly the locked block")
		return
	await get_tree().create_timer(0.6).timeout
	print(
		"QA_MINING_DEMO_PASS voxel=", target,
		" cancel_progress=", cancel_progress,
		" completion_ms=", Time.get_ticks_msec() - completion_started_ms,
		" visible_commit_ms=", Time.get_ticks_msec() - commit_started_ms,
		" one_block_removed=", true
	)
	get_tree().quit(0)


func _wait_for_target(mining: TeknikMiningController, target: Vector3i) -> bool:
	var started_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_ms < TARGET_TIMEOUT_MS:
		if mining.has_target() and mining.target_voxel() == target:
			return true
		await get_tree().process_frame
	return false


func _wait_for_progress(mining: TeknikMiningController, threshold: float) -> bool:
	var started_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_ms < PROGRESS_TIMEOUT_MS:
		if mining.is_waiting_for_commit():
			return false
		if mining.progress() >= threshold:
			return true
		await get_tree().process_frame
	return false


func _wait_for_world_idle() -> bool:
	var started_ms: int = Time.get_ticks_msec()
	while not bool(_world.qa_world_idle()) and Time.get_ticks_msec() - started_ms < WORLD_IDLE_TIMEOUT_MS:
		await get_tree().process_frame
	if not bool(_world.qa_world_idle()):
		_fail("timed out waiting for terrain rebuild")
		return false
	return true


func _save_poster() -> bool:
	var path: String = _argument_value("--qa-mining-poster=")
	if path.is_empty():
		return true
	await RenderingServer.frame_post_draw
	var absolute: String = path if path.is_absolute_path() else ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var result: Error = get_viewport().get_texture().get_image().save_png(absolute)
	if result != OK:
		_fail("failed to save mining poster: %s" % error_string(result))
		return false
	print("QA_MINING_POSTER_SAVED ", absolute)
	return true


func _argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(message: String) -> void:
	push_error("QA_MINING_DEMO " + message)
	get_tree().quit(1)
