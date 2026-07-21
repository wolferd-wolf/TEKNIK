class_name TeknikPlayabilityTraversalDirector
extends Node

const TARGET_DISTANCE: float = 190.0
const MAX_FRAMES: int = 2400
const SETTLE_FRAMES: int = 30

var _world: Node
var _player: TeknikExplorationController


func begin(world: Node, player: TeknikExplorationController) -> void:
	_world = world
	_player = player
	call_deferred("_run")


func _run() -> void:
	await _wait_for_world_idle()
	for _frame: int in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	var start: Vector3 = _player.global_position
	var target := start + Vector3(TARGET_DISTANCE + 64.0, 0.0, 0.0)
	_player.set_scripted_mode(true)
	_player.look_at_world(target)
	_player.set_scripted_move(Vector2(0.0, -1.0))

	var traveled: float = 0.0
	var minimum_y: float = start.y
	var frames: int = 0
	while frames < MAX_FRAMES and traveled < TARGET_DISTANCE:
		await get_tree().physics_frame
		frames += 1
		minimum_y = minf(minimum_y, _player.global_position.y)
		traveled = Vector2(
			_player.global_position.x - start.x,
			_player.global_position.z - start.z
		).length()

	_player.set_scripted_move(Vector2.ZERO)
	for _frame: int in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	var snapshot: Dictionary = _world.qa_playability_snapshot()
	var failed: bool = false
	if traveled < TARGET_DISTANCE:
		push_error("QA_PLAYABILITY traversal incomplete distance=%s" % traveled)
		failed = true
	if minimum_y < -1.0:
		push_error("QA_PLAYABILITY player entered invalid depth min_y=%s" % minimum_y)
		failed = true
	if int(snapshot.get("recoveries", 0)) != 0:
		push_error("QA_PLAYABILITY fall recovery was required")
		failed = true
	if _player.global_position.y < 0.0:
		push_error("QA_PLAYABILITY player ended below the world")
		failed = true

	var poster_path: String = _argument_value("--qa-playability-poster=")
	if not poster_path.is_empty():
		await RenderingServer.frame_post_draw
		var absolute_path: String = poster_path if poster_path.is_absolute_path() else ProjectSettings.globalize_path(poster_path)
		DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
		var image: Image = get_viewport().get_texture().get_image()
		var result: Error = image.save_png(absolute_path)
		if result != OK:
			push_error("QA_PLAYABILITY poster save failed: %s" % error_string(result))
			failed = true

	print("QA_PLAYABILITY_RESULT ", "FAIL" if failed else "PASS", " distance=", traveled, " frames=", frames, " min_y=", minimum_y, " snapshot=", snapshot)
	get_tree().quit(1 if failed else 0)


func _wait_for_world_idle() -> void:
	var frames: int = 0
	while not _world.qa_world_idle() and frames < 3600:
		await get_tree().process_frame
		frames += 1
	if frames >= 3600:
		push_error("QA_PLAYABILITY timed out waiting for initial world")
		get_tree().quit(1)


func _argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
