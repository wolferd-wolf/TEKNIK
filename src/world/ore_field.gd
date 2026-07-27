class_name TeknikOreField
extends RefCounted

const STONE: int = 1
const ZINC_ORE: int = 5
const COPPER_ORE: int = 6
const IRON_ORE: int = 7
const GOLD_ORE: int = 8

const CELL_SHIFT: int = 3
const CELL_SIZE: int = 1 << CELL_SHIFT
const MAX_ORE_Y: int = 24
const SURFACE_ROOF: int = 4
const HASH_MASK: int = 0x7fffffff


static func material_for_stone(seed: int, world_position: Vector3i, surface_height: int) -> int:
	if world_position.y <= 1:
		return STONE
	if world_position.y > MAX_ORE_Y:
		return STONE
	if surface_height - world_position.y < SURFACE_ROOF:
		return STONE

	var cell := Vector3i(
		world_position.x >> CELL_SHIFT,
		world_position.y >> CELL_SHIFT,
		world_position.z >> CELL_SHIFT
	)
	var value: int = _hash_3d(seed + 4201, cell.x, cell.y, cell.z)
	var selector: int = value % 1000
	var material: int = STONE
	if world_position.y <= 7 and selector < 35:
		material = GOLD_ORE
	elif world_position.y <= 14 and selector < 140:
		material = IRON_ORE
	elif world_position.y <= 20 and selector < 240:
		material = COPPER_ORE
	elif selector < 330:
		material = ZINC_ORE
	else:
		return STONE

	var center := Vector3i(
		1 + ((value >> 10) % 6),
		1 + ((value >> 13) % 6),
		1 + ((value >> 16) % 6)
	)
	var local := Vector3i(
		world_position.x - cell.x * CELL_SIZE,
		world_position.y - cell.y * CELL_SIZE,
		world_position.z - cell.z * CELL_SIZE
	)
	var radius: int = 3 if ((value >> 20) & 3) == 0 else 2
	var delta: Vector3i = local - center
	return material if delta.length_squared() <= radius * radius else STONE


static func _hash_3d(seed: int, x: int, y: int, z: int) -> int:
	var wrapped_x: int = x & 0x1fffff
	var wrapped_y: int = y & 0x1fffff
	var wrapped_z: int = z & 0x1fffff
	var value: int = (
		wrapped_x * 374761393
		+ wrapped_z * 668265263
		+ wrapped_y * 1442695041
		+ seed * 69069
	) & HASH_MASK
	value = ((value ^ (value >> 13)) * 1274126177) & HASH_MASK
	return (value ^ (value >> 16)) & HASH_MASK
