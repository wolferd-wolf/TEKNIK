class_name TeknikMobileControlMath
extends RefCounted


static func stick_vector(origin: Vector2, position: Vector2, radius: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var displacement: Vector2 = position - origin
	if displacement.length() > radius:
		displacement = displacement.normalized() * radius
	return displacement / radius


static func is_jump_zone(position: Vector2, viewport_size: Vector2) -> bool:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	var center := Vector2(viewport_size.x * 0.87, viewport_size.y * 0.78)
	var radius: float = minf(viewport_size.x, viewport_size.y) * 0.095
	return position.distance_to(center) <= radius


static func is_movement_zone(position: Vector2, viewport_size: Vector2) -> bool:
	return viewport_size.x > 0.0 and viewport_size.y > 0.0 and position.x < viewport_size.x * 0.48


static func is_look_zone(position: Vector2, viewport_size: Vector2) -> bool:
	return viewport_size.x > 0.0 and viewport_size.y > 0.0 and position.x >= viewport_size.x * 0.48 and not is_jump_zone(position, viewport_size)
