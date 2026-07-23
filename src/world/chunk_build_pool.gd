class_name TeknikChunkBuildPool
extends RefCounted

const ChunkBuildWorker = preload("res://src/world/chunk_build_worker.gd")
const AdaptiveFrameBudget = preload("res://src/diagnostics/adaptive_frame_budget.gd")

const MAX_DEFERRED_READY_FRAMES: int = 4
const READY_REPORTS_PER_WORKER: int = 2

var _workers: Array[TeknikChunkBuildWorker] = []
var _inflight: Dictionary = {}
var _ready_reports: Array[Dictionary] = []
var _frame_budget: TeknikAdaptiveFrameBudget = AdaptiveFrameBudget.new()
var _deferred_ready_frames: int = 0
var _total_deferred_ready_frames: int = 0
var _last_commit_limit: int = 0
var _last_ready_count: int = 0
var _last_frame_usec: int = 0
var _last_ready_wait_usec: int = 0
var _worst_ready_wait_usec: int = 0
var _last_harvested_reports: int = 0
var _total_harvested_reports: int = 0
var _peak_buffered_ready_reports: int = 0


func configure(worker_count: int) -> void:
	if not _workers.is_empty():
		return
	_frame_budget.configure(60)
	for _index: int in range(maxi(worker_count, 1)):
		_workers.append(ChunkBuildWorker.new())


func capacity() -> int:
	return _workers.size()


func pipeline_capacity() -> int:
	return maxi(_workers.size() * (READY_REPORTS_PER_WORKER + 1), 1)


func pipeline_count() -> int:
	return _inflight.size() + _ready_reports.size()


func buffered_ready_count() -> int:
	return _ready_reports.size()


func peak_buffered_ready_count() -> int:
	return _peak_buffered_ready_reports


func last_harvested_reports() -> int:
	return _last_harvested_reports


func total_harvested_reports() -> int:
	return _total_harvested_reports


func available_slots() -> int:
	if pipeline_count() >= pipeline_capacity():
		return 0
	var available: int = 0
	for worker: TeknikChunkBuildWorker in _workers:
		if not worker.is_busy():
			available += 1
	return mini(available, pipeline_capacity() - pipeline_count())


func has_capacity() -> bool:
	return available_slots() > 0


func has_coordinate(coordinate: Vector3i) -> bool:
	if _inflight.has(coordinate):
		return true
	for report: Dictionary in _ready_reports:
		var buffered_coordinate: Vector3i = report.get("coordinate", Vector3i.ZERO)
		if buffered_coordinate == coordinate:
			return true
	return false


func start(seed: int, coordinate: Vector3i, edit_snapshots: Dictionary = {}) -> Error:
	if has_coordinate(coordinate):
		return ERR_ALREADY_IN_USE
	if pipeline_count() >= pipeline_capacity():
		return ERR_BUSY
	for worker: TeknikChunkBuildWorker in _workers:
		if worker.is_busy():
			continue
		var result: Error = worker.start(seed, coordinate, edit_snapshots)
		if result == OK:
			_inflight[coordinate] = worker
		return result
	return ERR_BUSY


func collect_ready(max_reports: int = 1) -> Array[Dictionary]:
	_harvest_ready_workers()
	var reports: Array[Dictionary] = []
	var ready: int = _ready_reports.size()
	_last_ready_count = ready
	_last_frame_usec = int(Performance.get_monitor(Performance.TIME_PROCESS) * 1_000_000.0)
	_frame_budget.record(_last_frame_usec)
	_update_pending_wait_metrics()
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
	_last_commit_limit = mini(report_limit, _ready_reports.size())
	var delivery_usec: int = Time.get_ticks_usec()
	for _index: int in range(_last_commit_limit):
		var report: Dictionary = _ready_reports.pop_front()
		var build_finished_usec: int = int(report.get("build_finished_usec", delivery_usec))
		var buffered_usec: int = int(report.get("ready_buffered_usec", delivery_usec))
		var ready_wait_usec: int = maxi(delivery_usec - build_finished_usec, 0)
		var buffer_wait_usec: int = maxi(delivery_usec - buffered_usec, 0)
		_last_ready_wait_usec = ready_wait_usec
		_worst_ready_wait_usec = maxi(_worst_ready_wait_usec, ready_wait_usec)
		report["ready_wait_usec"] = ready_wait_usec
		report["ready_buffer_wait_usec"] = buffer_wait_usec
		report["ready_queue_depth"] = ready
		report["buffered_ready_depth"] = ready
		report["adaptive_frame_usec"] = _last_frame_usec
		report["adaptive_commit_limit"] = _last_commit_limit
		report["adaptive_total_deferred_frames"] = _total_deferred_ready_frames
		report["adaptive_p50_usec"] = _frame_budget.p50_usec()
		report["adaptive_p90_usec"] = _frame_budget.p90_usec()
		report["adaptive_slow_usec"] = _frame_budget.slow_usec()
		report["adaptive_critical_usec"] = _frame_budget.critical_usec()
		report["worst_ready_wait_usec"] = _worst_ready_wait_usec
		report["worker_released_before_commit"] = true
		reports.append(report)
	return reports


func _harvest_ready_workers() -> void:
	_last_harvested_reports = 0
	for worker: TeknikChunkBuildWorker in _workers:
		if not worker.is_ready():
			continue
		var coordinate: Vector3i = worker.coordinate()
		var report: Dictionary = worker.collect()
		_inflight.erase(coordinate)
		if report.is_empty():
			continue
		report["harvest_ready_wait_usec"] = int(report.get("ready_wait_usec", 0))
		report["ready_buffered_usec"] = Time.get_ticks_usec()
		_ready_reports.append(report)
		_last_harvested_reports += 1
		_total_harvested_reports += 1
	_peak_buffered_ready_reports = maxi(
		_peak_buffered_ready_reports,
		_ready_reports.size()
	)


func _update_pending_wait_metrics() -> void:
	if _ready_reports.is_empty():
		return
	var now_usec: int = Time.get_ticks_usec()
	var oldest_wait_usec: int = 0
	for report: Dictionary in _ready_reports:
		var build_finished_usec: int = int(report.get("build_finished_usec", now_usec))
		oldest_wait_usec = maxi(oldest_wait_usec, now_usec - build_finished_usec)
	_last_ready_wait_usec = maxi(oldest_wait_usec, 0)
	_worst_ready_wait_usec = maxi(_worst_ready_wait_usec, _last_ready_wait_usec)


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
	var ready: int = _ready_reports.size()
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
	return pipeline_count() > 0


func inflight_count() -> int:
	return _inflight.size()


func inflight_coordinates() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for coordinate: Vector3i in _inflight.keys():
		result.append(coordinate)
	return result
