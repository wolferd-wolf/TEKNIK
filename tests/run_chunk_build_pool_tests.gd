extends SceneTree

const ChunkBuildPool = preload("res://src/world/chunk_build_pool.gd")

var _failures: int = 0


func _init() -> void:
	_expect(ChunkBuildPool.adaptive_report_limit(16_000, 1, 0) == 1, "stable frames commit one ready chunk")
	_expect(ChunkBuildPool.adaptive_report_limit(24_000, 1, 0) == 0, "slow frames defer a small ready queue")
	_expect(ChunkBuildPool.adaptive_report_limit(24_000, 3, 0) == 1, "backpressure drains a growing ready queue")
	_expect(ChunkBuildPool.adaptive_report_limit(35_000, 3, 0) == 0, "critical frames defer mesh commits")
	_expect(ChunkBuildPool.adaptive_report_limit(35_000, 1, 4) == 1, "starvation protection guarantees progress")

	var pool: TeknikChunkBuildPool = ChunkBuildPool.new()
	pool.configure(2)
	_expect(pool.capacity() == 2, "worker pool exposes configured parallel capacity")
	_expect(pool.start(73_421, Vector3i.ZERO, {}) == OK, "first chunk dispatch succeeds")
	_expect(pool.start(73_421, Vector3i.RIGHT, {}) == OK, "second chunk dispatch runs in parallel")
	_expect(pool.inflight_count() == 2, "two chunks are tracked in flight")
	_expect(pool.start(73_421, Vector3i.LEFT, {}) == ERR_BUSY, "pool refuses work beyond capacity")

	var waited_ms: int = 0
	while pool.ready_count() < 2 and waited_ms < 30_000:
		OS.delay_msec(10)
		waited_ms += 10
	_expect(pool.ready_count() == 2, "both parallel workers become ready")

	var first_frame: Array[Dictionary] = pool.collect_ready(1)
	_expect(first_frame.size() <= 1, "default collection never commits more than one chunk per frame")
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
		_expect(int(report.get("boundary_column_count", 0)) <= 140, "boundary terrain columns are cached instead of resampled per voxel")
	_expect(coordinates.has(Vector3i.ZERO) and coordinates.has(Vector3i.RIGHT), "parallel results preserve requested coordinates")
	_expect(not pool.is_busy(), "pool becomes idle after adaptive collection")

	if _failures == 0:
		print("CHUNK_BUILD_POOL_TEST_RESULT PASS waited_ms=", waited_ms)
		quit(0)
	else:
		print("CHUNK_BUILD_POOL_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
