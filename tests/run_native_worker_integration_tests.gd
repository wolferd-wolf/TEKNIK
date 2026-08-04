extends SceneTree

const ChunkBuildWorker = preload("res://src/world/chunk_build_worker.gd")

const SEED: int = 73_421
var _failures: int = 0


func _init() -> void:
	var worker: TeknikChunkBuildWorker = ChunkBuildWorker.new()
	var start_result: Error = worker.start(SEED, Vector3i(1, 0, -1), {})
	_expect(start_result == OK, "threaded chunk worker starts")
	var waited_ms: int = 0
	while not worker.is_ready() and waited_ms < 30_000:
		OS.delay_msec(5)
		waited_ms += 5
	_expect(worker.is_ready(), "threaded native chunk worker completes")
	if worker.is_ready():
		var report: Dictionary = worker.collect()
		_expect(bool(report.get("native_backend", false)), "worker used Rust through the C++ bridge")
		_expect(not report.has("native_fallback_reason"), "worker did not silently fall back to GDScript")
		_expect(str(report.get("native_core_version", "")).begins_with("teknik-rust-core-"), "worker reports the Rust core version")
		_expect(int(report.get("quads", 0)) > 0, "native worker produced mesh quads")
		_expect((report.get("arrays", []) as Array).size() == Mesh.ARRAY_MAX, "native worker produced Godot mesh arrays")
		_expect(not (report.get("collision_profile", {}) as Dictionary).is_empty(), "native voxel output feeds collision generation")
		_expect(report.get("coordinate", Vector3i.ZERO) == Vector3i(1, 0, -1), "native worker preserves chunk coordinates")
		print(
			"NATIVE_WORKER_RESULT waited_ms=", waited_ms,
			" worker_usec=", report.get("worker_usec", 0),
			" generation_usec=", report.get("generation_usec", 0),
			" mesh_usec=", report.get("mesh_worker_usec", 0),
			" collision_usec=", report.get("collision_profile_usec", 0),
			" quads=", report.get("quads", 0)
		)

	if _failures == 0:
		print("NATIVE_WORKER_INTEGRATION_TEST_RESULT PASS")
		quit(0)
	else:
		print("NATIVE_WORKER_INTEGRATION_TEST_RESULT FAIL count=", _failures)
		quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		push_error("FAIL " + label)
		_failures += 1
