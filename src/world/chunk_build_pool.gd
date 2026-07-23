class_name TeknikChunkBuildPool
extends RefCounted

const ChunkBuildWorker = preload("res://src/world/chunk_build_worker.gd")
const AdaptiveFrameBudget = preload("res://src/diagnostics/adaptive_frame_budget.gd")

const MAX_DEFERRED_READY_FRAMES: int = 4

var _workers: Array[TeknikChunkBuildWorker] = []
var _inflight: Dictionary = {}
var _frame_budget: TeknikAdaptiveFrameBudget = AdaptiveFrameBudget.new()
var _deferred_ready_frames: int = 0
var _total_deferred_ready_frames: int = 0
var _last_commit_limit: int = 0
var _last_ready_count: int = 0
var _last_frame_usec: int = 0
var _last_ready_wait_usec: int = 0
var _worst_ready_wait_usec: int = 0


func configure(worker_count: int) -> void:
	if not _workers.is_empty():
		return
	_frame_budget.configure(60)
	for _index: int in range(maxi(worker_count, 1)):
		_workers.append(ChunkBuildWorker.new())


func capacity() -> int:
	return _workers.size()


func available_slots() -> int:
	var available: int = 0
	for worker: TeknikChunkBuildWorker in _workers:
		if not worker.is_busy():
			available += 1
	return available


func has_capacity() -> bool:
	return available_slots() > 0


func has_coordinate(coordinate: Vector3i) -> bool:
	return _inflight.has(coordinate)


func start(seed: int, coordinate: Vector3i, edit_snapshots: Dictionary = {}) -> Error:
	if _inflight.has(coordinate):
		return ERR_ALREADY_IN_USE
	for worker: TeknikChunkBuildWorker in _workers:
		if worker.is_busy():
			continue
		var result: Error = worker.start(seed, coordinate, edit_snapshots)
		if result == OK:
			_inflight[coordinate] = worker
		return result
	return ERR_BUSY


func collect_ready(max_reports: int = 1) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	var ready: int = ready_count()
	_last_ready_count = ready
	_last_frame_usec = int(Performance.get_monitor(Performance.TIME_PROCESS) * 1_000_000.0)
	_frame_budget.record(_last_frame_usec)
	if ready == 0:
		_deferred_ready_frames = 0
		_last_commit_limit = 0
		_last_ready_wait_usec = 0
		return reports
	if max_reports <= 0:
		_last_commit_limit = 0
		return reports

	var report_limit: int = max_reports
	if max_reports == 1:
		report_limit = adaptive_report_limit(
			_last_frame_usec,
			ready,
			_deferred_ready_frames,
			_frame_budget.slow_usec(),
			_frame_budget.critical_usec()
		)
	if report_limit <= 0:
		_deferred_ready_frames += 1
		_total_deferred_ready_frames += 1
		_last_commit_limit = 0
		return reports

	_deferred_ready_frames = 0
	_last_commit_limit = report_limit
	for worker: TeknikChunkBuildWorker in _workers:
		if reports.size() >= report_limit:
			break
		if not worker.is_ready():
			continue
		var coordinate: Vector3i = worker.coordinate()
		var report: Dictionary = worker.collect()
		_inflight.erase(coordinate)
		if not report.is_empty():
			var ready_wait_usec: int = int(report.get("ready_wait_usec", 0))
			_last_ready_wait_usec = ready_wait_usec
			_worst_ready_wait_usec = maxi(_worst_ready_wait_usec, ready_wait_usec)
			report["ready_queue_depth"] = ready
			report["adaptive_frame_usec"] = _last_frame_usec
			report["adaptive_commit_limit"] = report_limit
			report["adaptive_total_deferred_frames"] = _total_deferred_ready_frames
			report["adaptive_p50_usec"] = _frame_budget.p50_usec()
			report["adaptive_p90_usec"] = _frame_budget.p90_usec()
			report["adaptive_slow_usec"] = _frame_budget.slow_usec()
			report["adaptive_critical_usec"] = _frame_budget.critical_usec()
			report["worst_ready_wait_usec"] = _worst_ready_wait_usec
			reports.append(report)
	return reports


static func adaptive_report_limit(
	frame_usec: int,
	ready: int,
	deferred_frames: int,
	slow_frame_usec: int = 22_000,
	critical_frame_usec: int = 30_000
) -> int:
	if ready <= 0:
		return 0
	if deferred_frames >= MAX_DEFERRED_READY_FRAMES:
		return 1
	if frame_usec >= critical_frame_usec:
		return 0
	if frame_usec >= slow_frame_usec and ready < 3:
		return 0
	return 1


func ready_count() -> int:
	var ready: int = 0
	for worker: TeknikChunkBuildWorker in _workers:
		if worker.is_ready():
			ready += 1
	return ready


func deferred_ready_frames() -> int:
	return _deferred_ready_frames


func total_deferred_ready_frames() -> int:
	return _total_deferred_ready_frames


func last_commit_limit() -> int:
	return _last_commit_limit


func last_ready_count() -> int:
	return _last_ready_count


func last_frame_usec() -> int:
	return _last_frame_usec


func last_ready_wait_usec() -> int:
	return _last_ready_wait_usec


func worst_ready_wait_usec() -> int:
	return _worst_ready_wait_usec


func adaptive_target_usec() -> int:
	return _frame_budget.target_usec()


func adaptive_p50_usec() -> int:
	return _frame_budget.p50_usec()


func adaptive_p90_usec() -> int:
	return _frame_budget.p90_usec()


func adaptive_slow_usec() -> int:
	return _frame_budget.slow_usec()


func adaptive_critical_usec() -> int:
	return _frame_budget.critical_usec()


func adaptive_sample_count() -> int:
	return _frame_budget.sample_count()


func is_busy() -> bool:
	return not _inflight.is_empty()


func inflight_count() -> int:
	return _inflight.size()


func inflight_coordinates() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for coordinate: Vector3i in _inflight.keys():
		result.append(coordinate)
	return result
