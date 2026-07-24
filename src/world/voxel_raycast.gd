class_name TeknikVoxelRaycast
extends RefCounted

# Grid traversal follows the Amanatides-Woo voxel stepping technique. The
# implementation is original to TEKNIK; the technique attribution is recorded
# in docs/TECHNIQUE_ATTRIBUTION.md.
const MAX_STEPS: int = 512
const ZERO_EPSILON: float = 0.000001


static func cast(
	origin: Vector3,
	direction: Vector3,
	max_distance: float,
	is_target: Callable
) -> Dictionary:
	if max_distance <= 0.0 or direction.length_squared() <= ZERO_EPSILON or not is_target.is_valid():
		return {}

	var ray: Vector3 = direction.normalized()
	var voxel := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(_axis_step(ray.x), _axis_step(ray.y), _axis_step(ray.z))
	var t_delta := Vector3(_axis_delta(ray.x), _axis_delta(ray.y), _axis_delta(ray.z))
	var t_max := Vector3(
		_axis_first_boundary(origin.x, voxel.x, ray.x, step.x),
		_axis_first_boundary(origin.y, voxel.y, ray.y, step.y),
		_axis_first_boundary(origin.z, voxel.z, ray.z, step.z)
	)
	var entered_normal := Vector3.ZERO
	var travelled: float = 0.0

	for _iteration: int in range(MAX_STEPS):
		if travelled > max_distance + ZERO_EPSILON:
			break
		if bool(is_target.call(voxel)):
			return {
				"voxel": voxel,
				"distance": travelled,
				"normal": entered_normal,
			}

		if t_max.x <= t_max.y and t_max.x <= t_max.z:
			travelled = t_max.x
			voxel.x += step.x
			t_max.x += t_delta.x
			entered_normal = Vector3(-step.x, 0.0, 0.0)
		elif t_max.y <= t_max.z:
			travelled = t_max.y
			voxel.y += step.y
			t_max.y += t_delta.y
			entered_normal = Vector3(0.0, -step.y, 0.0)
		else:
			travelled = t_max.z
			voxel.z += step.z
			t_max.z += t_delta.z
			entered_normal = Vector3(0.0, 0.0, -step.z)

	return {}


static func outline_center(voxel: Vector3i) -> Vector3:
	return Vector3(voxel) + Vector3.ONE * 0.5


static func _axis_step(component: float) -> int:
	if component > ZERO_EPSILON:
		return 1
	if component < -ZERO_EPSILON:
		return -1
	return 0


static func _axis_delta(component: float) -> float:
	if absf(component) <= ZERO_EPSILON:
		return INF
	return absf(1.0 / component)


static func _axis_first_boundary(origin_component: float, voxel_component: int, direction_component: float, step_component: int) -> float:
	if step_component == 0:
		return INF
	var boundary: float = float(voxel_component + 1) if step_component > 0 else float(voxel_component)
	return maxf(0.0, (boundary - origin_component) / direction_component)
