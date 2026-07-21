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

	var reports: Array[Dictionary] = []
	var waited_ms: int = 0
	while reports.size() < 2 and waited_ms < 30_000:
		OS.delay_msec(10)
		waited_ms += 10
		reports.append_array(pool.collect_ready())
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
