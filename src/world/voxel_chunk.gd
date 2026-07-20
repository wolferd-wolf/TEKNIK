extends RefCounted
class_name TeknikVoxelChunk

const SIZE: int = 32
const VOLUME: int = SIZE * SIZE * SIZE
const AIR: int = 0

var revision: int = 0
var voxels: PackedByteArray = PackedByteArray()


func _init(fill_material: int = AIR) -> void:
	voxels.resize(VOLUME)
	voxels.fill(clampi(fill_material, 0, 255))


static func in_bounds(position: Vector3i) -> bool:
	return (
		position.x >= 0 and position.x < SIZE
		and position.y >= 0 and position.y < SIZE
		and position.z >= 0 and position.z < SIZE
	)


static func index_of(position: Vector3i) -> int:
	return position.x + SIZE * (position.z + SIZE * position.y)


func get_voxel(position: Vector3i) -> int:
	if not in_bounds(position):
		return AIR
	return int(voxels[index_of(position)])


func set_voxel(position: Vector3i, material: int) -> bool:
	if not in_bounds(position):
		return false
	var index: int = index_of(position)
	var value: int = clampi(material, 0, 255)
	if int(voxels[index]) == value:
		return false
	voxels[index] = value
	revision += 1
	return true


func fill(material: int) -> void:
	var value: int = clampi(material, 0, 255)
	voxels.fill(value)
	revision += 1


func count_solid() -> int:
	var count: int = 0
	for value: int in voxels:
		if value != AIR:
			count += 1
	return count

