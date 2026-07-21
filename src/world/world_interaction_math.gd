class_name TeknikWorldInteractionMath
extends RefCounted


static func removal_voxel(hit_position: Vector3, hit_normal: Vector3) -> Vector3i:
	return Vector3i(floor(hit_position.x - hit_normal.x * 0.01), floor(hit_position.y - hit_normal.y * 0.01), floor(hit_position.z - hit_normal.z * 0.01))


static func placement_voxel(hit_position: Vector3, hit_normal: Vector3) -> Vector3i:
	return Vector3i(floor(hit_position.x + hit_normal.x * 0.01), floor(hit_position.y + hit_normal.y * 0.01), floor(hit_position.z + hit_normal.z * 0.01))


static func affected_chunk_coordinates(world_position: Vector3i, chunk_size: int) -> Array[Vector3i]:
	var coordinate := Vector3i(
		floori(float(world_position.x) / float(chunk_size)),
		floori(float(world_position.y) / float(chunk_size)),
		floori(float(world_position.z) / float(chunk_size))
	)
	var result: Array[Vector3i] = [coordinate]
	var local: Vector3i = world_position - coordinate * chunk_size
	if local.x == 0:
		result.append(coordinate + Vector3i.LEFT)
	elif local.x == chunk_size - 1:
		result.append(coordinate + Vector3i.RIGHT)
	if local.y == 0:
		result.append(coordinate + Vector3i.DOWN)
	elif local.y == chunk_size - 1:
		result.append(coordinate + Vector3i.UP)
	if local.z == 0:
		result.append(coordinate + Vector3i(0, 0, -1))
	elif local.z == chunk_size - 1:
		result.append(coordinate + Vector3i(0, 0, 1))
	return result
