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
	coordinates.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var distance_a: int = _distance_squared(a, priority)
		var distance_b: int = _distance_squared(b, priority)
		if distance_a != distance_b:
			return distance_a < distance_b
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x
	)
	return coordinates


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


static func _distance_squared(a: Vector3i, b: Vector3i) -> int:
	var delta_x: int = a.x - b.x
	var delta_z: int = a.z - b.z
	return delta_x * delta_x + delta_z * delta_z
