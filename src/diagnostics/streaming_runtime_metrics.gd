class_name TeknikStreamingRuntimeMetrics
extends RefCounted


static func append_pool_metrics(target: Dictionary, pool: TeknikChunkBuildPool) -> Dictionary:
	if pool == null:
		return target
	target["stream_ready_queue_depth"] = pool.last_ready_count()
	target["stream_inflight_chunks"] = pool.inflight_count()
	target["stream_adaptive_frame_usec"] = pool.last_frame_usec()
	target["stream_adaptive_commit_limit"] = pool.last_commit_limit()
	target["stream_deferred_ready_frames"] = pool.deferred_ready_frames()
	target["stream_total_deferred_ready_frames"] = pool.total_deferred_ready_frames()
	target["stream_last_ready_wait_usec"] = pool.last_ready_wait_usec()
	target["stream_worst_ready_wait_usec"] = pool.worst_ready_wait_usec()
	target["stream_adaptive_target_usec"] = pool.adaptive_target_usec()
	target["stream_adaptive_p50_usec"] = pool.adaptive_p50_usec()
	target["stream_adaptive_p90_usec"] = pool.adaptive_p90_usec()
	target["stream_adaptive_slow_usec"] = pool.adaptive_slow_usec()
	target["stream_adaptive_critical_usec"] = pool.adaptive_critical_usec()
	target["stream_adaptive_sample_count"] = pool.adaptive_sample_count()
	return target
