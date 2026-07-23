extends "res://src/main/mobile_shipping_main.gd"

const FeatureDistribution = preload("res://src/world/feature_distribution.gd")

const FOREST_CELL: int = 5
const ROCK_CELL: int = 7
const COVER_CELL: int = 4


func _build_forest() -> void:
	var trunks: Array[Transform3D] = []
	var broadleaf_low: Array[Transform3D] = []
	var broadleaf_high: Array[Transform3D] = []
	var conifer_low: Array[Transform3D] = []
	var conifer_high: Array[Transform3D] = []
	var deadwood: Array[Transform3D] = []
	var world_rect: Rect2i = WorldWindowPlan.active_world_rect(_world_center, CHUNK_RADIUS, VoxelChunk.SIZE, 7)
	var observer: Vector3 = _player.global_position if _player != null else _camera_position()
	var min_cell_x: int = floori(float(world_rect.position.x) / float(FOREST_CELL)) - 1
	var max_cell_x: int = ceili(float(world_rect.end.x) / float(FOREST_CELL)) + 1
	var min_cell_z: int = floori(float(world_rect.position.y) / float(FOREST_CELL)) - 1
	var max_cell_z: int = ceili(float(world_rect.end.y) / float(FOREST_CELL)) + 1

	for cell_z: int in range(min_cell_z, max_cell_z):
		for cell_x: int in range(min_cell_x, max_cell_x):
			if not FeatureDistribution.is_local_winner(WORLD_SEED + 701, cell_x, cell_z):
				continue
			var candidate: Vector2i = FeatureDistribution.candidate_position(WORLD_SEED + 719, cell_x, cell_z, FOREST_CELL)
			if not world_rect.has_point(candidate):
				continue
			var world_x: int = candidate.x
			var world_z: int = candidate.y
			if Vector2(float(world_x) - observer.x, float(world_z) - observer.z).length() < 9.0:
				continue
			if TerrainGenerator.surface_material(WORLD_SEED, world_x, world_z) != TerrainGenerator.GRASS:
				continue
			var slope: int = TerrainGenerator.surface_slope(WORLD_SEED, world_x, world_z)
			if slope > 1 or TerrainGenerator.river_distance(WORLD_SEED, world_x, world_z) < 8.0:
				continue
			var vegetation: Vector3 = TerrainGenerator.vegetation_profile(WORLD_SEED, world_x, world_z)
			var patch: float = FeatureDistribution.forest_patch(WORLD_SEED, world_x, world_z)
			var habitat: float = vegetation.x * smoothstep(0.34, 0.76, patch)
			if habitat < 0.24:
				continue
			var acceptance: float = WorldSeed.sample_unit(WORLD_SEED + 743, cell_x, cell_z)
			if acceptance > lerpf(0.30, 0.94, habitat):
				continue

			var height: int = TerrainGenerator.surface_height(WORLD_SEED, world_x, world_z)
			var climate: Vector2 = TerrainGenerator.climate_at(WORLD_SEED, world_x, world_z)
			var age: float = WorldSeed.sample_unit(WORLD_SEED + 751, cell_x, cell_z)
			var scale: float = lerpf(0.72, 1.34, age) * lerpf(0.86, 1.08, habitat)
			var quarter_turn: int = int(WorldSeed.hash_2d(WORLD_SEED + 769, cell_x, cell_z) % 4)
			var rotation: float = float(quarter_turn) * PI * 0.5
			var ground := Vector3(float(world_x) + 0.5, float(height) + 1.0, float(world_z) + 0.5)
			var trunk_height: float = lerpf(3.8, 6.4, age) * scale
			var trunk_width: float = 0.58 if age < 0.76 else 0.82
			trunks.append(_box_transform(ground + Vector3.UP * trunk_height * 0.5, Vector3(trunk_width, trunk_height, trunk_width), rotation))

			var conifer_bias: float = clampf((0.53 - climate.y) * 1.7 + float(height - 16) * 0.035, 0.0, 1.0)
			var species: float = WorldSeed.sample_unit(WORLD_SEED + 787, cell_x, cell_z)
			if species < conifer_bias:
				conifer_low.append(_box_transform(ground + Vector3.UP * (trunk_height + 0.7 * scale), Vector3(3.8, 1.5, 3.8) * scale, rotation))
				conifer_high.append(_box_transform(ground + Vector3.UP * (trunk_height + 2.0 * scale), Vector3(2.3, 1.4, 2.3) * scale, rotation))
			else:
				broadleaf_low.append(_box_transform(ground + Vector3.UP * (trunk_height + 0.8 * scale), Vector3(4.2, 2.2, 3.8) * scale, rotation))
				broadleaf_high.append(_box_transform(ground + Vector3.UP * (trunk_height + 2.1 * scale), Vector3(2.8, 1.8, 2.8) * scale, rotation))

			if habitat < 0.36 and WorldSeed.sample_unit(WORLD_SEED + 809, cell_x, cell_z) > 0.78:
				deadwood.append(_box_transform(ground + Vector3(0.0, 0.32, 0.0), Vector3(2.8, 0.42, 0.42) * scale, rotation))

	_tree_count = trunks.size()
	_add_tree_multimesh(_voxel_box_mesh(Color("5a402d")), trunks)
	_add_tree_multimesh(_voxel_box_mesh(Color("315f3e")), broadleaf_low)
	_add_tree_multimesh(_voxel_box_mesh(Color("477a4b")), broadleaf_high)
	_add_tree_multimesh(_voxel_box_mesh(Color("234839")), conifer_low)
	_add_tree_multimesh(_voxel_box_mesh(Color("39694a")), conifer_high)
	_add_tree_multimesh(_voxel_box_mesh(Color("4c3829")), deadwood)
	print("WORLD_QA ecological_voxel_trees=", _tree_count, " deadwood=", deadwood.size())


func _build_boulders() -> void:
	var stone: Array[Transform3D] = []
	var world_rect: Rect2i = WorldWindowPlan.active_world_rect(_world_center, CHUNK_RADIUS, VoxelChunk.SIZE, 6)
	var min_x: int = floori(float(world_rect.position.x) / float(ROCK_CELL)) - 1
	var max_x: int = ceili(float(world_rect.end.x) / float(ROCK_CELL)) + 1
	var min_z: int = floori(float(world_rect.position.y) / float(ROCK_CELL)) - 1
	var max_z: int = ceili(float(world_rect.end.y) / float(ROCK_CELL)) + 1
	for cell_z: int in range(min_z, max_z):
		for cell_x: int in range(min_x, max_x):
			if not FeatureDistribution.is_local_winner(WORLD_SEED + 823, cell_x, cell_z):
				continue
			var candidate: Vector2i = FeatureDistribution.candidate_position(WORLD_SEED + 839, cell_x, cell_z, ROCK_CELL)
			if not world_rect.has_point(candidate):
				continue
			var vegetation: Vector3 = TerrainGenerator.vegetation_profile(WORLD_SEED, candidate.x, candidate.y)
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, candidate.x, candidate.y)
			var exposure: float = vegetation.z + clampf(float(height - 16) / 16.0, 0.0, 1.0)
			if WorldSeed.sample_unit(WORLD_SEED + 853, cell_x, cell_z) > 0.18 + exposure * 0.28:
				continue
			if TerrainGenerator.river_distance(WORLD_SEED, candidate.x, candidate.y) < 7.0:
				continue
			var width: float = lerpf(0.7, 1.8, WorldSeed.sample_unit(WORLD_SEED + 877, cell_x, cell_z))
			var depth: float = lerpf(0.7, 1.6, WorldSeed.sample_unit(WORLD_SEED + 881, cell_x, cell_z))
			var rise: float = lerpf(0.45, 1.15, WorldSeed.sample_unit(WORLD_SEED + 907, cell_x, cell_z))
			var rotation: float = float(WorldSeed.hash_2d(WORLD_SEED + 919, cell_x, cell_z) % 4) * PI * 0.5
			stone.append(_box_transform(Vector3(float(candidate.x) + 0.5, float(height) + 1.0 + rise * 0.42, float(candidate.y) + 0.5), Vector3(width, rise, depth), rotation))
	_boulder_count = stone.size()
	_add_tree_multimesh(_voxel_box_mesh(Color("66716d")), stone)


func _build_ground_detail() -> void:
	var lush: Array[Transform3D] = []
	var dry: Array[Transform3D] = []
	var shrubs: Array[Transform3D] = []
	var world_rect: Rect2i = WorldWindowPlan.active_world_rect(_world_center, CHUNK_RADIUS, VoxelChunk.SIZE, 4)
	var min_x: int = floori(float(world_rect.position.x) / float(COVER_CELL)) - 1
	var max_x: int = ceili(float(world_rect.end.x) / float(COVER_CELL)) + 1
	var min_z: int = floori(float(world_rect.position.y) / float(COVER_CELL)) - 1
	var max_z: int = ceili(float(world_rect.end.y) / float(COVER_CELL)) + 1
	for cell_z: int in range(min_z, max_z):
		for cell_x: int in range(min_x, max_x):
			if not FeatureDistribution.is_local_winner(WORLD_SEED + 947, cell_x, cell_z):
				continue
			var candidate: Vector2i = FeatureDistribution.candidate_position(WORLD_SEED + 953, cell_x, cell_z, COVER_CELL)
			if not world_rect.has_point(candidate):
				continue
			if TerrainGenerator.surface_material(WORLD_SEED, candidate.x, candidate.y) != TerrainGenerator.GRASS:
				continue
			if TerrainGenerator.surface_slope(WORLD_SEED, candidate.x, candidate.y) > 1:
				continue
			var vegetation: Vector3 = TerrainGenerator.vegetation_profile(WORLD_SEED, candidate.x, candidate.y)
			var patch: float = FeatureDistribution.understory_patch(WORLD_SEED, candidate.x, candidate.y)
			if patch * vegetation.y < 0.24:
				continue
			var height: int = TerrainGenerator.surface_height(WORLD_SEED, candidate.x, candidate.y)
			var climate: Vector2 = TerrainGenerator.climate_at(WORLD_SEED, candidate.x, candidate.y)
			var scale: float = lerpf(0.45, 0.95, WorldSeed.sample_unit(WORLD_SEED + 977, cell_x, cell_z))
			var rotation: float = float(WorldSeed.hash_2d(WORLD_SEED + 991, cell_x, cell_z) % 4) * PI * 0.5
			var ground := Vector3(float(candidate.x) + 0.5, float(height) + 1.0, float(candidate.y) + 0.5)
			var transform: Transform3D = _box_transform(ground + Vector3.UP * 0.22 * scale, Vector3(0.28, 0.44, 0.28) * scale, rotation)
			if climate.x > 0.48:
				lush.append(transform)
			else:
				dry.append(transform)
			if vegetation.x > 0.54 and patch > 0.68 and WorldSeed.sample_unit(WORLD_SEED + 1009, cell_x, cell_z) > 0.70:
				shrubs.append(_box_transform(ground + Vector3.UP * 0.48, Vector3(1.1, 0.9, 1.1) * scale, rotation))
	_grass_count = lush.size() + dry.size()
	_add_tree_multimesh(_voxel_box_mesh(Color("315f31")), lush, false)
	_add_tree_multimesh(_voxel_box_mesh(Color("71683a")), dry, false)
	_add_tree_multimesh(_voxel_box_mesh(Color("2c5d38")), shrubs, false)


func _box_transform(origin: Vector3, size: Vector3, rotation: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rotation).scaled(size), origin)


func _voxel_box_mesh(color: Color) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = _material(color, 1.0)
	return mesh
