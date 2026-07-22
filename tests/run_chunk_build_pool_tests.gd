extends SceneTree

const ChunkBuildPool = preload("res://src/world/chunk_build_pool.gd")

var _failures: int = 0


func _init() -> void:
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

	var first_frame: Array[Dictionary] = pool.collect_ready()
	_expect(first_frame.size() == 1, "default collection commits at most one chunk per frame")
	_expect(pool.inflight_count() == 1, "one completed worker remains queued after the first frame")
	var second_frame: Array[Dictionary] = pool.collect_ready()
	_expect(second_frame.size() == 1, "next frame collects the remaining completed chunk")

	var reports: Array[Dictionary] = []
	reports.append_array(first_frame)
	reports.append_array(second_frame)
	_expect(reports.size() == 2, "both parallel workers complete")
	var coordinates: Dictionary = {}
	for report: Dictionary in reports:
		coordinates[report.coordinate] = true
		_expect(int(report.get("generation_usec", 0)) > 0, "worker reports generation timing")
		_expect(int(report.get("mesh_worker_usec", 0)) > 0, "worker reports mesh timing")
		_expect(int(report.get("boundary_column_count", 0)) <= 140, "boundary terrain columns are cached instead of resampled per voxel")
	_expect(coordinates.has(Vector3i.ZERO) and coordinates.has(Vector3i.RIGHT), "parallel results preserve requested coordinates")
	_expect(not pool.is_busy(), "pool becomes idle after collection")

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
