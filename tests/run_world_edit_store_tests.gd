extends SceneTree

const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const WorldEditStore = preload("res://src/world/world_edit_store.gd")

var _failures: int = 0

func _init() -> void:
	_test_coordinates()
	_test_sparse_round_trip()
	_test_chunk_application()
	_test_file_round_trip()
	if _failures == 0:
		print("WORLD_EDIT_STORE_TEST_RESULT PASS")
		quit(0)
	else:
		print("WORLD_EDIT_STORE_TEST_RESULT FAIL count=", _failures)
		quit(1)

func _test_coordinates() -> void:
	_expect(WorldEditStore.chunk_coordinate(Vector3i(0, 0, 0)) == Vector3i.ZERO, "origin maps to origin chunk")
	_expect(WorldEditStore.chunk_coordinate(Vector3i(31, 31, 31)) == Vector3i.ZERO, "positive chunk boundary stays local")
	_expect(WorldEditStore.chunk_coordinate(Vector3i(32, 0, 0)) == Vector3i(1, 0, 0), "positive boundary advances chunk")
	_expect(WorldEditStore.chunk_coordinate(Vector3i(-1, 0, -1)) == Vector3i(-1, 0, -1), "negative coordinates floor into previous chunk")
	_expect(WorldEditStore.local_coordinate(Vector3i(-1, 0, -1)) == Vector3i(31, 0, 31), "negative coordinates wrap to valid local cells")

func _test_sparse_round_trip() -> void:
	var store := WorldEditStore.new()
	store.set_override(Vector3i(1, 2, 3), 4)
	store.set_override(Vector3i(-1, 5, -33), 0)
	var encoded: Dictionary = store.encode(73421)
	var restored := WorldEditStore.new()
	_expect(restored.decode(encoded, 73421) == OK, "versioned edit document decodes")
	_expect(restored.override_count() == 2, "sparse override count survives encoding")
	_expect(restored.get_override(Vector3i(1, 2, 3), -1) == 4, "positive override survives encoding")
	_expect(restored.get_override(Vector3i(-1, 5, -33), -1) == 0, "air override survives encoding")
	_expect(restored.decode(encoded, 1) == ERR_INVALID_DATA, "seed mismatch is rejected")

func _test_chunk_application() -> void:
	var store := WorldEditStore.new()
	var coordinate := Vector3i(-1, 0, 2)
	var world_position := coordinate * VoxelChunk.SIZE + Vector3i(31, 4, 7)
	store.set_override(world_position, 9)
	var chunk := VoxelChunk.new(2)
	_expect(store.apply_to_chunk(coordinate, chunk) == 1, "chunk receives one sparse override")
	_expect(chunk.get_voxel(Vector3i(31, 4, 7)) == 9, "applied override changes generated voxel")
	_expect(store.apply_to_chunk(coordinate, chunk) == 0, "reapplying identical overrides is stable")

func _test_file_round_trip() -> void:
	var path := "user://world-edit-test.json"
	var store := WorldEditStore.new()
	store.set_override(Vector3i(70, 8, -2), 3)
	_expect(store.save_atomic(path, 73421) == OK, "world edits save atomically")
	_expect(not store.is_dirty(), "successful save clears dirty state")
	var loaded := WorldEditStore.new()
	_expect(loaded.load_file(path, 73421) == OK, "world edits load from disk")
	_expect(loaded.get_override(Vector3i(70, 8, -2), -1) == 3, "disk round trip preserves edit")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		_failures += 1
		push_error("FAIL %s" % message)
