class_name TeknikVisibleMiningLock
extends RefCounted

const NO_CHUNK := Vector3i(2_147_483_647, 0, 2_147_483_647)

var _active: bool = false
var _voxel: Vector3i = Vector3i.ZERO
var _chunk: Vector3i = NO_CHUNK


func begin(voxel: Vector3i, chunk: Vector3i) -> bool:
	if _active:
		return false
	_active = true
	_voxel = voxel
	_chunk = chunk
	return true


func cancel() -> void:
	_active = false
	_voxel = Vector3i.ZERO
	_chunk = NO_CHUNK


func is_active() -> bool:
	return _active


func voxel() -> Vector3i:
	return _voxel


func chunk() -> Vector3i:
	return _chunk


func complete_if_visible_commit(committed_chunk: Vector3i, still_dirty: bool) -> bool:
	if not _active or committed_chunk != _chunk or still_dirty:
		return false
	cancel()
	return true
