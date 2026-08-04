class_name TeknikChunkBuildWorker
extends RefCounted

const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")
const TerrainCollisionProfile = preload("res://src/world/terrain_collision_profile.gd")
const NativeChunkBackend = preload("res://src/world/native_chunk_backend.gd")

var _thread := Thread.new()
var _busy: bool = false
var _coordinate: Vector3i = Vector3i.ZERO
var _seed: int = 0
var _started_usec: int = 0
var _edit_snapshots: Dictionary = {}


func is_busy() -> bool:
	return _busy


func coordinate() -> Vector3i:
	return _coordinate


func start(seed: int, coordinate_value: Vector3i, edit_snapshots: Dictionary = {}) -> Error:
	if _busy:
		return ERR_BUSY
	_seed = seed
	_coordinate = coordinate_value
	_edit_snapshots = edit_snapshots.duplicate(true)
	_started_usec = Time.get_ticks_usec()
	_busy = true
	return _thread.start(Callable(self, "_run_build"))


func is_ready() -> bool:
	return _busy and not _thread.is_alive()


func collect() -> Dictionary:
	if not is_ready():
		return {}
	var collected_usec: int = Time.get_ticks_usec()
	var result: Dictionary = _thread.wait_to_finish()
	_busy = false
	result["worker_usec"] = collected_usec - _started_usec
	result["ready_wait_usec"] = maxi(collected_usec - int(result.get("build_finished_usec", collected_usec)), 0)
	return result


func _run_build() -> Dictionary:
	var build_started_usec: int = Time.get_ticks_usec()
	var report: Dictionary = _build()
	var build_finished_usec: int = Time.get_ticks_usec()
	report["build_thread_usec"] = build_finished_usec - build_started_usec
	report["build_finished_usec"] = build_finished_usec
	return report


func _build() -> Dictionary:
	var native_backend := NativeChunkBackend.new()
	if native_backend.is_available():
		var native_report: Dictionary = native_backend.build_chunk(
			_seed,
			_coordinate,
			_edit_snapshots
		)
		if bool(native_report.get("success", false)):
			var native_voxels: PackedByteArray = native_report.get(
				"voxels",
				PackedByteArray()
			)
			if native_voxels.size() == VoxelChunk.VOLUME:
				var chunk := VoxelChunk.new()
				chunk.voxels = native_voxels
				chunk.revision = 1 + int(native_report.get("applied_edits", 0) > 0)
				var collision_started_usec: int = Time.get_ticks_usec()
				native_report["collision_profile"] = TerrainCollisionProfile.build_from_chunk(
					_seed,
					_coordinate,
					_edit_snapshots,
					chunk
				)
				native_report["collision_profile_usec"] = (
					Time.get_ticks_usec() - collision_started_usec
				)
				native_report["coordinate"] = _coordinate
				native_report.erase("voxels")
				return native_report
			native_report["error"] = "Native voxel buffer had an invalid size"
		var fallback: Dictionary = _build_gdscript()
		fallback["native_backend"] = false
		fallback["native_fallback_reason"] = str(native_report.get("error", "unknown"))
		fallback["native_core_version"] = native_backend.core_version()
		return fallback

	var report: Dictionary = _build_gdscript()
	report["native_backend"] = false
	report["native_fallback_reason"] = "native_extension_unavailable"
	return report


func _build_gdscript() -> Dictionary:
	var generation_started_usec: int = Time.get_ticks_usec()
	var chunk: TeknikVoxelChunk = TerrainGenerator.generate_chunk(_seed, _coordinate)
	var generation_usec: int = Time.get_ticks_usec() - generation_started_usec
	var current_edits: Dictionary = _edit_snapshots.get(_coordinate, {})
	var applied_edits: int = _apply_snapshot(chunk, current_edits)
	var world_origin: Vector3i = _coordinate * VoxelChunk.SIZE
	var boundary_columns: Dictionary = {}
	var mesh_started_usec: int = Time.get_ticks_usec()
	var report: Dictionary = GreedyMesher.build_arrays(
		chunk,
		world_origin,
		func(world_position: Vector3i) -> int:
			if world_position.y < world_origin.y:
				return TerrainGenerator.STONE
			if world_position.y >= world_origin.y + VoxelChunk.SIZE:
				return VoxelChunk.AIR
			var neighbor_coordinate := Vector3i(
				floori(float(world_position.x) / float(VoxelChunk.SIZE)),
				_coordinate.y,
				floori(float(world_position.z) / float(VoxelChunk.SIZE))
			)
			if neighbor_coordinate == _coordinate:
				return chunk.get_voxel(world_position - world_origin)
			var column_key := Vector2i(world_position.x, world_position.z)
			var column: Vector2i
			if boundary_columns.has(column_key):
				column = boundary_columns[column_key]
			else:
				column = TerrainGenerator.sample_column(
					_seed,
					world_position.x,
					world_position.z
				)
				boundary_columns[column_key] = column
			var generated: int = TerrainGenerator.material_from_column(
				world_position.y,
				column
			)
			var edits: Dictionary = _edit_snapshots.get(neighbor_coordinate, {})
			if edits.is_empty():
				return generated
			var local: Vector3i = world_position - neighbor_coordinate * VoxelChunk.SIZE
			var index: int = VoxelChunk.index_of(local)
			return int(edits.get(index, generated)),
		func(material: int, world_position: Vector3i) -> Color:
			return TerrainGenerator.fast_surface_color(_seed, material, world_position)
	)
	var mesh_usec: int = Time.get_ticks_usec() - mesh_started_usec
	var collision_started_usec: int = Time.get_ticks_usec()
	report["collision_profile"] = TerrainCollisionProfile.build_from_chunk(
		_seed,
		_coordinate,
		_edit_snapshots,
		chunk
	)
	report["collision_profile_usec"] = Time.get_ticks_usec() - collision_started_usec
	report["generation_usec"] = generation_usec
	report["mesh_worker_usec"] = mesh_usec
	report["boundary_column_count"] = boundary_columns.size()
	report["coordinate"] = _coordinate
	report["applied_edits"] = applied_edits
	return report


func _apply_snapshot(chunk: TeknikVoxelChunk, edits: Dictionary) -> int:
	var applied: int = 0
	for index_variant: Variant in edits.keys():
		var index: int = int(index_variant)
		if index < 0 or index >= VoxelChunk.VOLUME:
			continue
		var material: int = clampi(int(edits[index]), 0, 255)
		if int(chunk.voxels[index]) != material:
			chunk.voxels[index] = material
			applied += 1
	if applied > 0:
		chunk.revision += 1
	return applied
