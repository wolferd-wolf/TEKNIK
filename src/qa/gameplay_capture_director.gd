class_name TeknikGameplayCaptureDirector
extends Node

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const WALK_SECONDS: float = 3.2
const EDIT_PAUSE_SECONDS: float = 0.10
const STAGE_PAUSE_SECONDS: float = 0.8

var _world: Node
var _player: TeknikExplorationController


func begin(world: Node, player: TeknikExplorationController) -> void:
	_world = world
	_player = player
	call_deferred("_run")


func _run() -> void:
	await _wait_for_world_idle()
	var spawn: Vector3 = _player.global_position
	var forward := -_player.global_transform.basis.z
	var site_x: int = roundi(spawn.x + forward.x * 10.0)
	var site_z: int = roundi(spawn.z + forward.z * 10.0)
	var ground_y: int = TerrainGenerator.surface_height(_world.WORLD_SEED, site_x, site_z)
	var site_center := Vector3(float(site_x) + 2.5, float(ground_y) + 1.5, float(site_z) + 2.5)

	_player.set_scripted_mode(true)
	_player.look_at_world(site_center)
	_player.set_scripted_move(Vector2(0.0, -1.0))
	await get_tree().create_timer(WALK_SECONDS).timeout
	_player.set_scripted_move(Vector2.ZERO)
	await get_tree().create_timer(STAGE_PAUSE_SECONDS).timeout

	var camera_spot := Vector3(float(site_x) + 2.5, float(ground_y) + 2.5, float(site_z) + 9.5)
	_player.global_position = camera_spot
	_player.velocity = Vector3.ZERO
	_player.look_at_world(site_center)
	await get_tree().create_timer(STAGE_PAUSE_SECONDS).timeout

	# Demonstrate persistent breaking before construction.
	for offset: Vector3i in [Vector3i(1, 0, 1), Vector3i(2, 0, 1), Vector3i(3, 0, 1)]:
		_world.qa_apply_voxel_edit(Vector3i(site_x, ground_y, site_z) + offset, VoxelChunk.AIR, "qa_removed")
		await get_tree().create_timer(0.35).timeout
	await _wait_for_world_idle()
	await get_tree().create_timer(STAGE_PAUSE_SECONDS).timeout

	var blocks: Array[Vector3i] = _house_blocks(Vector3i(site_x, ground_y + 1, site_z))
	for voxel: Vector3i in blocks:
		_world.qa_apply_voxel_edit(voxel, _world.PLACE_MATERIAL, "qa_placed")
		await get_tree().create_timer(EDIT_PAUSE_SECONDS).timeout
	await _wait_for_world_idle()
	await get_tree().create_timer(2.0).timeout

	var poster_path: String = _argument_value("--qa-gameplay-poster=")
	if not poster_path.is_empty():
		await RenderingServer.frame_post_draw
		var absolute_path: String = poster_path if poster_path.is_absolute_path() else ProjectSettings.globalize_path(poster_path)
		DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
		var image: Image = get_viewport().get_texture().get_image()
		var result: Error = image.save_png(absolute_path)
		if result != OK:
			push_error("QA_GAMEPLAY poster save failed: %s" % error_string(result))
			get_tree().quit(1)
			return
		print("QA_GAMEPLAY_POSTER_SAVED ", absolute_path)

	_world.qa_save_edits_now()
	print("QA_GAMEPLAY_RESULT PASS blocks=", blocks.size())
	get_tree().quit(0)


func _house_blocks(origin: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	# Floor.
	for x: int in range(5):
		for z: int in range(5):
			result.append(origin + Vector3i(x, 0, z))
	# Three-block-high walls with a two-block doorway on the near side.
	for y: int in range(1, 4):
		for x: int in range(5):
			for z: int in range(5):
				var boundary: bool = x == 0 or x == 4 or z == 0 or z == 4
				var doorway: bool = z == 4 and x == 2 and y <= 2
				if boundary and not doorway:
					result.append(origin + Vector3i(x, y, z))
	# Flat roof keeps the first gameplay fixture simple and readable.
	for x: int in range(5):
		for z: int in range(5):
			result.append(origin + Vector3i(x, 4, z))
	return result


func _wait_for_world_idle() -> void:
	var frames: int = 0
	while not _world.qa_world_idle() and frames < 1800:
		await get_tree().process_frame
		frames += 1
	if frames >= 1800:
		push_error("QA_GAMEPLAY timed out waiting for world idle")
		get_tree().quit(1)


func _argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
