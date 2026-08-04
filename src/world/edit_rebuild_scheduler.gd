class_name TeknikEditRebuildScheduler
extends RefCounted

const NO_COORDINATE := Vector3i(2_147_483_647, 0, 2_147_483_647)


static func take_ready(
	queue: Array[Vector3i],
	resident_chunks: Dictionary,
	is_inflight: Callable
) -> Vector3i:
	var candidates: int = queue.size()
	for _index: int in range(candidates):
		var coordinate: Vector3i = queue.pop_front()
		if not resident_chunks.has(coordinate):
			continue
		if is_inflight.is_valid() and bool(is_inflight.call(coordinate)):
			# Keep the dirty marker until the in-flight snapshot commits. The next
			# rebuild then captures every edit made while that worker was running.
			queue.append(coordinate)
			continue
		return coordinate
	return NO_COORDINATE
