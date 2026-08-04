class_name TeknikCollisionWindowPlan
extends RefCounted


static func desired(center: Vector3i, radius: int) -> Array[Vector3i]:
	var coordinates: Array[Vector3i] = []
	var safe_radius: int = maxi(radius, 0)
	for z: int in range(center.z - safe_radius, center.z + safe_radius + 1):
		for x: int in range(center.x - safe_radius, center.x + safe_radius + 1):
			coordinates.append(Vector3i(x, 0, z))
	return coordinates


static func reconcile(active: Dictionary, center: Vector3i, radius: int) -> Dictionary:
	var wanted: Dictionary = {}
	for coordinate: Vector3i in desired(center, radius):
		wanted[coordinate] = true

	var add: Array[Vector3i] = []
	var remove: Array[Vector3i] = []
	for coordinate: Vector3i in wanted.keys():
		if not active.has(coordinate):
			add.append(coordinate)
	for coordinate: Vector3i in active.keys():
		if not wanted.has(coordinate):
			remove.append(coordinate)

	add.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector2i(a.x - center.x, a.z - center.z).length_squared() < Vector2i(b.x - center.x, b.z - center.z).length_squared()
	)
	return {"add": add, "remove": remove}
