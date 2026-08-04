class_name TeknikVoxelPlayerMotion
extends RefCounted

# Minecraft's standing player is 0.6 blocks wide and 1.8 blocks tall. TEKNIK
# uses one world unit per voxel, so these values map directly to our 1x1x1 blocks.
const BLOCK_SIZE: float = 1.0
const BODY_WIDTH: float = 0.60
const BODY_HEIGHT: float = 1.80
const EYE_HEIGHT: float = 1.62
const STEP_HEIGHT: float = 0.60
const GROUND_PROBE: float = 0.08
const BODY_HALF_WIDTH: float = BODY_WIDTH * 0.5
const HORIZONTAL_SKIN: float = 0.001
const EPSILON: float = 0.00001


static func solve_motion(
	position: Vector3,
	requested_motion: Vector3,
	solid_query: Callable,
	allow_step: bool = false
) -> Dictionary:
	if not solid_query.is_valid():
		return {
			"motion": requested_motion,
			"grounded": false,
			"stepped": false,
		}

	var vertical: float = _clip_axis(position, requested_motion.y, 1, solid_query)
	var after_vertical := position + Vector3(0.0, vertical, 0.0)
	var direct_horizontal := _clip_horizontal_best(
		after_vertical,
		Vector2(requested_motion.x, requested_motion.z),
		solid_query
	)
	var selected_motion := Vector3(direct_horizontal.x, vertical, direct_horizontal.y)
	var stepped: bool = false

	var horizontal_was_clipped: bool = (
		absf(direct_horizontal.x - requested_motion.x) > EPSILON
		or absf(direct_horizontal.y - requested_motion.z) > EPSILON
	)
	if (
		allow_step
		and horizontal_was_clipped
		and Vector2(requested_motion.x, requested_motion.z).length_squared() > EPSILON
	):
		var step_up: float = _clip_axis(position, STEP_HEIGHT, 1, solid_query)
		if step_up > EPSILON:
			var raised_position := position + Vector3.UP * step_up
			var stepped_horizontal := _clip_horizontal_best(
				raised_position,
				Vector2(requested_motion.x, requested_motion.z),
				solid_query
			)
			var horizontal_position := raised_position + Vector3(
				stepped_horizontal.x,
				0.0,
				stepped_horizontal.y
			)
			var step_down: float = _clip_axis(
				horizontal_position,
				-(step_up + GROUND_PROBE),
				1,
				solid_query
			)
			var stepped_motion := Vector3(
				stepped_horizontal.x,
				step_up + step_down,
				stepped_horizontal.y
			)
			if (
				stepped_horizontal.length_squared()
				> direct_horizontal.length_squared() + EPSILON
				and stepped_motion.y <= STEP_HEIGHT + EPSILON
			):
				selected_motion = stepped_motion
				stepped = true

	var final_position: Vector3 = position + selected_motion
	return {
		"motion": selected_motion,
		"grounded": is_supported(final_position, solid_query),
		"stepped": stepped,
	}


static func clip_motion(position: Vector3, requested_motion: Vector3, solid_query: Callable) -> Vector3:
	return solve_motion(position, requested_motion, solid_query).motion


static func is_supported(position: Vector3, solid_query: Callable) -> bool:
	if not solid_query.is_valid():
		return false
	var downward: float = _clip_axis(position, -GROUND_PROBE, 1, solid_query)
	return downward > -GROUND_PROBE + EPSILON


static func is_clear(position: Vector3, solid_query: Callable) -> bool:
	if not solid_query.is_valid():
		return true
	var minimum: Vector3 = body_min(position)
	var maximum: Vector3 = body_max(position)
	var min_voxel := Vector3i(
		floori(minimum.x + EPSILON),
		floori(minimum.y + EPSILON),
		floori(minimum.z + EPSILON)
	)
	var max_voxel := Vector3i(
		ceili(maximum.x - EPSILON) - 1,
		ceili(maximum.y - EPSILON) - 1,
		ceili(maximum.z - EPSILON) - 1
	)
	for y: int in range(min_voxel.y, max_voxel.y + 1):
		for z: int in range(min_voxel.z, max_voxel.z + 1):
			for x: int in range(min_voxel.x, max_voxel.x + 1):
				var voxel := Vector3i(x, y, z)
				if bool(solid_query.call(voxel)) and _body_overlaps_voxel(minimum, maximum, voxel):
					return false
	return true


static func recover_position(position: Vector3, solid_query: Callable) -> Vector3:
	if is_clear(position, solid_query):
		return position

	# Match Minecraft's push-out intent: prefer the smallest horizontal escape and
	# only move upward when no nearby horizontal resolution exists.
	for step_index: int in range(1, 11):
		var distance: float = float(step_index) * 0.05
		for offset: Vector3 in [
			Vector3(-distance, 0.0, 0.0),
			Vector3(distance, 0.0, 0.0),
			Vector3(0.0, 0.0, -distance),
			Vector3(0.0, 0.0, distance),
		]:
			var candidate: Vector3 = position + offset
			if is_clear(candidate, solid_query):
				return candidate
	for up_index: int in range(1, 21):
		var upward_candidate := position + Vector3.UP * (float(up_index) * 0.10)
		if is_clear(upward_candidate, solid_query):
			return upward_candidate
	return position


static func body_min(position: Vector3) -> Vector3:
	return Vector3(
		position.x - BODY_HALF_WIDTH + HORIZONTAL_SKIN,
		position.y,
		position.z - BODY_HALF_WIDTH + HORIZONTAL_SKIN
	)


static func body_max(position: Vector3) -> Vector3:
	return Vector3(
		position.x + BODY_HALF_WIDTH - HORIZONTAL_SKIN,
		position.y + BODY_HEIGHT - EPSILON,
		position.z + BODY_HALF_WIDTH - HORIZONTAL_SKIN
	)


static func _clip_horizontal_best(
	position: Vector3,
	requested: Vector2,
	solid_query: Callable
) -> Vector2:
	var x_first_x: float = _clip_axis(position, requested.x, 0, solid_query)
	var after_x := position + Vector3(x_first_x, 0.0, 0.0)
	var x_first_z: float = _clip_axis(after_x, requested.y, 2, solid_query)
	var x_first := Vector2(x_first_x, x_first_z)

	var z_first_z: float = _clip_axis(position, requested.y, 2, solid_query)
	var after_z := position + Vector3(0.0, 0.0, z_first_z)
	var z_first_x: float = _clip_axis(after_z, requested.x, 0, solid_query)
	var z_first := Vector2(z_first_x, z_first_z)

	return x_first if x_first.length_squared() >= z_first.length_squared() else z_first


static func _clip_axis(position: Vector3, axis_motion: float, axis: int, solid_query: Callable) -> float:
	if absf(axis_motion) <= EPSILON:
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
				var block_min: float = float(voxel[axis]) * BLOCK_SIZE
				var block_max: float = block_min + BLOCK_SIZE
				if axis_motion > 0.0:
					var positive_distance: float = block_min - maximum[axis]
					if positive_distance >= -EPSILON and positive_distance < allowed:
						allowed = maxf(0.0, positive_distance)
				else:
					var negative_distance: float = block_max - minimum[axis]
					if negative_distance <= EPSILON and negative_distance > allowed:
						allowed = minf(0.0, negative_distance)
	return allowed


static func _overlaps_other_axes(
	minimum: Vector3,
	maximum: Vector3,
	voxel: Vector3i,
	moving_axis: int
) -> bool:
	for axis: int in range(3):
		if axis == moving_axis:
			continue
		var block_min: float = float(voxel[axis]) * BLOCK_SIZE
		var block_max: float = block_min + BLOCK_SIZE
		if maximum[axis] <= block_min + EPSILON or minimum[axis] >= block_max - EPSILON:
			return false
	return true


static func _body_overlaps_voxel(minimum: Vector3, maximum: Vector3, voxel: Vector3i) -> bool:
	var block_min := Vector3(float(voxel.x), float(voxel.y), float(voxel.z)) * BLOCK_SIZE
	var block_max := block_min + Vector3.ONE * BLOCK_SIZE
	return (
		maximum.x > block_min.x + EPSILON
		and minimum.x < block_max.x - EPSILON
		and maximum.y > block_min.y + EPSILON
		and minimum.y < block_max.y - EPSILON
		and maximum.z > block_min.z + EPSILON
		and minimum.z < block_max.z - EPSILON
	)
