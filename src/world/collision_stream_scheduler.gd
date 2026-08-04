class_name TeknikCollisionStreamScheduler
extends RefCounted

const MIN_BUDGET_USEC: int = 700
const MAX_BUDGET_USEC: int = 2600
const DEFAULT_BUDGET_USEC: int = 1600


static func ordered_adds(
	coordinates: Array[Vector3i],
	center: Vector3i,
	movement_direction: Vector2i
) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	result.assign(coordinates)
	result.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var a_dx: int = a.x - center.x
		var a_dz: int = a.z - center.z
		var b_dx: int = b.x - center.x
		var b_dz: int = b.z - center.z
		var a_distance: int = absi(a_dx) + absi(a_dz)
		var b_distance: int = absi(b_dx) + absi(b_dz)
		var a_ahead: int = a_dx * movement_direction.x + a_dz * movement_direction.y
		var b_ahead: int = b_dx * movement_direction.x + b_dz * movement_direction.y
		if a_distance != b_distance:
			return a_distance < b_distance
		if a_ahead != b_ahead:
			return a_ahead > b_ahead
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x
	)
	return result


static func ordered_removes(coordinates: Array[Vector3i], center: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	result.assign(coordinates)
	result.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var a_distance: int = absi(a.x - center.x) + absi(a.z - center.z)
		var b_distance: int = absi(b.x - center.x) + absi(b.z - center.z)
		if a_distance != b_distance:
			return a_distance > b_distance
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x
	)
	return result


static func next_budget_usec(current_budget_usec: int, last_commit_usec: int) -> int:
	var current: int = clampi(current_budget_usec, MIN_BUDGET_USEC, MAX_BUDGET_USEC)
	if last_commit_usec > current:
		return maxi(MIN_BUDGET_USEC, int(float(current) * 0.78))
	if last_commit_usec > 0 and last_commit_usec < int(float(current) * 0.45):
		return mini(MAX_BUDGET_USEC, current + 120)
	return current
