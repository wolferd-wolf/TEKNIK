extends "res://src/main/procedural_gameplay_main.gd_stream.gd"

const VoxelChunkBiome = preload("res://src/world/voxel_chunk.gd")
const TerrainGeneratorBiome = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesherBiome = preload("res://src/world/greedy_mesher.gd")
const BiomeColorizer = preload("res://src/world/biome_mesh_colorizer.gd")
const BiomeDistantTerrainPlanner = preload("res://src/world/biome_distant_terrain_planner.gd")


func _ready() -> void:
	super._ready()
	_runtime_log.event("info", "world", "biome_visual_pass_ready", {
		"terrain_geometry_unchanged": true,
		"vegetation_untouched": true,
		"distant_palette_matched": true,
		"terrain_texture_atlas": true,
	})


func _build_initial_chunk(coordinate: Vector3i) -> void:
	super._build_initial_chunk(coordinate)
	var terrain: MeshInstance3D = _terrain_nodes.get(coordinate)
	if terrain == null:
		return
	var existing_mesh: ArrayMesh = terrain.mesh as ArrayMesh
	if existing_mesh == null or existing_mesh.get_surface_count() == 0:
		return
	var report: Dictionary = {
		"arrays": existing_mesh.surface_get_arrays(0),
		"packed_faces": terrain.get_meta("packed_faces", PackedInt32Array()),
		"material_sampler": Callable(self, "_texture_material_at"),
	}
	BiomeColorizer.recolor_report(
		report,
		coordinate * VoxelChunkBiome.SIZE,
		WORLD_SEED
	)
	terrain.mesh = GreedyMesherBiome.mesh_from_arrays(report["arrays"])
	if terrain.has_meta("packed_faces"):
		terrain.remove_meta("packed_faces")


func _texture_material_at(world_position: Vector3i) -> int:
	var generated: int = TerrainGeneratorBiome.voxel_at(WORLD_SEED, world_position)
	return _world_edits.get_override(world_position, generated)


func _commit_terrain_chunk(report: Dictionary) -> void:
	var coordinate: Vector3i = report.get("coordinate", Vector3i.ZERO)
	BiomeColorizer.recolor_report(
		report,
		coordinate * VoxelChunkBiome.SIZE,
		WORLD_SEED
	)
	super._commit_terrain_chunk(report)


func _begin_distant_generation() -> void:
	_distant_target = _world_center
	_distant_planner = BiomeDistantTerrainPlanner.new()
	_distant_thread = Thread.new()
	var start_result: Error = _distant_thread.start(
		Callable(_distant_planner, "build").bind(
			WORLD_SEED,
			_distant_target,
			VoxelChunkBiome.SIZE,
			CHUNK_RADIUS,
			DISTANT_WORLD_RADIUS,
			DISTANT_TERRAIN_STEP
		)
	)
	if start_result != OK:
		_runtime_log.event("error", "environment", "biome_distant_worker_start_failed", {
			"center": str(_distant_target),
			"error": error_string(start_result),
		})
		_distant_thread = null
		_distant_planner = null
		return
	_distant_state = DISTANT_GENERATING
	_distant_refresh_pending = false
	_runtime_log.event("info", "environment", "biome_distant_generation_started", {
		"center": str(_distant_target),
		"old_distant_visible": _distant_terrain != null,
	})
