class_name TeknikGameplayCaptureDirector
extends Node

const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")

const WALK_SECONDS: float = 1.5
const EDIT_PAUSE_SECONDS: float = 0.10
const STAGE_PAUSE_SECONDS: float = 0.8
const STREAM_TEST_MAX_FRAMES: int = 900

var _world: Node
var _player: TeknikExplorationController


func begin(world: Node, player: TeknikExplorationController) -> void:
	_world = world
	_player = player
	call_deferred("_run")


func _run() -> void:
	await _wait_for_world_idle()
	if not _verify_runtime_lod():
		return
	if not await _wait_for_visible_vegetation():
		return
	if not await _verify_chunk_local_vegetation():
		return
	var seed: int = _world.qa_world_seed()
	var spawn: Vector3 = _player.global_position
	var forward := -_player.global_transform.basis.z
	var site_x: int = roundi(spawn.x + forward.x * 10.0)
	var site_z: int = roundi(spawn.z + forward.z * 10.0)
	var ground_y: int = TerrainGenerator.surface_height(seed, site_x, site_z)
	var site_center := Vector3(float(site_x) + 2.5, float(ground_y) + 2.0, float(site_z) + 2.5)

	_player.set_scripted_mode(true)
	_player.look_at_world(site_center)
	_player.set_scripted_move(Vector2(0.0, -1.0))
	await get_tree().create_timer(WALK_SECONDS).timeout
	_player.set_scripted_move(Vector2.ZERO)
	await get_tree().create_timer(STAGE_PAUSE_SECONDS).timeout

	var camera_x: int = site_x + 2
	var camera_z: int = site_z + 10
	var camera_ground_y: int = TerrainGenerator.surface_height(seed, camera_x, camera_z)
	_player.global_position = Vector3(float(camera_x) + 0.5, float(camera_ground_y) + 3.0, float(camera_z) + 0.5)
	_player.velocity = Vector3.ZERO
	_player.look_at_world(site_center)
	await get_tree().create_timer(STAGE_PAUSE_SECONDS).timeout

	for offset: Vector3i in [Vector3i(1, 0, 1), Vector3i(2, 0, 1), Vector3i(3, 0, 1)]:
		_world.qa_apply_voxel_edit(Vector3i(site_x, ground_y, site_z) + offset, VoxelChunk.AIR, "qa_removed")
		await get_tree().create_timer(0.35).timeout
	await _wait_for_world_idle()
	await get_tree().create_timer(STAGE_PAUSE_SECONDS).timeout

	var blocks: Array[Vector3i] = _house_blocks(Vector3i(site_x, ground_y + 1, site_z))
	for voxel: Vector3i in blocks:
		_world.qa_apply_voxel_edit(voxel, _world.qa_place_material(), "qa_placed")
		await get_tree().create_timer(EDIT_PAUSE_SECONDS).timeout
	await _wait_for_world_idle()
	_player.look_at_world(site_center + Vector3(0.0, 1.0, 0.0))
	await get_tree().create_timer(2.0).timeout

	# Finalize survival, crafting, and kinetic QA before the poster is captured.
	# This makes the placed machines visible evidence instead of log-only proof.
	_world.qa_save_edits_now()
	await get_tree().process_frame
	await _focus_runtime_evidence()

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

	var snapshot: Dictionary = _world.qa_playability_snapshot()
	print(
		"QA_GAMEPLAY_RESULT PASS blocks=", blocks.size(),
		" trees=", int(_world.get("_tree_count")),
		" feature_instances=", int(_world.get("_streamed_feature_instances")),
		" ecology_chunks=", int(_world.call("qa_ecology_ready_chunk_count")),
		" cache_hits=", int(snapshot.get("chunk_cache_hits", 0)),
		" cache_size=", int(snapshot.get("chunk_cache_size", 0)),
		" intermediate_lod_step=", int(snapshot.get("intermediate_lod_step", 0)),
		" intermediate_lod_ring_chunks=", int(snapshot.get("intermediate_lod_ring_chunks", 0))
	)
	get_tree().quit(0)


func _focus_runtime_evidence() -> void:
	var machine_root: Variant = _world.get("_machine_root")
	if not machine_root is Node3D:
		return
	var root := machine_root as Node3D
	var machine_count: int = root.get_child_count()
	if machine_count <= 0:
		return
	var center := Vector3.ZERO
	var counted: int = 0
	for child: Node in root.get_children():
		if child is Node3D:
			center += (child as Node3D).global_position
			counted += 1
	if counted <= 0:
		return
	center /= float(counted)
	var camera_x: float = center.x + 5.5
	var camera_z: float = center.z + 7.0
	var camera_ground: int = TerrainGenerator.surface_height(
		int(_world.qa_world_seed()),
		floori(camera_x),
		floori(camera_z)
	)
	var camera_y: float = maxf(center.y + 7.0, float(camera_ground) + 4.0)
	_player.global_position = Vector3(camera_x, camera_y, camera_z)
	_player.velocity = Vector3.ZERO
	_player.look_at_world(center)
	await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	print(
		"QA_KINETIC_VISUAL_PASS instances=", counted,
		" target=", center,
		" camera=", _player.global_position
	)


func _verify_runtime_lod() -> bool:
	var snapshot: Dictionary = _world.qa_playability_snapshot()
	var intermediate_step: int = int(snapshot.get("intermediate_lod_step", 0))
	var intermediate_ring_chunks: int = int(snapshot.get("intermediate_lod_ring_chunks", 0))
	if intermediate_step <= 0 or intermediate_step >= 4:
		push_error("QA_GAMEPLAY invalid intermediate LOD step: %d" % intermediate_step)
		get_tree().quit(1)
		return false
	if intermediate_ring_chunks <= 0:
		push_error("QA_GAMEPLAY intermediate LOD ring is disabled")
		get_tree().quit(1)
		return false
	var distant: Variant = _world.get("_distant_terrain")
	if distant == null:
		push_error("QA_GAMEPLAY distant terrain was not committed")
		get_tree().quit(1)
		return false
	print(
		"QA_MULTI_LOD_PASS intermediate_step=", intermediate_step,
		" intermediate_ring_chunks=", intermediate_ring_chunks,
		" distant_visible=", true
	)
	return true


func _verify_chunk_local_vegetation() -> bool:
	if not _world.has_method("qa_ecology_ready_chunk_count") or not _world.has_method("qa_ecology_chunk_unload_count"):
		push_error("QA_GAMEPLAY chunk-local ecology diagnostics unavailable")
		get_tree().quit(1)
		return false
	var ready_before: int = int(_world.call("qa_ecology_ready_chunk_count"))
	var unloads_before: int = int(_world.call("qa_ecology_chunk_unload_count"))
	if ready_before <= 1:
		push_error("QA_GAMEPLAY insufficient ecology chunks before stream test: %d" % ready_before)
		get_tree().quit(1)
		return false

	var seed: int = _world.qa_world_seed()
	var original_position: Vector3 = _player.global_position
	var original_chunk_x: int = floori(original_position.x / float(VoxelChunk.SIZE))
	var current_chunk_x: int = original_chunk_x
	var target_chunk_x: int = current_chunk_x + 1
	var target_x: float = float(target_chunk_x * VoxelChunk.SIZE) + float(VoxelChunk.SIZE) * 0.5
	var target_z: float = original_position.z
	var target_y: int = TerrainGenerator.surface_height(seed, floori(target_x), floori(target_z))
	_player.set_scripted_mode(true)
	_player.global_position = Vector3(target_x, float(target_y) + 3.0, target_z)
	_player.velocity = Vector3.ZERO

	var frames: int = 0
	while frames < STREAM_TEST_MAX_FRAMES:
		var unloads_now: int = int(_world.call("qa_ecology_chunk_unload_count"))
		if unloads_now > unloads_before:
			var ready_now: int = int(_world.call("qa_ecology_ready_chunk_count"))
			if ready_now <= 0:
				push_error("QA_GAMEPLAY all vegetation vanished after one chunk unload")
				get_tree().quit(1)
				return false
			print(
				"QA_ECOLOGY_STREAM_PASS ready_before=", ready_before,
				" ready_after_first_unload=", ready_now,
				" unloads=", unloads_now - unloads_before
			)
			await _wait_for_world_idle()
			break
		await get_tree().process_frame
		frames += 1
	if frames >= STREAM_TEST_MAX_FRAMES:
		push_error("QA_GAMEPLAY chunk stream test did not observe an ecology unload")
		get_tree().quit(1)
		return false

	var original_y: int = TerrainGenerator.surface_height(
		seed,
		floori(original_position.x),
		floori(original_position.z)
	)
	_player.global_position = Vector3(
		original_position.x,
		float(original_y) + 3.0,
		original_position.z
	)
	_player.velocity = Vector3.ZERO
	await get_tree().process_frame
	await _wait_for_world_idle()
	var returned_chunk_x: int = floori(_player.global_position.x / float(VoxelChunk.SIZE))
	if returned_chunk_x != original_chunk_x:
		push_error("QA_GAMEPLAY backtracking did not return to the original chunk")
		get_tree().quit(1)
		return false
	var snapshot: Dictionary = _world.qa_playability_snapshot()
	var cache_hits: int = int(snapshot.get("chunk_cache_hits", 0))
	if cache_hits <= 0:
		push_error("QA_GAMEPLAY backtracking did not reuse any cached terrain chunks")
		get_tree().quit(1)
		return false
	var ready_after_return: int = int(_world.call("qa_ecology_ready_chunk_count"))
	if ready_after_return <= 0:
		push_error("QA_GAMEPLAY vegetation vanished during cached backtracking")
		get_tree().quit(1)
		return false
	print(
		"QA_CHUNK_CACHE_PASS hits=", cache_hits,
		" cache_size=", int(snapshot.get("chunk_cache_size", 0)),
		" ecology_chunks=", ready_after_return
	)
	return true


func _wait_for_visible_vegetation() -> bool:
	var frames: int = 0
	while frames < 1800:
		var trees: int = int(_world.get("_tree_count"))
		var instances: int = int(_world.get("_streamed_feature_instances"))
		if trees > 0 and instances > 1:
			print("QA_VEGETATION_READY trees=", trees, " feature_instances=", instances)
			return true
		await get_tree().process_frame
		frames += 1
	push_error(
		"QA_GAMEPLAY vegetation did not become visible: trees=%d feature_instances=%d"
		% [int(_world.get("_tree_count")), int(_world.get("_streamed_feature_instances"))]
	)
	get_tree().quit(1)
	return false


func _house_blocks(origin: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for x: int in range(5):
		for z: int in range(5):
			result.append(origin + Vector3i(x, 0, z))
	for y: int in range(1, 4):
		for x: int in range(5):
			for z: int in range(5):
				var boundary: bool = x == 0 or x == 4 or z == 0 or z == 4
				var doorway: bool = z == 4 and x == 2 and y <= 2
				if boundary and not doorway:
					result.append(origin + Vector3i(x, y, z))
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
