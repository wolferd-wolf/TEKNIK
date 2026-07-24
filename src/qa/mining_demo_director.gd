class_name TeknikMiningDemoDirector
extends Node

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const TARGET_WAIT_FRAMES: int = 240
const COMMIT_WAIT_FRAMES: int = 600
const CANCEL_PROGRESS_MIN: float = 0.30
const CANCEL_PROGRESS_MAX: float = 0.65

var _world: Node
var _player: TeknikExplorationController


func begin(world: Node, player: TeknikExplorationController) -> void:
	_world = world
	_player = player
	call_deferred("_run")


func _run() -> void:
	await _wait_for_world_idle()
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
	_world.qa_apply_voxel_edit(target, VoxelChunk.STONE, "qa_mining_demo_target")
	await _wait_for_world_idle()

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
	await get_tree().create_timer(1.0).timeout

	_world.call("_refresh_block_target")
	if not await _wait_for_target(mining, target):
		_fail("crosshair did not lock the visible demonstration block")
		return

	# First hold demonstrates cancellation. The same block must remain intact and
	# progress must reset immediately when the finger is released.
	_world.call("_on_break_hold_changed", true)
	while mining.progress() < 0.42:
		await get_tree().process_frame
	var cancel_progress: float = mining.progress()
	_world.call("_on_break_hold_changed", false)
	await get_tree().create_timer(0.75).timeout
	if cancel_progress < CANCEL_PROGRESS_MIN or cancel_progress > CANCEL_PROGRESS_MAX:
		_fail("cancellation sample did not reach a visible middle crack stage")
		return
	if mining.progress() > 0.001 or int(_world.call("_current_material", target)) != VoxelChunk.STONE:
		_fail("release did not cancel mining without removing the block")
		return
	print("QA_MINING_CANCEL_PASS voxel=", target, " progress_before_release=", cancel_progress)

	# Restart from zero and hold continuously. Capture the real crack overlay at
	# roughly sixty percent, then continue until one block completes.
	_world.call("_on_break_hold_changed", true)
	while mining.progress() < 0.60 and not mining.is_waiting_for_commit():
		await get_tree().process_frame
	if mining.is_waiting_for_commit():
		_fail("block completed before the visible crack poster could be captured")
		return
	if not await _save_poster():
		return
	print("QA_MINING_CRACK_PASS voxel=", target, " progress=", mining.progress())

	var completion_frames: int = 0
	while not mining.is_waiting_for_commit() and completion_frames < COMMIT_WAIT_FRAMES:
		await get_tree().process_frame
		completion_frames += 1
	if not mining.is_waiting_for_commit():
		_fail("held mining never reached completion")
		return
	var locked_target: Vector3i = mining.target_voxel()
	if locked_target != target:
		_fail("mining target changed before completion")
		return

	var commit_frames: int = 0
	while mining.is_waiting_for_commit() and commit_frames < COMMIT_WAIT_FRAMES:
		await get_tree().process_frame
		commit_frames += 1
	_world.call("_on_break_hold_changed", false)
	if mining.is_waiting_for_commit():
		_fail("visible terrain commit did not release the mining lock")
		return
	if int(_world.call("_current_material", target)) != VoxelChunk.AIR:
		_fail("completed mining did not remove exactly the locked block")
		return
	await get_tree().create_timer(1.2).timeout
	print(
		"QA_MINING_DEMO_PASS voxel=", target,
		" cancel_progress=", cancel_progress,
		" completion_frames=", completion_frames,
		" visible_commit_frames=", commit_frames,
		" one_block_removed=", true
	)
	get_tree().quit(0)


func _wait_for_target(mining: TeknikMiningController, target: Vector3i) -> bool:
	for _frame: int in range(TARGET_WAIT_FRAMES):
		if mining.has_target() and mining.target_voxel() == target:
			return true
		_world.call("_refresh_block_target")
		await get_tree().process_frame
	return false


func _wait_for_world_idle() -> void:
	var frames: int = 0
	while not bool(_world.qa_world_idle()) and frames < 1800:
		await get_tree().process_frame
		frames += 1
	if frames >= 1800:
		_fail("timed out waiting for terrain rebuild")


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
