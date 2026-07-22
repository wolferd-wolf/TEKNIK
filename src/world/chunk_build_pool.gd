class_name TeknikChunkBuildPool
extends RefCounted

const ChunkBuildWorker = preload("res://src/world/chunk_build_worker.gd")

var _workers: Array[TeknikChunkBuildWorker] = []
var _inflight: Dictionary = {}


func configure(worker_count: int) -> void:
	if not _workers.is_empty():
		return
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
	var report_limit: int = maxi(max_reports, 1)
	for worker: TeknikChunkBuildWorker in _workers:
		if reports.size() >= report_limit:
			break
		if not worker.is_ready():
			continue
		var coordinate: Vector3i = worker.coordinate()
		var report: Dictionary = worker.collect()
		_inflight.erase(coordinate)
		if not report.is_empty():
			reports.append(report)
	return reports


func ready_count() -> int:
	var ready: int = 0
	for worker: TeknikChunkBuildWorker in _workers:
		if worker.is_ready():
			ready += 1
	return ready


func is_busy() -> bool:
	return not _inflight.is_empty()


func inflight_count() -> int:
	return _inflight.size()


func inflight_coordinates() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for coordinate: Vector3i in _inflight.keys():
		result.append(coordinate)
	return result
