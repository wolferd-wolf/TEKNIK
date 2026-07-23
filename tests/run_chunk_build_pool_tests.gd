extends SceneTree

const ChunkBuildPool = preload("res://src/world/chunk_build_pool.gd")
const AdaptiveFrameBudget = preload("res://src/diagnostics/adaptive_frame_budget.gd")
const StreamingRuntimeMetrics = preload("res://src/diagnostics/streaming_runtime_metrics.gd")

var _failures: int = 0


func _init() -> void:
	_expect(ChunkBuildPool.adaptive_report_limit(16_000, 1, 0) == 1, "stable frames commit one ready chunk")
	_expect(ChunkBuildPool.adaptive_report_limit(24_000, 1, 0) == 0, "slow frames defer a small ready queue")
	_expect(ChunkBuildPool.adaptive_report_limit(24_000, 3, 0) == 1, "backpressure drains a growing ready queue")
	_expect(ChunkBuildPool.adaptive_report_limit(35_000, 3, 0) == 0, "critical frames defer mesh commits")
	_expect(ChunkBuildPool.adaptive_report_limit(35_000, 1, 4) == 1, "starvation protection guarantees progress")
	_expect(ChunkBuildPool.adaptive_report_limit(25_000, 1, 0, 26_000, 36_000) == 1, "measured budget permits frames inside the device baseline")

	var budget: TeknikAdaptiveFrameBudget = AdaptiveFrameBudget.new()
	budget.configure(60)
	for frame_usec: int in [15_800, 16_100, 16_400, 16_700, 17_000, 17_300, 18_000, 19_500, 23_000, 31_000]:
		budget.record(frame_usec)
	_expect(budget.sample_count() == 10, "rolling budget records frame samples")
	_expect(budget.p50_usec() >= 16_000 and budget.p50_usec() <= 18_000, "rolling budget calculates a representative median")
	_expect(budget.p90_usec() >= budget.p50_usec(), "rolling budget preserves percentile ordering")
	_expect(budget.slow_usec() >= 20_000 and budget.slow_usec() <= 26_000, "slow threshold stays inside safe bounds")
	_expect(budget.critical_usec() >= 28_000 and budget.critical_usec() <= 36_000, "critical threshold stays inside safe bounds")
	for _index: int in range(80):
		budget.record(80_000)
	_expect(budget.slow_usec() == 26_000, "sustained stalls cannot train away the slow-frame ceiling")
	_expect(budget.critical_usec() == 36_000, "sustained stalls cannot train away the critical-frame ceiling")

	_test_ready_buffer_releases_worker()

	var pool: TeknikChunkBuildPool = ChunkBuildPool.new()
	pool.configure(2)
	_expect(pool.capacity() == 2, "worker pool exposes configured parallel capacity")
	_expect(pool.pipeline_capacity() == 6, "ready report buffering remains bounded per worker")
	_expect(pool.start(73_421, Vector3i.ZERO, {}) == OK, "first chunk dispatch succeeds")
	_expect(pool.start(73_421, Vector3i.RIGHT, {}) == OK, "second chunk dispatch runs in parallel")
	_expect(pool.inflight_count() == 2, "two chunks are tracked in flight")
	_expect(pool.start(73_421, Vector3i.LEFT, {}) == ERR_BUSY, "pool refuses work beyond active worker capacity")

	var waited_ms: int = 0
	while pool.ready_count() < 2 and waited_ms < 30_000:
		OS.delay_msec(10)
		waited_ms += 10
	_expect(pool.ready_count() == 2, "both parallel workers become ready")

	var first_frame: Array[Dictionary] = pool.collect_ready(1)
	_expect(first_frame.size() <= 1, "default collection never commits more than one chunk per frame")
	_expect(pool.inflight_count() == 0, "all completed workers are released before adaptive mesh delivery")
	_expect(pool.buffered_ready_count() >= 1, "uncommitted completed reports remain in the ready buffer")
	var reports: Array[Dictionary] = []
	reports.append_array(first_frame)
	while pool.is_busy() and waited_ms < 31_000:
		var next_frame: Array[Dictionary] = pool.collect_ready(1)
		reports.append_array(next_frame)
		if next_frame.is_empty():
			OS.delay_msec(1)
			waited_ms += 1
	_expect(reports.size() == 2, "adaptive collection eventually drains both completed chunks")

	var coordinates: Dictionary = {}
	for report: Dictionary in reports:
		coordinates[report.coordinate] = true
		_expect(int(report.get("generation_usec", 0)) > 0, "worker reports generation timing")
		_expect(int(report.get("mesh_worker_usec", 0)) > 0, "worker reports mesh timing")
		_expect(int(report.get("build_thread_usec", 0)) > 0, "worker reports pure thread build timing")
		_expect(int(report.get("ready_wait_usec", -1)) >= 0, "worker reports completed-to-delivery latency")
		_expect(int(report.get("harvest_ready_wait_usec", -1)) >= 0, "worker reports completed-to-buffer latency")
		_expect(int(report.get("ready_buffer_wait_usec", -1)) >= 0, "worker reports buffer-to-delivery latency")
		_expect(bool(report.get("worker_released_before_commit", false)), "report proves worker release precedes mesh commit")
		_expect(int(report.get("ready_queue_depth", 0)) >= 1, "pool records ready queue depth at collection")
		_expect(int(report.get("buffered_ready_depth", 0)) >= 1, "pool records buffered ready depth at delivery")
		_expect(int(report.get("adaptive_commit_limit", 0)) == 1, "pool records adaptive commit decision")
		_expect(int(report.get("adaptive_frame_usec", -1)) >= 0, "pool records frame time used by adaptive policy")
		_expect(int(report.get("adaptive_p50_usec", 0)) > 0, "pool reports rolling median frame time")
		_expect(int(report.get("adaptive_p90_usec", 0)) >= int(report.get("adaptive_p50_usec", 0)), "pool reports ordered frame percentiles")
		_expect(int(report.get("adaptive_slow_usec", 0)) >= 20_000, "pool reports measured slow threshold")
		_expect(int(report.get("adaptive_critical_usec", 0)) >= 28_000, "pool reports measured critical threshold")
		_expect(int(report.get("worst_ready_wait_usec", -1)) >= int(report.get("ready_wait_usec", 0)), "pool tracks worst ready latency")
		_expect(int(report.get("boundary_column_count", 0)) <= 140, "boundary terrain columns are cached instead of resampled per voxel")
	_expect(coordinates.has(Vector3i.ZERO) and coordinates.has(Vector3i.RIGHT), "parallel results preserve requested coordinates")
	_expect(pool.last_ready_count() >= 1, "pool exposes the last observed ready queue depth")
	_expect(pool.last_frame_usec() >= 0, "pool exposes the last adaptive frame time")
	_expect(pool.last_ready_wait_usec() >= 0, "pool exposes the most recent ready latency")
	_expect(pool.worst_ready_wait_usec() >= pool.last_ready_wait_usec(), "pool preserves worst observed ready latency")
	_expect(pool.total_deferred_ready_frames() >= 0, "pool exposes cumulative adaptive deferrals")
	_expect(pool.total_harvested_reports() == 2, "pool counts every harvested worker report")
	_expect(pool.peak_buffered_ready_count() >= 2, "pool records ready buffer pressure")
	# Headless CI can report TIME_PROCESS as zero. Zero samples are intentionally
	# ignored, so only require the count to be valid here; the budget's sampling
	# behavior is covered deterministically above with explicit frame values.
	_expect(pool.adaptive_sample_count() >= 0, "pool exposes a valid adaptive sample count")
	_expect(not pool.is_busy(), "pool becomes idle after adaptive collection")

	var payload: Dictionary = StreamingRuntimeMetrics.append_pool_metrics({}, pool)
	_expect(payload.has("stream_ready_queue_depth"), "runtime payload includes ready queue depth")
	_expect(payload.has("stream_buffered_ready_reports"), "runtime payload includes buffered report count")
	_expect(payload.has("stream_peak_buffered_ready_reports"), "runtime payload includes peak buffer pressure")
	_expect(payload.has("stream_pipeline_count"), "runtime payload includes total chunk pipeline depth")
	_expect(payload.has("stream_pipeline_capacity"), "runtime payload includes bounded pipeline capacity")
	_expect(payload.has("stream_last_harvested_reports"), "runtime payload includes latest harvested workers")
	_expect(payload.has("stream_total_harvested_reports"), "runtime payload includes total harvested workers")
	_expect(payload.has("stream_inflight_chunks"), "runtime payload includes inflight chunk count")
	_expect(payload.has("stream_adaptive_frame_usec"), "runtime payload includes adaptive frame timing")
	_expect(payload.has("stream_adaptive_commit_limit"), "runtime payload includes adaptive commit decision")
	_expect(payload.has("stream_deferred_ready_frames"), "runtime payload includes current deferral streak")
	_expect(payload.has("stream_total_deferred_ready_frames"), "runtime payload includes cumulative deferrals")
	_expect(payload.has("stream_last_ready_wait_usec"), "runtime payload includes latest ready wait")
	_expect(payload.has("stream_worst_ready_wait_usec"), "runtime payload includes worst ready wait")
	_expect(payload.has("stream_adaptive_target_usec"), "runtime payload includes target frame budget")
	_expect(payload.has("stream_adaptive_p50_usec"), "runtime payload includes rolling median")
	_expect(payload.has("stream_adaptive_p90_usec"), "runtime payload includes rolling tail percentile")
	_expect(payload.has("stream_adaptive_slow_usec"), "runtime payload includes measured slow threshold")
	_expect(payload.has("stream_adaptive_critical_usec"), "runtime payload includes measured critical threshold")
	_expect(payload.has("stream_adaptive_sample_count"), "runtime payload includes frame sample count")

	if _failures == 0:
		print("CHUNK_BUILD_POOL_TEST_RESULT PASS waited_ms=", waited_ms)
		quit(0)
	else:
		print("CHUNK_BUILD_POOL_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_ready_buffer_releases_worker() -> void:
	var pool: TeknikChunkBuildPool = ChunkBuildPool.new()
	pool.configure(1)
	var first := Vector3i(7, 0, 3)
	var second := Vector3i(8, 0, 3)
	_expect(pool.start(73_421, first, {}) == OK, "buffer test dispatches first chunk")
	var waited_ms: int = 0
	while pool.ready_count() < 1 and waited_ms < 30_000:
		OS.delay_msec(10)
		waited_ms += 10
	_expect(pool.ready_count() == 1, "buffer test worker completes")
	var withheld: Array[Dictionary] = pool.collect_ready(0)
	_expect(withheld.is_empty(), "zero delivery budget withholds the completed report")
	_expect(pool.buffered_ready_count() == 1, "completed report moves into the bounded ready buffer")
	_expect(pool.inflight_count() == 0, "harvesting releases the finished worker slot")
	_expect(pool.has_capacity(), "released worker can accept more generation work")
	_expect(pool.has_coordinate(first), "buffered coordinates remain protected from duplicate dispatch")
	_expect(pool.start(73_421, first, {}) == ERR_ALREADY_IN_USE, "buffer prevents duplicate buffered chunk work")
	_expect(pool.start(73_421, second, {}) == OK, "freed worker starts the next chunk before first mesh commit")
	while pool.ready_count() < 2 and waited_ms < 60_000:
		OS.delay_msec(10)
		waited_ms += 10
	_expect(pool.ready_count() == 2, "buffer and newly completed worker are both visible")
	var delivered: Array[Dictionary] = pool.collect_ready(8)
	_expect(delivered.size() == 2, "explicit delivery budget drains buffered and newly harvested reports")
	_expect(pool.buffered_ready_count() == 0, "ready buffer drains completely")
	_expect(not pool.is_busy(), "buffer test leaves no worker or report behind")
	for report: Dictionary in delivered:
		_expect(bool(report.get("worker_released_before_commit", false)), "buffer test reports worker-first release ordering")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
