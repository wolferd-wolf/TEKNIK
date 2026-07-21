extends RefCounted
class_name TeknikWorldWindowPlan


static func active_world_rect(
	center: Vector3i,
	radius: int,
	chunk_size: int,
	margin: int = 0
) -> Rect2i:
	var safe_radius: int = maxi(0, radius)
	var safe_chunk_size: int = maxi(1, chunk_size)
	var full_size: int = (safe_radius * 2 + 1) * safe_chunk_size
	var safe_margin: int = clampi(margin, 0, full_size >> 1)
	return Rect2i(
		Vector2i(
			(center.x - safe_radius) * safe_chunk_size + safe_margin,
			(center.z - safe_radius) * safe_chunk_size + safe_margin
		),
		Vector2i(
			full_size - safe_margin * 2,
			full_size - safe_margin * 2
		)
	)


static func distant_x_bounds(
	center: Vector3i,
	chunk_size: int,
	distant_radius: int
) -> Vector2i:
	var center_world_x: int = center.x * maxi(1, chunk_size)
	var safe_radius: int = maxi(1, distant_radius)
	return Vector2i(center_world_x - safe_radius, center_world_x + safe_radius)


static func distant_world_rect(
	center: Vector3i,
	chunk_size: int,
	distant_radius: int
) -> Rect2i:
	var safe_chunk_size: int = maxi(1, chunk_size)
	var safe_radius: int = maxi(1, distant_radius)
	var center_world := Vector2i(
		center.x * safe_chunk_size,
		center.z * safe_chunk_size
	)
	return Rect2i(
		center_world - Vector2i(safe_radius, safe_radius),
		Vector2i(safe_radius * 2, safe_radius * 2)
	)


static func chunk_coordinate(world_position: Vector3, chunk_size: int) -> Vector3i:
	var safe_chunk_size: float = float(maxi(1, chunk_size))
	return Vector3i(
		floori(world_position.x / safe_chunk_size),
		0,
		floori(world_position.z / safe_chunk_size)
	)
