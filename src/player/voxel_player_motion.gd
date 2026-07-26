class_name TeknikVoxelPlayerMotion
extends RefCounted

const BODY_WIDTH: float = 0.58
const BODY_HEIGHT: float = 1.80
const BODY_HALF_WIDTH: float = BODY_WIDTH * 0.5
const EPSILON: float = 0.0001


static func clip_motion(position: Vector3, requested_motion: Vector3, solid_query: Callable) -> Vector3:
	if not solid_query.is_valid():
		return requested_motion
	var clipped := requested_motion
	var working_position := position
	clipped.y = _clip_axis(working_position, clipped.y, 1, solid_query)
	working_position.y += clipped.y
	clipped.x = _clip_axis(working_position, clipped.x, 0, solid_query)
	working_position.x += clipped.x
	clipped.z = _clip_axis(working_position, clipped.z, 2, solid_query)
	return clipped


static func body_min(position: Vector3) -> Vector3:
	return Vector3(position.x - BODY_HALF_WIDTH, position.y, position.z - BODY_HALF_WIDTH)


static func body_max(position: Vector3) -> Vector3:
	return Vector3(position.x + BODY_HALF_WIDTH, position.y + BODY_HEIGHT, position.z + BODY_HALF_WIDTH)


static func _clip_axis(position: Vector3, axis_motion: float, axis: int, solid_query: Callable) -> float:
	if is_zero_approx(axis_motion):
		return 0.0
	var minimum: Vector3 = body_min(position)
	var maximum: Vector3 = body_max(position)
	var moved_minimum := minimum
	var moved_maximum := maximum
	moved_minimum[axis] += axis_motion
	moved_maximum[axis] += axis_motion
	var swept_min := Vector3(
		minf(minimum.x, moved_minimum.x),
		minf(minimum.y, moved_minimum.y),
		minf(minimum.z, moved_minimum.z)
	)
	var swept_max := Vector3(
		maxf(maximum.x, moved_maximum.x),
		maxf(maximum.y, moved_maximum.y),
		maxf(maximum.z, moved_maximum.z)
	)
	var min_voxel := Vector3i(
		floori(swept_min.x + EPSILON),
		floori(swept_min.y + EPSILON),
		floori(swept_min.z + EPSILON)
	)
	var max_voxel := Vector3i(
		ceili(swept_max.x - EPSILON) - 1,
		ceili(swept_max.y - EPSILON) - 1,
		ceili(swept_max.z - EPSILON) - 1
	)
	var allowed: float = axis_motion
	for y: int in range(min_voxel.y, max_voxel.y + 1):
		for z: int in range(min_voxel.z, max_voxel.z + 1):
			for x: int in range(min_voxel.x, max_voxel.x + 1):
				var voxel := Vector3i(x, y, z)
				if not bool(solid_query.call(voxel)):
					continue
				if not _overlaps_other_axes(minimum, maximum, voxel, axis):
					continue
				var block_min: float = float(voxel[axis])
				var block_max: float = block_min + 1.0
				if axis_motion > 0.0:
					var positive_distance: float = block_min - maximum[axis]
					if positive_distance >= -EPSILON and positive_distance < allowed:
						allowed = maxf(0.0, positive_distance)
				else:
					var negative_distance: float = block_max - minimum[axis]
					if negative_distance <= EPSILON and negative_distance > allowed:
						allowed = minf(0.0, negative_distance)
	return allowed


static func _overlaps_other_axes(minimum: Vector3, maximum: Vector3, voxel: Vector3i, moving_axis: int) -> bool:
	for axis: int in range(3):
		if axis == moving_axis:
			continue
		var block_min: float = float(voxel[axis])
		var block_max: float = block_min + 1.0
		if maximum[axis] <= block_min + EPSILON or minimum[axis] >= block_max - EPSILON:
			return false
	return true
