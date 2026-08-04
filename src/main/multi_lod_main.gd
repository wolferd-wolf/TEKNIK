extends "res://src/main/incremental_collision_main.gd"

const MultiLodTerrainPlanner = preload("res://src/world/multi_lod_terrain_planner.gd")


func _ready() -> void:
	super._ready()
	_runtime_log.event("info", "environment", "multi_lod_ready", {
		"intermediate_step": MultiLodTerrainPlanner.INTERMEDIATE_STEP,
		"intermediate_ring_chunks": MultiLodTerrainPlanner.INTERMEDIATE_RING_CHUNKS,
		"vegetation_untouched": true,
	})


func _begin_distant_generation() -> void:
	_distant_target = _world_center
	_distant_planner = MultiLodTerrainPlanner.new()
	_distant_thread = Thread.new()
	var start_result: Error = _distant_thread.start(
		Callable(_distant_planner, "build").bind(
			WORLD_SEED,
			_distant_target,
			VoxelChunk.SIZE,
			CHUNK_RADIUS,
			DISTANT_WORLD_RADIUS,
			DISTANT_TERRAIN_STEP
		)
	)
	if start_result != OK:
		_runtime_log.event("error", "environment", "multi_lod_worker_start_failed", {
			"center": str(_distant_target),
			"error": error_string(start_result),
		})
		_distant_thread = null
		_distant_planner = null
		return
	_distant_state = DISTANT_GENERATING
	_distant_refresh_pending = false
	_runtime_log.event("info", "environment", "multi_lod_generation_started", {
		"center": str(_distant_target),
		"old_lod_visible": _distant_terrain != null,
	})


func _commit_distant_plan() -> void:
	var intermediate_quads: int = int(_distant_plan.get("intermediate_quads", 0))
	var outer_quads: int = int(_distant_plan.get("outer_quads", 0))
	super._commit_distant_plan()
	_runtime_log.event("info", "environment", "multi_lod_committed", {
		"intermediate_quads": intermediate_quads,
		"outer_quads": outer_quads,
		"single_draw_call": true,
		"overlap_filtered": true,
	})


func qa_playability_snapshot() -> Dictionary:
	var snapshot: Dictionary = super.qa_playability_snapshot()
	snapshot["intermediate_lod_step"] = MultiLodTerrainPlanner.INTERMEDIATE_STEP
	snapshot["intermediate_lod_ring_chunks"] = MultiLodTerrainPlanner.INTERMEDIATE_RING_CHUNKS
	return snapshot
