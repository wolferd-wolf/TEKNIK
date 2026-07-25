extends "res://scripts/world/atomic_voxel_world.gd"

func _ready() -> void:
	super._ready()
	shared_material.albedo_texture = null
	shared_material.vertex_color_use_as_albedo = true
	shared_material.roughness = 0.94
	shared_material.metallic = 0.0

func _block_color(block: int, cell: Vector3i, shade: float) -> Color:
	var base_color: Color
	match block:
		BLOCK_GRASS:
			# Top faces are clean green; side and underside faces become earthy.
			base_color = Color(0.34, 0.68, 0.25) if shade >= 0.98 else Color(0.38, 0.48, 0.23)
		BLOCK_DIRT:
			base_color = Color(0.50, 0.34, 0.20)
		BLOCK_STONE:
			base_color = Color(0.56, 0.58, 0.60)
		BLOCK_SAND:
			base_color = Color(0.82, 0.75, 0.54)
		_:
			base_color = Color.WHITE

	var hash_value: int = absi((cell.x * 73856093) ^ (cell.y * 83492791) ^ (cell.z * 19349663))
	var variation: float = 0.97 + float(hash_value % 7) * 0.01
	var factor: float = shade * variation
	return Color(
		clampf(base_color.r * factor, 0.0, 1.0),
		clampf(base_color.g * factor, 0.0, 1.0),
		clampf(base_color.b * factor, 0.0, 1.0),
		1.0
	)

func _face_shade(face_index: int) -> float:
	match face_index:
		0:
			return 1.0
		1:
			return 0.78
		2, 3:
			return 0.92
		_:
			return 0.86
