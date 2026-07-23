extends "res://src/main/procedural_gameplay_main.gd"


func _rebuild_streamed_features() -> void:
	# Keep the last complete ecology root visible while the replacement is planned
	# and committed. Removing it here leaves the world barren whenever continuous
	# movement prevents the idle-gated ecology worker from starting.
	if _feature_root == null:
		_feature_root = Node3D.new()
		_feature_root.name = "StreamedWorldFeatures"
		add_child(_feature_root)
		_streamed_feature_instances = 0
		_build_water()
	_feature_refresh_pending = true
	_runtime_log.event("info", "environment", "ecology_refresh_queued", {
		"current_center": str(_feature_center),
		"target_center": str(_world_center),
		"visible_instances": _streamed_feature_instances,
		"preserved_visible_root": true,
	})


func _begin_ecology_generation() -> void:
	_feature_refresh_target = _world_center
	_ecology_refresh_started_usec = Time.get_ticks_usec()
	_ecology_planner = ProceduralFeaturePlanner.new()
	_ecology_thread = Thread.new()
	var observer_position: Vector3 = (
		_player.global_position if _player != null else _planned_spawn
	)
	var start_result: Error = _ecology_thread.start(
		Callable(_ecology_planner, "build").bind(
			WORLD_SEED,
			_feature_refresh_target,
			CHUNK_RADIUS,
			VoxelChunk.SIZE,
			observer_position
		)
	)
	if start_result != OK:
		_runtime_log.event("error", "environment", "ecology_worker_start_failed", {
			"center": str(_feature_refresh_target),
			"error": error_string(start_result),
		})
		_ecology_thread = null
		_ecology_planner = null
		return
	_ecology_state = ECOLOGY_GENERATING
	_feature_refresh_pending = false
	_runtime_log.event("info", "environment", "ecology_generation_started", {
		"center": str(_feature_refresh_target),
		"observer": str(observer_position),
		"old_features_visible": true,
	})
