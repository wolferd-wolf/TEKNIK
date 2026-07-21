extends SceneTree

const WorldSeed = preload("res://src/world/world_seed.gd")
const KineticNetwork = preload("res://src/simulation/kinetic_network.gd")
const VoxelChunk = preload("res://src/world/voxel_chunk.gd")
const TerrainGenerator = preload("res://src/world/voxel_terrain_generator.gd")
const GreedyMesher = preload("res://src/world/greedy_mesher.gd")
const ChunkStreamPlan = preload("res://src/world/chunk_stream_plan.gd")
const ChunkStreamState = preload("res://src/world/chunk_stream_state.gd")

var _failures: int = 0


func _init() -> void:
	_test_world_seed()
	_test_voxel_chunk()
	_test_greedy_mesher()
	_test_chunk_stream_plan()
	_test_chunk_stream_state()
	_test_kinetic_network()
	_test_product_constraints()

	if _failures == 0:
		print("TEST_RESULT PASS")
		quit(0)
	else:
		print("TEST_RESULT FAIL count=", _failures)
		quit(1)


func _test_world_seed() -> void:
	var first: int = WorldSeed.hash_2d(42, 100, -25)
	var second: int = WorldSeed.hash_2d(42, 100, -25)
	var neighbor: int = WorldSeed.hash_2d(42, 101, -25)
	_expect(first == second, "world hash is deterministic")
	_expect(first != neighbor, "neighboring coordinates vary")
	var sample: float = WorldSeed.sample_preview_height(42, 4, 7)
	_expect(sample >= 0.0 and sample <= 1.0, "height sample stays normalized")
	var adjacent: float = WorldSeed.sample_preview_height(42, 5, 7)
	_expect(absf(sample - adjacent) < 0.12, "neighboring height noise remains coherent")


func _test_kinetic_network() -> void:
	var network := KineticNetwork.new()
	network.configure_source(20.0, 5.0)
	network.add_consumer(&"press", 2.0, 1.5)
	network.add_consumer(&"belt", -0.5, 1.0)
	var report: Dictionary = network.report()
	_expect(is_equal_approx(float(report.capacity), 100.0), "capacity scales with source RPM")
	_expect(is_equal_approx(float(report.stress), 70.0), "consumer stress uses geared RPM")
	_expect(not bool(report.overstressed), "network remains active under capacity")
	network.add_consumer(&"crusher", 2.0, 2.0)
	_expect(bool(network.report().overstressed), "network reports overload")


func _test_voxel_chunk() -> void:
	var chunk := VoxelChunk.new()
	_expect(chunk.voxels.size() == VoxelChunk.VOLUME, "voxel chunk allocates 32 cubed cells")
	_expect(chunk.set_voxel(Vector3i(2, 3, 4), 7), "voxel mutation succeeds in bounds")
	_expect(chunk.get_voxel(Vector3i(2, 3, 4)) == 7, "voxel mutation round-trips")
	_expect(not chunk.set_voxel(Vector3i(-1, 3, 4), 7), "out-of-bounds mutation is rejected")
	_expect(chunk.get_voxel(Vector3i(-1, 3, 4)) == VoxelChunk.AIR, "out-of-bounds reads are air")
	var generated_a: TeknikVoxelChunk = TerrainGenerator.generate_chunk(99, Vector3i.ZERO)
	var generated_b: TeknikVoxelChunk = TerrainGenerator.generate_chunk(99, Vector3i.ZERO)
	_expect(generated_a.voxels == generated_b.voxels, "voxel terrain is deterministic")
	_expect(generated_a.count_solid() > 0, "voxel terrain contains solid material")
	var negative_chunk: TeknikVoxelChunk = TerrainGenerator.generate_chunk(99, Vector3i(-1, 0, -1))
	_expect(negative_chunk.count_solid() > 0, "negative world coordinates generate terrain")
	var different_seed: TeknikVoxelChunk = TerrainGenerator.generate_chunk(100, Vector3i.ZERO)
	_expect(generated_a.voxels != different_seed.voxels, "world seed changes generated terrain")
	_expect(
		TerrainGenerator.voxel_at(99, Vector3i(0, TerrainGenerator.MAX_SURFACE_HEIGHT + 1, 0)) == VoxelChunk.AIR,
		"world sampler returns air above the terrain budget"
	)
	var cached_column: Vector2i = TerrainGenerator.sample_column(99, 7, -11)
	_expect(
		TerrainGenerator.material_from_column(cached_column.x, cached_column)
		== TerrainGenerator.voxel_at(99, Vector3i(7, cached_column.x, -11)),
		"cached terrain columns preserve voxel sampling"
	)
	var climate_a: Vector2 = TerrainGenerator.climate_at(99, -120, 84)
	var climate_b: Vector2 = TerrainGenerator.climate_at(99, -120, 84)
	_expect(climate_a == climate_b, "terrain climate sampling is deterministic")
	_expect(
		climate_a.x >= 0.0 and climate_a.x <= 1.0
		and climate_a.y >= 0.0 and climate_a.y <= 1.0,
		"terrain climate remains normalized"
	)
	var dry_color: Color = TerrainGenerator.surface_color(
		99, TerrainGenerator.GRASS, Vector3i(-180, 10, -120)
	)
	var wet_color: Color = TerrainGenerator.surface_color(
		99, TerrainGenerator.GRASS, Vector3i(180, 10, 120)
	)
	_expect(dry_color != wet_color, "world-space climate varies terrain color")

	var max_step: int = 0
	var heights_in_budget: bool = true
	for z: int in range(-48, 49):
		for x: int in range(-48, 49):
			var height: int = TerrainGenerator.surface_height(99, x, z)
			heights_in_budget = heights_in_budget and (
				height >= 2 and height <= TerrainGenerator.MAX_SURFACE_HEIGHT
			)
			max_step = maxi(max_step, absi(height - TerrainGenerator.surface_height(99, x + 1, z)))
			max_step = maxi(max_step, absi(height - TerrainGenerator.surface_height(99, x, z + 1)))
	_expect(heights_in_budget, "terrain height stays inside the foundation vertical budget")
	_expect(max_step <= 2, "terrain avoids needle-like neighboring height jumps")
	for x: int in range(-96, 97, 12):
		var river_z: int = roundi(TerrainGenerator.river_center_z(99, x))
		_expect(
			TerrainGenerator.surface_height(99, x, river_z) <= TerrainGenerator.WATER_LEVEL - 2,
			"river channel remains continuously carved below water"
		)


func _test_greedy_mesher() -> void:
	var chunk := VoxelChunk.new()
	chunk.set_voxel(Vector3i(4, 4, 4), 1)
	var single: Dictionary = GreedyMesher.build_mesh(chunk)
	_expect(int(single.quads) == 6, "one voxel produces six greedy quads")
	_expect(int(single.triangles) == 12, "one voxel produces twelve triangles")
	chunk.set_voxel(Vector3i(5, 4, 4), 1)
	var joined: Dictionary = GreedyMesher.build_mesh(chunk)
	_expect(int(joined.quads) == 6, "adjacent equal voxels merge into a cuboid")
	var solid := VoxelChunk.new(1)
	var solid_mesh: Dictionary = GreedyMesher.build_mesh(solid)
	_expect(int(solid_mesh.quads) == 6, "solid chunk collapses to six boundary quads")
	var tint_calls: Array[int] = [0]
	var tinted: Dictionary = GreedyMesher.build_mesh(
		chunk,
		Vector3i(32, 0, -32),
		Callable(),
		func(_material: int, _position: Vector3i) -> Color:
			tint_calls[0] += 1
			return Color.MAGENTA
	)
	_expect(tint_calls[0] == int(tinted.vertices), "greedy mesher samples climate color at every vertex")


func _test_chunk_stream_plan() -> void:
	var priority := Vector3i(-2, 0, 1)
	var plan: Array[Vector3i] = ChunkStreamPlan.ordered_square(Vector3i.ZERO, 3, priority)
	_expect(plan.size() == 49, "chunk stream plan covers the active square")
	_expect(plan[0] == priority, "chunk stream plan loads nearest terrain first")
	var unique: Dictionary = {}
	for coordinate: Vector3i in plan:
		unique[coordinate] = true
	_expect(unique.size() == plan.size(), "chunk stream plan contains no duplicates")
	var active: Array[Vector3i] = [
		Vector3i.ZERO, Vector3i(4, 0, 0), Vector3i(-2, 0, -5)
	]
	var outside: Array[Vector3i] = ChunkStreamPlan.outside_square(
		active,
		Vector3i.ZERO,
		3
	)
	_expect(outside == [Vector3i(4, 0, 0), Vector3i(-2, 0, -5)], "stream plan identifies chunks to unload")


func _test_chunk_stream_state() -> void:
	var state: TeknikChunkStreamState = ChunkStreamState.new()
	var initial: Dictionary = state.reconcile(Vector3i.ZERO, 3, Vector3i.ZERO)
	var initial_load: Array[Vector3i] = initial.load
	_expect(initial_load.size() == 49, "empty residency state requests the complete active window")
	for coordinate: Vector3i in initial_load:
		state.mark_loaded(coordinate)
	_expect(state.active_count() == 49, "residency state tracks loaded chunks")

	var shifted: Dictionary = state.reconcile(Vector3i(1, 0, 0), 3, Vector3i(1, 0, 0))
	var shifted_load: Array[Vector3i] = shifted.load
	var shifted_unload: Array[Vector3i] = shifted.unload
	_expect(shifted_load.size() == 7, "one-chunk movement loads only the new edge")
	_expect(shifted_unload.size() == 7, "one-chunk movement unloads only the old edge")
	for coordinate: Vector3i in shifted_unload:
		state.mark_unloaded(coordinate)
	for coordinate: Vector3i in shifted_load:
		state.mark_loaded(coordinate)
	_expect(state.active_count() == 49, "shifted residency preserves the chunk budget")
	_expect(state.has(Vector3i(4, 0, 0)), "shifted residency contains the new leading edge")
	_expect(not state.has(Vector3i(-3, 0, 0)), "shifted residency releases the trailing edge")


func _test_product_constraints() -> void:
	var project_text: String = FileAccess.get_file_as_string("res://project.godot").to_lower()
	_expect(project_text.find("creative") == -1, "project exposes no creative mode")
	_expect(ProjectSettings.get_setting("physics/common/physics_ticks_per_second") == 30, "physics rate is mobile-budgeted")
	_expect(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "mobile", "mobile renderer is selected")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)
