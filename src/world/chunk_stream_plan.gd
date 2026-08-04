extends RefCounted
class_name TeknikChunkStreamPlan


static func ordered_square(
	center: Vector3i,
	radius: int,
	priority: Vector3i = Vector3i.ZERO
) -> Array[Vector3i]:
	var coordinates: Array[Vector3i] = []
	for z: int in range(center.z - radius, center.z + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			coordinates.append(Vector3i(x, center.y, z))
	return sort_directional(coordinates, center, priority, Vector2i.ZERO)


static func sort_directional(
	coordinates: Array[Vector3i],
	center: Vector3i,
	priority: Vector3i,
	direction: Vector2i
) -> Array[Vector3i]:
	var ordered: Array[Vector3i] = coordinates.duplicate()
	var normalized_direction := Vector2(
		float(clampi(direction.x, -1, 1)),
		float(clampi(direction.y, -1, 1))
	)
	if normalized_direction.length_squared() > 0.0:
		normalized_direction = normalized_direction.normalized()
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var score_a: float = _priority_score(a, center, priority, normalized_direction)
		var score_b: float = _priority_score(b, center, priority, normalized_direction)
		if not is_equal_approx(score_a, score_b):
			return score_a < score_b
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x
	)
	return ordered


static func outside_square(
	active: Array[Vector3i],
	center: Vector3i,
	radius: int
) -> Array[Vector3i]:
	var outside: Array[Vector3i] = []
	for coordinate: Vector3i in active:
		if (
			absi(coordinate.x - center.x) > radius
			or absi(coordinate.z - center.z) > radius
		):
			outside.append(coordinate)
	return outside


static func _priority_score(
	coordinate: Vector3i,
	center: Vector3i,
	priority: Vector3i,
	direction: Vector2
) -> float:
	var distance_score: float = float(_distance_squared(coordinate, priority))
	if direction.length_squared() == 0.0:
		return distance_score
	var offset := Vector2(
		float(coordinate.x - center.x),
		float(coordinate.z - center.z)
	)
	# Negative projection rewards chunks in front of the player. The distance term
	# remains dominant enough that nearby safety chunks always precede far chunks.
	var forward_projection: float = offset.dot(direction)
	return distance_score - forward_projection * 2.25


static func _distance_squared(a: Vector3i, b: Vector3i) -> int:
	var delta_x: int = a.x - b.x
	var delta_z: int = a.z - b.z
	return delta_x * delta_x + delta_z * delta_z
